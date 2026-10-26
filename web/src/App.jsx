import React, { useState, useEffect, useCallback } from 'react'
import StatusBar from './components/StatusBar.jsx'
import Dock from './components/Dock.jsx'
import Dashboard from './components/Dashboard.jsx'
import ToolArsenal from './components/ToolArsenal.jsx'
import TargetMapper from './components/TargetMapper.jsx'
import PayloadStudio from './components/PayloadStudio.jsx'
import Terminal from './components/Terminal.jsx'
import { api } from './api.js'

const VIEWS = {
  dashboard: { label: 'Dashboard', component: Dashboard },
  tools: { label: 'Tool Arsenal', component: ToolArsenal },
  targets: { label: 'Target Mapper', component: TargetMapper },
  payloads: { label: 'Payload Studio', component: PayloadStudio },
}

export default function App() {
  const [view, setView] = useState('dashboard')
  const [stats, setStats] = useState(null)
  const [terminalOpen, setTerminalOpen] = useState(true)
  const [refreshKey, setRefreshKey] = useState(0)

  const triggerRefresh = useCallback(() => setRefreshKey((k) => k + 1), [])

  useEffect(() => {
    let active = true
    async function poll() {
      try {
        const s = await api.getStats()
        if (active) setStats(s)
      } catch { /* ignore */ }
    }
    poll()
    const interval = setInterval(poll, 3000)
    return () => { active = false; clearInterval(interval) }
  }, [])

  const ActiveView = VIEWS[view].component

  return (
    <div className="app">
      <StatusBar stats={stats} />
      <Dock view={view} setView={setView} onToggleTerminal={() => setTerminalOpen((o) => !o)} terminalOpen={terminalOpen} />
      <main className="main-content">
        <ActiveView stats={stats} refreshKey={refreshKey} triggerRefresh={triggerRefresh} />
      </main>
      <Terminal open={terminalOpen} onToggle={() => setTerminalOpen((o) => !o)} />
    </div>
  )
}
