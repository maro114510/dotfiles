// Pure policy of the srt sandbox plugin: what a sandboxed command may read and write, and which GitHub
// credential replaces the placeholder it holds. index.js wires this into OpenCode and srt.

import { execFileSync } from 'node:child_process'
import { createSign, randomBytes } from 'node:crypto'
import { existsSync, readFileSync, realpathSync } from 'node:fs'
import { isAbsolute, join, resolve } from 'node:path'

// Hosts whose requests get the real credential. Any other host only ever sees the placeholder.
const GITHUB_HOSTS = new Set(['github.com', 'api.github.com', 'uploads.github.com'])
const PLACEHOLDER = /srt_gh_[A-Za-z0-9_-]{32}/
// A Bot token is replaced this long before it expires, so a long command never sends an expired one.
const REFRESH_MARGIN_MS = 10 * 60 * 1000

// srt settings shared by every command. Each command adds its own working tree to allowWrite.
// env is the environment of the process that runs commands outside the sandbox later: its PATH and XDG
// base directories decide where the shell loads code from.
export function sandboxConfig({ home, tmp, env = {} }) {
  const at = (path) => join(home, path)
  const searchPath = env.PATH ?? ''
  const xdg = (name, fallback) => (isAbsolute(env[name] ?? '') ? env[name] : at(fallback))
  const cache = xdg('XDG_CACHE_HOME', '.cache')
  const data = xdg('XDG_DATA_HOME', '.local/share')
  const config = xdg('XDG_CONFIG_HOME', '.config')
  const pathDirs = searchPath.split(':').filter((dir) => isAbsolute(dir) && dir.startsWith(`${home}/`))
  const credentials = [
    at('.ssh'),
    at('Library/Keychains'),
    at('.config/op'),
    at('Library/Group Containers/2BUA8C4S2C.com.1password'),
    at('Library/Containers/com.1password.1password'),
    at('.config/opencode/service.json'),
    at('.local/share/opencode'),
    at('.local/state/opencode'),
    at('.pi/agent/auth.json'),
    at('.aws'),
    at('.netrc'),
    at('.git-credentials'),
  ]
  return {
    network: {
      // Every host is reachable through the ask callback; only requests to GitHub get a real credential,
      // which needs their TLS terminated.
      allowedDomains: [],
      deniedDomains: [],
      tlsTerminate: {},
    },
    filesystem: {
      denyRead: credentials,
      allowWrite: [home, tmp, '/private/tmp'],
      // The home stays writable except for the credential stores, which some tools also run code from, and
      // where code is loaded from later outside the sandbox: shell startup files, tool and agent
      // configuration, PATH and login items, and the hooks and config of every clone.
      denyWrite: [
        ...credentials,
        ...['.zshenv', '.zprofile', '.zshrc', '.zlogin', '.zlogout', '.bashrc', '.bash_profile', '.bash_login', '.profile']
          .map(at),
        at('.npmrc'),
        at('.bunfig.toml'),
        // Sourced by the zsh startup files, or able to name a program cargo runs. ~/.cargo itself stays
        // writable, since cargo downloads crates under it.
        at('.cargo/env'),
        at('.cargo/config.toml'),
        at('.cargo/config'),
        join(cache, 'zsh'),
        join(cache, 'gtr'),
        join(data, 'sheldon'),
        join(config, 'sheldon'),
        // Every other home entry this repository manages, and tool configs that can name a program to run:
        // kubeconfig exec plugins, Docker CLI plugins, Gradle init scripts, and editor and tmux configs.
        ...['.vimrc', '.vim', '.tmux.conf', '.tmux.session.conf', '.tmux', '.Brewfile', '.myclirc', '.raycast', '.apm'].map(at),
        at('.kube'),
        at('.docker'),
        at('.gnupg'),
        at('.gradle/init.d'),
        at('.gradle/gradle.properties'),
        at('.m2/settings.xml'),
        at('.terraformrc'),
        at('.ipython'),
        at('.gitconfig'),
        at('.config'),
        ...pathDirs,
        at('.local/bin'),
        at('.local/share/mise'),
        at('Library/LaunchAgents'),
        at('.claude'),
        at('.codex'),
        at('.pi/agent'),
        at('.srt-settings.json'),
        at('**/.git/hooks'),
        at('**/.git/config'),
        at('**/.git/config.worktree'),
        at('**/.git/worktrees/*/config.worktree'),
        at('**/.git/modules/**/hooks'),
        at('**/.git/modules/**/config'),
        // OpenCode loads plugin code from its caches outside the sandbox.
        at('.cache/opencode'),
        at('Library/Caches/opencode'),
      ],
    },
    // gh verifies TLS through trustd, which only the weaker isolation lets it reach. The keychain stays closed.
    enableWeakerNetworkIsolation: true,
  }
}

// The filesystem rules of one command: the shared ones plus its working tree and git directory, minus
// what git reads or runs outside the sandbox later: hooks, config, and the pointer of a linked worktree.
export function filesystemFor(base, tree) {
  if (!tree) return base.filesystem
  const { top, gitDir } = tree
  const pointer = join(top, '.git')
  return {
    ...base.filesystem,
    allowWrite: [...base.filesystem.allowWrite, top, gitDir],
    denyWrite: [
      ...base.filesystem.denyWrite,
      ...(pointer === gitDir ? [] : [pointer]),
      join(gitDir, 'hooks'),
      join(gitDir, 'config'),
      join(gitDir, 'config.worktree'),
      join(gitDir, 'worktrees/*/config.worktree'),
      join(gitDir, 'modules/**/hooks'),
      join(gitDir, 'modules/**/config'),
    ],
  }
}

// gh keeps its token in hosts.yml when it cannot use the keychain. The file stays readable because gh does
// not start without it, so a token there must stop the sandbox instead. Same lookup order as gh's.
export function ghTokenInPlainText({ env, home }) {
  const dir = env.GH_CONFIG_DIR || (env.XDG_CONFIG_HOME ? join(env.XDG_CONFIG_HOME, 'gh') : join(home, '.config/gh'))
  const hosts = join(dir, 'hosts.yml')
  return existsSync(hosts) && /^\s*oauth_token\s*:/m.test(readFileSync(hosts, 'utf8'))
}

// SSH cannot authenticate inside the sandbox, which hides the keys and the agent, so git reaches GitHub over
// HTTPS, where the placeholder is swapped. Appended after any git config the command already passes.
export function httpsRemoteEnv(env) {
  const first = Number.parseInt(env.GIT_CONFIG_COUNT ?? '0', 10) || 0
  const added = {}
  ;['git@github.com:', 'ssh://git@github.com/'].forEach((from, offset) => {
    added[`GIT_CONFIG_KEY_${first + offset}`] = 'url.https://github.com/.insteadOf'
    added[`GIT_CONFIG_VALUE_${first + offset}`] = from
  })
  added.GIT_CONFIG_COUNT = String(first + 2)
  return added
}

export function repoFromRemote(url) {
  const match = /^(?:https:\/\/(?:[^@/]+@)?github\.com\/|ssh:\/\/git@github\.com\/|git@github\.com:)([^/]+)\/([^/]+?)(?:\.git)?\/?$/.exec(
    url.trim(),
  )
  return match ? { owner: match[1], name: match[2] } : null
}

// ownerToken: () => Promise<string>, the owner's own gh login.
// bot: null, or { account: () => Promise<string>, mint: (name) => Promise<{ token, expiresAt } | null> },
// where mint answers null for a repository the installation does not cover.
export function createBroker({ ownerToken, bot, now = Date.now }) {
  const repos = new Map()
  const botTokens = new Map()

  async function botToken(repo) {
    const cached = botTokens.get(repo.name)
    if (cached && now() < cached.expiresAt - REFRESH_MARGIN_MS) return cached.token
    const minted = await bot.mint(repo.name)
    if (minted) botTokens.set(repo.name, minted)
    return minted?.token ?? null
  }

  async function credentialFor(repo) {
    // GitHub logins are case-insensitive, and a remote may spell the account either way.
    if (bot && repo && repo.owner.toLowerCase() === (await bot.account()).toLowerCase()) {
      const token = await botToken(repo)
      if (token) return token
    }
    return ownerToken()
  }

  return {
    placeholderFor(repo) {
      const placeholder = `srt_gh_${randomBytes(24).toString('base64url')}`
      repos.set(placeholder, repo)
      return placeholder
    },

    async filterRequest(request) {
      if (!GITHUB_HOSTS.has(new URL(request.url).hostname)) return { action: 'allow' }
      const auth = request.headers.get('authorization')
      if (!auth) return { action: 'allow' }
      // git sends the placeholder as Basic credentials, base64-encoded, so look inside them too.
      const basic = /^basic\s+(\S+)$/i.exec(auth)
      const plain = basic ? Buffer.from(basic[1], 'base64').toString('utf8') : auth
      const placeholder = PLACEHOLDER.exec(plain)?.[0]
      if (!placeholder) return { action: 'allow' }
      if (!repos.has(placeholder)) {
        return { action: 'deny', status: 401, reason: 'srt sandbox: unknown GitHub credential placeholder' }
      }
      let token
      try {
        token = await credentialFor(repos.get(placeholder))
      } catch (error) {
        return { action: 'deny', status: 503, reason: `srt sandbox: no GitHub credential: ${error.message}` }
      }
      const swapped = plain.replace(placeholder, token)
      const value = basic ? `Basic ${Buffer.from(swapped).toString('base64')}` : swapped
      return { action: 'allow', setHeaders: [['authorization', value]] }
    },
  }
}

// What a Bot token may do: push, open pull requests, comment, set commit statuses, and read check runs.
// Never Workflows or Administration.
const BOT_PERMISSIONS = {
  contents: 'write',
  pull_requests: 'write',
  issues: 'write',
  statuses: 'write',
  checks: 'read',
  metadata: 'read',
}

// The App key stays in this process's memory; the JWT is built here and sent only in a request header.
export function createAppClient({ appId, installationId, key, fetch = globalThis.fetch }) {
  let account

  function jwt() {
    const now = Math.floor(Date.now() / 1000)
    const part = (value) => Buffer.from(JSON.stringify(value)).toString('base64url')
    const unsigned = `${part({ alg: 'RS256', typ: 'JWT' })}.${part({ iat: now - 60, exp: now + 540, iss: appId })}`
    return `${unsigned}.${createSign('RSA-SHA256').update(unsigned).sign(key, 'base64url')}`
  }

  async function call(method, path, body) {
    return fetch(`https://api.github.com${path}`, {
      method,
      headers: { authorization: `Bearer ${jwt()}`, accept: 'application/vnd.github+json' },
      body: body && JSON.stringify(body),
    })
  }

  const client = {
    async account() {
      if (account) return account
      const response = await call('GET', `/app/installations/${installationId}`)
      if (!response.ok) throw new Error(`reading the Bot installation failed: ${response.status}`)
      account = (await response.json()).account.login
      return account
    },

    async mint(name) {
      const response = await call('POST', `/app/installations/${installationId}/access_tokens`, {
        repositories: [name],
        permissions: BOT_PERMISSIONS,
      })
      // GitHub answers 422 both for a repository the installation does not cover and for a permission the
      // App lacks. Only the first may fall back to the owner, so ask GitHub which one it is.
      if (response.status === 422) {
        const installed = await call('GET', `/repos/${await client.account()}/${name}/installation`)
        if (installed.status === 404) return null
      }
      if (!response.ok) throw new Error(`minting a Bot token failed: ${response.status}`)
      const body = await response.json()
      return { token: body.token, expiresAt: Date.parse(body.expires_at) }
    },
  }
  return client
}

function git(cwd, ...args) {
  try {
    return execFileSync('git', ['-C', cwd, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim()
  } catch {
    return null
  }
}

// The tree a command may write to, the git directory its commits go to, and its GitHub repository.
export function workTreeAt(cwd) {
  const top = git(cwd, 'rev-parse', '--show-toplevel')
  if (!top) return null
  const gitDir = realpathSync(resolve(cwd, git(cwd, 'rev-parse', '--git-common-dir')))
  const remote = git(cwd, 'remote', 'get-url', 'origin')
  return { top: realpathSync(top), gitDir, repo: remote ? repoFromRemote(remote) : null }
}
