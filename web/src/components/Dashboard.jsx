import React, { useState, useEffect } from 'react'
import { api } from '../api.js'

const QUICK_LAUNCH = [
  { icon: '⚙', title: 'Tool Arsenal', desc: 'Manage security tools', view: 'tools', statKey: 'toolCount' },
  { icon: '⊕', title: 'Target Mapper', desc: 'Recon & network mapping', view: 'targets', statKey: 'targetCount' },
  { icon: '⚡', title: 'Payload Studio', desc: 'Generate & encode payloads', view: 'payloads', statKey: 'payloadCount' },
  { icon: '◈', title: 'Vuln Tracker', desc: 'Discovered vulnerabilities', view: 'targets', statKey: 'vulnCount' },
]

export default function Dashboard({ stats, triggerRefresh }) {
  const [recentLogs, setRecentLogs] = useState([])

  useEffect(() => {
    api.getLogs({ limit: 6 }).then(setRecentLogs).catch(() => {})
    const interval = setInterval(() => {
      api.getLogs({ limit: 6 }).then(setRecentLogs).catch(() => {})
    }, 4000)
    return () => clearInterval(interval)
  }, [])

  const s = stats || {}

  return (
    <div>
      <div className="page-title">
        <span className="accent">◈</span> Operations Dashboard
      </div>
      <div className="page-subtitle">$ zlinux --status --realtime</div>

      {/* Stats row */}
      <div className="stats-row">
        <div className="stat-box">
          <div className="label">CPU Usage</div>
          <div className="value" style={{ color: s.cpu > 70 ? 'var(--danger)' : 'var(--cyan)' }}>{s.cpu ?? '--'}%</div>
          <div className="bar"><div className="bar-fill" style={{ width: `${s.cpu || 0}%`, background: 'var(--cyan)' }} /></div>
        </div>
        <div className="stat-box">
          <div className="label">Memory</div>
          <div className="value" style={{ color: 'var(--emerald)' }}>{s.ram ?? '--'}%</div>
          <div className="bar"><div className="bar-fill" style={{ width: `${s.ram || 0}%`, background: 'var(--emerald)' }} /></div>
        </div>
        <div className="stat-box">
          <div className="label">Active Scans</div>
          <div className="value">{s.activeScans ?? 0}</div>
          <div className="bar"><div className="bar-fill" style={{ width: `${(s.activeScans || 0) * 20}%`, background: 'var(--warning)' }} /></div>
        </div>
        <div className="stat-box">
          <div className="label">Tunnels</div>
          <div className="value" style={{ color: 'var(--cyan)' }}>{s.tunnels ?? 0}</div>
          <div className="bar"><div className="bar-fill" style={{ width: `${(s.tunnels || 0) * 25}%`, background: 'var(--cyan)' }} /></div>
        </div>
      </div>

      {/* Quick launcher */}
      <h3 style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '12px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Quick Launch</h3>
      <div className="dash-grid">
        {QUICK_LAUNCH.map((card) => (
          <div key={card.title} className="dash-card" onClick={() => triggerRefresh()}>
            <span className="icon">{card.icon}</span>
            <div className="title">{card.title}</div>
            <div className="desc">{card.desc}</div>
            <div className="count">{s[card.statKey] ?? 0}</div>
          </div>
        ))}
      </div>

      {/* Recent activity */}
      <h3 style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '12px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Recent Activity</h3>
      <div style={{ background: 'var(--bg-surface)', border: '1px solid var(--border)', borderRadius: '10px', padding: '14px' }}>
        {recentLogs.length === 0 ? (
          <div className="empty-state"><div className="text">No recent activity</div></div>
        ) : (
          recentLogs.map((log) => (
            <div key={log.id} className={`log-line ${log.level}`} style={{ padding: '4px 0', borderBottom: '1px solid var(--border)' }}>
              <span className="time">{new Date(log.timestamp).toLocaleTimeString()}</span>
              <span className="level">[{log.level.toUpperCase()}]</span>
              <span className="msg">{log.message}</span>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
