const http = require("http");

// ── Admin authorization ────────────────────────────────────────────────────
// Roblox UserIds allowed to issue /admin/* commands. Add more IDs here.
// NOTE: This server has no transport-level auth — any client can claim to be
// any UserId on /register. For a basic kick panel that's acceptable; harden
// later with a shared secret or signed tokens if needed.
const ADMIN_IDS = new Set([
    2401825836,
]);

// activeUsers[userId] = { lastSeen, displayName, name, jobId, placeId, executor }
const activeUsers = {};

// Set of userIds the admin has queued for disconnect. Cleared when the
// affected client next /register's (server tells them kick = true).
const disconnectsPending = new Set();

// ── Chat state ─────────────────────────────────────────────────────────────
// In-memory ring buffer of chat messages. Not persisted — resets on redeploy.
const chatMessages = [];   // { id, userId, displayName, name, text, ts }
const MAX_CHAT_MESSAGES = 200;
const CHAT_TTL_MS = 60 * 1000;  // messages older than 60s are dropped
let chatIdCounter = 0;

const TIMEOUT = 15000; // 15 seconds before a client is considered gone

// placeId -> game name shown on the website's Live tab
const PLACE_NAMES = {
    83038462357724: "Graben und reinigen",
    94640181989498: "Grow a Chicken Fighter",
    107778070777162: "Steal an Egg",
    100068273119174: "Leaf Simulator",
    128736949265057: "Gakuran",
};

function pushChat(userId, displayName, name, text) {
    const msg = {
        id: ++chatIdCounter,
        userId,
        displayName: String(displayName || "").slice(0, 64),
        name: String(name || "").slice(0, 64),
        text: String(text || "").slice(0, 500),
        ts: Date.now(),
    };
    chatMessages.push(msg);
    if (chatMessages.length > MAX_CHAT_MESSAGES) {
        chatMessages.splice(0, chatMessages.length - MAX_CHAT_MESSAGES);
    }
    return msg;
}

function pruneChat() {
    const cutoff = Date.now() - CHAT_TTL_MS;
    while (chatMessages.length && chatMessages[0].ts < cutoff) {
        chatMessages.shift();
    }
}

function readBody(req) {
    return new Promise((resolve) => {
        let body = "";
        req.on("data", (chunk) => {
            body += chunk;
            if (body.length > 32 * 1024) {
                // guard against absurdly large bodies
                try { req.socket.destroy(); } catch (_) {}
            }
        });
        req.on("end", () => resolve(body));
        req.on("error", () => resolve(""));
    });
}

function sendJson(res, status, payload) {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(payload));
}

const server = http.createServer(async (req, res) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
        res.writeHead(200);
        res.end();
        return;
    }

    // POST /register — a client tells the server they are active.
    // Response includes { kick: true } if the admin queued this user for
    // disconnect, in which case the server clears the pending entry.
    if (req.method === "POST" && req.url === "/register") {
        const body = await readBody(req);
        let data;
        try { data = JSON.parse(body || "{}"); }
        catch (e) { return sendJson(res, 400, { error: "bad json" }); }

        const userId = Number(data.userId);
        if (!Number.isFinite(userId) || userId <= 0) {
            return sendJson(res, 400, { error: "missing userId" });
        }

        const prev = activeUsers[userId] || {};
        activeUsers[userId] = {
            lastSeen: Date.now(),
            displayName: typeof data.displayName === "string" && data.displayName.length
                ? data.displayName.slice(0, 64)
                : (prev.displayName || ""),
            name: typeof data.name === "string" && data.name.length
                ? data.name.slice(0, 64)
                : (prev.name || ""),
            jobId: typeof data.jobId === "string" && data.jobId.length
                ? data.jobId.slice(0, 128)
                : (prev.jobId || ""),
            placeId: Number.isFinite(Number(data.placeId)) && Number(data.placeId) > 0
                ? Number(data.placeId)
                : (prev.placeId || 0),
            executor: typeof data.executor === "string" && data.executor.length
                ? data.executor.slice(0, 64)
                : (prev.executor || ""),
        };

        let kick = false;
        if (disconnectsPending.has(userId)) {
            kick = true;
            disconnectsPending.delete(userId);
            delete activeUsers[userId];
        }
        return sendJson(res, 200, { ok: true, kick });
    }

    // GET /users — list of currently active clients with their metadata.
    if (req.method === "GET" && req.url === "/users") {
        const now = Date.now();
        const alive = [];
        for (const [idStr, info] of Object.entries(activeUsers)) {
            if (now - info.lastSeen >= TIMEOUT) continue;
            alive.push({
                userId: Number(idStr),
                displayName: info.displayName || "",
                name: info.name || "",
                jobId: info.jobId || "",
                placeId: info.placeId || 0,
                executor: info.executor || "",
            });
        }
        return sendJson(res, 200, alive);
    }

    // GET /online — aggregates for the website's Live tab:
    // { total, games: [{name, online, place_id}], executors: [{executor, online}] }
    if (req.method === "GET" && req.url === "/online") {
        const now = Date.now();
        const byGame = new Map();
        const byExecutor = new Map();
        let total = 0;
        for (const [idStr, info] of Object.entries(activeUsers)) {
            if (now - info.lastSeen >= TIMEOUT) continue;
            total++;
            const placeId = info.placeId || 0;
            const name = PLACE_NAMES[placeId] || "Unsupported";
            if (!byGame.has(placeId)) byGame.set(placeId, { name, place_id: placeId, online: 0 });
            byGame.get(placeId).online++;
            const exec = info.executor || "Unknown";
            if (!byExecutor.has(exec)) byExecutor.set(exec, { executor: exec, online: 0 });
            byExecutor.get(exec).online++;
        }
        const games = [...byGame.values()].sort((a, b) => b.online - a.online);
        const executors = [...byExecutor.values()].sort((a, b) => b.online - a.online);
        return sendJson(res, 200, { total, games, executors });
    }

    // POST /admin/disconnect — admin queues a user for kick on their next ping.
    // Body: { adminId, userId }
    if (req.method === "POST" && req.url === "/admin/disconnect") {
        const body = await readBody(req);
        let data;
        try { data = JSON.parse(body || "{}"); }
        catch (e) { return sendJson(res, 400, { error: "bad json" }); }

        const adminId = Number(data.adminId);
        const userId = Number(data.userId);
        if (!ADMIN_IDS.has(adminId)) {
            return sendJson(res, 403, { error: "not authorized" });
        }
        if (!Number.isFinite(userId) || userId <= 0) {
            return sendJson(res, 400, { error: "missing userId" });
        }
        disconnectsPending.add(userId);
        return sendJson(res, 200, { ok: true });
    }

    // ── Chat ────────────────────────────────────────────────────────────────
    // GET /chat/messages?since=<id> — messages newer than <id> (incremental
    // polling). Without `since`, returns the latest MAX_CHAT_MESSAGES.
    if (req.method === "GET" && (req.url === "/chat/messages" || req.url.startsWith("/chat/messages?"))) {
        const url = new URL(req.url, "http://localhost");
        const since = Number(url.searchParams.get("since")) || 0;
        pruneChat();
        const out = since > 0
            ? chatMessages.filter((m) => m.id > since)
            : chatMessages.slice(-MAX_CHAT_MESSAGES);
        return sendJson(res, 200, out);
    }

    // POST /chat/send — body: { userId, displayName, name, text }
    if (req.method === "POST" && req.url === "/chat/send") {
        const body = await readBody(req);
        let data;
        try { data = JSON.parse(body || "{}"); }
        catch (e) { return sendJson(res, 400, { error: "bad json" }); }

        const userId = Number(data.userId);
        if (!Number.isFinite(userId) || userId <= 0) {
            return sendJson(res, 400, { error: "missing userId" });
        }
        const text = typeof data.text === "string" ? data.text.trim() : "";
        if (!text) {
            return sendJson(res, 400, { error: "empty message" });
        }
        const msg = pushChat(userId, data.displayName, data.name, text);
        return sendJson(res, 200, { ok: true, msg });
    }

    // GET / — health check so Koyeb knows server is alive
    if (req.method === "GET" && req.url === "/") {
        res.writeHead(200);
        res.end("Solis Presence Server OK");
        return;
    }

    res.writeHead(404);
    res.end("Not found");
});

// Periodic cleanup of stale users (in case nothing else triggers it).
setInterval(() => {
    const now = Date.now();
    for (const [idStr, info] of Object.entries(activeUsers)) {
        if (now - info.lastSeen >= TIMEOUT) {
            delete activeUsers[idStr];
        }
    }
    pruneChat();
}, 10000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log("Solis Presence Server running on port " + PORT);
});
