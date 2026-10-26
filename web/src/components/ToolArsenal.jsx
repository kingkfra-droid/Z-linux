import React, { useState, useEffect, useCallback } from 'react'
import { api } from '../api.js'

const CATEGORIES = ['All', 'Recon', 'Exploitation', 'Wireless', 'Forensics', 'Reverse Engineering']

export default function ToolArsenal({ triggerRefresh }) {
  const [tools, setTools] = useState([])
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState('All')
  const [targets, setTargets] = useState([])
  const [running, setRunning] = useState({})

  const load = useCallback(async () => {
    try {
      const params = {}
      if (category !== 'All') params.category = category
      if (search) params.search = search
      const [toolList, targetList] = await Promise.all([
        api.getTools(params),
        api.getTargets(),
      ])
      setTools(toolList)
      setTargets(targetList)
    } catch { /* */ }
  }, [category, search])

  useEffect(() => { load() }, [load])

  const handleRun = async (toolId) => {
    const targetId = targets[0]?.id
    setRunning((r) => ({ ...r, [toolId]: true }))
    try {
      await api.runTool(toolId, targetId)
      triggerRefresh()
    } catch { /* */ }
    setTimeout(() => {
      setRunning((r) => ({ ...r, [toolId]: false }))
      load()
      triggerRefresh()
    }, 8000)
  }

  const handleInstall = async (toolId) => {
    setRunning((r) => ({ ...r, [toolId]: true }))
    try { await api.installTool(toolId) } catch { /* */ }
    setTimeout(() => {
      setRunning((r) => ({ ...r, [toolId]: false }))
      load()
    }, 2000)
  }

  return (
    <div>
      <div className="page-title"><span className="accent">⚙</span> Tool Arsenal</div>
      <div className="page-subtitle">$ zlinux --tools --manage</div>

      <div className="toolbar">
        <input
          className="search-input"
          placeholder="Search tools... (e.g. nmap, metasploit)"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="category-pills">
        {CATEGORIES.map((cat) => (
          <button
            key={cat}
            className={`pill ${category === cat ? 'active' : ''}`}
            onClick={() => setCategory(cat)}
          >{cat}</button>
        ))}
      </div>

      {tools.length === 0 ? (
        <div className="empty-state">
          <div className="icon">⚙</div>
          <div className="text">No tools found</div>
        </div>
      ) : (
        <div className="tool-grid">
          {tools.map((tool) => (
            <div key={tool.id} className="tool-card">
              <div className="header">
                <span className="name">{tool.name}</span>
                <span className="cat">{tool.category}</span>
              </div>
              <div className="desc">{tool.description}</div>
              <div className="meta">
                <span className="version">v{tool.version}</span>
                <span className={`status status-${tool.status}`}>{tool.status}</span>
              </div>
              <div className="actions">
                {tool.status === 'not-installed' ? (
                  <button
                    className="btn btn-emerald"
                    disabled={running[tool.id]}
                    onClick={() => handleInstall(tool.id)}
                  >{running[tool.id] ? 'Installing...' : 'Install'}</button>
                ) : (
                  <button
                    className="btn btn-primary"
                    disabled={running[tool.id]}
                    onClick={() => handleRun(tool.id)}
                  >{running[tool.id] ? 'Running...' : 'Run'}</button>
                )}
                <button className="btn" disabled>Config</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
