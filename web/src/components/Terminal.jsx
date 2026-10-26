import React, { useState, useEffect, useRef } from 'react'
import { api } from '../api.js'

export default function Terminal({ open, onToggle }) {
  const [logs, setLogs] = useState([])
  const bodyRef = useRef(null)

  useEffect(() => {
    let active = true
    async function poll() {
      try {
        const l = await api.getLogs({ limit: 50 })
        if (active) setLogs(l)
      } catch { /* */ }
    }
    poll()
    const interval = setInterval(poll, 2000)
    return () => { active = false; clearInterval(interval) }
  }, [])

  useEffect(() => {
    if (bodyRef.current) {
      bodyRef.current.scrollTop = bodyRef.current.scrollHeight
    }
  }, [logs])

  return (
    <div className={`terminal-drawer ${open ? 'expanded' : 'collapsed'}`}>
      <div className="terminal-header" onClick={onToggle}>
        <span className="title">
          <span className="dot" />
          terminal — zlinux@core:~$
        </span>
        <div className="controls">
          <button className="ctrl-btn" onClick={(e) => { e.stopPropagation(); onToggle() }}>
            {open ? '▼' : '▲'}
          </button>
        </div>
      </div>
      {open && (
        <div className="terminal-body" ref={bodyRef}>
          {logs.length === 0 ? (
            <div style={{ color: 'var(--text-muted)' }}>No output. Run a tool or scan to see live results.</div>
          ) : (
            logs.map((log) => (
              <div key={log.id} className={`log-line ${log.level}`}>
                <span className="time">{new Date(log.timestamp).toLocaleTimeString()}</span>
                <span className="level">[{log.level.toUpperCase()}]</span>
                <span className="msg">{log.message}</span>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}
