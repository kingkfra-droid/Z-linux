import React from 'react'

export default function StatusBar({ stats }) {
  const s = stats || {}
  return (
    <div className="status-bar">
      <div className="status-brand">
        <div className="logo">Z</div>
        Z-LINUX OS CORE
      </div>
      <div className="status-metric">
        <span className="label">CPU</span>
        <span className="value cyan">{s.cpu ?? '--'}%</span>
      </div>
      <div className="status-metric">
        <span className="label">RAM</span>
        <span className="value emerald">{s.ram ?? '--'}%</span>
      </div>
      <div className="status-metric">
        <span className="label">TUNNELS</span>
        <span className="value">{s.tunnels ?? 0}</span>
      </div>
      <div className="status-metric">
        <span className="label">SCANS</span>
        <span className="value cyan">{s.activeScans ?? 0}</span>
      </div>
      <div className="spacer" />
      <div className="status-metric">
        <span className="label">NET↑</span>
        <span className="value">{s.netOut ?? 0} KB/s</span>
      </div>
      <div className="status-metric">
        <span className="label">NET↓</span>
        <span className="value">{s.netIn ?? 0} KB/s</span>
      </div>
      <div className="status-metric">
        <span className="label">IP</span>
        <span className="value emerald">{s.localIP || '10.10.10.1'}</span>
      </div>
      <div className="pulse" />
      <div className="status-metric">
        <span className="value emerald">SECURE</span>
      </div>
    </div>
  )
}
