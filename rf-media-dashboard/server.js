#!/usr/bin/env node
'use strict';

// RF MEDIA read-only dashboard bridge for GenieACS 1.2.x.
// Binds to loopback by default. Never returns PPPoE credentials or Wi-Fi keys.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const HOST = process.env.RF_DASH_HOST || '127.0.0.1';
const PORT = Number(process.env.RF_DASH_PORT || 7568);
const NBI = (process.env.GENIEACS_NBI || 'http://127.0.0.1:7557').replace(/\/$/, '');
const ONLINE_MINUTES = Number(process.env.RF_ONLINE_MINUTES || 5);
const PUBLIC_DIR = path.resolve(__dirname);
const TOKEN = process.env.RF_DASH_TOKEN || '';

function send(res, status, data, type = 'application/json; charset=utf-8') {
  res.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  res.end(type.startsWith('application/json') ? JSON.stringify(data) : data);
}
function authorized(req) {
  if (!TOKEN) return true; // loopback-only default; set token when exposing through a proxy.
  return req.headers.authorization === 'Bearer ' + TOKEN;
}
async function getDevices() {
  const url = new URL(NBI + '/devices/');
  url.searchParams.set('query', '{}');
  // Deliberately limited projection: excludes WAN PPPoE username/password and Wi-Fi keys.
  url.searchParams.set('projection', '_id,_lastInform,_deviceId');
  const r = await fetch(url, { headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(20000) });
  if (!r.ok) throw new Error('GenieACS NBI returned HTTP ' + r.status);
  const data = await r.json();
  if (!Array.isArray(data)) throw new Error('Unexpected NBI response');
  return data;
}
function mapDevice(d, now) {
  const id = d._deviceId || {};
  const last = d._lastInform || null;
  const ageMs = last ? Math.max(0, now - Date.parse(last)) : Infinity;
  return {
    id: d._id || '',
    manufacturer: id._Manufacturer || 'Unknown',
    model: id._ProductClass || 'Unknown',
    serial: id._SerialNumber || '',
    oui: id._OUI || '',
    lastInform: last,
    ageSeconds: Number.isFinite(ageMs) ? Math.floor(ageMs / 1000) : null,
    online: ageMs <= ONLINE_MINUTES * 60 * 1000
  };
}
const server = http.createServer(async (req, res) => {
  try {
    if (!authorized(req)) return send(res, 401, { error: 'Unauthorized' });
    const u = new URL(req.url, 'http://' + req.headers.host);
    if (u.pathname === '/api/health') return send(res, 200, { ok: true, service: 'rf-media-dashboard', nbi: NBI });
    if (u.pathname === '/api/summary' || u.pathname === '/api/devices') {
      const raw = await getDevices();
      const now = Date.now();
      const devices = raw.map(d => mapDevice(d, now));
      const online = devices.filter(d => d.online).length;
      const vendors = {};
      const models = {};
      for (const d of devices) {
        vendors[d.manufacturer] = (vendors[d.manufacturer] || 0) + 1;
        models[d.model] = (models[d.model] || 0) + 1;
      }
      if (u.pathname === '/api/summary') {
        return send(res, 200, {
          generatedAt: new Date(now).toISOString(),
          total: devices.length, online, offline: devices.length - online,
          onlineWindowMinutes: ONLINE_MINUTES,
          vendors: Object.entries(vendors).sort((a,b) => b[1]-a[1]).map(([name,count]) => ({ name, count })),
          models: Object.entries(models).sort((a,b) => b[1]-a[1]).map(([name,count]) => ({ name, count }))
        });
      }
      const q = (u.searchParams.get('q') || '').toLowerCase();
      const limit = Math.min(200, Math.max(1, Number(u.searchParams.get('limit') || 100)));
      const filtered = devices.filter(d => !q || [d.id,d.manufacturer,d.model,d.serial].some(v => v.toLowerCase().includes(q)));
      filtered.sort((a,b) => Date.parse(b.lastInform || 0) - Date.parse(a.lastInform || 0));
      return send(res, 200, { total: filtered.length, devices: filtered.slice(0, limit) });
    }
    if (u.pathname === '/' || u.pathname === '/index.html' || u.pathname === '/app.js' || u.pathname === '/style.css') {
      const file = path.join(PUBLIC_DIR, u.pathname === '/' ? 'index.html' : path.basename(u.pathname));
      if (!file.startsWith(PUBLIC_DIR + path.sep) || !fs.existsSync(file)) return send(res, 404, { error: 'Not found' });
      const ext = path.extname(file);
      const type = ext === '.js' ? 'text/javascript; charset=utf-8' : ext === '.css' ? 'text/css; charset=utf-8' : 'text/html; charset=utf-8';
      return send(res, 200, fs.readFileSync(file, 'utf8'), type);
    }
    return send(res, 404, { error: 'Not found' });
  } catch (e) {
    return send(res, 502, { error: 'Dashboard backend error', detail: e.message });
  }
});
server.listen(PORT, HOST, () => console.log(`RF MEDIA dashboard listening on http://${HOST}:${PORT}; NBI=${NBI}; online threshold=${ONLINE_MINUTES}m`));
