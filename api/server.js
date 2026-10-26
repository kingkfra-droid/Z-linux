import express from 'express';
import cors from 'cors';
import { Store, nextId } from './store.js';
import {
  seedTools, seedTargets, seedPorts, seedVulns,
  seedPayloads, seedListeners, seedLogs,
} from './seed.js';

const app = express();
app.use(cors());
app.use(express.json());

// ── Stores ──────────────────────────────────────────────
const tools = new Store('tools', seedTools);
const targets = new Store('targets', seedTargets);
const ports = new Store('ports', seedPorts);
const vulns = new Store('vulns', seedVulns);
const payloads = new Store('payloads', seedPayloads);
const listeners = new Store('listeners', seedListeners);
const logs = new Store('logs', seedLogs);

// ── Helpers ─────────────────────────────────────────────
function log(targetId, toolId, message, level = 'info') {
  return logs.add({
    target_id: targetId,
    tool_id: toolId,
    message,
    level,
    timestamp: new Date().toISOString(),
  });
}

// Simulate a scan: add log entries over time
function simulateScan(targetId, toolId) {
  const target = targets.find(targetId);
  if (!target) return;
  const msgs = [
    `Starting scan on ${target.ip}...`,
    `Host is up (0.0012s latency)`,
    `Scanning common ports...`,
    `Discovered open port 80/tcp`,
    `Discovered open port 443/tcp`,
    `Service detection complete`,
    `Script scan phase starting...`,
    `Vulnerability checks running...`,
    `Scan complete: 8 open ports found`,
  ];
  msgs.forEach((msg, i) => {
    setTimeout(() => log(targetId, toolId, msg, i === 8 ? 'warning' : 'info'), i * 800);
  });
}

// ── Health ──────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime(), tools: tools.all().length });
});

// ── System Stats ────────────────────────────────────────
app.get('/api/stats', (req, res) => {
  res.json({
    cpu: Math.round(20 + Math.random() * 45),
    ram: Math.round(40 + Math.random() * 35),
    disk: 62,
    netIn: Math.round(Math.random() * 1200),
    netOut: Math.round(Math.random() * 800),
    localIP: '10.10.10.1',
    publicIP: '203.0.113.42',
    tunnels: listeners.filter((l) => l.status === 'active').length,
    activeScans: targets.filter((t) => t.status === 'scanning').length,
    toolCount: tools.all().length,
    targetCount: targets.all().length,
    payloadCount: payloads.all().length,
    vulnCount: vulns.all().length,
  });
});

// ── Tools ───────────────────────────────────────────────
app.get('/api/tools', (req, res) => {
  let list = tools.all();
  if (req.query.category) list = list.filter((t) => t.category === req.query.category);
  if (req.query.search) {
    const q = req.query.search.toLowerCase();
    list = list.filter((t) => t.name.toLowerCase().includes(q) || t.description.toLowerCase().includes(q));
  }
  res.json(list);
});

app.post('/api/tools', (req, res) => {
  const t = tools.add(req.body);
  res.status(201).json(t);
});

app.put('/api/tools/:id', (req, res) => {
  const t = tools.update(req.params.id, req.body);
  if (!t) return res.status(404).json({ error: 'Tool not found' });
  res.json(t);
});

app.delete('/api/tools/:id', (req, res) => {
  tools.remove(req.params.id);
  res.status(204).end();
});

// Run a tool against a target
app.post('/api/tools/:id/run', (req, res) => {
  const tool = tools.find(req.params.id);
  if (!tool) return res.status(404).json({ error: 'Tool not found' });
  const targetId = req.body.target_id;
  const target = targetId ? targets.find(targetId) : null;
  tools.update(req.params.id, { status: 'running' });
  const cmd = target ? tool.command.replace('{target}', target.ip).replace('{domain}', target.name) : tool.command;
  log(targetId || null, tool.id, `Executing: ${cmd}`, 'info');
  if (target) simulateScan(targetId, tool.id);
  setTimeout(() => {
    tools.update(req.params.id, { status: 'installed' });
    log(targetId || null, tool.id, `${tool.name} finished execution`, 'info');
  }, 8000);
  res.json({ status: 'started', command: cmd });
});

// Install a tool
app.post('/api/tools/:id/install', (req, res) => {
  const tool = tools.find(req.params.id);
  if (!tool) return res.status(404).json({ error: 'Tool not found' });
  log(null, tool.id, `Installing ${tool.name}...`, 'info');
  setTimeout(() => {
    tools.update(req.params.id, { status: 'installed' });
    log(null, tool.id, `${tool.name} installed successfully`, 'info');
  }, 2000);
  res.json({ status: 'installing' });
});

// ── Targets ─────────────────────────────────────────────
app.get('/api/targets', (req, res) => {
  res.json(targets.all());
});

app.post('/api/targets', (req, res) => {
  const t = targets.add({ ...req.body, status: 'idle', createdAt: new Date().toISOString() });
  res.status(201).json(t);
});

app.put('/api/targets/:id', (req, res) => {
  const t = targets.update(req.params.id, req.body);
  if (!t) return res.status(404).json({ error: 'Target not found' });
  res.json(t);
});

app.delete('/api/targets/:id', (req, res) => {
  const id = req.params.id;
  targets.remove(id);
  ports.remove(id); // won't work by id; handle below
  // Remove related data
  ports.all().filter((p) => p.target_id == id).forEach((p) => ports.remove(p.id));
  vulns.all().filter((v) => v.target_id == id).forEach((v) => vulns.remove(v.id));
  res.status(204).end();
});

// Start scan on a target
app.post('/api/targets/:id/scan', (req, res) => {
  const target = targets.find(req.params.id);
  if (!target) return res.status(404).json({ error: 'Target not found' });
  targets.update(req.params.id, { status: 'scanning' });
  log(req.params.id, 1, `Starting nmap scan on ${target.ip}`, 'info');
  simulateScan(req.params.id, 1);
  setTimeout(() => {
    targets.update(req.params.id, { status: 'complete' });
    log(req.params.id, 1, `Scan complete for ${target.ip}`, 'info');
  }, 8000);
  res.json({ status: 'scanning' });
});

// ── Ports ───────────────────────────────────────────────
app.get('/api/targets/:id/ports', (req, res) => {
  res.json(ports.filter((p) => p.target_id == req.params.id));
});

app.post('/api/targets/:id/ports', (req, res) => {
  const p = ports.add({ ...req.body, target_id: Number(req.params.id) });
  res.status(201).json(p);
});

app.delete('/api/ports/:id', (req, res) => {
  ports.remove(req.params.id);
  res.status(204).end();
});

// ── Vulnerabilities ─────────────────────────────────────
app.get('/api/targets/:id/vulns', (req, res) => {
  res.json(vulns.filter((v) => v.target_id == req.params.id));
});

app.post('/api/targets/:id/vulns', (req, res) => {
  const v = vulns.add({ ...req.body, target_id: Number(req.params.id) });
  res.status(201).json(v);
});

app.delete('/api/vulns/:id', (req, res) => {
  vulns.remove(req.params.id);
  res.status(204).end();
});

// ── Payloads ────────────────────────────────────────────
app.get('/api/payloads', (req, res) => {
  res.json(payloads.all());
});

app.post('/api/payloads', (req, res) => {
  const { name, type, target_id, format, lhost, lport, encoder } = req.body;
  const typeMap = {
    meterpreter: 'windows/meterpreter/reverse_tcp',
    shellcode: 'linux/x86/shell/reverse_tcp',
    webshell: 'php/meterpreter/reverse_tcp',
    python: 'python/meterpreter/reverse_tcp',
    java: 'java/jsp_shell_reverse_tcp',
  };
  const base = typeMap[type] || 'windows/meterpreter/reverse_tcp';
  const enc = encoder && encoder !== 'none' ? ` -e ${encoder}` : '';
  const encoded = `msfvenom -p ${base} LHOST=${lhost || '0.0.0.0'} LPORT=${lport || 4444}${enc} -f ${format || 'raw'}`;
  const p = payloads.add({
    name: name || `${type} payload`,
    type, target_id: target_id || null, format: format || 'raw',
    lhost: lhost || '0.0.0.0', lport: lport || 4444,
    encoder: encoder || 'none', status: 'generated',
    createdAt: new Date().toISOString(), encoded,
  });
  log(target_id || null, 6, `Payload generated: ${p.name}`, 'info');
  res.status(201).json(p);
});

app.delete('/api/payloads/:id', (req, res) => {
  payloads.remove(req.params.id);
  res.status(204).end();
});

// ── Listeners ───────────────────────────────────────────
app.get('/api/listeners', (req, res) => {
  res.json(listeners.all());
});

app.post('/api/listeners', (req, res) => {
  const l = listeners.add({ ...req.body, status: 'active' });
  log(null, 6, `Listener started on ${l.host}:${l.port} (${l.type})`, 'info');
  res.status(201).json(l);
});

app.put('/api/listeners/:id', (req, res) => {
  const l = listeners.update(req.params.id, req.body);
  if (!l) return res.status(404).json({ error: 'Listener not found' });
  res.json(l);
});

app.delete('/api/listeners/:id', (req, res) => {
  listeners.remove(req.params.id);
  res.status(204).end();
});

// ── Logs ─────────────────────────────────────────────────
app.get('/api/logs', (req, res) => {
  let list = logs.all().sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  if (req.query.target_id) list = list.filter((l) => l.target_id == req.query.target_id);
  if (req.query.level) list = list.filter((l) => l.level === req.query.level);
  if (req.query.limit) list = list.slice(0, Number(req.query.limit));
  res.json(list);
});

app.post('/api/logs', (req, res) => {
  const l = log(req.body.target_id, req.body.tool_id, req.body.message, req.body.level);
  res.status(201).json(l);
});

// ── Start ───────────────────────────────────────────────
const PORT = process.env.PORT || 8000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Z-Linux OS Core API running on port ${PORT}`);
});
