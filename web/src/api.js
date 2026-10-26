const API_BASE = '/api';

async function request(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (res.status === 204) return null;
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export const api = {
  // Stats
  getStats: () => request('/stats'),

  // Tools
  getTools: (params = {}) => {
    const q = new URLSearchParams(params).toString();
    return request(`/tools${q ? '?' + q : ''}`);
  },
  runTool: (id, target_id) => request(`/tools/${id}/run`, { method: 'POST', body: JSON.stringify({ target_id }) }),
  installTool: (id) => request(`/tools/${id}/install`, { method: 'POST' }),
  updateTool: (id, data) => request(`/tools/${id}`, { method: 'PUT', body: JSON.stringify(data) }),

  // Targets
  getTargets: () => request('/targets'),
  addTarget: (data) => request('/targets', { method: 'POST', body: JSON.stringify(data) }),
  scanTarget: (id) => request(`/targets/${id}/scan`, { method: 'POST' }),
  deleteTarget: (id) => request(`/targets/${id}`, { method: 'DELETE' }),
  getPorts: (id) => request(`/targets/${id}/ports`),
  addPort: (id, data) => request(`/targets/${id}/ports`, { method: 'POST', body: JSON.stringify(data) }),
  getVulns: (id) => request(`/targets/${id}/vulns`),
  addVuln: (id, data) => request(`/targets/${id}/vulns`, { method: 'POST', body: JSON.stringify(data) }),

  // Payloads
  getPayloads: () => request('/payloads'),
  addPayload: (data) => request('/payloads', { method: 'POST', body: JSON.stringify(data) }),
  deletePayload: (id) => request(`/payloads/${id}`, { method: 'DELETE' }),

  // Listeners
  getListeners: () => request('/listeners'),
  addListener: (data) => request('/listeners', { method: 'POST', body: JSON.stringify(data) }),
  updateListener: (id, data) => request(`/listeners/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteListener: (id) => request(`/listeners/${id}`, { method: 'DELETE' }),

  // Logs
  getLogs: (params = {}) => {
    const q = new URLSearchParams(params).toString();
    return request(`/logs${q ? '?' + q : ''}`);
  },
};
