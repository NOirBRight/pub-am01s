import { describe, expect, it } from 'vitest'
import {
  catalogCommand,
  enabledCommand,
  loginLabel,
  movedOrder,
  orderCommand,
  presentSettings,
  remainingModeCommand,
  settingsCommand,
  withOrder,
} from '../plugin/settings-model.mjs'

describe('settings commands', () => {
  it('builds the enabled toggle argv', () => {
    expect(enabledCommand('claude', true)).toEqual(['settings', 'set', 'enabled', 'claude', 'true'])
    expect(enabledCommand('ollama-cloud', false)).toEqual(['settings', 'set', 'enabled', 'ollama-cloud', 'false'])
    expect(catalogCommand()).toEqual(['catalog'])
    expect(settingsCommand()).toEqual(['settings'])
  })

  it('builds the remaining-mode switch argv', () => {
    expect(remainingModeCommand(true)).toEqual(['settings', 'set', 'remaining-mode', 'true'])
    expect(remainingModeCommand(false)).toEqual(['settings', 'set', 'remaining-mode', 'false'])
  })
})

describe('login label', () => {
  it('turns snapshot errorKind signed-out into 未登录', () => {
    expect(loginLabel('signed-out')).toBe('未登录')
    expect(loginLabel('rate-limit')).toBe('')
    expect(loginLabel('unauthorized')).toBe('')
    expect(loginLabel('')).toBe('')

    const live = {
      0: { id: 'ghost', errorKind: 'signed-out' },
      1: { id: 'claude', errorKind: 'rate-limit', error: 'slow down' },
      length: 2,
    }
    const view = presentSettings(
      [
        { id: 'ghost', name: 'Ghost', shortName: 'Ghost' },
        { id: 'claude', shortName: 'Claude' },
      ],
      {
        remainingMode: false,
        providers: [
          { id: 'ghost', enabled: true },
          { id: 'claude', enabled: false },
        ],
      },
      { providers: live },
    )

    expect(view.remainingMode).toBe(false)
    expect(view.providers).toEqual([
      { id: 'ghost', name: 'Ghost', enabled: true, loginLabel: '未登录' },
      { id: 'claude', name: 'Claude', enabled: false, loginLabel: '' },
    ])
  })

  it('lists providers in settings order, not catalog order', () => {
    const view = presentSettings(
      [
        { id: 'claude', name: 'Claude' },
        { id: 'codex', name: 'Codex' },
        { id: 'grok', name: 'Grok' },
      ],
      {
        remainingMode: true,
        providers: [
          { id: 'grok', enabled: true },
          { id: 'claude', enabled: false },
          { id: 'codex', enabled: true },
        ],
      },
      { providers: [] },
    )
    expect(view.providers.map(row => row.id)).toEqual(['grok', 'claude', 'codex'])
  })
})

describe('provider order', () => {
  const rows = [
    { id: 'claude' },
    { id: 'codex' },
    { id: 'cursor' },
  ]

  it('swaps one step and refuses the ends', () => {
    expect(movedOrder(rows, 'codex', -1)).toEqual(['codex', 'claude', 'cursor'])
    expect(movedOrder(rows, 'codex', 1)).toEqual(['claude', 'cursor', 'codex'])
    expect(movedOrder(rows, 'claude', -1)).toBeNull()
    expect(movedOrder(rows, 'cursor', 1)).toBeNull()
    expect(movedOrder(rows, 'missing', 1)).toBeNull()
  })

  it('builds order argv and reorders settings rows', () => {
    expect(orderCommand(['grok', 'claude'])).toEqual(['settings', 'set', 'order', 'grok', 'claude'])
    expect(orderCommand(['claude', 'claude'])).toBeNull()
    expect(orderCommand([])).toBeNull()
    const next = withOrder({
      remainingMode: false,
      providers: [
        { id: 'claude', enabled: true, pinned: true },
        { id: 'codex', enabled: false, primary: 'weekly' },
        { id: 'extra', enabled: true },
      ],
    }, ['codex', 'claude'])
    expect(next.remainingMode).toBe(false)
    expect(next.providers).toEqual([
      { id: 'codex', enabled: false, primary: 'weekly' },
      { id: 'claude', enabled: true, pinned: true },
      { id: 'extra', enabled: true },
    ])
  })
})
