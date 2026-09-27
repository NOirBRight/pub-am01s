// Settings Overlay decisions. The plugin never writes settings.json.

export function catalogCommand() {
  return ['catalog']
}

export function settingsCommand() {
  return ['settings']
}

export function enabledCommand(id, enabled) {
  return ['settings', 'set', 'enabled', text(id), onOff(enabled)]
}

export function remainingModeCommand(remainingMode) {
  return ['settings', 'set', 'remaining-mode', onOff(remainingMode)]
}

export function loginLabel(errorKind) {
  return errorKind === 'signed-out' ? '未登录' : ''
}

export function parseDocument(text) {
  if (typeof text !== 'string') return { ok: false, value: null }
  const trimmed = text.replace(/^\uFEFF/, '').replace(/^\s+|\s+$/g, '')
  if (!trimmed) return { ok: false, value: null }
  try {
    const value = JSON.parse(trimmed)
    if (value === null || typeof value !== 'object') return { ok: false, value: null }
    return { ok: true, value }
  } catch (error) {
    return { ok: false, value: null }
  }
}

export function remainingModeOf(settings) {
  if (!settings || typeof settings !== 'object' || isList(settings)) return true
  return settings.remainingMode !== false
}

export function presentSettings(catalog, settings, snapshot) {
  const enabled = enabledMap(settings)
  const signedOut = signedOutMap(snapshot)
  const rows = []
  const providers = providersFrom(catalog)
  for (let i = 0; i < providers.length; i += 1) {
    const provider = providers[i]
    if (!provider || typeof provider !== 'object' || isList(provider)) continue
    const id = text(provider.id)
    if (!id) continue
    const known = Object.prototype.hasOwnProperty.call(enabled, id)
    rows.push({
      id,
      name: text(provider.name) || text(provider.shortName) || id,
      enabled: known ? enabled[id] === true : false,
      loginLabel: signedOut[id] ? loginLabel('signed-out') : '',
    })
  }
  return {
    remainingMode: remainingModeOf(settings),
    providers: rows,
  }
}

export function withEnabled(settings, id, enabled) {
  const wanted = text(id)
  const next = copyProviders(settings)
  let found = false
  for (let i = 0; i < next.length; i += 1) {
    if (next[i].id !== wanted) continue
    next[i].enabled = enabled === true
    found = true
  }
  if (!found && wanted) next.push({ id: wanted, enabled: enabled === true })
  return { remainingMode: remainingModeOf(settings), providers: next }
}

export function withRemainingMode(settings, remainingMode) {
  return {
    remainingMode: remainingMode === true,
    providers: copyProviders(settings),
  }
}

function onOff(value) {
  return value === true ? 'true' : 'false'
}

function text(value) {
  return typeof value === 'string' ? value : ''
}

function isList(value) {
  if (!value || typeof value !== 'object') return false
  const length = value.length
  return typeof length === 'number' && Number.isFinite(length) && length >= 0
}

function asArray(value) {
  if (Array.isArray(value)) return value
  if (!isList(value)) return null
  const out = []
  for (let i = 0; i < value.length; i += 1) out.push(value[i])
  return out
}

function providersFrom(value) {
  if (!value || typeof value !== 'object') return []
  const direct = asArray(value)
  if (direct) return direct
  const nested = asArray(value.providers)
  return nested || []
}

function copyProviders(settings) {
  const rows = providersFrom(settings)
  const next = []
  const seen = {}
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i]
    if (!row || typeof row !== 'object' || isList(row)) continue
    const id = text(row.id)
    if (!id || seen[id]) continue
    seen[id] = true
    const copy = { id, enabled: row.enabled !== false }
    if (row.pinned === true) copy.pinned = true
    if (typeof row.primary === 'string' && row.primary.length > 0) copy.primary = row.primary
    next.push(copy)
  }
  return next
}

function enabledMap(settings) {
  const rows = providersFrom(settings)
  const out = {}
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i]
    if (!row || typeof row !== 'object' || isList(row)) continue
    const id = text(row.id)
    if (!id || Object.prototype.hasOwnProperty.call(out, id)) continue
    out[id] = row.enabled !== false
  }
  return out
}

function signedOutMap(snapshot) {
  const rows = providersFrom(snapshot)
  const out = {}
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i]
    if (!row || typeof row !== 'object' || isList(row)) continue
    const id = text(row.id)
    if (!id) continue
    if (row.errorKind === 'signed-out') out[id] = true
  }
  return out
}
