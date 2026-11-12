// OpenCode server plugin: runs every shell command inside srt and hands it GitHub credentials only as
// placeholders. The rules live in policy.js.

import { execFile } from 'node:child_process'
import { existsSync, readFileSync, realpathSync } from 'node:fs'
import { homedir, tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'
import {
  createAppClient,
  createBroker,
  filesystemFor,
  ghTokenInPlainText,
  sandboxConfig,
  workTreeAt,
} from './policy.js'

const here = dirname(fileURLToPath(import.meta.url))
const STAND_IN = join(here, 'zsh')
// Not committed: { "appId", "installationId", "keyRef" } of the Bot GitHub App, keyRef being the
// 1Password reference of its private key. Without the file every command acts as the owner.
const BOT_CONFIG = join(here, 'bot.local.json')
const OWNER_TOKEN_TTL_MS = 5 * 60 * 1000

// Asynchronous on purpose: the proxy shares this event loop, and a 1Password prompt can take seconds.
const run = promisify(execFile)

async function botClient() {
  if (!existsSync(BOT_CONFIG)) return null
  const { appId, installationId, keyRef } = JSON.parse(readFileSync(BOT_CONFIG, 'utf8'))
  try {
    const { stdout: key } = await run('op', ['read', keyRef])
    return createAppClient({ appId, installationId, key })
  } catch {
    // Acting as the owner where the Bot should act would be the wrong identity, so GitHub requests fail.
    const unavailable = async () => {
      throw new Error('the Bot key could not be read from 1Password; restart OpenCode after unlocking it')
    }
    return { account: unavailable, mint: unavailable }
  }
}

let owner = { token: null, until: 0 }
async function ownerToken() {
  if (Date.now() < owner.until) return owner.token
  const token = (await run('gh', ['auth', 'token', '--hostname', 'github.com'])).stdout.trim()
  owner = { token, until: Date.now() + OWNER_TOKEN_TTL_MS }
  return token
}

// One proxy per OpenCode process, shared by the plugin instance of every location. A failed start stays
// failed, so every command is refused until OpenCode restarts.
let sandbox
function start() {
  sandbox ??= (async () => {
    const { SandboxManager } = await import('@anthropic-ai/sandbox-runtime')
    const broker = createBroker({ ownerToken, bot: await botClient() })
    const base = sandboxConfig({ home: homedir(), tmp: realpathSync(tmpdir()) })
    await SandboxManager.initialize(
      { ...base, network: { ...base.network, filterRequest: broker.filterRequest } },
      async () => true,
    )
    return { SandboxManager, broker, base }
  })()
  return sandbox
}

export default {
  id: 'srt-sandbox',
  async setup(ctx) {
    const hook = await ctx.shell.hook('create.before', async (event) => {
      // The stand-in runs only what is prepared below, so any failure here refuses the command.
      const shell = event.shell
      event.shell = STAND_IN
      delete event.env.SRT_WRAPPED
      try {
        // Checked for every command, since gh can switch to plain text at any time while OpenCode runs.
        if (ghTokenInPlainText({ env: event.env, home: homedir() })) {
          throw new Error('gh keeps its token in plain text in hosts.yml; move it to the keychain with `gh auth login`')
        }
        const { SandboxManager, broker, base } = await start()
        const tree = workTreeAt(resolve(ctx.location.directory, event.cwd))
        const placeholder = broker.placeholderFor(tree?.repo ?? null)
        event.env.GH_TOKEN = placeholder
        event.env.GITHUB_TOKEN = placeholder
        event.env.SRT_WRAPPED = await SandboxManager.wrapWithSandbox(event.command, shell, {
          filesystem: filesystemFor(base, tree),
        })
      } catch (error) {
        console.error(`srt sandbox: ${error.message}`)
      }
    })
    return () => hook.dispose()
  },
}
