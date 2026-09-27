import { describe, expect, it } from 'vitest'
import { checkSnapshot, layoutMeterBank } from '../plugin/meter-model.mjs'

const CANVAS = 960

function window(fields) {
  return {
    id: fields.id,
    label: fields.label,
    shortLabel: fields.shortLabel,
    remaining: fields.remaining,
    resetLabel: fields.resetLabel,
    primary: fields.primary,
  }
}

function provider(fields) {
  return {
    id: fields.id,
    name: fields.name,
    shortName: fields.shortName,
    plan: fields.plan,
    remaining: fields.remaining,
    error: fields.error,
    errorKind: fields.errorKind,
    windows: fields.windows,
  }
}

function snapshot(providers, schemaVersion = 1) {
  return {
    schemaVersion,
    fetchedAt: '2026-09-27T00:00:00.000Z',
    remainingMode: true,
    providers,
  }
}

const claude = provider({
  id: 'claude',
  name: 'Claude',
  shortName: 'Claude',
  plan: 'Pro',
  windows: [
    window({ id: 'session', label: 'Session', shortLabel: 'Session', remaining: 0.62, resetLabel: 'Resets in 3h 20m', primary: false }),
    window({ id: 'weekly', label: 'Weekly', shortLabel: 'Weekly', remaining: 0.04, resetLabel: 'Resets in 5d 6h', primary: true }),
  ],
})

const codex = provider({
  id: 'codex',
  name: 'Codex',
  shortName: 'Codex',
  plan: 'Plus',
  windows: [
    window({ id: 'session', label: '5-hour', shortLabel: '5-hour', remaining: 0.21, resetLabel: 'Resets in 45m', primary: true }),
    window({ id: 'weekly', label: 'Weekly', shortLabel: 'Week', remaining: 0.2, resetLabel: 'Resets in 6d 0h', primary: false }),
  ],
})

const cursor = provider({
  id: 'cursor',
  name: 'Cursor',
  shortName: 'Cursor',
  plan: 'Pro',
  windows: [
    window({ id: 'cursor-models', label: 'Cursor Models', shortLabel: 'Cursor', remaining: null, resetLabel: 'Resets in 2d 4h', primary: false }),
    window({ id: 'other-models', label: 'Other Models', shortLabel: 'Other', remaining: 0, resetLabel: 'Resets in 2d 4h', primary: false }),
    window({ id: 'total', label: 'Total', shortLabel: 'Total', remaining: 0.2, resetLabel: 'Resets in 12d 3h', primary: true }),
  ],
})

const commandCode = provider({
  id: 'commandcode',
  name: 'Command Code',
  shortName: 'Cmd Code',
  plan: 'Pro',
  windows: [
    window({ id: 'monthly', label: 'Monthly', shortLabel: 'Month', remaining: 0.05, resetLabel: 'Resets soon', primary: true }),
  ],
})

const ollama = provider({
  id: 'ollama-cloud',
  name: 'Ollama Cloud',
  shortName: 'Ollama',
  plan: 'Pro',
  windows: [
    window({ id: 'session', label: '5-hour', shortLabel: '5-hour', remaining: 0.9, resetLabel: 'Resets in 1h 5m', primary: false }),
    window({ id: 'weekly', label: 'Weekly', shortLabel: 'Week', remaining: 0.5, resetLabel: 'Resets in 4d 2h', primary: true }),
  ],
})

const openCode = provider({
  id: 'opencode-go',
  name: 'OpenCode Go',
  shortName: 'OpenCode',
  plan: 'Go',
  windows: [
    window({ id: 'session', label: '5-hour', shortLabel: '5-hour', remaining: 0.4, resetLabel: 'Resets in 2h 0m', primary: false }),
    window({ id: 'weekly', label: 'Weekly', shortLabel: 'Week', remaining: 0.3, resetLabel: 'Resets in 3d 1h', primary: false }),
    window({ id: 'monthly', label: 'Monthly', shortLabel: 'Month', remaining: 0.15, resetLabel: 'Resets in 9d 8h', primary: true }),
  ],
})

const grok = provider({
  id: 'grok',
  name: 'Grok',
  shortName: 'Grok',
  plan: 'SuperGrok',
  windows: [
    window({ id: 'weekly', label: 'Weekly', shortLabel: 'Week', remaining: 0.8, resetLabel: 'Resets in 1d 4h', primary: true }),
    window({ id: 'monthly', label: 'Monthly', shortLabel: 'Month', remaining: 1, resetLabel: 'Resets in 20d 0h', primary: false }),
  ],
})

const signedOut = provider({
  id: 'ghost',
  name: 'Ghost',
  shortName: 'Ghost',
  error: 'signed out',
  errorKind: 'signed-out',
  windows: [
    window({ id: 'a', label: 'A', shortLabel: 'A', remaining: 0.5, resetLabel: 'Resets in 1d 1h', primary: true }),
    window({ id: 'b', label: 'B', shortLabel: 'B', remaining: 0.5, resetLabel: 'Resets in 1d 1h', primary: false }),
    window({ id: 'c', label: 'C', shortLabel: 'C', remaining: 0.5, resetLabel: 'Resets in 1d 1h', primary: false }),
    window({ id: 'd', label: 'D', shortLabel: 'D', remaining: 0.5, resetLabel: 'Resets in 1d 1h', primary: false }),
    window({ id: 'e', label: 'E', shortLabel: 'E', remaining: 0.5, resetLabel: 'Resets in 1d 1h', primary: false }),
  ],
})

const failed = provider({
  id: 'codex',
  name: 'Codex',
  shortName: 'Codex',
  plan: 'Plus',
  error: 'slow down',
  errorKind: 'rate-limit',
  windows: codex.windows,
})

function lay(providers) {
  return layoutMeterBank(snapshot(providers), CANVAS)
}

describe('checkSnapshot', () => {
  it('accepts only integer schemaVersion 1', () => {
    expect(checkSnapshot(JSON.stringify(snapshot([claude])))).toEqual({ status: 'ok' })
    expect(checkSnapshot('{"schemaVersion":1}')).toEqual({ status: 'ok' })
    expect(checkSnapshot('{"schemaVersion":2,"providers":[]}')).toEqual({ status: 'needs-update' })
    expect(checkSnapshot('{"schemaVersion":"1"}')).toEqual({ status: 'needs-update' })
    expect(checkSnapshot('{"schemaVersion":1.5}')).toEqual({ status: 'needs-update' })
    expect(checkSnapshot('{"providers":[]}')).toEqual({ status: 'needs-update' })
    expect(checkSnapshot('null')).toEqual({ status: 'needs-update' })
    expect(checkSnapshot('[]')).toEqual({ status: 'needs-update' })
    expect(checkSnapshot('')).toEqual({ status: 'unreadable' })
    expect(checkSnapshot('{')).toEqual({ status: 'unreadable' })
    expect(checkSnapshot('not json')).toEqual({ status: 'unreadable' })
  })

  it('treats an unknown schemaVersion fixture as needs-update', () => {
    const text = JSON.stringify(snapshot([claude, codex, cursor], 2))
    expect(checkSnapshot(text)).toEqual({ status: 'needs-update' })
  })
})

describe('layoutMeterBank', () => {
  it('lays out 1 provider wide, only as wide as its windows', () => {
    const layout = lay([claude])
    expect(checkSnapshot(JSON.stringify(snapshot([claude]))).status).toBe('ok')
    expect(layout.mode).toBe('wide')
    expect(layout.meterWidth).toBe(188)
    expect(layout.meterWidth).toBeLessThan(CANVAS)
    expect(layout.slotWidth).toBe(84)
    expect(layout.providers.map(row => row.width)).toEqual([188])
    expect(layout.providers[0]).toMatchObject({
      id: 'claude',
      name: 'Claude',
      shortName: 'Claude',
      plan: 'Pro',
      displayName: 'Claude',
      error: null,
    })
    expect(layout.providers[0].windows.map(row => row.id)).toEqual(['session', 'weekly'])
    expect(layout.providers[0].windows.map(row => row.displayLabel)).toEqual(['Session', 'Weekly'])
    expect(layout.providers[0].windows.map(row => row.level)).toEqual(['ok', 'danger'])
    expect(layout.providers[0].windows[1]).toMatchObject({
      primary: true,
      remaining: 0.04,
      resetLabel: 'Resets in 5d 6h',
      resetAbbrev: '5d',
    })
    expect(layout.providers[0].windows[0]).toMatchObject({
      resetLabel: 'Resets in 3h 20m',
      resetAbbrev: '3h 20m',
    })
    expect((layout.providers[0].width - 20) / layout.providers[0].windows.length).toBe(84)
  })

  it('lays out 2 providers wide with equal slots', () => {
    const layout = lay([claude, codex])
    expect(layout.mode).toBe('wide')
    expect(layout.meterWidth).toBe(376)
    expect(layout.meterWidth).toBeLessThan(CANVAS)
    expect(layout.slotWidth).toBe(84)
    expect(layout.providers.map(row => row.id)).toEqual(['claude', 'codex'])
    expect(layout.providers.map(row => row.width)).toEqual([188, 188])
    expect(layout.providers.map(row => (row.width - 20) / row.windows.length)).toEqual([84, 84])
    expect(layout.providers[1].windows.map(row => row.level)).toEqual(['ok', 'warn'])
    expect(layout.providers[1].windows[1].resetAbbrev).toBe('6d')
    expect(layout.providers[1].windows[0].resetAbbrev).toBe('45m')
  })

  it('lays out 3 providers wide and keeps every level bar slot equal', () => {
    const layout = lay([claude, codex, cursor])
    expect(layout.mode).toBe('wide')
    expect(layout.meterWidth).toBe(590)
    expect(layout.meterWidth).toBeLessThan(CANVAS)
    expect(layout.slotWidth).toBe(75.71428571428571)
    expect(layout.providers.map(row => row.width)).toEqual([
      171.42857142857142,
      171.42857142857142,
      247.14285714285714,
    ])
    expect(layout.providers.map(row => (row.width - 20) / row.windows.length)).toEqual([
      75.71428571428571,
      75.71428571428571,
      75.71428571428571,
    ])
    expect(layout.providers[2].windows.map(row => [row.displayLabel, row.level, row.primary])).toEqual([
      ['Cursor', 'none', false],
      ['Other', 'danger', false],
      ['Total', 'warn', true],
    ])
    expect(layout.providers[2].windows[0].resetLabel).toBe('Resets in 2d 4h')
    expect(layout.providers[2].windows[0].resetAbbrev).toBe('2d')
    expect(layout.providers[2].windows[2].resetAbbrev).toBe('12d')
  })

  it('lays out 4 providers wide and shortens a narrow column', () => {
    const layout = lay([claude, codex, cursor, commandCode])
    expect(layout.mode).toBe('wide')
    expect(layout.meterWidth).toBe(590)
    expect(layout.slotWidth).toBe(63.75)
    expect(layout.providers.map(row => row.width)).toEqual([147.5, 147.5, 211.25, 83.75])
    expect(layout.providers.map(row => row.displayName)).toEqual(['Claude', 'Codex', 'Cursor', 'Cmd Code'])
    expect(layout.providers[3]).toMatchObject({
      id: 'commandcode',
      name: 'Command Code',
      shortName: 'Cmd Code',
      plan: 'Pro',
      displayName: 'Cmd Code',
    })
    expect(layout.providers[3].windows[0]).toMatchObject({
      displayLabel: 'Month',
      shortLabel: 'Month',
      level: 'danger',
      remaining: 0.05,
      resetLabel: 'Resets soon',
      resetAbbrev: 'Resets soon',
      primary: true,
    })
    expect(layout.providers.map(row => (row.width - 20) / row.windows.length)).toEqual([63.75, 63.75, 63.75, 63.75])
  })

  it('collapses 7 providers to compact primary windows', () => {
    const providers = [claude, codex, cursor, commandCode, ollama, openCode, grok]
    const layout = lay(providers)
    expect(checkSnapshot(JSON.stringify(snapshot(providers))).status).toBe('ok')
    expect(layout.mode).toBe('compact')
    expect(layout.meterWidth).toBe(590)
    expect(layout.meterWidth).toBeLessThan(CANVAS)
    expect(layout.slotWidth).toBe(84.28571428571429)
    expect(layout.providers.map(row => row.width)).toEqual([
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
    ])
    expect(layout.providers.map(row => row.displayName)).toEqual([
      'Claude', 'Codex', 'Cursor', 'Cmd Code', 'Ollama', 'OpenCode', 'Grok',
    ])
    expect(layout.providers.map(row => row.windows.map(item => item.id))).toEqual([
      ['weekly'],
      ['session'],
      ['total'],
      ['monthly'],
      ['weekly'],
      ['monthly'],
      ['weekly'],
    ])
    expect(layout.providers[5].windows[0]).toMatchObject({
      displayLabel: 'Month',
      label: 'Monthly',
      shortLabel: 'Month',
      level: 'warn',
      primary: true,
      resetLabel: 'Resets in 9d 8h',
      resetAbbrev: '9d',
    })
    expect(layout.providers[2].windows).toHaveLength(1)
    expect(layout.providers[6].windows[0].level).toBe('ok')
  })

  it('stays wide for 7 providers when each window still has room', () => {
    const oneEach = [claude, codex, cursor, commandCode, ollama, openCode, grok].map((row, index) => provider({
      id: `p${index}`,
      name: row.name,
      shortName: row.shortName,
      plan: row.plan,
      windows: [window({
        id: 'only',
        label: 'Weekly',
        shortLabel: 'Week',
        remaining: 0.5,
        resetLabel: 'Resets in 1d 2h',
        primary: true,
      })],
    }))
    const layout = lay(oneEach)
    expect(layout.mode).toBe('wide')
    expect(layout.meterWidth).toBe(590)
    expect(layout.slotWidth).toBe(64.28571428571429)
    expect(layout.providers).toHaveLength(7)
    expect(layout.providers.map(row => row.width)).toEqual([
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
      84.28571428571429,
    ])
    expect(layout.providers[0].windows[0].displayLabel).toBe('Week')
    expect(layout.providers[5].displayName).toBe('OpenCode')
  })

  it('hides signed-out providers and shows a failed login with its error', () => {
    const layout = lay([signedOut, failed])
    expect(layout.mode).toBe('wide')
    expect(layout.meterWidth).toBe(188)
    expect(layout.providers.map(row => row.id)).toEqual(['codex'])
    expect(layout.providers[0].width).toBe(188)
    expect(layout.providers[0].error).toBe('slow down')
    expect(layout.providers[0].windows).toHaveLength(2)
  })

  it('drops signed-out providers from an otherwise 3-provider bank', () => {
    const layout = lay([claude, signedOut, codex, cursor])
    expect(layout.providers.map(row => row.id)).toEqual(['claude', 'codex', 'cursor'])
    expect(layout.meterWidth).toBe(590)
    expect(layout.providers.map(row => row.width)).toEqual([
      171.42857142857142,
      171.42857142857142,
      247.14285714285714,
    ])
  })

  it('gives a bank of only signed-out providers no width', () => {
    const layout = lay([signedOut, provider({
      id: 'other',
      name: 'Other',
      shortName: 'Other',
      errorKind: 'signed-out',
      windows: [],
    })])
    expect(layout).toMatchObject({ mode: 'compact', meterWidth: 0, slotWidth: 0, providers: [] })
  })

  it('keeps a logged-in failure that has no error string', () => {
    const layout = lay([provider({
      id: 'grok',
      name: 'Grok',
      shortName: 'Grok',
      errorKind: 'transport',
      windows: [window({ id: 'weekly', label: 'Weekly', shortLabel: 'Week', remaining: 0.4, resetLabel: 'Resets in 1d 0h', primary: true })],
    })])
    expect(layout.meterWidth).toBe(104)
    expect(layout.slotWidth).toBe(84)
    expect(layout.providers[0].width).toBe(104)
    expect(layout.providers[0].error).toBe('transport')
    expect(layout.providers[0].displayName).toBe('Grok')
  })

  it('does not hide a provider whose error text says signed out without errorKind', () => {
    const layout = lay([provider({
      id: 'claude',
      name: 'Claude',
      shortName: 'Claude',
      error: 'signed out',
      windows: claude.windows,
    }), signedOut])
    expect(layout.providers.map(row => row.id)).toEqual(['claude'])
    expect(layout.providers[0].error).toBe('signed out')
    expect(layout.providers[0].width).toBe(188)
    expect(layout.meterWidth).toBe(188)
  })
})
