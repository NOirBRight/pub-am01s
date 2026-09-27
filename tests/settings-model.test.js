import { describe, expect, it } from 'vitest'
import {
  catalogCommand,
  enabledCommand,
  loginLabel,
  presentSettings,
  remainingModeCommand,
  settingsCommand,
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
})
