#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import threading
import time
import uuid
import webbrowser
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, List, Optional
from urllib.parse import parse_qs, urlparse


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
INVOKE_SCRIPT = SCRIPT_DIR / "invoke-siemens-plc-dev.ps1"
MAX_TREE_DEPTH = 5
MAX_TREE_ENTRIES = 500
MAX_TEXT_BYTES = 512 * 1024

JOBS: Dict[str, Dict[str, Any]] = {}
JOBS_LOCK = threading.Lock()


def now_iso() -> str:
    return datetime.now().replace(microsecond=0).isoformat()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Visual console for Siemens TIA PLC development workflows.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8788)
    parser.add_argument("--project", default="")
    parser.add_argument("--open", action="store_true", help="Open the console in the default browser.")
    return parser.parse_args()


def path_from_query(value: str, fallback: str = "") -> Path:
    raw = value or fallback
    if not raw:
        raise ValueError("Missing path")
    return Path(raw).expanduser().resolve()


def project_dir(project_path: str) -> Path:
    path = path_from_query(project_path)
    if path.is_file():
        return path.parent
    return path


def is_under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def read_text(path: Path) -> str:
    data = path.read_bytes()
    if len(data) > MAX_TEXT_BYTES:
        data = data[:MAX_TEXT_BYTES] + b"\n\n[truncated]\n"
    for encoding in ("utf-8-sig", "utf-8", "gb18030", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def detect_project_files(root: Path) -> List[str]:
    suffixes = {f".ap{version}" for version in range(16, 22)}
    return [str(p) for p in sorted(root.glob("*")) if p.is_file() and p.suffix.lower() in suffixes]


def build_tree(root: Path) -> Dict[str, Any]:
    count = 0
    interesting_ext = {
        ".ap16", ".ap17", ".ap18", ".ap19", ".ap20", ".ap21",
        ".xml", ".scl", ".db", ".udt", ".json", ".md", ".txt", ".csv", ".xlsx",
        ".ps1", ".py",
    }
    skip_dirs = {".git", "__pycache__", ".session-cache", "bin", "obj"}

    def walk(path: Path, depth: int) -> Dict[str, Any]:
        nonlocal count
        count += 1
        node = {
            "name": path.name or str(path),
            "path": str(path),
            "type": "directory" if path.is_dir() else "file",
            "children": [],
        }
        if count > MAX_TREE_ENTRIES:
            node["truncated"] = True
            return node
        if not path.is_dir() or depth >= MAX_TREE_DEPTH:
            return node
        children = []
        try:
            items = sorted(path.iterdir(), key=lambda item: (item.is_file(), item.name.lower()))
        except OSError:
            return node
        for item in items:
            if item.is_dir() and item.name in skip_dirs:
                continue
            if item.is_file() and item.suffix.lower() not in interesting_ext:
                continue
            children.append(walk(item, depth + 1))
            if count > MAX_TREE_ENTRIES:
                break
        node["children"] = children
        return node

    return walk(root, 0)


def list_runs(root: Path) -> List[Dict[str, Any]]:
    runs_root = root / "PLC_Code" / "runs"
    if not runs_root.exists():
        return []
    rows = []
    for item in sorted(runs_root.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)[:30]:
        if not item.is_dir():
            continue
        report = item / "workflow-report.json"
        current_step = item / "current-step.json"
        rows.append({
            "name": item.name,
            "path": str(item),
            "mtime": datetime.fromtimestamp(item.stat().st_mtime).isoformat(timespec="seconds"),
            "reportPath": str(report) if report.exists() else "",
            "currentStepPath": str(current_step) if current_step.exists() else "",
        })
    return rows


def latest_block_list(root: Path) -> str:
    runs = list_runs(root)
    for run in runs:
        candidate = Path(run["path"]) / "reports" / "block-list.txt"
        if candidate.exists():
            return read_text(candidate)
    return ""


def ai_prompt(project_root: Path, message: str) -> Dict[str, Any]:
    out_dir = project_root / "PLC_Code" / "ai-prompts"
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = out_dir / f"codex-task-{stamp}.md"
    block_list = latest_block_list(project_root)
    runs = list_runs(project_root)[:8]
    content = "\n".join([
        "# Codex PLC Task",
        "",
        f"Created: {now_iso()}",
        f"Project: `{project_root}`",
        "",
        "## User Request",
        "",
        message.strip(),
        "",
        "## Recent Runs",
        "",
        json.dumps(runs, ensure_ascii=False, indent=2),
        "",
        "## Latest Block List",
        "",
        "```text",
        block_list[:12000],
        "```",
        "",
        "## Suggested Codex Workflow",
        "",
        "1. Run `read-cycle -Attach -SkipExport` if project structure is stale.",
        "2. Edit exported LAD XML, LAD JSON specs, SCL sources, or DB sources.",
        "3. Use `write-cycle` for cloned import/compile verification before applying to the real project.",
    ])
    path.write_text(content, encoding="utf-8")
    reply = (
        "已生成一份 Codex 任务草稿，并自动带上最近运行记录和块列表。"
        "当前窗口先作为本地工程驾驶舱使用；真正的代码生成与审查仍建议交给 Codex 主对话执行。"
    )
    return {"reply": reply, "promptPath": str(path)}


def command_args(command: str, body: Dict[str, Any], project: Path) -> List[str]:
    if command == "doctor":
        return ["doctor", "-ProjectPath", str(project)]
    if command == "read-cycle-skip":
        args = ["read-cycle", "-ProjectPath", str(project), "-Attach", "-SkipExport"]
        return args
    if command == "read-cycle-full":
        args = ["read-cycle", "-ProjectPath", str(project), "-Attach"]
        return args
    if command == "list-blocks":
        plc = body.get("plcName") or "PLC_1"
        return ["list-blocks", "--project", str(project), "--plc", plc, "--attach"]
    if command == "write-cycle":
        input_xml = str(body.get("inputXml") or "").strip()
        if not input_xml:
            raise ValueError("write-cycle requires inputXml")
        plc = body.get("plcName") or "PLC_1"
        timeout = str(body.get("stepTimeoutSeconds") or "300")
        return [
            "write-cycle", "-ProjectPath", str(project), "-InputXml", input_xml,
            "-PlcName", plc, "-StepTimeoutSeconds", timeout,
        ]
    raise ValueError(f"Unsupported command: {command}")


def start_job(command: str, args: List[str], project: Path) -> Dict[str, Any]:
    job_id = uuid.uuid4().hex[:12]
    job_root = project / "PLC_Code" / "console-jobs"
    job_root.mkdir(parents=True, exist_ok=True)
    stdout_path = job_root / f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{command}-{job_id}.log"
    stderr_path = job_root / f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{command}-{job_id}.err.log"
    ps_args = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(INVOKE_SCRIPT)] + args
    stdout_handle = stdout_path.open("w", encoding="utf-8", errors="replace")
    stderr_handle = stderr_path.open("w", encoding="utf-8", errors="replace")
    process = subprocess.Popen(ps_args, stdout=stdout_handle, stderr=stderr_handle, cwd=str(project))
    stdout_handle.close()
    stderr_handle.close()
    job = {
        "id": job_id,
        "command": command,
        "args": args,
        "pid": process.pid,
        "startedAt": now_iso(),
        "status": "running",
        "exitCode": None,
        "stdoutPath": str(stdout_path),
        "stderrPath": str(stderr_path),
    }

    def watch() -> None:
        exit_code = process.wait()
        with JOBS_LOCK:
            current = JOBS.get(job_id)
            if current:
                current["status"] = "passed" if exit_code == 0 else "failed"
                current["exitCode"] = exit_code
                current["completedAt"] = now_iso()

    with JOBS_LOCK:
        JOBS[job_id] = job
    threading.Thread(target=watch, daemon=True).start()
    return job


HTML = r"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Siemens TIA PLC Dev Console</title>
  <style>
    :root {
      --ink: #122022;
      --muted: #667271;
      --panel: rgba(250, 248, 240, 0.88);
      --line: rgba(26, 44, 42, 0.14);
      --accent: #e26d2d;
      --accent-2: #0e7c7b;
      --good: #25845a;
      --bad: #b84235;
      --code: #102624;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      font-family: Bahnschrift, "Microsoft YaHei UI", "Microsoft YaHei", sans-serif;
      background:
        radial-gradient(circle at 12% 15%, rgba(226, 109, 45, 0.22), transparent 28rem),
        radial-gradient(circle at 92% 4%, rgba(14, 124, 123, 0.22), transparent 34rem),
        linear-gradient(135deg, #f6f1e4 0%, #dfe8df 52%, #cbd8d1 100%);
    }
    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 1rem;
      padding: 1rem 1.25rem;
      border-bottom: 1px solid var(--line);
      backdrop-filter: blur(18px);
    }
    h1 { margin: 0; font-size: clamp(1.25rem, 2vw, 2rem); letter-spacing: 0.02em; }
    .subtitle { color: var(--muted); font-size: 0.92rem; margin-top: 0.2rem; }
    .project-bar { display: flex; gap: 0.5rem; min-width: min(48rem, 60vw); }
    input, textarea, button, select {
      font: inherit;
      border-radius: 0.8rem;
      border: 1px solid var(--line);
    }
    input, textarea {
      width: 100%;
      padding: 0.75rem 0.85rem;
      background: rgba(255,255,255,0.72);
      color: var(--ink);
      outline: none;
    }
    button {
      border: none;
      padding: 0.72rem 0.9rem;
      background: var(--ink);
      color: #fff8ea;
      cursor: pointer;
      box-shadow: 0 0.45rem 1.2rem rgba(18,32,34,0.14);
      transition: transform 0.12s ease, opacity 0.12s ease;
      white-space: nowrap;
    }
    button:hover { transform: translateY(-1px); }
    button.secondary { background: var(--accent-2); }
    button.warn { background: var(--accent); }
    main {
      display: grid;
      grid-template-columns: 23rem minmax(20rem, 1fr) 26rem;
      gap: 1rem;
      padding: 1rem;
      height: calc(100vh - 5rem);
    }
    section {
      min-height: 0;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 1.15rem;
      overflow: hidden;
      box-shadow: 0 1rem 3rem rgba(28, 45, 42, 0.12);
    }
    .panel-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.8rem;
      padding: 0.9rem 1rem;
      border-bottom: 1px solid var(--line);
      background: rgba(255,255,255,0.32);
    }
    .panel-head h2 { margin: 0; font-size: 1rem; letter-spacing: 0.04em; }
    .panel-body { height: calc(100% - 3.6rem); overflow: auto; padding: 0.9rem; }
    .tree ul { list-style: none; margin: 0; padding-left: 1rem; }
    .tree li { margin: 0.25rem 0; }
    .tree button {
      width: 100%;
      color: var(--ink);
      background: transparent;
      box-shadow: none;
      text-align: left;
      padding: 0.28rem 0.35rem;
      white-space: normal;
    }
    .tree button:hover { background: rgba(14,124,123,0.09); transform: none; }
    .tag {
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      padding: 0.2rem 0.5rem;
      border-radius: 999px;
      background: rgba(18,32,34,0.08);
      color: var(--muted);
      font-size: 0.78rem;
    }
    .actions { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.6rem; margin-bottom: 0.8rem; }
    .log-list { display: grid; gap: 0.5rem; margin-bottom: 0.8rem; }
    .run-card {
      border: 1px solid var(--line);
      background: rgba(255,255,255,0.48);
      border-radius: 0.9rem;
      padding: 0.7rem;
      cursor: pointer;
    }
    .run-card:hover { border-color: rgba(14,124,123,0.45); }
    pre {
      margin: 0;
      min-height: 12rem;
      padding: 0.9rem;
      border-radius: 0.9rem;
      background: var(--code);
      color: #d7f1dc;
      overflow: auto;
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 0.82rem;
      line-height: 1.45;
      white-space: pre-wrap;
    }
    .chat { display: flex; flex-direction: column; gap: 0.75rem; height: 100%; }
    .messages {
      flex: 1;
      overflow: auto;
      display: flex;
      flex-direction: column;
      gap: 0.65rem;
    }
    .bubble {
      padding: 0.75rem 0.85rem;
      border-radius: 1rem;
      background: rgba(255,255,255,0.58);
      border: 1px solid var(--line);
      line-height: 1.5;
    }
    .bubble.user { background: rgba(226,109,45,0.13); }
    .bubble.ai { background: rgba(14,124,123,0.13); }
    .chat-input { display: grid; gap: 0.55rem; }
    textarea { min-height: 7rem; resize: vertical; }
    .small { color: var(--muted); font-size: 0.82rem; line-height: 1.45; }
    @media (max-width: 1100px) {
      header { align-items: stretch; flex-direction: column; }
      .project-bar { min-width: 0; width: 100%; }
      main { grid-template-columns: 1fr; height: auto; }
      section { min-height: 28rem; }
    }
  </style>
</head>
<body>
  <header>
    <div>
      <h1>Siemens TIA PLC Dev Console</h1>
      <div class="subtitle">项目结构、日志、AI 任务草稿和 Openness 工作流集中在一个窗口里</div>
    </div>
    <div class="project-bar">
      <input id="projectPath" placeholder="项目路径，例如 D:\plc\手动程序">
      <button class="secondary" id="loadBtn">加载项目</button>
    </div>
  </header>
  <main>
    <section>
      <div class="panel-head"><h2>项目结构</h2><span id="projectMeta" class="tag">未加载</span></div>
      <div class="panel-body tree" id="tree"></div>
    </section>
    <section>
      <div class="panel-head"><h2>工作流与日志</h2><span id="jobStatus" class="tag">idle</span></div>
      <div class="panel-body">
        <div class="actions">
          <button data-command="doctor">Doctor 检查</button>
          <button data-command="read-cycle-skip" class="secondary">快速读取</button>
          <button data-command="read-cycle-full" class="warn">完整导出</button>
          <button data-command="list-blocks">列程序块</button>
        </div>
        <input id="inputXml" placeholder="write-cycle 输入 XML 路径，可从左侧点击 XML 文件后自动填入">
        <div class="actions" style="margin-top:0.6rem">
          <button data-command="write-cycle" class="warn">克隆验证 LAD</button>
          <button id="refreshBtn" class="secondary">刷新日志</button>
        </div>
        <div class="small">写入验证默认不会直接修改主工程；它会走克隆导入、编译、回导出和报告。</div>
        <h3>最近 runs</h3>
        <div id="runs" class="log-list"></div>
        <h3>文件/日志预览</h3>
        <pre id="preview">等待加载...</pre>
      </div>
    </section>
    <section>
      <div class="panel-head"><h2>AI 对话区</h2><span class="tag">Codex-ready</span></div>
      <div class="panel-body chat">
        <div id="messages" class="messages">
          <div class="bubble ai">告诉我你想改什么 PLC 逻辑。我会生成一份带项目上下文的 Codex 任务草稿，方便继续在主对话里执行代码生成、LAD 修改和验证。</div>
        </div>
        <div class="chat-input">
          <textarea id="aiMessage" placeholder="例如：把 FC5 自动流程加上取料超时报警，并用 LAD 写入后做克隆编译验证。"></textarea>
          <button id="sendAi" class="secondary">生成 Codex 任务草稿</button>
        </div>
      </div>
    </section>
  </main>
  <script>
    const initialProject = "__PROJECT__";
    const projectPath = document.getElementById("projectPath");
    const tree = document.getElementById("tree");
    const runs = document.getElementById("runs");
    const preview = document.getElementById("preview");
    const projectMeta = document.getElementById("projectMeta");
    const jobStatus = document.getElementById("jobStatus");
    const inputXml = document.getElementById("inputXml");
    const messages = document.getElementById("messages");
    const aiMessage = document.getElementById("aiMessage");
    projectPath.value = initialProject;

    async function api(path, options = {}) {
      const res = await fetch(path, options);
      const text = await res.text();
      let body;
      try { body = JSON.parse(text); } catch { body = { text }; }
      if (!res.ok) throw new Error(body.error || text);
      return body;
    }

    function escapeHtml(text) {
      return String(text).replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
    }

    function renderTree(node) {
      const icon = node.type === "directory" ? "▸" : "•";
      const html = `<button data-path="${escapeHtml(node.path)}" data-type="${node.type}">${icon} ${escapeHtml(node.name)}</button>`;
      const children = node.children && node.children.length
        ? `<ul>${node.children.map(renderTree).join("")}</ul>` : "";
      return `<li>${html}${children}</li>`;
    }

    async function loadProject() {
      const p = encodeURIComponent(projectPath.value.trim());
      tree.innerHTML = "加载中...";
      const state = await api(`/api/state?projectPath=${p}`);
      projectMeta.textContent = `${state.projectFiles.length || 0} 个 TIA 项目文件`;
      tree.innerHTML = `<ul>${renderTree(state.tree)}</ul>`;
      renderRuns(state.runs);
      preview.textContent = state.latestBlockList || "没有找到最近的 block-list.txt，可先运行快速读取。";
    }

    function renderRuns(items) {
      runs.innerHTML = items.length ? "" : "<div class='small'>暂无 runs</div>";
      for (const run of items) {
        const div = document.createElement("div");
        div.className = "run-card";
        div.innerHTML = `<strong>${escapeHtml(run.name)}</strong><br><span class="small">${escapeHtml(run.mtime)}</span>`;
        div.onclick = () => openPath(run.reportPath || run.currentStepPath || run.path);
        runs.appendChild(div);
      }
    }

    async function openPath(path) {
      if (!path) return;
      const p = encodeURIComponent(projectPath.value.trim());
      const target = encodeURIComponent(path);
      const file = await api(`/api/file?projectPath=${p}&path=${target}`);
      preview.textContent = file.text;
      if (path.toLowerCase().endsWith(".xml")) inputXml.value = path;
    }

    tree.addEventListener("click", e => {
      const btn = e.target.closest("button[data-path]");
      if (!btn || btn.dataset.type !== "file") return;
      openPath(btn.dataset.path).catch(err => preview.textContent = err.message);
    });

    async function runCommand(command) {
      jobStatus.textContent = "starting";
      const body = { command, projectPath: projectPath.value.trim(), inputXml: inputXml.value.trim(), stepTimeoutSeconds: 300 };
      const job = await api("/api/run", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
      jobStatus.textContent = `${job.command} #${job.id}`;
      preview.textContent = `已启动 ${job.command}\nPID: ${job.pid}\n日志: ${job.stdoutPath}\n错误: ${job.stderrPath}`;
      pollJob(job.id);
    }

    async function pollJob(id) {
      const job = await api(`/api/job?id=${encodeURIComponent(id)}`);
      jobStatus.textContent = `${job.command}: ${job.status}`;
      if (job.stdoutTail) preview.textContent = job.stdoutTail + (job.stderrTail ? `\n\n[stderr]\n${job.stderrTail}` : "");
      if (job.status === "running") setTimeout(() => pollJob(id), 1500);
      else loadProject().catch(() => {});
    }

    document.querySelectorAll("button[data-command]").forEach(btn => {
      btn.onclick = () => runCommand(btn.dataset.command).catch(err => { jobStatus.textContent = "error"; preview.textContent = err.message; });
    });
    document.getElementById("loadBtn").onclick = () => loadProject().catch(err => preview.textContent = err.message);
    document.getElementById("refreshBtn").onclick = () => loadProject().catch(err => preview.textContent = err.message);
    document.getElementById("sendAi").onclick = async () => {
      const text = aiMessage.value.trim();
      if (!text) return;
      messages.insertAdjacentHTML("beforeend", `<div class="bubble user">${escapeHtml(text)}</div>`);
      aiMessage.value = "";
      const res = await api("/api/ai", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ projectPath: projectPath.value.trim(), message: text }) });
      messages.insertAdjacentHTML("beforeend", `<div class="bubble ai">${escapeHtml(res.reply)}<br><br><span class="small">${escapeHtml(res.promptPath)}</span></div>`);
      messages.scrollTop = messages.scrollHeight;
    };
    loadProject().catch(err => preview.textContent = err.message);
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "PLCDevConsole/0.1"

    def send_json(self, data: Any, status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, text: str, content_type: str = "text/html; charset=utf-8") -> None:
        body = text.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_body(self) -> Dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8") if length else "{}"
        return json.loads(raw or "{}")

    def handle_error(self, exc: Exception) -> None:
        self.send_json({"error": str(exc)}, status=500)

    def do_GET(self) -> None:
        try:
            parsed = urlparse(self.path)
            query = parse_qs(parsed.query)
            if parsed.path == "/":
                project = getattr(self.server, "default_project", "")
                self.send_text(HTML.replace("__PROJECT__", project.replace("\\", "\\\\")))
                return
            if parsed.path == "/api/state":
                root = project_dir(query.get("projectPath", [""])[0] or getattr(self.server, "default_project", ""))
                self.send_json({
                    "projectRoot": str(root),
                    "projectFiles": detect_project_files(root),
                    "tree": build_tree(root),
                    "runs": list_runs(root),
                    "latestBlockList": latest_block_list(root),
                })
                return
            if parsed.path == "/api/file":
                root = project_dir(query.get("projectPath", [""])[0] or getattr(self.server, "default_project", ""))
                target = path_from_query(query.get("path", [""])[0])
                allowed_roots = [root, root / "PLC_Code", SKILL_DIR]
                if not any(is_under(target, allowed) or target == allowed for allowed in allowed_roots):
                    raise ValueError("Refusing to read a file outside the project or skill directory")
                if target.is_dir():
                    text = "\n".join(item.name for item in sorted(target.iterdir(), key=lambda p: p.name.lower()))
                else:
                    text = read_text(target)
                self.send_json({"path": str(target), "text": text})
                return
            if parsed.path == "/api/job":
                job_id = query.get("id", [""])[0]
                with JOBS_LOCK:
                    job = dict(JOBS.get(job_id) or {})
                if not job:
                    raise ValueError("Job not found")
                for key, out_key in (("stdoutPath", "stdoutTail"), ("stderrPath", "stderrTail")):
                    path = Path(job[key])
                    if path.exists():
                        text = read_text(path)
                        job[out_key] = text[-20000:]
                self.send_json(job)
                return
            self.send_json({"error": "Not found"}, status=404)
        except Exception as exc:
            self.handle_error(exc)

    def do_POST(self) -> None:
        try:
            parsed = urlparse(self.path)
            body = self.read_body()
            if parsed.path == "/api/run":
                command = str(body.get("command") or "").strip()
                root = project_dir(body.get("projectPath") or getattr(self.server, "default_project", ""))
                args = command_args(command, body, root)
                self.send_json(start_job(command, args, root))
                return
            if parsed.path == "/api/ai":
                root = project_dir(body.get("projectPath") or getattr(self.server, "default_project", ""))
                message = str(body.get("message") or "").strip()
                if not message:
                    raise ValueError("Message is empty")
                self.send_json(ai_prompt(root, message))
                return
            self.send_json({"error": "Not found"}, status=404)
        except Exception as exc:
            self.handle_error(exc)

    def log_message(self, format: str, *args: Any) -> None:
        sys_msg = "%s - %s" % (self.address_string(), format % args)
        print(sys_msg)


def main() -> int:
    args = parse_args()
    if not INVOKE_SCRIPT.exists():
        raise FileNotFoundError(f"Missing invoke script: {INVOKE_SCRIPT}")
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.default_project = str(path_from_query(args.project)) if args.project else ""
    url = f"http://{args.host}:{args.port}"
    print(json.dumps({"url": url, "project": server.default_project, "script": str(Path(__file__).resolve())}, ensure_ascii=False))
    if args.open:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
