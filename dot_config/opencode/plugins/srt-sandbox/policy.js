// Pure policy of the srt sandbox plugin: what a sandboxed command may read and write, and which GitHub
// credential replaces the placeholder it holds. index.js wires this into OpenCode and srt.

import { randomBytes } from 'node:crypto'

// Hosts whose requests get the real credential. Any other host only ever sees the placeholder.
const GITHUB_HOSTS = new Set(['github.com', 'api.github.com', 'uploads.github.com'])
const PLACEHOLDER = /srt_gh_[A-Za-z0-9_-]{32}/
// A Bot token is replaced this long before it expires, so a long command never sends an expired one.
const REFRESH_MARGIN_MS = 10 * 60 * 1000

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
    if (bot && repo && repo.owner === (await bot.account())) {
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

export function createAppClient(options) {
  return {
    async account() {},
    async mint(name) {},
  }
}

export function workTreeAt(cwd) {}
