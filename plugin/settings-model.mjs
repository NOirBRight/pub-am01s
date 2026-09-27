// Settings Overlay decisions. The plugin never writes settings.json or credentials.json.
// Login fields come from the Engine catalog. Secrets stay on the credentials-set stdin.

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

// Engine flags are the catalog extra key in kebab case: accountId → --account-id.
export function credentialsSetCommand(entry, extraValues) {
  if (!entry || typeof entry !== 'object' || isList(entry)) return null
  const id = text(entry.id).replace(/^\s+|\s+$/g, '')
  if (!id) return null
  const argv = ['credentials', 'set', id]
  const extra = entry.extra
  if (!extra || typeof extra !== 'object' || isList(extra)) return argv
  const key = text(extra.key).replace(/^\s+|\s+$/g, '')
  if (!key) return extra.required === true ? null : argv
  const value = extraText(extraValues, key)
  if (!value) return extra.required === true ? null : argv
  argv.push(flagFor(key), value)
  return argv
}

export function credentialsClearCommand(id) {
  const wanted = text(id).replace(/^\s+|\s+$/g, '')
  if (!wanted) return null
  return ['credentials', 'clear', wanted]
}

export function cliLoginCommand(entry) {
  const cli = entry && entry.cli && typeof entry.cli === 'object' && !isList(entry.cli) ? entry.cli : null
  if (!cli) return null
  const bin = text(cli.bin).replace(/^\s+|\s+$/g, '')
  if (!bin) return null
  const argv = [bin]
  const args = asArray(cli.args) || []
  for (let i = 0; i < args.length; i += 1) {
    if (typeof args[i] !== 'string') continue
    argv.push(args[i])
  }
  return argv
}

// credentialSource "pub" is the PUB file. With no source, Clear is only for a
// signed-in key or both. cli and env are never cleared from here.
export function clearOffered(provider, entry) {
  const source = credentialSourceOf(provider)
  if (source === 'pub') return true
  if (source) return false
  if (!signedIn(provider)) return false
  const kind = entry && typeof entry === 'object' && !isList(entry) ? text(entry.credentialKind) : ''
  return kind === 'key' || kind === 'both'
}

export function isInvalidCodeLine(line, codeEntry) {
  if (typeof line !== 'string') return false
  if (!codeEntry || typeof codeEntry !== 'object' || isList(codeEntry)) return false
  const pattern = text(codeEntry.invalidPattern)
  if (!pattern) return false
  try {
    return new RegExp(pattern, text(codeEntry.flags)).test(line)
  } catch (error) {
    return false
  }
}

export function loginUrl(line) {
  if (typeof line !== 'string') return ''
  const match = /https:\/\/[^\s"'<>]+/.exec(line)
  if (!match) return ''
  return match[0].replace(/[),.;]+$/, '')
}

export function withLogin(providers, catalog, snapshot) {
  const entries = indexById(providersFrom(catalog))
  const lives = indexById(providersFrom(snapshot))
  const rows = asArray(providers) || []
  const out = []
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i]
    if (!row || typeof row !== 'object' || isList(row)) continue
    const id = text(row.id)
    const entry = id && entries[id] ? entries[id] : null
    const live = id && lives[id] ? lives[id] : null
    out.push({
      id: row.id,
      name: row.name,
      enabled: row.enabled === true,
      loginLabel: text(row.loginLabel),
      credentialKind: entry ? text(entry.credentialKind) : '',
      hint: entry ? text(entry.hint) : '',
      cli: entry ? copyCli(entry.cli) : null,
      page: entry ? copyPage(entry.page) : null,
      extra: entry ? copyExtra(entry.extra) : null,
      codeEntry: entry ? copyCode(entry.codeEntry) : null,
      credentialSource: credentialSourceOf(live),
      clearOffered: clearOffered(live, entry),
    })
  }
  return out
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

function flagFor(key) {
  let out = '--'
  for (let i = 0; i < key.length; i += 1) {
    const ch = key.charAt(i)
    if (ch >= 'A' && ch <= 'Z') out += '-' + ch.toLowerCase()
    else out += ch
  }
  return out
}

function extraText(extraValues, key) {
  if (!extraValues || typeof extraValues !== 'object' || isList(extraValues)) return ''
  const raw = extraValues[key]
  if (typeof raw !== 'string') return ''
  return raw.replace(/^\s+|\s+$/g, '')
}

function credentialSourceOf(provider) {
  if (!provider || typeof provider !== 'object' || isList(provider)) return ''
  if (typeof provider.credentialSource !== 'string') return ''
  return provider.credentialSource.replace(/^\s+|\s+$/g, '')
}

function signedIn(provider) {
  if (!provider || typeof provider !== 'object' || isList(provider)) return false
  if (provider.errorKind === 'signed-out' || provider.error === 'signed out') return false
  return true
}

function indexById(rows) {
  const out = {}
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i]
    if (!row || typeof row !== 'object' || isList(row)) continue
    const id = text(row.id)
    if (!id || out[id]) continue
    out[id] = row
  }
  return out
}

function copyCli(cli) {
  if (!cli || typeof cli !== 'object' || isList(cli)) return null
  const bin = text(cli.bin).replace(/^\s+|\s+$/g, '')
  if (!bin) return null
  const args = asArray(cli.args) || []
  const copied = []
  for (let i = 0; i < args.length; i += 1) {
    if (typeof args[i] !== 'string') continue
    copied.push(args[i])
  }
  const out = { bin, args: copied, label: text(cli.label) }
  if (text(cli.file)) out.file = text(cli.file)
  return out
}

function copyPage(page) {
  if (!page || typeof page !== 'object' || isList(page)) return null
  const url = text(page.url).replace(/^\s+|\s+$/g, '')
  if (!url) return null
  return { url, label: text(page.label) || url }
}

function copyExtra(extra) {
  if (!extra || typeof extra !== 'object' || isList(extra)) return null
  const key = text(extra.key).replace(/^\s+|\s+$/g, '')
  if (!key) return null
  return { key, hint: text(extra.hint), required: extra.required === true }
}

function copyCode(codeEntry) {
  if (!codeEntry || typeof codeEntry !== 'object' || isList(codeEntry)) return null
  const hint = text(codeEntry.hint)
  const invalidPattern = text(codeEntry.invalidPattern)
  if (!hint && !invalidPattern) return null
  return { hint, invalidPattern, flags: text(codeEntry.flags) }
}
