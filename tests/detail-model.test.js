import { describe, expect, it } from 'vitest'
import { detailFor, layoutMeterBank } from '../plugin/meter-model.mjs'

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

function snapshot(providers) {
  return {
    schemaVersion: 1,
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
    window({ id: 'session', label: 'Session', shortLabel: 'Sess', remaining: 0.62, resetLabel: 'Resets in 3h 20m', primary: false }),
    window({ id: 'weekly', label: 'Weekly', shortLabel: 'Week', remaining: 0.04, resetLabel: 'Resets in 5d 6h', primary: true }),
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

describe('detailFor', () => {
  it('returns every Quota Window with full labels and full reset times', () => {
    expect(detailFor(snapshot([claude]), 'claude')).toEqual({
      id: 'claude',
      name: 'Claude',
      plan: 'Pro',
      failed: false,
      reason: null,
      windows: [
        {
          id: 'session',
          label: 'Session',
          resetLabel: 'Resets in 3h 20m',
          remaining: 0.62,
          level: 'ok',
          primary: false,
        },
        {
          id: 'weekly',
          label: 'Weekly',
          resetLabel: 'Resets in 5d 6h',
          remaining: 0.04,
          level: 'danger',
          primary: true,
        },
      ],
    })
  })

  it('keeps the full name and does not abbreviate a reset the bank would shorten', () => {
    const detail = detailFor(snapshot([cursor, claude]), 'cursor')
    const layout = layoutMeterBank(snapshot([cursor, claude]), CANVAS)
    expect(detail.name).toBe('Cursor')
    expect(detail.plan).toBe('Pro')
    expect(detail.failed).toBe(false)
    expect(detail.reason).toBeNull()
    expect(detail.windows.map(row => row.label)).toEqual(['Cursor Models', 'Other Models', 'Total'])
    expect(detail.windows.map(row => row.resetLabel)).toEqual([
      'Resets in 2d 4h',
      'Resets in 2d 4h',
      'Resets in 12d 3h',
    ])
    expect(detail.windows.map(row => row.level)).toEqual(['none', 'danger', 'warn'])
    expect(detail.windows.map(row => row.primary)).toEqual([false, false, true])
    expect(layout.providers[0].windows[0].resetAbbrev).toBe('2d')
    expect(detail.windows[0].resetLabel).not.toBe(layout.providers[0].windows[0].resetAbbrev)
    expect(layout.mode).toBe('wide')
    expect(layout.providers[0].windows.map(row => row.displayLabel)).toEqual([
      'Cursor',
      'Other',
      'Total',
    ])
  })

  it('still lists every window when the bank is compact', () => {
    const many = []
    for (let i = 0; i < 7; i += 1) {
      many.push(provider({
        id: i === 2 ? 'cursor' : `p${i}`,
        name: i === 2 ? 'Cursor' : `Provider ${i}`,
        shortName: i === 2 ? 'Cursor' : `P${i}`,
        plan: 'Pro',
        windows: i === 2 ? cursor.windows : [
          window({ id: 'only', label: 'Weekly', shortLabel: 'Week', remaining: 0.5, resetLabel: 'Resets in 1d 2h', primary: true }),
          window({ id: 'extra', label: 'Monthly', shortLabel: 'Month', remaining: 0.5, resetLabel: 'Resets in 8d 0h', primary: false }),
        ],
      }))
    }
    const layout = layoutMeterBank(snapshot(many), CANVAS)
    expect(layout.mode).toBe('compact')
    expect(layout.providers[2].windows).toHaveLength(1)
    const detail = detailFor(snapshot(many), 'cursor')
    expect(detail.windows.map(row => row.id)).toEqual(['cursor-models', 'other-models', 'total'])
    expect(detail.windows[0].label).toBe('Cursor Models')
    expect(detail.windows[2].resetLabel).toBe('Resets in 12d 3h')
  })

  it('maps remaining to none, danger, warn, and ok', () => {
    const levels = [
      [null, 'none'],
      [undefined, 'none'],
      [Number.NaN, 'none'],
      [Number.POSITIVE_INFINITY, 'none'],
      [-0.1, 'danger'],
      [0, 'danger'],
      [0.05, 'danger'],
      [0.06, 'warn'],
      [0.2, 'warn'],
      [0.21, 'ok'],
      [1, 'ok'],
    ]
    const windows = levels.map((row, index) => window({
      id: `w${index}`,
      label: `Window ${index}`,
      shortLabel: `W${index}`,
      remaining: row[0],
      resetLabel: `Resets in ${index}d 1h`,
      primary: index === 9,
    }))
    const detail = detailFor(snapshot([provider({
      id: 'levels',
      name: 'Levels',
      shortName: 'Lv',
      plan: '',
      windows,
    })]), 'levels')
    expect(detail.plan).toBe('')
    expect(detail.windows.map(row => row.level)).toEqual(levels.map(row => row[1]))
    expect(detail.windows.map(row => row.remaining)).toEqual([
      null, null, null, null, -0.1, 0, 0.05, 0.06, 0.2, 0.21, 1,
    ])
    expect(detail.windows[9].primary).toBe(true)
    expect(detail.windows[0].primary).toBe(false)
    expect(detail.windows[0]).not.toHaveProperty('resetAbbrev')
    expect(detail.windows[0]).not.toHaveProperty('shortLabel')
  })

  it('uses the full label even when the short label differs', () => {
    const detail = detailFor(snapshot([provider({
      id: 'commandcode',
      name: 'Command Code',
      shortName: 'Cmd Code',
      plan: 'Pro',
      windows: [
        window({ id: 'monthly', label: 'Monthly', shortLabel: 'Month', remaining: 0.05, resetLabel: 'Resets soon', primary: true }),
      ],
    })]), 'commandcode')
    expect(detail).toMatchObject({
      id: 'commandcode',
      name: 'Command Code',
      plan: 'Pro',
      failed: false,
      reason: null,
    })
    expect(detail.windows[0]).toEqual({
      id: 'monthly',
      label: 'Monthly',
      resetLabel: 'Resets soon',
      remaining: 0.05,
      level: 'danger',
      primary: true,
    })
  })

  it('returns null when the provider is missing or signed out', () => {
    const signedOut = provider({
      id: 'ghost',
      name: 'Ghost',
      shortName: 'Ghost',
      plan: 'Pro',
      error: 'session expired',
      errorKind: 'signed-out',
      windows: claude.windows,
    })
    expect(detailFor(snapshot([claude, signedOut]), 'ghost')).toBeNull()
    expect(detailFor(snapshot([claude]), 'missing')).toBeNull()
    expect(detailFor(snapshot([]), 'claude')).toBeNull()
    expect(detailFor(null, 'claude')).toBeNull()
    expect(detailFor(undefined, 'claude')).toBeNull()
    expect(detailFor([], 'claude')).toBeNull()
    expect(detailFor({ providers: null }, 'claude')).toBeNull()
    expect(detailFor(snapshot([signedOut, claude]), 'claude').id).toBe('claude')
  })

  it('treats a non-empty error as a failure and keeps the error text', () => {
    const failed = provider({
      id: 'codex',
      name: 'Codex',
      shortName: 'Codex',
      plan: 'Plus',
      error: 'slow down',
      errorKind: 'rate-limit',
      windows: [
        window({ id: 'session', label: '5-hour', shortLabel: '5-hour', remaining: 0.21, resetLabel: 'Resets in 45m', primary: true }),
      ],
    })
    expect(detailFor(snapshot([failed]), 'codex')).toEqual({
      id: 'codex',
      name: 'Codex',
      plan: 'Plus',
      failed: true,
      reason: 'slow down',
      windows: [
        {
          id: 'session',
          label: '5-hour',
          resetLabel: 'Resets in 45m',
          remaining: 0.21,
          level: 'ok',
          primary: true,
        },
      ],
    })
  })

  it('uses errorKind as the reason when a logged-in failure has no error string', () => {
    const detail = detailFor(snapshot([provider({
      id: 'grok',
      name: 'Grok',
      shortName: 'Grok',
      plan: 'SuperGrok',
      errorKind: 'transport',
      windows: [
        window({ id: 'weekly', label: 'Weekly', shortLabel: 'Week', remaining: 0.4, resetLabel: 'Resets in 1d 0h', primary: true }),
      ],
    })]), 'grok')
    expect(detail.failed).toBe(true)
    expect(detail.reason).toBe('transport')
    expect(detail.windows).toHaveLength(1)
  })

  it('does not treat the words signed out as signed-out without errorKind', () => {
    const detail = detailFor(snapshot([provider({
      id: 'claude',
      name: 'Claude',
      shortName: 'Claude',
      plan: 'Pro',
      error: 'signed out',
      windows: claude.windows,
    })]), 'claude')
    expect(detail.failed).toBe(true)
    expect(detail.reason).toBe('signed out')
    expect(detail.windows).toHaveLength(2)
  })

  it('skips broken entries and reads a QML-style list', () => {
    const row = provider({
      id: 'ollama-cloud',
      name: 'Ollama Cloud',
      shortName: 'Ollama',
      plan: 'Pro',
      windows: {
        length: 2,
        0: null,
        1: window({ id: 'weekly', label: 'Weekly', shortLabel: 'Week', remaining: 0.5, resetLabel: 'Resets in 4d 2h', primary: 1 }),
      },
    })
    const list = { length: 3, 0: null, 1: 'nope', 2: row }
    const detail = detailFor({ providers: list }, 'ollama-cloud')
    expect(detail.id).toBe('ollama-cloud')
    expect(detail.name).toBe('Ollama Cloud')
    expect(detail.windows).toEqual([
      {
        id: 'weekly',
        label: 'Weekly',
        resetLabel: 'Resets in 4d 2h',
        remaining: 0.5,
        level: 'ok',
        primary: false,
      },
    ])
  })

  it('returns an empty window list when the provider has none', () => {
    expect(detailFor(snapshot([provider({
      id: 'bare',
      name: 'Bare',
      shortName: 'Bare',
      plan: 'Free',
      windows: [],
    })]), 'bare')).toEqual({
      id: 'bare',
      name: 'Bare',
      plan: 'Free',
      failed: false,
      reason: null,
      windows: [],
    })
  })
})
