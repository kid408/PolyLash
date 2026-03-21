import fs from "node:fs";
import path from "node:path";

function capHistory(history, maxTurns) {
  const maxEntries = Math.max(maxTurns * 2, 2);
  return history.slice(-maxEntries);
}

export class SessionStore {
  constructor(filePath, maxHistoryTurns) {
    this.filePath = filePath;
    this.maxHistoryTurns = maxHistoryTurns;
    this.sessions = new Map();
    this.loaded = false;
  }

  load() {
    if (this.loaded) {
      return;
    }
    this.loaded = true;

    if (!fs.existsSync(this.filePath)) {
      return;
    }

    const raw = fs.readFileSync(this.filePath, "utf8");
    if (!raw.trim()) {
      return;
    }

    const parsed = JSON.parse(raw);
    for (const session of parsed.sessions || []) {
      this.sessions.set(session.id, session);
    }
  }

  save() {
    const directory = path.dirname(this.filePath);
    fs.mkdirSync(directory, { recursive: true });

    const payload = {
      sessions: [...this.sessions.values()],
    };

    const tempPath = `${this.filePath}.tmp`;
    fs.writeFileSync(tempPath, JSON.stringify(payload, null, 2), "utf8");
    fs.renameSync(tempPath, this.filePath);
  }

  get(sessionId, userId = "") {
    this.load();
    if (!this.sessions.has(sessionId)) {
      this.sessions.set(sessionId, {
        id: sessionId,
        userId,
        history: [],
        pendingAction: null,
        updatedAt: new Date().toISOString(),
      });
    }

    const session = this.sessions.get(sessionId);
    if (!session.userId && userId) {
      session.userId = userId;
    }
    return session;
  }

  appendTurn(sessionId, role, text) {
    const session = this.get(sessionId);
    session.history.push({
      role,
      text,
      at: new Date().toISOString(),
    });
    session.history = capHistory(session.history, this.maxHistoryTurns);
    session.updatedAt = new Date().toISOString();
    this.save();
  }

  setPendingAction(sessionId, pendingAction) {
    const session = this.get(sessionId);
    session.pendingAction = pendingAction;
    session.updatedAt = new Date().toISOString();
    this.save();
  }

  clearPendingAction(sessionId) {
    const session = this.get(sessionId);
    session.pendingAction = null;
    session.updatedAt = new Date().toISOString();
    this.save();
  }

  getPendingAction(sessionId) {
    const session = this.get(sessionId);
    return session.pendingAction;
  }
}
