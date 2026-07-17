'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '0.0.0.0';
const DATA_FILE = process.env.COACHSPLIT_DATA_FILE || path.join(__dirname, 'coachsplit-sync-data.json');
const DEVICE_ONLINE_WINDOW_MS = 45_000;

function emptyStore() {
  return { schemaVersion: 2, sequence: 0, sessions: {}, tokens: {}, invitations: {}, events: {} };
}

function normalizeStore(value) {
  const base = { ...emptyStore(), ...(value || {}) };
  base.sessions ||= {};
  base.tokens ||= {};
  base.invitations ||= {};
  base.events ||= {};
  return base;
}

function loadStore() {
  try {
    return normalizeStore(JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')));
  } catch (error) {
    if (error.code !== 'ENOENT') console.error('Could not read data file:', error);
    return emptyStore();
  }
}

let store = loadStore();
let writeChain = Promise.resolve();
function persist() {
  const snapshot = JSON.stringify(store, null, 2);
  writeChain = writeChain.then(async () => {
    const temp = `${DATA_FILE}.tmp`;
    await fs.promises.writeFile(temp, snapshot, 'utf8');
    await fs.promises.rename(temp, DATA_FILE);
  });
  return writeChain;
}

function token() { return crypto.randomBytes(32).toString('base64url'); }
function now() { return new Date().toISOString(); }
function canonical(event) {
  const keys = ['id','sessionId','participationId','athleteId','measurementPointId','kind','activityTimeMs','deviceTime','createdByUserId','deviceId','shootingData','correctionOfEventId','syncVersion'];
  const out = {};
  for (const key of keys) if (event[key] !== undefined) out[key] = event[key];
  return JSON.stringify(out);
}
function headers(extra={}) {
  return {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'content-type, authorization',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    ...extra,
  };
}
function send(res, status, body) {
  res.writeHead(status, headers());
  res.end(JSON.stringify(body));
}
function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', chunk => {
      raw += chunk;
      if (raw.length > 2_000_000) reject(new Error('Request too large'));
    });
    req.on('end', () => {
      try { resolve(raw ? JSON.parse(raw) : {}); } catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}
function auth(req) {
  const value = req.headers.authorization || '';
  const bearer = value.startsWith('Bearer ') ? value.slice(7) : '';
  return store.tokens[bearer] ? { token: bearer, ...store.tokens[bearer] } : null;
}
function requireSession(identity) {
  return identity ? store.sessions[identity.sessionId] : null;
}
function checkpoint(session, id) {
  return session.checkpoints.find(point => point.id === id) || null;
}
function touchDevice(session, identity, pendingEventCount) {
  const key = identity.deviceId || identity.token;
  const current = session.devices[key] || {};
  session.devices[key] = {
    ...current,
    deviceId: key,
    displayName: current.displayName || identity.deviceName || 'Helfergerät',
    lastSeenAt: now(),
    pendingEventCount: Number.isFinite(Number(pendingEventCount)) ? Number(pendingEventCount) : (current.pendingEventCount || 0),
  };
  return session.devices[key];
}
function roleAllows(identity, event, session) {
  if (identity.sessionId !== event.sessionId) return 'Token gehört zu einer anderen Session.';
  if (!['openForJoining', 'active'].includes(session.status)) return 'Session ist nicht aktiv.';
  if (identity.role === 'administrator') return null;
  if (identity.role !== 'helper') return 'Unbekannte Rolle.';
  const device = session.devices[identity.deviceId];
  if (!device || !device.checkpointId) return 'Dem Gerät ist noch kein Messpunkt zugewiesen.';
  if (device.checkpointId !== event.measurementPointId) return 'Messpunkt ist nicht freigeschaltet.';
  const point = checkpoint(session, device.checkpointId);
  if (!point) return 'Messpunkt existiert nicht.';
  if (point.kind !== event.kind && !(point.kind === 'finish' && event.kind === 'didNotFinish')) {
    return `Ereignistyp ${event.kind} ist für ${point.name} nicht erlaubt.`;
  }
  return null;
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') { res.writeHead(204, headers()); return res.end(); }
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  try {
    if (req.method === 'GET' && url.pathname === '/health') {
      return send(res, 200, { ok: true, sessions: Object.keys(store.sessions).length, sequence: store.sequence });
    }

    if (req.method === 'POST' && url.pathname === '/api/sessions') {
      const body = await readJson(req);
      const competition = body.competition;
      const checkpoints = Array.isArray(body.checkpoints) ? body.checkpoints : [];
      if (!competition || !competition.id || checkpoints.length === 0) return send(res, 400, { error: 'Bewerb und Messpunkte sind erforderlich.' });
      const sessionId = String(competition.id);
      if (store.sessions[sessionId] && store.sessions[sessionId].status !== 'closed') return send(res, 409, { error: 'Für diesen Bewerb existiert bereits eine offene Session.' });
      const adminToken = token();
      const joinToken = token();
      const createdAt = now();
      const appBaseUrl = String(body.appBaseUrl || '').replace(/\/$/, '');
      store.sessions[sessionId] = {
        sessionId,
        competition,
        checkpoints,
        status: 'openForJoining',
        createdAt,
        revision: 1,
        assignmentRevision: 0,
        devices: {},
        joinToken,
      };
      store.events[sessionId] = {};
      store.tokens[adminToken] = {
        sessionId,
        role: 'administrator',
        deviceId: String(body.deviceId || ''),
        deviceName: String(body.deviceName || 'Administrator'),
        createdAt,
      };
      store.invitations[joinToken] = {
        sessionId,
        expiresAt: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(),
        revokedAt: null,
      };
      await persist();
      const joinUrl = `${appBaseUrl}/?join=${encodeURIComponent(joinToken)}`;
      return send(res, 201, { sessionId, accessToken: adminToken, joinToken, joinUrl });
    }

    if (req.method === 'POST' && url.pathname === '/api/join') {
      const body = await readJson(req);
      const invitation = store.invitations[String(body.joinToken || '')];
      if (!invitation) return send(res, 404, { error: 'Einladung ist ungültig.' });
      if (invitation.revokedAt) return send(res, 403, { error: 'Einladung wurde widerrufen.' });
      if (Date.parse(invitation.expiresAt) < Date.now()) return send(res, 403, { error: 'Einladung ist abgelaufen.' });
      const session = store.sessions[invitation.sessionId];
      if (!session || session.status === 'closed') return send(res, 403, { error: 'Session ist geschlossen.' });
      const deviceId = String(body.deviceId || '');
      if (!deviceId) return send(res, 400, { error: 'Geräte-ID fehlt.' });
      const displayName = String(body.displayName || 'Helfergerät').trim().slice(0, 80) || 'Helfergerät';
      const accessToken = token();
      const existing = session.devices[deviceId] || {};
      session.devices[deviceId] = {
        ...existing,
        deviceId,
        displayName,
        lastSeenAt: now(),
        pendingEventCount: existing.pendingEventCount || 0,
        checkpointId: existing.checkpointId || null,
        assignmentRevision: existing.assignmentRevision || 0,
      };
      store.tokens[accessToken] = {
        sessionId: invitation.sessionId,
        role: 'helper',
        deviceId,
        deviceName: displayName,
        createdAt: now(),
      };
      await persist();
      const assigned = checkpoint(session, session.devices[deviceId].checkpointId);
      return send(res, 200, {
        sessionId: invitation.sessionId,
        accessToken,
        checkpointId: assigned?.id || null,
        checkpointName: assigned?.name || null,
        assignmentRevision: session.devices[deviceId].assignmentRevision || 0,
        competition: session.competition,
      });
    }

    if (req.method === 'GET' && url.pathname === '/api/collaboration/state') {
      const identity = auth(req);
      if (!identity) return send(res, 401, { error: 'Zugriffstoken fehlt oder ist ungültig.' });
      if (url.searchParams.get('sessionId') !== identity.sessionId) return send(res, 403, { error: 'Session nicht freigeschaltet.' });
      const session = requireSession(identity);
      if (!session) return send(res, 404, { error: 'Session wurde nicht gefunden.' });
      const devices = Object.values(session.devices).map(device => {
        const point = checkpoint(session, device.checkpointId);
        return {
          ...device,
          checkpointName: point?.name || null,
          online: Date.now() - Date.parse(device.lastSeenAt || 0) <= DEVICE_ONLINE_WINDOW_MS,
        };
      });
      return send(res, 200, { status: session.status, revision: session.revision, devices });
    }

    if (req.method === 'POST' && url.pathname === '/api/devices/heartbeat') {
      const identity = auth(req);
      if (!identity) return send(res, 401, { error: 'Zugriffstoken fehlt oder ist ungültig.' });
      const body = await readJson(req);
      if (body.sessionId !== identity.sessionId) return send(res, 403, { error: 'Session nicht freigeschaltet.' });
      const session = requireSession(identity);
      if (!session) return send(res, 404, { error: 'Session wurde nicht gefunden.' });
      const device = touchDevice(session, identity, body.pendingEventCount);
      const point = checkpoint(session, device.checkpointId);
      await persist();
      return send(res, 200, {
        checkpointId: point?.id || null,
        checkpointName: point?.name || null,
        assignmentRevision: device.assignmentRevision || 0,
        sessionStatus: session.status,
      });
    }

    if (req.method === 'POST' && url.pathname === '/api/assignments') {
      const identity = auth(req);
      if (!identity) return send(res, 401, { error: 'Zugriffstoken fehlt oder ist ungültig.' });
      if (identity.role !== 'administrator') return send(res, 403, { error: 'Nur der Administrator darf Messpunkte zuweisen.' });
      const body = await readJson(req);
      if (body.sessionId !== identity.sessionId) return send(res, 403, { error: 'Session nicht freigeschaltet.' });
      const session = requireSession(identity);
      const device = session?.devices[String(body.deviceId || '')];
      if (!session || !device) return send(res, 404, { error: 'Helfergerät wurde nicht gefunden.' });
      const checkpointId = body.checkpointId == null ? null : String(body.checkpointId);
      if (checkpointId && !checkpoint(session, checkpointId)) return send(res, 400, { error: 'Messpunkt wurde nicht gefunden.' });
      session.assignmentRevision += 1;
      device.checkpointId = checkpointId;
      device.assignmentRevision = session.assignmentRevision;
      device.assignedAt = now();
      device.assignedByDeviceId = identity.deviceId;
      await persist();
      return send(res, 200, { assignmentRevision: device.assignmentRevision });
    }

    if (req.method === 'POST' && url.pathname === '/api/competition') {
      const identity = auth(req);
      if (!identity) return send(res, 401, { error: 'Zugriffstoken fehlt oder ist ungültig.' });
      if (identity.role !== 'administrator') return send(res, 403, { error: 'Nur der Administrator darf Bewerbsdaten ändern.' });
      const body = await readJson(req);
      if (body.sessionId !== identity.sessionId || !body.competition) return send(res, 400, { error: 'Ungültige Bewerbsdaten.' });
      const session = requireSession(identity);
      if (!session) return send(res, 404, { error: 'Session wurde nicht gefunden.' });
      session.competition = body.competition;
      session.revision += 1;
      session.updatedAt = now();
      await persist();
      return send(res, 200, { revision: session.revision });
    }

    if (req.method === 'GET' && url.pathname === '/api/competition') {
      const identity = auth(req);
      if (!identity) return send(res, 401, { error: 'Zugriffstoken fehlt oder ist ungültig.' });
      if (url.searchParams.get('sessionId') !== identity.sessionId) return send(res, 403, { error: 'Session nicht freigeschaltet.' });
      const session = requireSession(identity);
      if (!session) return send(res, 404, { error: 'Session wurde nicht gefunden.' });
      return send(res, 200, { revision: session.revision, competition: session.competition });
    }

    if (req.method === 'POST' && url.pathname === '/api/events/push') {
      const identity = auth(req);
      if (!identity) return send(res, 401, { error: 'Zugriffstoken fehlt oder ist ungültig.' });
      const body = await readJson(req);
      const session = requireSession(identity);
      if (!session) return send(res, 404, { error: 'Session wurde nicht gefunden.' });
      const events = Array.isArray(body.events) ? body.events : [];
      const receipts = [];
      for (const event of events) {
        const receivedAt = now();
        if (!event || !event.id || !event.sessionId || !event.measurementPointId || !event.kind) {
          receipts.push({ eventId: String(event?.id || ''), decision: 'rejectedInvalidData', reason: 'Pflichtfelder fehlen.', serverReceivedAt: receivedAt });
          continue;
        }
        const denied = roleAllows(identity, event, session);
        if (denied) {
          receipts.push({ eventId: event.id, decision: ['openForJoining','active'].includes(session.status) ? 'rejectedUnauthorized' : 'rejectedSessionClosed', reason: denied, serverReceivedAt: receivedAt });
          continue;
        }
        const existing = store.events[identity.sessionId][event.id];
        if (existing) {
          const same = canonical(existing.event) === canonical(event);
          receipts.push({ eventId: event.id, decision: same ? 'duplicate' : 'acceptedWithConflict', reason: same ? null : 'Gleiche Event-ID mit abweichendem Inhalt.', serverReceivedAt: existing.serverReceivedAt });
          continue;
        }
        store.sequence += 1;
        store.events[identity.sessionId][event.id] = { sequence: store.sequence, serverReceivedAt: receivedAt, event: { ...event, serverReceivedAt: receivedAt } };
        receipts.push({ eventId: event.id, decision: 'accepted', serverReceivedAt: receivedAt });
      }
      touchDevice(session, identity, 0);
      await persist();
      return send(res, 200, { receipts });
    }

    if (req.method === 'GET' && url.pathname === '/api/events/pull') {
      const identity = auth(req);
      if (!identity) return send(res, 401, { error: 'Zugriffstoken fehlt oder ist ungültig.' });
      if (url.searchParams.get('sessionId') !== identity.sessionId) return send(res, 403, { error: 'Session nicht freigeschaltet.' });
      const after = Number(url.searchParams.get('after') || 0);
      const records = Object.values(store.events[identity.sessionId] || {})
        .filter(item => item.sequence > after)
        .sort((a,b) => a.sequence - b.sequence);
      const cursor = records.length ? records[records.length - 1].sequence : after;
      const session = requireSession(identity);
      touchDevice(session, identity);
      await persist();
      return send(res, 200, { cursor, events: records.map(item => item.event) });
    }

    return send(res, 404, { error: 'Endpunkt nicht gefunden.' });
  } catch (error) {
    console.error(error);
    return send(res, 500, { error: error.message || 'Interner Serverfehler.' });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`CoachSplit Sync Server listening on http://${HOST}:${PORT}`);
  console.log(`Persistent data: ${DATA_FILE}`);
});
