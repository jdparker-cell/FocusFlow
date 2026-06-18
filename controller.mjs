import http from "node:http";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import os from "node:os";
import fs from "node:fs";

const directory = path.dirname(fileURLToPath(import.meta.url));
const nativeHelper = path.join(directory, "native-window.ps1");
const port = Number(process.env.FOCUS_FLOW_PORT || 38473);

let state = {
  active: false,
  generation: 0,
  startedAt: null,
};
let transition = Promise.resolve();
const eventClients = new Set();

function runNative(action) {
  return new Promise((resolve, reject) => {
    const child = spawn(
      "powershell.exe",
      [
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        nativeHelper,
        action,
      ],
      { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] },
    );

    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(stderr.trim() || `Native helper exited with ${code}`));
    });
  });
}

function sendJson(response, status, payload) {
  response.writeHead(status, {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Cache-Control": "no-store",
    "Content-Type": "application/json; charset=utf-8",
  });
  response.end(JSON.stringify(payload));
}

function broadcastState() {
  const message = `data: ${JSON.stringify(state)}\n\n`;
  for (const client of eventClients) {
    client.write(message);
  }
}

function queueTransition(action) {
  transition = transition.then(action, action);
  return transition;
}

async function activate() {
  if (!state.active) {
    await runNative("start");
    state = {
      active: true,
      generation: state.generation + 1,
      startedAt: new Date().toISOString(),
    };
    broadcastState();
    await new Promise((resolve) => setTimeout(resolve, 400));
    await runNative("focus-reels");
  }
  return state;
}

async function deactivate() {
  if (state.active) {
    state = { ...state, active: false };
    broadcastState();
    await new Promise((resolve) => setTimeout(resolve, 150));
    await runNative("stop");
  }
  return state;
}

const server = http.createServer(async (request, response) => {
  if (request.method === "OPTIONS") {
    sendJson(response, 204, {});
    return;
  }

  if (request.method === "GET" && request.url === "/state") {
    sendJson(response, 200, state);
    return;
  }

  if (request.method === "GET" && request.url === "/events") {
    response.writeHead(200, {
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "no-cache, no-transform",
      "Connection": "keep-alive",
      "Content-Type": "text/event-stream",
    });
    response.write(`data: ${JSON.stringify(state)}\n\n`);
    eventClients.add(response);
    request.on("close", () => eventClients.delete(response));
    return;
  }

  if (request.method === "POST" && request.url === "/event/start") {
    try {
      sendJson(response, 200, await queueTransition(activate));
    } catch (error) {
      sendJson(response, 500, { error: error.message });
    }
    return;
  }

  if (request.method === "POST" && request.url === "/event/stop") {
    try {
      sendJson(response, 200, await queueTransition(deactivate));
    } catch (error) {
      sendJson(response, 500, { error: error.message });
    }
    return;
  }

  sendJson(response, 404, { error: "Not found" });
});

const sessionRoot = path.join(os.homedir(), ".codex", "sessions");
const offsets = new Map();
const remainders = new Map();
const pendingReads = new Map();

function seedSessionOffsets(directory) {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) seedSessionOffsets(fullPath);
    else if (entry.isFile() && entry.name.endsWith(".jsonl")) {
      offsets.set(fullPath, fs.statSync(fullPath).size);
    }
  }
}

async function readSessionAppend(filePath) {
  if (!filePath.endsWith(".jsonl") || !fs.existsSync(filePath)) return;

  const size = fs.statSync(filePath).size;
  const start = offsets.get(filePath) ?? 0;
  if (size <= start) return;

  const handle = await fs.promises.open(filePath, "r");
  try {
    const buffer = Buffer.alloc(size - start);
    await handle.read(buffer, 0, buffer.length, start);
    offsets.set(filePath, size);

    const combined = (remainders.get(filePath) ?? "") + buffer.toString("utf8");
    const lines = combined.split(/\r?\n/);
    remainders.set(filePath, lines.pop() ?? "");

    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const event = JSON.parse(line);
        if (event.type !== "event_msg") continue;
        if (event.payload?.type === "user_message") {
          await queueTransition(activate);
        } else if (event.payload?.type === "task_complete") {
          await queueTransition(deactivate);
        }
      } catch {
        // Ignore malformed completed lines; partial lines are retained above.
      }
    }
  } finally {
    await handle.close();
  }
}

function watchCodexSessions() {
  if (!fs.existsSync(sessionRoot)) return;
  seedSessionOffsets(sessionRoot);

  fs.watch(sessionRoot, { recursive: true }, (_eventType, relativeName) => {
    if (!relativeName?.endsWith(".jsonl")) return;
    const filePath = path.join(sessionRoot, relativeName);
    clearTimeout(pendingReads.get(filePath));
    pendingReads.set(
      filePath,
      setTimeout(() => {
        pendingReads.delete(filePath);
        readSessionAppend(filePath).catch((error) => {
          console.error(`Session watcher error: ${error.message}`);
        });
      }, 75),
    );
  });

  setInterval(() => {
    for (const [filePath, previousSize] of offsets) {
      if (!fs.existsSync(filePath)) continue;
      if (fs.statSync(filePath).size > previousSize) {
        readSessionAppend(filePath).catch((error) => {
          console.error(`Session polling error: ${error.message}`);
        });
      }
    }
  }, 250);
}

server.listen(port, "127.0.0.1", () => {
  console.log(`FocusFlow listening on http://127.0.0.1:${port}`);
  watchCodexSessions();
});
