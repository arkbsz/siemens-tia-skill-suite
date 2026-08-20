#!/usr/bin/env python3
import argparse
import json
import locale
import queue
import subprocess
import sys
import threading
import time
import uuid
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse


SCRIPT_DIR = Path(__file__).resolve().parent
INVOKE_SCRIPT = SCRIPT_DIR / "invoke-siemens-plc-dev.ps1"
SESSION_ROOT = SCRIPT_DIR / ".session-cache"
DEFAULT_TIMEOUT_SECONDS = 600
DEFAULT_SESSION_STARTUP_TIMEOUT_SECONDS = 120
MAX_TIMEOUT_SECONDS = 3600
PREFERRED_ENCODING = locale.getpreferredencoding(False) or "utf-8"

ALLOWED_COMMANDS = {
    "route-info",
    "create-project",
    "hold-project",
    "list-devices",
    "list-plcs",
    "list-blocks",
    "export-blocks",
    "import-blocks",
    "compile-plc",
    "inspect-lad",
    "validate-lad",
    "summarize-lad",
    "patch-lad-network",
    "prepare-release",
    "apply-release",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Local REST bridge for Siemens TIA Portal Openness workflows.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--powershell", default="powershell.exe")
    parser.add_argument("--default-timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS)
    return parser.parse_args()


def clamp_timeout(value: Any, default_seconds: int) -> int:
    if value is None:
        return default_seconds
    try:
        seconds = int(value)
    except (TypeError, ValueError):
        return default_seconds
    if seconds < 1:
        return default_seconds
    return min(seconds, MAX_TIMEOUT_SECONDS)


def to_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return False


def require(body: Dict[str, Any], key: str) -> Any:
    value = body.get(key)
    if value is None or (isinstance(value, str) and not value.strip()):
        raise ValueError(f"Missing required field: {key}")
    return value


def canonical_project_path(value: str) -> str:
    return str(Path(value).expanduser().resolve())


def parse_json_if_possible(text: str) -> Optional[Any]:
    stripped = text.strip()
    if not stripped:
        return None
    if stripped[0] not in "[{":
        return None
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        return None


def parse_event_lines(stdout: str) -> List[Dict[str, Any]]:
    events: List[Dict[str, Any]] = []
    for raw_line in stdout.splitlines():
        line = raw_line.rstrip()
        if not line:
            continue
        parts = line.split("\t")
        event = {"tag": parts[0], "fields": parts[1:], "raw": line}
        events.append(event)
    return events


def parse_list_plcs(stdout: str) -> Dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.strip()]
    rows: List[Dict[str, str]] = []
    header_index = -1
    for index, line in enumerate(lines):
        if line.startswith("Device\tItemPath\tSoftware"):
            header_index = index
            break
    if header_index == -1:
        return {"rows": rows}
    for line in lines[header_index + 1:]:
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        rows.append({"device": parts[0], "itemPath": parts[1], "software": parts[2]})
    return {"rows": rows}


def parse_list_devices(stdout: str) -> Dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.strip()]
    rows: List[Dict[str, Any]] = []
    header_index = -1
    for index, line in enumerate(lines):
        if line.startswith("Name\tTypeIdentifier"):
            header_index = index
            break
    if header_index == -1:
        return {"rows": rows}
    for line in lines[header_index + 1:]:
        raw_name, _, type_identifier = line.partition("\t")
        indent = len(raw_name) - len(raw_name.lstrip(" "))
        rows.append(
            {
                "level": indent // 2,
                "name": raw_name.strip(),
                "typeIdentifier": type_identifier.strip(),
                "raw": line,
            }
        )
    return {"rows": rows}


def parse_list_blocks(stdout: str) -> Dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.strip()]
    sections: List[Dict[str, Any]] = []
    current: Optional[Dict[str, Any]] = None
    for line in lines:
        if line.startswith("# PLC\t"):
            parts = line.split("\t")
            current = {
                "device": parts[1] if len(parts) > 1 else "",
                "itemPath": parts[2] if len(parts) > 2 else "",
                "software": parts[3] if len(parts) > 3 else "",
                "blocks": [],
            }
            sections.append(current)
            continue
        if line.startswith("Name\tType\tNumber\tLanguage\tGroup\tConsistent\tKnowHowProtected"):
            continue
        if current is None:
            continue
        parts = line.split("\t")
        if len(parts) < 7:
            continue
        current["blocks"].append(
            {
                "name": parts[0],
                "type": parts[1],
                "number": parts[2],
                "language": parts[3],
                "group": parts[4],
                "consistent": parts[5],
                "knowHowProtected": parts[6],
            }
        )
    return {"sections": sections}


def parse_common_output(command: str, stdout: str) -> Dict[str, Any]:
    parsed_json = parse_json_if_possible(stdout)
    if parsed_json is not None:
        return {"json": parsed_json}
    if command == "list-plcs":
        return parse_list_plcs(stdout)
    if command == "list-devices":
        return parse_list_devices(stdout)
    if command == "list-blocks":
        return parse_list_blocks(stdout)
    return {"events": parse_event_lines(stdout)}


def build_command_from_body(path: str, body: Dict[str, Any]) -> Tuple[List[str], str]:
    if path == "/route-info":
        return ["route-info"], "route-info"
    if path == "/api/v1/command":
        command = require(body, "command")
        if command not in ALLOWED_COMMANDS:
            raise ValueError(f"Unsupported command: {command}")
        args = body.get("args", [])
        if not isinstance(args, list):
            raise ValueError("Field 'args' must be a list.")
        return [command] + [str(item) for item in args], str(command)
    if path == "/api/v1/tia/create-project":
        args = ["create-project", "--name", str(require(body, "name"))]
        if body.get("directory"):
            args += ["--directory", str(body["directory"])]
        if body.get("deviceType"):
            args += ["--device-type", str(body["deviceType"])]
        if body.get("deviceItemType"):
            args += ["--device-item-type", str(body["deviceItemType"])]
        if body.get("itemName"):
            args += ["--item-name", str(body["itemName"])]
        if body.get("deviceName"):
            args += ["--device-name", str(body["deviceName"])]
        return args, "create-project"
    if path == "/api/v1/tia/list-devices":
        return ["list-devices", "--project", str(require(body, "projectPath"))], "list-devices"
    if path == "/api/v1/tia/list-plcs":
        return ["list-plcs", "--project", str(require(body, "projectPath"))], "list-plcs"
    if path == "/api/v1/tia/list-blocks":
        args = ["list-blocks", "--project", str(require(body, "projectPath"))]
        if body.get("plc"):
            args += ["--plc", str(body["plc"])]
        return args, "list-blocks"
    if path == "/api/v1/tia/export-blocks":
        args = ["export-blocks", "--project", str(require(body, "projectPath"))]
        if body.get("plc"):
            args += ["--plc", str(body["plc"])]
        if body.get("block"):
            args += ["--block", str(body["block"])]
        if body.get("language"):
            args += ["--language", str(body["language"])]
        if body.get("outputPath"):
            args += ["--output", str(body["outputPath"])]
        if to_bool(body.get("includeInconsistent")):
            args += ["--include-inconsistent"]
        return args, "export-blocks"
    if path == "/api/v1/tia/import-blocks":
        args = [
            "import-blocks",
            "--project",
            str(require(body, "projectPath")),
            "--input",
            str(require(body, "inputPath")),
        ]
        if body.get("plc"):
            args += ["--plc", str(body["plc"])]
        if body.get("group"):
            args += ["--group", str(body["group"])]
        if to_bool(body.get("apply")):
            args += ["--apply"]
        if to_bool(body.get("noSave")):
            args += ["--no-save"]
        return args, "import-blocks"
    if path == "/api/v1/tia/compile-plc":
        args = ["compile-plc", "--project", str(require(body, "projectPath"))]
        if body.get("plc"):
            args += ["--plc", str(body["plc"])]
        if to_bool(body.get("save")):
            args += ["--save"]
        return args, "compile-plc"
    if path == "/api/v1/lad/summarize":
        return [
            "summarize-lad",
            "-Path",
            str(require(body, "path")),
            "-OutputPath",
            str(require(body, "outputPath")),
        ], "summarize-lad"
    if path == "/api/v1/lad/validate":
        return ["validate-lad", "-Path", str(require(body, "path"))], "validate-lad"
    if path == "/api/v1/lad/patch-network":
        args = [
            "patch-lad-network",
            "-TargetXml",
            str(require(body, "targetXml")),
            "-DonorXml",
            str(require(body, "donorXml")),
            "-OutputXml",
            str(require(body, "outputXml")),
            "-TargetNetworkIndex",
            str(require(body, "targetNetworkIndex")),
        ]
        if body.get("donorNetworkIndex") is not None:
            args += ["-DonorNetworkIndex", str(body["donorNetworkIndex"])]
        if to_bool(body.get("copyTitle")):
            args += ["-CopyTitle"]
        if to_bool(body.get("copyComment")):
            args += ["-CopyComment"]
        return args, "patch-lad-network"
    if path == "/api/v1/releases/prepare":
        args = [
            "prepare-release",
            "-ProjectPath",
            str(require(body, "projectPath")),
            "-InputXml",
            str(require(body, "inputXml")),
            "-ReleaseName",
            str(require(body, "releaseName")),
        ]
        if body.get("readableSummaryPath"):
            args += ["-ReadableSummaryPath", str(body["readableSummaryPath"])]
        if body.get("verificationReportPath"):
            args += ["-VerificationReportPath", str(body["verificationReportPath"])]
        return args, "prepare-release"
    if path == "/api/v1/releases/apply":
        args = [
            "apply-release",
            "-ProjectPath",
            str(require(body, "projectPath")),
            "-InputXml",
            str(require(body, "inputXml")),
            "-PlcName",
            str(require(body, "plcName")),
        ]
        if body.get("blockName"):
            args += ["-BlockName", str(body["blockName"])]
        if body.get("releaseLabel"):
            args += ["-ReleaseLabel", str(body["releaseLabel"])]
        if to_bool(body.get("skipBackup")):
            args += ["-SkipBackup"]
        if to_bool(body.get("dryRunOnly")):
            args += ["-DryRunOnly"]
        return args, "apply-release"
    raise ValueError(f"Unsupported endpoint: {path}")


def run_bridge(powershell: str, command_args: List[str], timeout_seconds: int) -> Dict[str, Any]:
    command = [
        powershell,
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(INVOKE_SCRIPT),
        *command_args,
    ]
    completed = subprocess.run(
        command,
        cwd=str(SCRIPT_DIR),
        capture_output=True,
        text=True,
        encoding=PREFERRED_ENCODING,
        errors="replace",
        timeout=timeout_seconds,
    )
    return {
        "commandLine": command,
        "exitCode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


class SessionRecord:
    def __init__(
        self,
        project_path: str,
        lease_file: Path,
        process: subprocess.Popen,
        ui: bool,
        writable: bool,
        startup_log: List[str],
    ) -> None:
        self.project_path = project_path
        self.lease_file = lease_file
        self.process = process
        self.ui = ui
        self.writable = writable
        self.startup_log = startup_log
        self.created_at = time.time()

    def to_dict(self) -> Dict[str, Any]:
        return {
            "projectPath": self.project_path,
            "leaseFile": str(self.lease_file),
            "pid": self.process.pid,
            "alive": self.process.poll() is None,
            "ui": self.ui,
            "writable": self.writable,
            "createdAtEpoch": self.created_at,
            "startupLog": self.startup_log,
        }


class SessionManager:
    def __init__(self, powershell: str) -> None:
        self.powershell = powershell
        self.lock = threading.RLock()
        self.sessions: Dict[str, SessionRecord] = {}
        SESSION_ROOT.mkdir(parents=True, exist_ok=True)

    def _cleanup_dead_locked(self) -> None:
        dead_paths = [path for path, record in self.sessions.items() if record.process.poll() is not None]
        for path in dead_paths:
            record = self.sessions.pop(path)
            if record.lease_file.exists():
                try:
                    record.lease_file.unlink()
                except OSError:
                    pass

    def list_sessions(self) -> List[Dict[str, Any]]:
        with self.lock:
            self._cleanup_dead_locked()
            return [record.to_dict() for record in self.sessions.values()]

    def get_session(self, project_path: str) -> Optional[SessionRecord]:
        normalized = canonical_project_path(project_path)
        with self.lock:
            self._cleanup_dead_locked()
            return self.sessions.get(normalized)

    def open_session(
        self,
        project_path: str,
        ui: bool = False,
        writable: bool = False,
        startup_timeout_seconds: int = DEFAULT_SESSION_STARTUP_TIMEOUT_SECONDS,
    ) -> Tuple[SessionRecord, bool]:
        normalized = canonical_project_path(project_path)
        with self.lock:
            self._cleanup_dead_locked()
            existing = self.sessions.get(normalized)
            if existing is not None:
                return existing, False

            lease_file = SESSION_ROOT / f"{uuid.uuid4().hex}.lease"
            lease_file.write_text(normalized, encoding="utf-8")

            command = [
                self.powershell,
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(INVOKE_SCRIPT),
                "hold-project",
                "--project",
                normalized,
                "--lease-file",
                str(lease_file),
            ]
            if ui:
                command.append("--ui")

            startup_lines: List[str] = []
            ready_queue: "queue.Queue[Optional[str]]" = queue.Queue()

            process = subprocess.Popen(
                command,
                cwd=str(SCRIPT_DIR),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
                text=True,
                encoding=PREFERRED_ENCODING,
                errors="replace",
            )

            def pump_stdout() -> None:
                try:
                    if process.stdout is None:
                        return
                    for raw_line in process.stdout:
                        line = raw_line.rstrip("\r\n")
                        startup_lines.append(line)
                        ready_queue.put(line)
                finally:
                    ready_queue.put(None)

            threading.Thread(target=pump_stdout, daemon=True).start()

            deadline = time.time() + startup_timeout_seconds
            ready = False
            while time.time() < deadline:
                if process.poll() is not None:
                    break
                try:
                    line = ready_queue.get(timeout=0.5)
                except queue.Empty:
                    continue
                if line is None:
                    continue
                if line.startswith("SESSION_READY\t"):
                    ready = True
                    break

            if not ready:
                self._terminate_process(process)
                if lease_file.exists():
                    try:
                        lease_file.unlink()
                    except OSError:
                        pass
                message = "\n".join(startup_lines[-20:]) if startup_lines else "No startup output."
                raise ValueError(f"Failed to open TIA session for project: {normalized}\n{message}")

            record = SessionRecord(
                project_path=normalized,
                lease_file=lease_file,
                process=process,
                ui=ui,
                writable=writable,
                startup_log=startup_lines[-20:],
            )
            self.sessions[normalized] = record
            return record, True

    def close_session(self, project_path: str) -> bool:
        normalized = canonical_project_path(project_path)
        with self.lock:
            self._cleanup_dead_locked()
            record = self.sessions.pop(normalized, None)
        if record is None:
            return False
        if record.lease_file.exists():
            try:
                record.lease_file.unlink()
            except OSError:
                pass
        deadline = time.time() + 10
        while time.time() < deadline:
            if record.process.poll() is not None:
                break
            time.sleep(0.25)
        if record.process.poll() is None:
            self._terminate_process(record.process)
        return True

    def shutdown(self) -> None:
        for session in list(self.list_sessions()):
            self.close_session(session["projectPath"])

    @staticmethod
    def _terminate_process(process: subprocess.Popen) -> None:
        try:
            process.terminate()
            process.wait(timeout=5)
        except Exception:
            try:
                process.kill()
            except Exception:
                pass


def maybe_project_path_from_body(body: Dict[str, Any]) -> Optional[str]:
    project_path = body.get("projectPath")
    if isinstance(project_path, str) and project_path.strip():
        return project_path
    return None


def replace_project_arg(command_args: List[str], project_path: str) -> None:
    for index in range(len(command_args) - 1):
        if command_args[index] == "--project":
            command_args[index + 1] = project_path
            return


def get_network_adapter_snapshot(powershell: str, timeout_seconds: int = 30) -> Dict[str, Any]:
    command = [
        powershell,
        "-NoProfile",
        "-Command",
        "Get-NetAdapter | Select-Object Name,InterfaceDescription,Status,MacAddress,LinkSpeed | ConvertTo-Json -Depth 4",
    ]
    completed = subprocess.run(
        command,
        cwd=str(SCRIPT_DIR),
        capture_output=True,
        text=True,
        encoding=PREFERRED_ENCODING,
        errors="replace",
        timeout=timeout_seconds,
    )
    payload: Dict[str, Any] = {
        "exitCode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "json": None,
    }
    parsed = parse_json_if_possible(completed.stdout)
    if parsed is not None:
        payload["json"] = parsed
    return payload


def openapi_document() -> Dict[str, Any]:
    return {
        "openapi": "3.0.0",
        "info": {
            "title": "TIA REST Bridge",
            "version": "1.1.0",
            "description": "Local REST bridge that exposes selected Siemens TIA Openness workflows through the generic skill wrapper.",
        },
        "paths": {
            "/health": {"get": {"summary": "Service health"}},
            "/route-info": {"get": {"summary": "Bridge routing information"}},
            "/openapi.json": {"get": {"summary": "OpenAPI document"}},
            "/api/v1/sessions": {"get": {"summary": "List warm TIA sessions"}},
            "/api/v1/sessions/open": {"post": {"summary": "Open a warm TIA session for a project"}},
            "/api/v1/sessions/close": {"post": {"summary": "Close a warm TIA session for a project"}},
            "/api/v1/download/prepare": {"post": {"summary": "Open a visible TIA session and prepare for manual PLC download"}},
            "/api/v1/download/close": {"post": {"summary": "Close the visible TIA download session"}},
            "/api/v1/tia/create-project": {"post": {"summary": "Create a new TIA project"}},
            "/api/v1/tia/list-devices": {"post": {"summary": "List devices in a project"}},
            "/api/v1/tia/list-plcs": {"post": {"summary": "List PLC software targets"}},
            "/api/v1/tia/list-blocks": {"post": {"summary": "List PLC blocks"}},
            "/api/v1/tia/export-blocks": {"post": {"summary": "Export blocks to XML"}},
            "/api/v1/tia/import-blocks": {"post": {"summary": "Preview or apply XML imports"}},
            "/api/v1/tia/compile-plc": {"post": {"summary": "Compile PLC software"}},
            "/api/v1/lad/summarize": {"post": {"summary": "Summarize LAD XML"}},
            "/api/v1/lad/validate": {"post": {"summary": "Validate LAD XML structure"}},
            "/api/v1/lad/patch-network": {"post": {"summary": "Patch one LAD network by replacing only NetworkSource/FlgNet"}},
            "/api/v1/releases/prepare": {"post": {"summary": "Prepare a reusable PLC release package"}},
            "/api/v1/releases/apply": {"post": {"summary": "Apply a release package to a project"}},
            "/api/v1/command": {"post": {"summary": "Call an allowed generic command"}},
        },
    }


class TiaRestHandler(BaseHTTPRequestHandler):
    server_version = "TiaRestBridge/1.1"

    def _send_json(self, payload: Dict[str, Any], status: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def _read_json_body(self) -> Dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8")
        if not raw.strip():
            return {}
        data = json.loads(raw)
        if not isinstance(data, dict):
            raise ValueError("JSON body must be an object.")
        return data

    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stdout.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), fmt % args))

    def do_OPTIONS(self) -> None:
        self._send_json({"ok": True})

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            self._send_json(
                {
                    "ok": True,
                    "service": "tia-rest-bridge",
                    "invokeScript": str(INVOKE_SCRIPT),
                    "sessionCount": len(self.server.session_manager.list_sessions()),
                }
            )
            return
        if path == "/openapi.json":
            self._send_json(openapi_document())
            return
        if path == "/route-info":
            self._handle_bridge_call(path, {}, self.server.default_timeout)
            return
        if path == "/api/v1/sessions":
            self._send_json({"ok": True, "sessions": self.server.session_manager.list_sessions()})
            return
        self._send_json({"ok": False, "error": f"Unknown path: {path}"}, status=HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        try:
            body = self._read_json_body()
        except json.JSONDecodeError as exc:
            self._send_json({"ok": False, "error": f"Invalid JSON: {exc}"}, status=HTTPStatus.BAD_REQUEST)
            return
        except ValueError as exc:
            self._send_json({"ok": False, "error": str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return

        if path == "/api/v1/sessions/open":
            self._handle_open_session(body)
            return
        if path == "/api/v1/sessions/close":
            self._handle_close_session(body)
            return
        if path == "/api/v1/download/prepare":
            self._handle_prepare_download(body)
            return
        if path == "/api/v1/download/close":
            self._handle_close_download(body)
            return

        self._handle_bridge_call(path, body, self.server.default_timeout)

    def _handle_open_session(self, body: Dict[str, Any]) -> None:
        project_path = str(require(body, "projectPath"))
        ui = to_bool(body.get("ui"))
        writable = to_bool(body.get("writable"))
        timeout_seconds = clamp_timeout(body.get("startupTimeoutSeconds"), DEFAULT_SESSION_STARTUP_TIMEOUT_SECONDS)
        try:
            with self.server.command_lock:
                session, created = self.server.session_manager.open_session(
                    project_path,
                    ui=ui,
                    writable=writable,
                    startup_timeout_seconds=timeout_seconds,
                )
            self._send_json({"ok": True, "created": created, "session": session.to_dict()})
        except ValueError as exc:
            self._send_json({"ok": False, "error": str(exc)}, status=HTTPStatus.BAD_GATEWAY)

    def _handle_close_session(self, body: Dict[str, Any]) -> None:
        project_path = str(require(body, "projectPath"))
        with self.server.command_lock:
            closed = self.server.session_manager.close_session(project_path)
        self._send_json({"ok": True, "closed": closed, "projectPath": canonical_project_path(project_path)})

    def _handle_prepare_download(self, body: Dict[str, Any]) -> None:
        project_path = str(require(body, "projectPath"))
        plc_name = body.get("plcName")
        compile_before_download = body.get("compileBeforeDownload", True)
        save_after_compile = body.get("saveAfterCompile", True)
        timeout_seconds = clamp_timeout(body.get("timeoutSeconds"), self.server.default_timeout)

        with self.server.command_lock:
            session, created = self.server.session_manager.open_session(
                project_path,
                ui=True,
                writable=True,
                startup_timeout_seconds=clamp_timeout(
                    body.get("sessionStartupTimeoutSeconds"),
                    DEFAULT_SESSION_STARTUP_TIMEOUT_SECONDS,
                ),
            )

            compile_payload = None
            if to_bool(compile_before_download):
                compile_args = ["compile-plc", "--project", project_path, "--attach"]
                if plc_name:
                    compile_args += ["--plc", str(plc_name)]
                if to_bool(save_after_compile):
                    compile_args += ["--save"]
                compile_result = run_bridge(self.server.powershell, compile_args, timeout_seconds)
                compile_payload = {
                    "ok": compile_result["exitCode"] == 0,
                    "command": "compile-plc",
                    "args": compile_args[1:],
                    "exitCode": compile_result["exitCode"],
                    "stdout": compile_result["stdout"],
                    "stderr": compile_result["stderr"],
                    "parsed": parse_common_output("compile-plc", compile_result["stdout"]),
                }
                if compile_result["exitCode"] != 0:
                    self._send_json(
                        {
                            "ok": False,
                            "error": "Compile failed while preparing GUI download.",
                            "session": session.to_dict(),
                            "compile": compile_payload,
                        },
                        status=HTTPStatus.BAD_GATEWAY,
                    )
                    return

            list_devices_result = run_bridge(
                self.server.powershell,
                ["list-devices", "--project", project_path, "--attach"],
                timeout_seconds,
            )
            devices_payload = {
                "ok": list_devices_result["exitCode"] == 0,
                "command": "list-devices",
                "args": ["--project", project_path, "--attach"],
                "exitCode": list_devices_result["exitCode"],
                "stdout": list_devices_result["stdout"],
                "stderr": list_devices_result["stderr"],
                "parsed": parse_common_output("list-devices", list_devices_result["stdout"]),
            }

        adapters = get_network_adapter_snapshot(self.server.powershell)
        next_steps = [
            "TIA Portal should now be open in a visible session for this project.",
            "In TIA, select the CPU and use Download to device.",
            "Use Accessible devices to find the PLC if the target is not already mapped.",
            "Verify the target IP and device match before confirming the download.",
        ]
        warnings = [
            "Manual confirmation inside TIA is still required for the actual PLC download.",
            "Do not proceed if the target equipment cannot tolerate a stop or restart.",
        ]

        self._send_json(
            {
                "ok": True,
                "createdSession": created,
                "session": session.to_dict(),
                "compile": compile_payload,
                "devices": devices_payload,
                "networkAdapters": adapters,
                "nextSteps": next_steps,
                "warnings": warnings,
            }
        )

    def _handle_close_download(self, body: Dict[str, Any]) -> None:
        project_path = str(require(body, "projectPath"))
        with self.server.command_lock:
            closed = self.server.session_manager.close_session(project_path)
        self._send_json(
            {
                "ok": True,
                "closed": closed,
                "projectPath": canonical_project_path(project_path),
                "message": "Visible TIA download session closed.",
            }
        )

    def _handle_bridge_call(self, path: str, body: Dict[str, Any], default_timeout: int) -> None:
        try:
            command_args, command_name = build_command_from_body(path, body)
            timeout_seconds = clamp_timeout(body.get("timeoutSeconds"), default_timeout)
            session_info = None

            project_path = maybe_project_path_from_body(body)
            if project_path is not None:
                with self.server.command_lock:
                    if to_bool(body.get("useSession")):
                        session, _ = self.server.session_manager.open_session(
                            project_path,
                            ui=to_bool(body.get("sessionUi")),
                            writable=to_bool(body.get("sessionWritable")),
                            startup_timeout_seconds=clamp_timeout(
                                body.get("sessionStartupTimeoutSeconds"),
                                DEFAULT_SESSION_STARTUP_TIMEOUT_SECONDS,
                            ),
                        )
                        session_info = session.to_dict()
                        replace_project_arg(command_args, session.project_path)
                        if "--attach" not in command_args:
                            command_args.append("--attach")
                    else:
                        existing = self.server.session_manager.get_session(project_path)
                        if existing is not None:
                            replace_project_arg(command_args, existing.project_path)
                        if existing is not None and "--attach" not in command_args:
                            command_args.append("--attach")
                            session_info = existing.to_dict()

                    if to_bool(body.get("attach")) and "--attach" not in command_args:
                        command_args.append("--attach")
                    if to_bool(body.get("ui")) and "--ui" not in command_args:
                        command_args.append("--ui")

                    result = run_bridge(self.server.powershell, command_args, timeout_seconds)
            else:
                with self.server.command_lock:
                    result = run_bridge(self.server.powershell, command_args, timeout_seconds)

            payload = {
                "ok": result["exitCode"] == 0,
                "command": command_name,
                "args": command_args[1:],
                "exitCode": result["exitCode"],
                "stdout": result["stdout"],
                "stderr": result["stderr"],
                "parsed": parse_common_output(command_name, result["stdout"]),
                "session": session_info,
            }
            status = HTTPStatus.OK if result["exitCode"] == 0 else HTTPStatus.BAD_GATEWAY
            self._send_json(payload, status=status)
        except subprocess.TimeoutExpired:
            self._send_json({"ok": False, "error": "Bridge command timed out."}, status=HTTPStatus.GATEWAY_TIMEOUT)
        except ValueError as exc:
            self._send_json({"ok": False, "error": str(exc)}, status=HTTPStatus.BAD_REQUEST)
        except Exception as exc:  # pragma: no cover - defensive error envelope
            self._send_json({"ok": False, "error": str(exc)}, status=HTTPStatus.INTERNAL_SERVER_ERROR)


class TiaRestServer(ThreadingHTTPServer):
    def __init__(self, server_address: Tuple[str, int], handler_class: type, powershell: str, default_timeout: int):
        super().__init__(server_address, handler_class)
        self.powershell = powershell
        self.default_timeout = default_timeout
        self.command_lock = threading.RLock()
        self.session_manager = SessionManager(powershell)


def main() -> int:
    args = parse_args()
    if not INVOKE_SCRIPT.exists():
        print(f"Missing bridge script: {INVOKE_SCRIPT}", file=sys.stderr)
        return 1
    server = TiaRestServer((args.host, args.port), TiaRestHandler, args.powershell, args.default_timeout)
    print(f"TIA REST bridge listening on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down TIA REST bridge...")
    finally:
        server.session_manager.shutdown()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
