import { describe, expect, it } from 'vitest'
import {
  clearOffered,
  cliLoginCommand,
  credentialsClearCommand,
  credentialsSetCommand,
  isInvalidCodeLine,
  loginUrl,
  withLogin,
} from '../plugin/settings-model.mjs'

const codex = {
  id: 'codex',
  credentialKind: 'cli',
  extra: { key: 'accountId', hint: 'Codex account ID', required: true },
}

const cursor = {
  id: 'cursor',
  credentialKind: 'cli',
  extra: { key: 'userId', hint: 'Cursor user ID（token 已含时留空）', required: false },
}

const claudeCode = { hint: '粘贴浏览器页面上的授权码', invalidPattern: 'invalid code', flags: 'iu' }

describe('credentials set command', () => {
  it('sends Codex account-id as a flag and never puts the secret in argv', () => {
    expect(credentialsSetCommand(codex, { accountId: ' acct-1 ', token: 'secret-value' })).toEqual([
      'credentials', 'set', 'codex', '--account-id', 'acct-1',
    ])
    expect(credentialsSetCommand(codex, {})).toBeNull()
    expect(credentialsSetCommand(codex, { accountId: '   ' })).toBeNull()
    expect(credentialsSetCommand(codex, { accountId: 'acct', token: 'secret-value' }).join('\n')).not.toContain('secret')
  })

  it('omits optional Cursor user-id when blank and includes it when set', () => {
    expect(credentialsSetCommand(cursor, {})).toEqual(['credentials', 'set', 'cursor'])
    expect(credentialsSetCommand(cursor, { userId: ' ' })).toEqual(['credentials', 'set', 'cursor'])
    expect(credentialsSetCommand(cursor, { userId: ' user_1 ' })).toEqual([
      'credentials', 'set', 'cursor', '--user-id', 'user_1',
    ])
  })

  it('rejects a required user id and accepts a key with no extra', () => {
    const requiredUser = { id: 'cursor', extra: { key: 'userId', required: true } }
    expect(credentialsSetCommand(requiredUser, { userId: '' })).toBeNull()
    expect(credentialsSetCommand({ id: 'ollama-cloud', credentialKind: 'key' }, null)).toEqual([
      'credentials', 'set', 'ollama-cloud',
    ])
    expect(credentialsSetCommand({ id: '  ' }, {})).toBeNull()
    expect(credentialsSetCommand(null, {})).toBeNull()
    expect(credentialsClearCommand(' codex ')).toEqual(['credentials', 'clear', 'codex'])
    expect(credentialsClearCommand('')).toBeNull()
  })
})

describe('clear is offered only for a PUB-stored credential', () => {
  const key = { credentialKind: 'key' }
  const both = { credentialKind: 'both' }
  const cli = { credentialKind: 'cli' }

  it('follows credentialSource when the snapshot has one', () => {
    expect(clearOffered({ credentialSource: 'pub', errorKind: 'signed-out' }, cli)).toBe(true)
    expect(clearOffered({ credentialSource: ' pub ' }, cli)).toBe(true)
    expect(clearOffered({ credentialSource: 'cli' }, key)).toBe(false)
    expect(clearOffered({ credentialSource: ' cli ' }, key)).toBe(false)
    expect(clearOffered({ credentialSource: 'env' }, both)).toBe(false)
    expect(clearOffered({ credentialSource: 'file', remaining: 0.4 }, key)).toBe(false)
  })

  it('falls back to a signed-in key or both when credentialSource is absent', () => {
    expect(clearOffered({ id: 'ollama-cloud', remaining: 0.5 }, key)).toBe(true)
    expect(clearOffered({ id: 'opencode-go', errorKind: 'rate-limit' }, both)).toBe(true)
    expect(clearOffered({ id: 'claude', remaining: 0.4 }, cli)).toBe(false)
    expect(clearOffered({ errorKind: 'signed-out' }, key)).toBe(false)
    expect(clearOffered({ error: 'signed out' }, both)).toBe(false)
    expect(clearOffered(null, key)).toBe(false)
    expect(clearOffered({ credentialSource: 'pub' }, null)).toBe(true)
    expect(clearOffered({ remaining: 1 }, null)).toBe(false)
  })
})

describe('invalid CLI code line', () => {
  it('matches the catalog pattern with its flags', () => {
    expect(isInvalidCodeLine('Error: Invalid code. Try again', claudeCode)).toBe(true)
    expect(isInvalidCodeLine('invalid code', claudeCode)).toBe(true)
    expect(isInvalidCodeLine('logged in', claudeCode)).toBe(false)
    expect(isInvalidCodeLine('Invalid code', null)).toBe(false)
    expect(isInvalidCodeLine(null, claudeCode)).toBe(false)
    expect(isInvalidCodeLine('Invalid code', { invalidPattern: 'invalid code', flags: '' })).toBe(false)
    expect(isInvalidCodeLine('invalid code', { invalidPattern: '(', flags: 'iu' })).toBe(false)
    expect(isInvalidCodeLine('invalid code', { invalidPattern: 'invalid code', flags: 'z' })).toBe(false)
  })
})

describe('catalog login command', () => {
  it('spawns cli.bin plus cli.args and keeps list-like args', () => {
    expect(cliLoginCommand({
      cli: { bin: 'claude', args: ['auth', 'login'], label: 'Claude Code' },
    })).toEqual(['claude', 'auth', 'login'])
    const listed = { 0: 'login', length: 1 }
    expect(cliLoginCommand({ cli: { bin: 'codex', args: listed } })).toEqual(['codex', 'login'])
    expect(cliLoginCommand({ cli: { bin: ' ', args: ['login'] } })).toBeNull()
    expect(cliLoginCommand({})).toBeNull()
    expect(loginUrl('open https://claude.ai/login). now')).toBe('https://claude.ai/login')
    expect(loginUrl('no link')).toBe('')
  })

  it('attaches catalog fields and clear state without a local login table', () => {
    const presented = [
      { id: 'claude', name: 'Claude', enabled: true, loginLabel: '未登录' },
      { id: 'codex', name: 'Codex', enabled: true, loginLabel: '' },
      { id: 'ollama-cloud', name: 'Ollama Cloud', enabled: false, loginLabel: '' },
    ]
    const catalog = [
      {
        id: 'claude',
        credentialKind: 'cli',
        hint: 'Claude access token',
        cli: { bin: 'claude', args: ['auth', 'login'], file: '~/.claude/.credentials.json', label: 'Claude Code' },
        codeEntry: claudeCode,
      },
      {
        id: 'codex',
        credentialKind: 'cli',
        hint: 'Codex access token',
        cli: { bin: 'codex', args: ['login'], label: 'Codex CLI' },
        extra: codex.extra,
      },
      {
        id: 'ollama-cloud',
        credentialKind: 'key',
        hint: 'Ollama API key',
        page: { url: 'https://ollama.com/settings/keys', label: 'ollama.com' },
      },
    ]
    const snapshot = {
      providers: [
        { id: 'claude', errorKind: 'signed-out' },
        { id: 'codex', credentialSource: 'cli', remaining: 0.5 },
        { id: 'ollama-cloud', remaining: 0.2 },
      ],
    }
    const original = presented[0]
    const rows = withLogin(presented, catalog, snapshot)
    expect(original).toEqual({ id: 'claude', name: 'Claude', enabled: true, loginLabel: '未登录' })
    expect(rows.map(row => row.clearOffered)).toEqual([false, false, true])
    expect(rows[0].loginLabel).toBe('未登录')
    expect(rows[0].codeEntry).toEqual(claudeCode)
    expect(rows[0].cli).toEqual({
      bin: 'claude',
      args: ['auth', 'login'],
      label: 'Claude Code',
      file: '~/.claude/.credentials.json',
    })
    expect(rows[1].extra).toEqual({ key: 'accountId', hint: 'Codex account ID', required: true })
    expect(rows[1].credentialSource).toBe('cli')
    expect(rows[2].page).toEqual({ url: 'https://ollama.com/settings/keys', label: 'ollama.com' })
    expect(rows[2].cli).toBeNull()
    expect(rows[2].clearOffered).toBe(true)
  })
})
