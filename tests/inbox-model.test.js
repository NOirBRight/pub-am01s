import { Buffer } from "node:buffer"
import { describe, expect, it } from "vitest"
import { focusAddress, iconCandidates, matchDesktop, parseDesktopCatalog, readInbox, swipeDecision, textFromBase64 } from "../plugin/inbox-model.mjs"

const now = 1790441347328

function file(path, value) {
  return { path, text: JSON.stringify(value) }
}

describe("readInbox", () => {
  it("orders rows newest first and keeps the body on one line", () => {
    const rows = readInbox([
      file("/history/older.json", {
        app: "omp",
        summary: "older",
        body: "one\nline",
        timestamp: now - 3 * 60 * 60 * 1000,
      }),
      file("/history/newer.json", {
        app: "Feishu",
        summary: "newer",
        body: "hello",
        timestamp: now - 30 * 1000,
      }),
    ], now)

    expect(rows.map((row) => row.path)).toEqual([
      "/history/newer.json",
      "/history/older.json",
    ])
    expect(rows.map((row) => row.app)).toEqual(["Feishu", "omp"])
    expect(rows[0].timeLabel).toBe("now")
    expect(rows[1].timeLabel).toBe("3h")
    expect(rows[1].body).toBe("one line")
  })

  it("classifies file, theme-name, and initial icons", () => {
    const rows = readInbox([
      file("/history/file.json", {
        app: "Feishu",
        appIcon: "file:///tmp/a%20b.png",
        timestamp: now,
      }),
      file("/history/theme.json", {
        app: "Grok Bot",
        appIcon: "grok-bot",
        timestamp: now - 1000,
      }),
      file("/history/initial.json", {
        app: "omp",
        appIcon: "",
        timestamp: now - 2000,
      }),
    ], now)

    expect(rows.map((row) => row.icon)).toEqual([
      { kind: "file", path: "/tmp/a b.png", names: ["feishu"] },
      { kind: "theme-name", name: "grok-bot", names: ["grok-bot", "grokbot"] },
      { kind: "initial", letter: "O", color: expect.stringMatching(/^#[0-9a-f]{6}$/), names: ["omp"] },
    ])
    const again = readInbox([
      file("/history/initial.json", { app: "omp", appIcon: "", timestamp: now }),
    ], now)
    expect(again[0].icon).toEqual(rows[2].icon)
  })

  it("flags a notification within 10 minutes as fresh", () => {
    const rows = readInbox([
      file("/history/fresh.json", { app: "a", timestamp: now - 10 * 60 * 1000 }),
      file("/history/stale.json", { app: "b", timestamp: now - 10 * 60 * 1000 - 1 }),
      file("/history/minutes.json", { app: "c", timestamp: now - 5 * 60 * 1000 }),
      file("/history/days.json", { app: "d", timestamp: now - 3 * 24 * 60 * 60 * 1000 }),
    ], now)

    expect(rows.find((row) => row.app === "a").fresh).toBe(true)
    expect(rows.find((row) => row.app === "b").fresh).toBe(false)
    expect(rows.find((row) => row.app === "c")).toMatchObject({ fresh: true, timeLabel: "5m" })
    expect(rows.find((row) => row.app === "d")).toMatchObject({ fresh: false, timeLabel: "3d" })
  })

  it("omits the action when execArgv is missing, empty, or unparseable", () => {
    const rows = readInbox([
      file("/history/missing.json", { app: "missing", timestamp: now }),
      file("/history/empty.json", { app: "empty", execArgv: "", timestamp: now - 1 }),
      file("/history/bad.json", { app: "bad", execArgv: "not-json", timestamp: now - 2 }),
      file("/history/array.json", { app: "array", execArgv: "[]", timestamp: now - 3 }),
      file("/history/types.json", { app: "types", execArgv: "[1]", timestamp: now - 4 }),
      file("/history/dash.json", { app: "dash", execArgv: "[\"-rf\",\"x\"]", timestamp: now - 5 }),
      file("/history/ok.json", {
        app: "ok",
        execArgv: "[\"tensaku-edit\",\"/path.png\"]",
        timestamp: now - 6,
      }),
    ], now)

    expect(rows.find((row) => row.app === "missing").action).toBeNull()
    expect(rows.find((row) => row.app === "empty").action).toBeNull()
    expect(rows.find((row) => row.app === "bad").action).toBeNull()
    expect(rows.find((row) => row.app === "array").action).toBeNull()
    expect(rows.find((row) => row.app === "types").action).toBeNull()
    expect(rows.find((row) => row.app === "dash").action).toBeNull()
    expect(rows.find((row) => row.app === "ok").action).toEqual(["tensaku-edit", "/path.png"])
  })

  it("skips a malformed file and still returns the valid one", () => {
    const rows = readInbox([
      { path: "/history/torn.json", text: "{not json" },
      { path: "/history/blank.json", text: "   " },
      file("/history/good.json", { app: "ok", summary: "kept", timestamp: now }),
    ], now)

    expect(rows.map((row) => row.path)).toEqual(["/history/good.json"])
    expect(rows[0].summary).toBe("kept")
  })

  it("decodes utf-8 history text carried as base64", () => {
    const body = "用户243770: [Image]虽然"
    const text = JSON.stringify({ app: "Feishu", summary: "群", body, timestamp: now })
    const decoded = textFromBase64(Buffer.from(text, "utf8").toString("base64"))
    const rows = readInbox([{ path: "/history/utf8.json", text: decoded }], now)

    expect(decoded).toBe(text)
    expect(rows[0].summary).toBe("群")
    expect(rows[0].body).toBe(body)
  })
})

describe("iconCandidates", () => {
  it("uses the desktop icon name for T3 Code, not a content picture", () => {
    expect(iconCandidates("T3 Code", "")).toEqual(["t3code", "t3-code"])
    expect(iconCandidates("T3 Code (Nightly)", "")).toEqual([
      "t3codenightly",
      "t3-code-nightly",
      "t3code",
      "t3code-nightly",
    ])
    expect(iconCandidates("WeChat", "wechat")[0]).toBe("wechat")
    expect(iconCandidates("omarchy-action", "")).toContain("t3code")
    expect(focusAddress([
      { class: "com.t3tools.T3Code", title: "T3 Code (Nightly)", address: "0x59af9bb330c0" },
      { class: "dev.tensaku.Tensaku", title: "Tensaku", address: "0x111" },
    ], { app: "omarchy-action", summary: "Screenshot saved to clipboard and file" })).toBe("0x59af9bb330c0")
  })
})

describe("desktop icons", () => {
  const catalog = parseDesktopCatalog([
    "T3 Code\tt3code\tt3code",
    "T3 Code (Nightly)\t\tt3code",
    "WeChat\twechat\twechat",
  ].join("\n"))

  it("picks the T3 Code icon and window class", () => {
    expect(matchDesktop("T3 Code", catalog)).toEqual({ name: "T3 Code", icon: "t3code", wm: "t3code" })
    expect(matchDesktop("T3 Code (Nightly)", catalog).icon).toBe("t3code")
    expect(focusAddress([
      { class: "com.t3tools.T3Code", title: "T3 Code (Nightly)", address: "0x59af9bb330c0" },
      { class: "dev.tensaku.Tensaku", title: "Tensaku", address: "0x111" },
    ], { app: "T3 Code", summary: "done", wmClass: "t3code" })).toBe("0x59af9bb330c0")
  })
})

describe("focusAddress", () => {
  const clients = [
    {
      class: "org.omarchy.agent",
      initialClass: "org.omarchy.agent",
      initialTitle: "foot",
      title: "π > 调查 Omarchy 平铺切换默认行为",
      address: "0x59af9bcb4810",
    },
    {
      class: "org.omarchy.agent",
      initialClass: "org.omarchy.agent",
      initialTitle: "foot",
      title: "π ⠙ 修复豆包说接口兼容性问题",
      address: "0x59af9bbe2fa0",
    },
    {
      class: "com.t3tools.T3Code",
      initialClass: "com.t3tools.T3Code",
      title: "T3 Code",
      address: "0x59af9bb330c0",
    },
  ]

  it("focuses the agent window whose title contains the summary", () => {
    expect(focusAddress(clients, {
      app: "omp",
      summary: "调查 Omarchy 平铺切换默认行为",
    })).toBe("0x59af9bcb4810")
  })

  it("focuses T3 when the app name is spaced and the class is not", () => {
    const t3 = {
      class: "com.t3tools.T3Code",
      initialClass: "com.t3tools.T3Code",
      title: "T3 Code (Nightly)",
      address: "0x59af9bb330c0",
    }
    expect(focusAddress(clients.concat([t3]), { app: "T3 Code", summary: "build finished" })).toBe("0x59af9bb330c0")
    expect(focusAddress([t3], { app: "T3 Code (Nightly)", summary: "hello" })).toBe("0x59af9bb330c0")
  })

  it("falls back to the sender class, then an agent launch title", () => {
    expect(focusAddress(clients, { app: "T3Code", summary: "" })).toBe("0x59af9bb330c0")
    expect(focusAddress([
      { class: "org.omarchy.agent", initialClass: "org.omarchy.agent", initialTitle: "kitty", title: "shell", address: "0xabc" },
    ], { app: "kitty", summary: "nope" })).toBe("0xabc")
  })

  it("returns nothing for a bad address or no match", () => {
    expect(focusAddress([
      { class: "Slack", title: "Slack", address: "not-an-address" },
    ], { app: "Slack", summary: "Slack" })).toBe("")
    expect(focusAddress(clients, { app: "missing", summary: "no such task" })).toBe("")
    expect(focusAddress(null, null)).toBe("")
  })
})

describe("swipeDecision", () => {
  it("commits at 40% of the row width and snaps back otherwise", () => {
    expect(swipeDecision(-40, 100)).toBe("commit")
    expect(swipeDecision(-80, 200)).toBe("commit")
    expect(swipeDecision(-39, 100)).toBe("snap-back")
    expect(swipeDecision(0, 100)).toBe("snap-back")
    expect(swipeDecision(40, 100)).toBe("snap-back")
    expect(swipeDecision(-100, 0)).toBe("snap-back")
    expect(swipeDecision(Number.NaN, 100)).toBe("snap-back")
  })
})
