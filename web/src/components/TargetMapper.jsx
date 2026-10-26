import React, { useState, useEffect, useCallback } from 'react'
import { api } from '../api.js'

export default function TargetMapper({ triggerRefresh }) {
  const [targets, setTargets] = useState([])
  const [selected, setSelected] = useState(null)
  const [ports, setPorts] = useState([])
  const [vulns, setVulns] = useState([])
  const [newTarget, setNewTarget] = useState({ name: '', ip: '', scope: '', os: '' })
  const [scanning, setScanning] = useState(false)

  const loadTargets = useCallback(async () => {
    try {
      const list = await api.getTargets()
      setTargets(list)
      if (!selected && list.length > 0) setSelected(list[0].id)
    } catch { /* */ }
  }, [selected])

  useEffect(() => { loadTargets() }, [loadTargets])

  const loadDetail = useCallback(async () => {
    if (!selected) return
    try {
      const [p, v] = await Promise.all([
        api.getPorts(selected),
        api.getVulns(selected),
      ])
      setPorts(p)
      setVulns(v)
    } catch { /* */ }
  }, [selected])

  useEffect(() => {
    loadDetail()
    const interval = setInterval(loadDetail, 3000)
    return () => clearInterval(interval)
  }, [loadDetail])

  const handleAdd = async () => {
    if (!newTarget.name || !newTarget.ip) return
    await api.addTarget(newTarget)
    setNewTarget({ name: '', ip: '', scope: '', os: '' })
    loadTargets()
    triggerRefresh()
  }

  const handleScan = async (id) => {
    setScanning(true)
    try {
      await api.scanTarget(id)
      triggerRefresh()
    } catch { /* */ }
    setTimeout(() => {
      setScanning(false)
      loadTargets()
    }, 8000)
  }

  const handleDelete = async (id) => {
    await api.deleteTarget(id)
    if (selected === id) setSelected(null)
    loadTargets()
    triggerRefresh()
  }

  const activeTarget = targets.find((t) => t.id === selected)

  return (
    <div>
      <div className="page-title"><span className="accent">⊕</span> Live Target Mapper</div>
      <div className="page-subtitle">$ zlinux --recon --scope</div>

      {/* Network topology */}
      <div className="topology">
        <div className="topology-grid">
          <div className="topo-node attacker">
            <span className="icon">🖥</span>
            <span className="label">Z-Linux Host</span>
            <span className="ip">10.10.10.1</span>
          </div>
          <span className="topo-connector">━━━</span>
          {targets.slice(0, 4).map((t) => (
            <React.Fragment key={t.id}>
              <div className="topo-node" onClick={() => setSelected(t.id)} style={{ cursor: 'pointer' }}>
                <span className="icon">{t.status === 'scanning' ? '🔄' : '📡'}</span>
                <span className="label">{t.name}</span>
                <span className="ip">{t.ip}</span>
              </div>
              {targets.indexOf(t) < Math.min(targets.length, 4) - 1 && (
                <span className="topo-connector">━━━</span>
              )}
            </React.Fragment>
          ))}
        </div>
      </div>

      <div className="target-layout">
        {/* Target list */}
        <div className="target-list-panel">
          <div className="panel-header">
            Targets ({targets.length})
          </div>
          <div className="inline-form">
            <input
              placeholder="Name"
              value={newTarget.name}
              onChange={(e) => setNewTarget({ ...newTarget, name: e.target.value })}
            />
            <input
              placeholder="IP"
              value={newTarget.ip}
              onChange={(e) => setNewTarget({ ...newTarget, ip: e.target.value })}
            />
            <button className="btn btn-primary" onClick={handleAdd}>Add</button>
          </div>
          <div style={{ overflowY: 'auto', flex: 1 }}>
            {targets.map((t) => (
              <div
                key={t.id}
                className={`target-item ${selected === t.id ? 'active' : ''}`}
                onClick={() => setSelected(t.id)}
              >
                <div className="name">
                  {t.name}
                  <span className={`target-badge badge-${t.status}`}>{t.status}</span>
                </div>
                <div className="ip">{t.ip}</div>
                <div className="os">{t.os}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Target detail */}
        <div className="target-detail">
          {activeTarget ? (
            <>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                <div>
                  <div style={{ fontSize: '16px', fontWeight: 700, color: 'var(--text-bright)' }}>{activeTarget.name}</div>
                  <div style={{ fontFamily: 'var(--mono)', fontSize: '13px', color: 'var(--cyan)' }}>{activeTarget.ip} · {activeTarget.scope}</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>{activeTarget.os}</div>
                </div>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button
                    className="btn btn-primary"
                    disabled={scanning}
                    onClick={() => handleScan(activeTarget.id)}
                  >{scanning ? 'Scanning...' : 'Scan Now'}</button>
                  <button className="btn btn-danger" onClick={() => handleDelete(activeTarget.id)}>Delete</button>
                </div>
              </div>

              {/* Ports */}
              <div className="detail-section">
                <h3>Open Ports <span className="count">({ports.length})</span></h3>
                {ports.length === 0 ? (
                  <div className="empty-state"><div className="text">No ports discovered</div></div>
                ) : (
                  <table className="port-table">
                    <thead>
                      <tr><th>Port</th><th>Service</th><th>State</th><th>Version</th></tr>
                    </thead>
                    <tbody>
                      {ports.map((p) => (
                        <tr key={p.id}>
                          <td className="port-num">{p.port}/tcp</td>
                          <td>{p.service}</td>
                          <td className={`state-${p.state}`}>{p.state}</td>
                          <td>{p.version}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>

              {/* Vulnerabilities */}
              <div className="detail-section">
                <h3>Vulnerabilities <span className="count">({vulns.length})</span></h3>
                {vulns.length === 0 ? (
                  <div className="empty-state"><div className="text">No vulnerabilities found</div></div>
                ) : (
                  <div className="vuln-list">
                    {vulns.map((v) => (
                      <div key={v.id} className="vuln-card">
                        <div className={`sev sev-${v.severity}`} />
                        <div>
                          <div className="cve">
                            {v.cve}
                            <span className={`sev-label ${v.severity}`}>{v.severity}</span>
                          </div>
                          <div className="desc">{v.description}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="empty-state">
              <div className="icon">⊕</div>
              <div className="text">Select a target to view details</div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
