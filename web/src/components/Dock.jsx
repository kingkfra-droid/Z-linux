import React from 'react'

const NAV_ITEMS = [
  { id: 'dashboard', icon: '◈', label: 'Dashboard' },
  { id: 'tools', icon: '⚙', label: 'Tool Arsenal' },
  { id: 'targets', icon: '⊕', label: 'Target Mapper' },
  { id: 'payloads', icon: '⚡', label: 'Payload Studio' },
]

export default function Dock({ view, setView, onToggleTerminal, terminalOpen }) {
  return (
    <nav className="dock">
      {NAV_ITEMS.map((item) => (
        <button
          key={item.id}
          className={`dock-btn ${view === item.id ? 'active' : ''}`}
          onClick={() => setView(item.id)}
        >
          {item.icon}
          <span className="tooltip">{item.label}</span>
        </button>
      ))}
      <div className="dock-divider" />
      <button
        className={`dock-btn ${terminalOpen ? 'active' : ''}`}
        onClick={onToggleTerminal}
      >
        ▣
        <span className="tooltip">Terminal</span>
      </button>
    </nav>
  )
}
