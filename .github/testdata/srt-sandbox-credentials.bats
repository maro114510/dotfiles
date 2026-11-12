#!/usr/bin/env bats
#
# Verifies how the srt sandbox plugin keeps GitHub credentials out of the
# sandbox: a command receives only a placeholder, and the proxy swaps in the
# real credential on requests to GitHub, chosen by the owner of the
# repository the command runs in.
#
# Each test runs a small ES module against policy.js with fake tokens; no
# network or GitHub login is used.
#
# Usage: bats .github/testdata/srt-sandbox-credentials.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  policy="${repo_root}/dot_config/opencode/plugins/srt-sandbox/policy.js"
}

# Runs an ES module body with `policy` imported and helpers in scope:
#   ownerOnly()         a broker whose only credential is the owner's login
#   withBot(bot)        a broker that also has the Bot interface `bot`
#   req(url, auth)      a Request to `url` carrying the Authorization `auth`
#   header(decision)    the authorization value a decision sets, or "none"
run_policy() {
  node --input-type=module -e "
    const policy = await import(process.argv[1]);
    const ownerOnly = () => policy.createBroker({ ownerToken: async () => 'gho_owner', bot: null });
    const withBot = (bot) => policy.createBroker({ ownerToken: async () => 'gho_owner', bot });
    const req = (url, auth) => new Request(url, { headers: auth ? { authorization: auth } : {} });
    const header = (d) => (d.setHeaders ?? []).find(([n]) => n.toLowerCase() === 'authorization')?.[1] ?? 'none';
    $1
  " "${policy}"
}

@test "an https remote of GitHub gives its owner and repository name" {
  run run_policy 'console.log(JSON.stringify(policy.repoFromRemote("https://github.com/acme/tool.git")))'
  [ "$status" -eq 0 ]
  [ "$output" = '{"owner":"acme","name":"tool"}' ]
}

@test "an scp-style ssh remote of GitHub gives its owner and repository name" {
  run run_policy 'console.log(JSON.stringify(policy.repoFromRemote("git@github.com:acme/tool.git")))'
  [ "$output" = '{"owner":"acme","name":"tool"}' ]
}

@test "an ssh url remote without the .git suffix gives its owner and repository name" {
  run run_policy 'console.log(JSON.stringify(policy.repoFromRemote("ssh://git@github.com/acme/tool")))'
  [ "$output" = '{"owner":"acme","name":"tool"}' ]
}

@test "a remote on another host gives no repository" {
  run run_policy 'console.log(JSON.stringify(policy.repoFromRemote("https://gitlab.com/acme/tool.git")))'
  [ "$output" = 'null' ]
}

@test "the placeholder a command receives is not the owner's token" {
  run run_policy '
    const p = ownerOnly().placeholderFor({ owner: "someone", name: "x" });
    console.log(p.length > 20 && !p.includes("gho_owner") ? "masked" : `leaked: ${p}`);
  '
  [ "$output" = masked ]
}

@test "a gh request to the GitHub API with the placeholder carries the owner's token" {
  run run_policy '
    const b = ownerOnly();
    const p = b.placeholderFor({ owner: "someone", name: "x" });
    const d = await b.filterRequest(req("https://api.github.com/repos/someone/x", `token ${p}`));
    console.log(d.action, header(d));
  '
  [ "$status" -eq 0 ]
  [ "$output" = "allow token gho_owner" ]
}

@test "a git push with the placeholder as Basic credentials carries the owner's token re-encoded" {
  run run_policy '
    const b = ownerOnly();
    const p = b.placeholderFor({ owner: "someone", name: "x" });
    const basic = "Basic " + Buffer.from(`x-access-token:${p}`).toString("base64");
    const d = await b.filterRequest(req("https://github.com/someone/x.git/git-receive-pack", basic));
    const sent = header(d).replace(/^Basic /, "");
    console.log(d.action, Buffer.from(sent, "base64").toString());
  '
  [ "$output" = "allow x-access-token:gho_owner" ]
}

@test "the placeholder sent to a host other than GitHub is not replaced" {
  run run_policy '
    const b = ownerOnly();
    const p = b.placeholderFor({ owner: "someone", name: "x" });
    const d = await b.filterRequest(req("https://example.com/collect", `token ${p}`));
    console.log(d.action, header(d));
  '
  [ "$output" = "allow none" ]
}

@test "a GitHub request with a placeholder the plugin never issued is denied" {
  run run_policy '
    const d = await ownerOnly().filterRequest(req("https://api.github.com/user", "token srt_gh_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"));
    console.log(d.action);
  '
  [ "$output" = deny ]
}

@test "a GitHub request without credentials passes unchanged" {
  run run_policy '
    const d = await ownerOnly().filterRequest(req("https://api.github.com/zen"));
    console.log(d.action, header(d));
  '
  [ "$output" = "allow none" ]
}

# A Bot whose installation belongs to `acme` and covers only acme/covered.
bot_fixture='
  const minted = [];
  const bot = {
    account: async () => "acme",
    mint: async (name) => { minted.push(name); return name === "covered" ? { token: `ghs_bot_${name}`, expiresAt: Date.now() + 3600e3 } : null; },
  };
'

@test "a command in a repository the Bot's installation covers acts as the Bot" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "acme", name: "covered" });
    const d = await b.filterRequest(req("https://api.github.com/repos/acme/covered/pulls", `Bearer ${p}`));
    console.log(header(d), minted.join(","));
  '
  [ "$output" = "Bearer ghs_bot_covered covered" ]
}

@test "a remote spelling the Bot account in other letter case still acts as the Bot" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "Acme", name: "covered" });
    const d = await b.filterRequest(req("https://api.github.com/repos/Acme/covered", `token ${p}`));
    console.log(header(d));
  '
  [ "$output" = "token ghs_bot_covered" ]
}

@test "a command in a repository of the Bot account outside the installation acts as the owner" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "acme", name: "uncovered" });
    const d = await b.filterRequest(req("https://api.github.com/repos/acme/uncovered", `token ${p}`));
    console.log(header(d));
  '
  [ "$output" = "token gho_owner" ]
}

@test "a command in a repository of another owner acts as the owner without asking the Bot" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "other-org", name: "covered" });
    const d = await b.filterRequest(req("https://api.github.com/repos/other-org/covered", `token ${p}`));
    console.log(header(d), `minted=${minted.length}`);
  '
  [ "$output" = "token gho_owner minted=0" ]
}

@test "a command outside any GitHub repository acts as the owner" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor(null);
    const d = await b.filterRequest(req("https://api.github.com/user", `token ${p}`));
    console.log(header(d));
  '
  [ "$output" = "token gho_owner" ]
}

@test "an API request for another repository with a Bot credential is refused with a reason naming both" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "acme", name: "covered" });
    const d = await b.filterRequest(req("https://api.github.com/repos/acme/other/issues", `token ${p}`));
    console.log(d.action, d.status, d.reason.includes("acme/covered") && d.reason.includes("acme/other"));
  '
  [ "$status" -eq 0 ]
  [ "$output" = "deny 403 true" ]
}

@test "a git request for another repository with a Bot credential is refused the same way" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "acme", name: "covered" });
    const basic = `Basic ${Buffer.from(`x-access-token:${p}`).toString("base64")}`;
    const d = await b.filterRequest(req("https://github.com/acme/other.git/info/refs?service=git-receive-pack", basic));
    console.log(d.action, d.status);
  '
  [ "$status" -eq 0 ]
  [ "$output" = "deny 403" ]
}

@test "a Bot credential still passes for its own repository by git and for GraphQL" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "acme", name: "covered" });
    const basic = `Basic ${Buffer.from(`x-access-token:${p}`).toString("base64")}`;
    const git = await b.filterRequest(req("https://github.com/Acme/covered.git/git-upload-pack", basic));
    const graphql = await b.filterRequest(req("https://api.github.com/graphql", `bearer ${p}`));
    console.log(git.action, graphql.action, header(graphql));
  '
  [ "$status" -eq 0 ]
  [ "$output" = "allow allow bearer ghs_bot_covered" ]
}

@test "the owner's credential passes for any repository" {
  run run_policy "${bot_fixture}"'
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "someone", name: "x" });
    const d = await b.filterRequest(req("https://api.github.com/repos/acme/other", `token ${p}`));
    console.log(d.action, header(d));
  '
  [ "$status" -eq 0 ]
  [ "$output" = "allow token gho_owner" ]
}

@test "a Bot token failure in a Bot repository is refused instead of acting as the owner" {
  run run_policy '
    const bot = { account: async () => "acme", mint: async () => { throw new Error("GitHub answered 500"); } };
    const b = withBot(bot);
    const p = b.placeholderFor({ owner: "acme", name: "covered" });
    const d = await b.filterRequest(req("https://api.github.com/repos/acme/covered", `token ${p}`)).catch((e) => ({ action: "deny" }));
    console.log(d.action, header(d));
  '
  [ "$output" = "deny none" ]
}

@test "a Bot token is reused until ten minutes before it expires, then minted again" {
  run run_policy '
    let clock = 0;
    let count = 0;
    const bot = { account: async () => "acme", mint: async () => ({ token: `ghs_${++count}`, expiresAt: clock + 60 * 60e3 }) };
    const b = policy.createBroker({ ownerToken: async () => "gho_owner", bot, now: () => clock });
    const p = b.placeholderFor({ owner: "acme", name: "covered" });
    const call = async () => header(await b.filterRequest(req("https://api.github.com/repos/acme/covered", `token ${p}`)));
    const first = await call();
    clock = 49 * 60e3;
    const beforeMargin = await call();
    clock = 51 * 60e3;
    const afterMargin = await call();
    console.log(first, beforeMargin, afterMargin);
  '
  [ "$output" = "token ghs_1 token ghs_1 token ghs_2" ]
}

# A GitHub App client with a throwaway key and a fake fetch that records
# every request and answers from `answers`, keyed by "<METHOD> <path>".
app_fixture='
  const { generateKeyPairSync, createVerify } = await import("node:crypto");
  const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const key = privateKey.export({ type: "pkcs8", format: "pem" });
  const sent = [];
  const fetch = async (url, init = {}) => {
    const method = init.method ?? "GET";
    sent.push({ method, url: String(url), headers: init.headers, body: init.body && JSON.parse(init.body) });
    const [status, body] = answers[`${method} ${new URL(url).pathname}`] ?? [500, {}];
    return new Response(JSON.stringify(body), { status });
  };
  const app = policy.createAppClient({ appId: "11", installationId: "22", key, fetch });
'

@test "minting a Bot token asks only for the one repository and the agreed permissions" {
  run run_policy '
    const answers = { "POST /app/installations/22/access_tokens": [201, { token: "ghs_x", expires_at: "2030-01-01T00:00:00Z" }] };
    '"${app_fixture}"'
    const minted = await app.mint("tool");
    console.log(minted.token, minted.expiresAt === Date.parse("2030-01-01T00:00:00Z"));
    console.log(JSON.stringify(sent[0].body));
  '
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "ghs_x true" ]
  [ "${lines[1]}" = '{"repositories":["tool"],"permissions":{"contents":"write","pull_requests":"write","issues":"write","statuses":"write","checks":"read","actions":"read","metadata":"read"}}' ]
}

@test "the token request is signed as the App with a short-lived JWT" {
  run run_policy '
    const answers = { "POST /app/installations/22/access_tokens": [201, { token: "ghs_x", expires_at: "2030-01-01T00:00:00Z" }] };
    '"${app_fixture}"'
    await app.mint("tool");
    const jwt = sent[0].headers.authorization.replace(/^Bearer /, "");
    const [h, p, s] = jwt.split(".");
    const valid = createVerify("RSA-SHA256").update(`${h}.${p}`).verify(publicKey, Buffer.from(s, "base64url"));
    const claims = JSON.parse(Buffer.from(p, "base64url").toString());
    console.log(valid, claims.iss, claims.exp - claims.iat <= 600);
  '
  [ "$output" = "true 11 true" ]
}

@test "a repository the installation does not cover mints no Bot token" {
  run run_policy '
    const answers = {
      "POST /app/installations/22/access_tokens": [422, { message: "not accessible to the parent installation" }],
      "GET /app/installations/22": [200, { account: { login: "acme" } }],
      "GET /repos/acme/elsewhere/installation": [404, { message: "Not Found" }],
    };
    '"${app_fixture}"'
    console.log(JSON.stringify(await app.mint("elsewhere")));
  '
  [ "$output" = null ]
}

# GitHub also answers 422 when the App lacks a requested permission. Falling
# back to the owner there would act with more power than the Bot was given.
@test "a 422 for a repository the installation covers is an error, not a fallback" {
  run run_policy '
    const answers = {
      "POST /app/installations/22/access_tokens": [422, { message: "The permissions requested are not granted to this installation." }],
      "GET /app/installations/22": [200, { account: { login: "acme" } }],
      "GET /repos/acme/tool/installation": [200, { id: 22 }],
    };
    '"${app_fixture}"'
    console.log(await app.mint("tool").then((m) => `minted ${JSON.stringify(m)}`, () => "failed"));
  '
  [ "$output" = failed ]
}

@test "any other token failure is an error, not a fallback" {
  run run_policy '
    const answers = { "POST /app/installations/22/access_tokens": [401, { message: "bad credentials" }] };
    '"${app_fixture}"'
    console.log(await app.mint("tool").then(() => "minted", () => "failed"));
  '
  [ "$output" = failed ]
}

@test "the Bot account is the login that owns the installation" {
  run run_policy '
    const answers = { "GET /app/installations/22": [200, { account: { login: "acme" } }] };
    '"${app_fixture}"'
    console.log(await app.account(), await app.account(), sent.length);
  '
  [ "$output" = "acme acme 1" ]
}
