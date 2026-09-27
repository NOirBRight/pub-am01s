// Omarchy notification history parsing. No QML imports (ADR 0003).

var FRESH_MS = 10 * 60 * 1000
// Swipe left is a negative dx. Commit once it passes 40% of the row width.
var SWIPE_COMMIT_RATIO = 0.4
var INITIAL_COLORS = ["#509475", "#2dd5b7", "#d2689c", "#a2734b", "#81b8a8", "#549e6a"]
var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function oneLine(value) {
  return String(value == null ? "" : value).replace(/\r\n|\r|\n/g, " ").replace(/^\s+|\s+$/g, "")
}

function finiteNumber(value) {
  var n = Number(value)
  return isFinite(n) ? n : 0
}

function timeLabel(timestamp, nowMs) {
  var now = Number(nowMs)
  if (!isFinite(now)) return ""
  var seconds = Math.max(0, (now - timestamp) / 1000)
  if (seconds < 60) return "now"
  if (seconds < 3600) return Math.floor(seconds / 60) + "m"
  if (seconds < 86400) return Math.floor(seconds / 3600) + "h"
  return Math.floor(seconds / 86400) + "d"
}

function fresh(timestamp, nowMs) {
  var now = Number(nowMs)
  if (!isFinite(now)) return false
  return Math.abs(now - timestamp) <= FRESH_MS
}

function initialLetter(app) {
  var text = oneLine(app)
  if (!text) return "?"
  var code = text.charCodeAt(0)
  var ch = code >= 0xd800 && code <= 0xdbff && text.length > 1 ? text.slice(0, 2) : text.charAt(0)
  return ch.toUpperCase()
}

function initialIcon(app) {
  var name = oneLine(app)
  var hash = 0
  for (var i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) >>> 0
  return {
    kind: "initial",
    letter: initialLetter(name),
    color: INITIAL_COLORS[hash % INITIAL_COLORS.length],
    names: iconCandidates(app, ""),
  }
}

// Desktop icon names for this app. "T3 Code (Nightly)" yields t3code, which is
// the Icon= in the desktop file. The notification's content image is not an icon.
function iconCandidates(app, appIcon) {
  var names = []
  function add(name) {
    var text = String(name || "").replace(/^\s+|\s+$/g, "")
    if (!text || names.indexOf(text) >= 0) return
    names.push(text)
  }
  var raw = oneLine(appIcon)
  if (raw && raw.indexOf("://") < 0 && raw.charAt(0) !== "/") add(raw)
  var words = oneLine(app).toLowerCase().split(/[^a-z0-9]+/)
  var clean = []
  for (var i = 0; i < words.length; i++) if (words[i]) clean.push(words[i])
  if (clean.length) {
    add(clean.join(""))
    add(clean.join("-"))
    if (clean.length >= 2) {
      add(clean[0] + clean[1])
      if (clean.length > 2) add(clean[0] + clean[1] + "-" + clean.slice(2).join("-"))
    }
  }
  return names
}

function filePath(raw) {
  var path = raw
  if (path.indexOf("file://") === 0) {
    path = path.slice(7)
    try { path = decodeURIComponent(path) } catch (e) { return "" }
    if (path.charAt(0) !== "/") {
      var slash = path.indexOf("/")
      path = slash >= 0 ? path.slice(slash) : ""
    }
  }
  return path.charAt(0) === "/" ? path : ""
}

// Omarchy's own toasts and bare notify-send come from no application. They get
// their glyph, as on Omarchy's popup card, or the Omarchy mark.
function systemSender(app) {
  var name = oneLine(app)
  return name === "omarchy-action" || name === "notify-send"
}

function iconFrom(appIcon, app, glyph) {
  var names = iconCandidates(app, appIcon)
  var raw = oneLine(appIcon)
  if (!raw && systemSender(app)) {
    var mark = oneLine(glyph)
    if (mark) return { kind: "glyph", glyph: mark, names: [] }
    return { kind: "system", names: ["omarchy"] }
  }
  if (!raw) return initialIcon(app)
  if (raw.indexOf("file://") === 0 || raw.charAt(0) === "/") {
    var path = filePath(raw)
    if (!path) return initialIcon(app)
    return { kind: "file", path: path, names: names }
  }
  // image:// and other schemes are not theme icons.
  if (raw.indexOf("://") >= 0) return initialIcon(app)
  return { kind: "theme-name", name: names[0] || raw, names: names }
}

// execArgv is "" or a JSON argv array. A leading-dash program is not runnable
// (it would be read as an option), so it is treated as no action.
function actionFrom(execArgv) {
  if (execArgv == null || execArgv === "") return null
  var parsed = execArgv
  if (typeof parsed === "string") {
    try { parsed = JSON.parse(parsed) } catch (e) { return null }
  }
  if (!Array.isArray(parsed) || parsed.length === 0) return null
  for (var i = 0; i < parsed.length; i++) {
    if (typeof parsed[i] !== "string") return null
  }
  if (!parsed[0] || parsed[0].charAt(0) === "-") return null
  return parsed.slice()
}

function rowFrom(path, entry, nowMs) {
  var timestamp = finiteNumber(entry.timestamp)
  return {
    path: String(path || ""),
    app: oneLine(entry.app),
    summary: oneLine(entry.summary),
    body: oneLine(entry.body),
    timeLabel: timeLabel(timestamp, nowMs),
    fresh: fresh(timestamp, nowMs),
    icon: iconFrom(entry.appIcon, entry.app, entry.glyph),
    action: actionFrom(entry.execArgv),
    system: systemSender(entry.app),
    timestamp: timestamp,
  }
}

function readInbox(files, nowMs) {
  var list = Array.isArray(files) ? files : []
  var rows = []
  for (var i = 0; i < list.length; i++) {
    var file = list[i] || {}
    var text = file.text
    if (typeof text !== "string") {
      if (text == null) continue
      text = String(text)
    }
    var trimmed = text.replace(/^\s+|\s+$/g, "")
    if (trimmed.charCodeAt(0) === 0xfeff) trimmed = trimmed.slice(1)
    if (!trimmed) continue
    var parsed
    try { parsed = JSON.parse(trimmed) } catch (e) { continue }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) continue
    rows.push(rowFrom(file.path, parsed, nowMs))
  }
  rows.sort(function(a, b) {
    if (a.timestamp !== b.timestamp) return b.timestamp - a.timestamp
    if (a.path < b.path) return 1
    if (a.path > b.path) return -1
    return 0
  })
  var seen = {}
  var unique = []
  for (var j = 0; j < rows.length; j++) {
    if (seen[rows[j].path]) continue
    seen[rows[j].path] = true
    unique.push(rows[j])
  }
  return unique
}

// No execArgv: focus the window this notification is about. A task summary
// sits in the agent terminal title; otherwise match the sender the way
// omarchy-hyprland-focus-app does.
function focusAddress(clients, note) {
  var list = Array.isArray(clients) ? clients : []
  var summary = oneLine(note && note.summary)
  var app = oneLine(note && note.app)
  var address = ""
  if (summary.length >= 2) address = addressByTitle(list, summary)
  if (!address && note && note.wmClass) address = addressByApp(list, note.wmClass)
  if (!address && app) address = addressByApp(list, app)
  return safeAddress(address)
}

function safeAddress(value) {
  var text = String(value || "")
  return /^0x[0-9a-fA-F]+$/.test(text) ? text : ""
}

function addressByTitle(list, summary) {
  var matches = []
  for (var i = 0; i < list.length; i++) {
    var client = list[i] || {}
    if (String(client.title || "").indexOf(summary) >= 0) matches.push(client)
  }
  return pickAddress(matches)
}

function compact(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "")
}

// "T3 Code" is not a substring of class com.t3tools.T3Code. Compare the
// letters of the app name with the class and the window title.
function addressByApp(list, app) {
  var wanted = compact(app)
  if (wanted.length < 3) return ""
  var matches = []
  for (var i = 0; i < list.length; i++) {
    var client = list[i] || {}
    var fields = [client.class, client.initialClass, client.title, client.initialTitle]
    var hit = false
    for (var j = 0; j < fields.length && !hit; j++) {
      var field = compact(fields[j])
      if (!field) continue
      if (field.indexOf(wanted) >= 0) hit = true
      else if (field.length >= 4 && wanted.indexOf(field) >= 0) hit = true
    }
    if (hit) matches.push(client)
  }
  return pickAddress(matches)
}

function pickAddress(matches) {
  if (!matches.length) return ""
  var agents = []
  for (var i = 0; i < matches.length; i++) {
    var client = matches[i]
    if (client.class === "org.omarchy.agent" || client.initialClass === "org.omarchy.agent")
      agents.push(client)
  }
  var pool = agents.length ? agents : matches
  var best = pool[0]
  for (var j = 1; j < pool.length; j++) {
    if (String(pool[j].title || "").length < String(best.title || "").length) best = pool[j]
  }
  return String(best.address || "")
}

function swipeDecision(dx, width) {
  var distance = Number(dx)
  var rowWidth = Number(width)
  if (!isFinite(distance) || !isFinite(rowWidth) || rowWidth <= 0) return "snap-back"
  if (distance <= -SWIPE_COMMIT_RATIO * rowWidth) return "commit"
  return "snap-back"
}

function decodeUtf8(bytes) {
  var out = ""
  var i = 0
  while (i < bytes.length) {
    var c = bytes[i] & 255
    if (c < 0x80) {
      out += String.fromCharCode(c)
      i++
      continue
    }
    var need = 0
    var cp = 0
    if ((c & 0xe0) === 0xc0) { need = 1; cp = c & 0x1f }
    else if ((c & 0xf0) === 0xe0) { need = 2; cp = c & 0x0f }
    else if ((c & 0xf8) === 0xf0) { need = 3; cp = c & 0x07 }
    else { i++; continue }
    if (i + need >= bytes.length) break
    var ok = true
    for (var j = 1; j <= need; j++) {
      var next = bytes[i + j] & 255
      if ((next & 0xc0) !== 0x80) { ok = false; break }
      cp = (cp << 6) | (next & 0x3f)
    }
    if (!ok) { i++; continue }
    i += need + 1
    if (cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) continue
    if (cp < 0x10000) out += String.fromCharCode(cp)
    else {
      cp -= 0x10000
      out += String.fromCharCode(0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff))
    }
  }
  return out
}

function textFromBase64(b64) {
  var clean = String(b64 || "").replace(/[^A-Za-z0-9+/=]/g, "")
  if (!clean || clean.length % 4 === 1) return ""
  var bytes = []
  for (var i = 0; i < clean.length; i += 4) {
    var a = B64.indexOf(clean.charAt(i))
    var b = B64.indexOf(clean.charAt(i + 1))
    var third = clean.charAt(i + 2)
    var fourth = clean.charAt(i + 3)
    var c = third === "=" || !third ? -1 : B64.indexOf(third)
    var d = fourth === "=" || !fourth ? -1 : B64.indexOf(fourth)
    if (a < 0 || b < 0 || (third && third !== "=" && c < 0) || (fourth && fourth !== "=" && d < 0)) return ""
    bytes.push((a << 2) | (b >> 4))
    if (c >= 0) bytes.push(((b & 15) << 4) | (c >> 2))
    if (d >= 0) bytes.push(((c & 3) << 6) | d)
  }
  return decodeUtf8(bytes)
}

function compactName(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "")
}

// Lines are "Name<TAB>Icon<TAB>StartupWMClass" from desktop files.
export function parseDesktopCatalog(text) {
  var rows = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split("\t")
    if (parts.length < 2) continue
    var name = parts[0].replace(/^\s+|\s+$/g, "")
    if (!name) continue
    rows.push({
      name: name,
      icon: (parts[1] || "").replace(/^\s+|\s+$/g, ""),
      wm: (parts[2] || "").replace(/^\s+|\s+$/g, ""),
    })
  }
  return rows
}

export function matchDesktop(app, rows) {
  var wanted = compactName(app)
  if (wanted.length < 3 || !rows || !rows.length) return null
  var best = null
  var bestScore = 0
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    var name = compactName(row && row.name)
    if (!name) continue
    var score = 0
    if (name === wanted) score = 100 + name.length
    else if (wanted.indexOf(name) === 0 || name.indexOf(wanted) === 0) score = Math.min(name.length, wanted.length)
    if (score > bestScore) {
      best = row
      bestScore = score
    }
  }
  if (bestScore < 4 || !best) return null
  if (!best.icon) {
    for (var j = 0; j < rows.length; j++) {
      var other = rows[j]
      var otherName = compactName(other && other.name)
      if (!other || !other.icon || !otherName) continue
      if (wanted.indexOf(otherName) === 0 || otherName.indexOf(wanted) === 0)
        return { name: best.name, icon: other.icon, wm: best.wm || other.wm }
    }
  }
  return best
}

export { focusAddress, iconCandidates, readInbox, swipeDecision, textFromBase64 }
