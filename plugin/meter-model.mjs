// Layout decisions for the Meter Bank. QML only renders the result.

const PAD = 20
const SLOT_MIN = 56
const SLOT_NATURAL = 84
const NARROW_COLUMN = 120

export function checkSnapshot(jsonText) {
  if (typeof jsonText !== 'string') return { status: 'unreadable' }
  let parsed
  try {
    parsed = JSON.parse(jsonText)
  } catch (error) {
    return { status: 'unreadable' }
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return { status: 'needs-update' }
  if (!Number.isInteger(parsed.schemaVersion) || parsed.schemaVersion !== 1) return { status: 'needs-update' }
  return { status: 'ok' }
}

export function layoutMeterBank(snapshot, canvasWidth) {
  const width = Number(canvasWidth)
  const maxW = Number.isFinite(width) ? Math.round(width * 0.615) : 0
  const providers = visibleProviders(snapshot)
  const n = providers.length
  const counts = providers.map(provider => Math.max(1, windowsOf(provider).length))
  let slots = 0
  for (let i = 0; i < counts.length; i += 1) slots += counts[i]
  const wide = n > 0 && (maxW - n * PAD) / slots >= SLOT_MIN
  let natural = wide ? Math.min(maxW, slots * SLOT_NATURAL + n * PAD) : maxW
  // No visible provider takes no width. The compact branch would otherwise use maxW.
  if (n === 0) natural = 0
  const slotWidth = n > 0 && slots > 0
    ? (wide ? (natural - n * PAD) / slots : natural / n)
    : 0
  return {
    mode: wide ? 'wide' : 'compact',
    meterWidth: natural,
    slotWidth,
    providers: providers.map((provider, index) => {
      const mine = counts[index]
      const providerWidth = wide ? (natural - n * PAD) * mine / slots + PAD : natural / n
      return presentProvider(provider, providerWidth, wide)
    }),
  }
}

function asArray(value) {
  if (Array.isArray(value)) return value
  // QML property var turns arrays into list objects that fail Array.isArray.
  if (!value || typeof value !== 'object') return null
  const length = value.length
  if (typeof length !== 'number' || !Number.isFinite(length) || length < 0) return null
  const out = []
  for (let i = 0; i < length; i += 1) out.push(value[i])
  return out
}

function visibleProviders(snapshot) {
  const list = snapshot && typeof snapshot === 'object' && !Array.isArray(snapshot)
    ? (asArray(snapshot.providers) || [])
    : []
  const kept = []
  for (let i = 0; i < list.length; i += 1) {
    const provider = list[i]
    if (!provider || typeof provider !== 'object' || Array.isArray(provider)) continue
    if (provider.errorKind === 'signed-out') continue
    kept.push(provider)
  }
  return kept
}

function windowsOf(provider) {
  const raw = asArray(provider.windows)
  if (!raw) return []
  const windows = []
  for (let i = 0; i < raw.length; i += 1) {
    const window = raw[i]
    if (!window || typeof window !== 'object' || Array.isArray(window)) continue
    windows.push(window)
  }
  return windows
}

function presentProvider(provider, width, wide) {
  const name = text(provider.name)
  const shortName = text(provider.shortName) || name
  const source = windowsOf(provider)
  const windows = source.length > 0 ? source : [fallbackWindow(provider)]
  const shown = wide ? windows : [primaryOf(windows)]
  // Compact, and a wide column under 120 design pixels, uses the short name.
  const narrow = !wide || width < NARROW_COLUMN
  return {
    id: text(provider.id),
    name,
    shortName,
    plan: text(provider.plan),
    width,
    error: errorText(provider),
    displayName: narrow ? shortName : name,
    windows: shown.map(window => presentWindow(window, wide)),
  }
}

function presentWindow(window, wide) {
  const label = text(window.label)
  const shortLabel = text(window.shortLabel) || label
  const resetLabel = text(window.resetLabel)
  const remaining = typeof window.remaining === 'number' && Number.isFinite(window.remaining) ? window.remaining : null
  return {
    id: text(window.id),
    label,
    shortLabel,
    resetLabel,
    resetAbbrev: abbreviateReset(resetLabel),
    remaining,
    level: levelFor(remaining),
    primary: window.primary === true,
    displayLabel: wide ? label : shortLabel,
  }
}

function fallbackWindow(provider) {
  const remaining = typeof provider.remaining === 'number' && Number.isFinite(provider.remaining) ? provider.remaining : null
  return { id: '', label: '', shortLabel: '', resetLabel: '', remaining, primary: true }
}

function primaryOf(windows) {
  for (let i = 0; i < windows.length; i += 1) {
    if (windows[i].primary === true) return windows[i]
  }
  return windows[0]
}

function errorText(provider) {
  if (typeof provider.error === 'string' && provider.error.length > 0) return provider.error
  if (typeof provider.errorKind === 'string' && provider.errorKind.length > 0) return provider.errorKind
  return null
}

function levelFor(remaining) {
  return remaining == null ? 'none' : remaining <= 0.05 ? 'danger' : remaining <= 0.2 ? 'warn' : 'ok'
}

function abbreviateReset(resetLabel) {
  const stripped = resetLabel.replace(/^Resets in /, '')
  const days = /^(\d+d) \d+h$/.exec(stripped)
  return days ? days[1] : stripped
}

function text(value) {
  return typeof value === 'string' ? value : ''
}
