import React, { useState, useEffect, useCallback } from 'react'
import { api } from '../api.js'

const PAYLOAD_TYPES = [
  { value: 'meterpreter', label: 'Meterpreter Reverse TCP' },
  { value: 'shellcode', label: 'Linux Shell Reverse' },
  { value: 'webshell', label: 'PHP Web Shell' },
  { value: 'python', label: 'Python Meterpreter' },
  { value: 'java', label: 'Java JSP Shell' },
]

const FORMATS = ['raw', 'c', 'python', 'php', 'exe', 'jar', 'elf', 'ps1']
const ENCODERS = ['none', 'shikata_ga_nai', 'x86/countdown', 'x86/fnsteg', 'cmd/powershell_base64']

export default function PayloadStudio({ triggerRefresh }) {
  const [payloads, setPayloads] = useState([])
  const [listeners, setListeners] = useState([])
  const [targets, setTargets] = useState([])
  const [form, setForm] = useState({
    name: '', type: 'meterpreter', target_id: '', format: 'raw',
    lhost: '10.10.10.1', lport: '4444', encoder: 'none',
  })

  const load = useCallback(async () => {
    try {
      const [p, l, t] = await Promise.all([
        api.getPayloads(),
        api.getListeners(),
        api.getTargets(),
      ])
      setPayloads(p)
      setListeners(l)
      setTargets(t)
    } catch { /* */ }
  }, [])

  useEffect(() => {
    load()
    const interval = setInterval(load, 5000)
    return () => clearInterval(interval)
  }, [load])

  const handleGenerate = async () => {
    if (!form.lhost || !form.lport) return
    await api.addPayload(form)
    setForm({ ...form, name: '' })
    load()
    triggerRefresh()
  }

  const handleStartListener = async (payloadId) => {
    const payload = payloads.find((p) => p.id === payloadId)
    if (!payload) return
    await api.addListener({
      name: `Listener-${payload.name}`,
      type: payload.type,
      host: payload.lhost,
      port: payload.lport,
      payload_id: payloadId,
    })
    load()
    triggerRefresh()
  }

  const handleToggleListener = async (id, currentStatus) => {
    await api.updateListener(id, { status: currentStatus === 'active' ? 'idle' : 'active' })
    load()
  }

  const handleDeletePayload = async (id) => {
    await api.deletePayload(id)
    load()
    triggerRefresh()
  }

  return (
    <div>
      <div className="page-title"><span className="accent">⚡</span> Payload & Exploit Studio</div>
      <div className="page-subtitle">$ zlinux --payload --generate</div>

      <div className="payload-layout">
        {/* Form */}
        <div className="payload-form">
          <h3 style={{ fontSize: '14px', color: 'var(--text-bright)', marginBottom: '16px' }}>Configure Payload</h3>
          <div className="form-group">
            <label>Name</label>
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Custom payload name"
            />
          </div>
          <div className="form-group">
            <label>Type</label>
            <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
              {PAYLOAD_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label>Target</label>
            <select value={form.target_id} onChange={(e) => setForm({ ...form, target_id: e.target.value })}>
              <option value="">None</option>
              {targets.map((t) => <option key={t.id} value={t.id}>{t.name} ({t.ip})</option>)}
            </select>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label>LHOST</label>
              <input value={form.lhost} onChange={(e) => setForm({ ...form, lhost: e.target.value })} placeholder="0.0.0.0" />
            </div>
            <div className="form-group">
              <label>LPORT</label>
              <input value={form.lport} onChange={(e) => setForm({ ...form, lport: e.target.value })} placeholder="4444" />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label>Format</label>
              <select value={form.format} onChange={(e) => setForm({ ...form, format: e.target.value })}>
                {FORMATS.map((f) => <option key={f} value={f}>{f}</option>)}
              </select>
            </div>
            <div className="form-group">
              <label>Encoder</label>
              <select value={form.encoder} onChange={(e) => setForm({ ...form, encoder: e.target.value })}>
                {ENCODERS.map((enc) => <option key={enc} value={enc}>{enc}</option>)}
              </select>
            </div>
          </div>
          <button className="btn btn-primary" style={{ width: '100%', marginTop: '4px', padding: '10px' }} onClick={handleGenerate}>
            ⚡ Generate Payload
          </button>
        </div>

        {/* Output */}
        <div className="payload-output">
          <h3 style={{ fontSize: '14px', color: 'var(--text-bright)' }}>Generated Payloads ({payloads.length})</h3>
          {payloads.length === 0 ? (
            <div className="empty-state"><div className="icon">⚡</div><div className="text">No payloads generated yet</div></div>
          ) : (
            <div className="payload-list">
              {payloads.map((p) => (
                <div key={p.id} className="payload-item">
                  <div className="name">
                    {p.name}
                    <button className="btn btn-danger" style={{ padding: '2px 8px', fontSize: '11px' }} onClick={() => handleDeletePayload(p.id)}>✕</button>
                  </div>
                  <div className="cmd">{p.encoded}</div>
                  <div style={{ marginTop: '6px' }}>
                    <button className="btn btn-emerald" style={{ fontSize: '11px', padding: '4px 10px' }} onClick={() => handleStartListener(p.id)}>
                      Start Listener
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Listeners */}
          <h3 style={{ fontSize: '14px', color: 'var(--text-bright)', marginTop: '8px' }}>Active Listeners</h3>
          <div className="listener-panel">
            {listeners.length === 0 ? (
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', padding: '8px 0' }}>No listeners active</div>
            ) : (
              listeners.map((l) => (
                <div key={l.id} className="listener-item">
                  <span>
                    <span className={`listener-dot ${l.status}`} />
                    {l.name}
                  </span>
                  <span style={{ color: 'var(--cyan)' }}>{l.host}:{l.port}</span>
                  <button
                    className="btn"
                    style={{ fontSize: '11px', padding: '3px 8px' }}
                    onClick={() => handleToggleListener(l.id, l.status)}
                  >{l.status === 'active' ? 'Stop' : 'Start'}</button>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
