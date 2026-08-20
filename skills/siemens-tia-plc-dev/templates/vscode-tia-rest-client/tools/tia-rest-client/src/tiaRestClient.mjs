const baseUrl = process.env.TIA_REST_BASE_URL || "http://127.0.0.1:8765";

async function request(path, method = "GET", body = undefined) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: body ? { "Content-Type": "application/json" } : {},
    body: body ? JSON.stringify(body) : undefined
  });

  const payload = await response.json();
  if (!response.ok || payload.ok === false) {
    const error = new Error(payload.error || `Request failed with status ${response.status}`);
    error.payload = payload;
    throw error;
  }
  return payload;
}

export async function health() {
  return request("/health");
}

export async function routeInfo() {
  return request("/route-info");
}

export async function openSession(projectPath, options = {}) {
  return request("/api/v1/sessions/open", "POST", {
    projectPath,
    ui: options.ui ?? false,
    writable: options.writable ?? false
  });
}

export async function closeSession(projectPath) {
  return request("/api/v1/sessions/close", "POST", { projectPath });
}

export async function listPlcs(projectPath) {
  return request("/api/v1/tia/list-plcs", "POST", { projectPath });
}

export async function listBlocks(projectPath, plc = "PLC_1", useSession = true) {
  return request("/api/v1/tia/list-blocks", "POST", { projectPath, plc, useSession });
}

export async function compilePlc(projectPath, plc = "PLC_1", save = true) {
  return request("/api/v1/tia/compile-plc", "POST", { projectPath, plc, save, useSession: true });
}

export async function prepareGuiDownload(projectPath, plcName = "PLC_1") {
  return request("/api/v1/download/prepare", "POST", { projectPath, plcName });
}
