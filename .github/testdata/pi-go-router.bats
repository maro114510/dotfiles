#!/usr/bin/env bats
#
# Verifies the go-router extension's local/go-auto virtual model: what it
# registers, and which physical model and thinking level its router picks for
# each request.
#
# Each test loads the extension with a stand-in for Pi's extension API and a
# model catalog that holds only the models the test names, then prints the
# registered definition or one routing decision as JSON. Node strips the
# extension's type annotations itself, so no TypeScript toolchain is needed.
#
# Usage: bats .github/testdata/pi-go-router.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  extension="${repo_root}/dot_pi/agent/extensions/go-router.ts"
}

# Prints the virtual model definitions the extension registers, without route.
registered() {
  node --input-type=module -e '
    const { default: register } = await import(process.argv[1]);
    const models = [];
    register({ registerVirtualModel: (definition) => models.push(definition) });
    console.log(JSON.stringify(models.map(({ route, ...rest }) => rest)));
  ' "${extension}"
}

# Routes one request and prints the chosen "provider/id" and thinking level.
# $1 is the request as JSON, where each model is written as "provider/id";
# $2 is the catalog, a JSON list of "provider/id".
route() {
  node --input-type=module -e '
    const { default: register } = await import(process.argv[1]);
    const request = JSON.parse(process.argv[2]);
    const catalog = JSON.parse(process.argv[3]);
    const model = (ref) => {
      const [provider, id] = ref.split("/");
      return { provider, id };
    };
    for (const key of ["previous", "failed"]) {
      if (request[key]) request[key].model = model(request[key].model);
    }
    const models = [];
    register({ registerVirtualModel: (definition) => models.push(definition) });
    const ctx = {
      modelRegistry: {
        find: (provider, id) => (catalog.includes(`${provider}/${id}`) ? model(`${provider}/${id}`) : undefined),
      },
    };
    try {
      const result = models[0].route({ messages: [], ...request }, ctx);
      console.log(`${result.model.provider}/${result.model.id} ${result.thinkingLevel}`);
    } catch (error) {
      console.log(`error: ${error.message}`);
    }
  ' "${extension}" "$1" "$2"
}

@test "the extension registers local/go-auto offering low, medium, and high with the smaller limits of its routes" {
  run registered
  [ "$status" -eq 0 ]
  [ "$(jq -S -c . <<<"$output")" = '[{"contextWindow":1000000,"id":"go-auto","maxTokens":128000,"name":"Go Auto","provider":"local","thinkingLevels":["low","medium","high"]}]' ]
}

both_routes='["claude-code/claude-sonnet-5-5","opencode-go/deepseek-v4.1-flash"]'

@test "a user request at high goes to claude-sonnet-5-5 at high" {
  run route '{"reason":"user","thinkingLevel":"high"}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code/claude-sonnet-5-5 high" ]
}

@test "a user request at medium goes to deepseek-v4.1-flash at medium" {
  run route '{"reason":"user","thinkingLevel":"medium"}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "opencode-go/deepseek-v4.1-flash medium" ]
}

@test "a user request at low goes to deepseek-v4.1-flash at low" {
  run route '{"reason":"user","thinkingLevel":"low"}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "opencode-go/deepseek-v4.1-flash low" ]
}

@test "a user request at high after a flash turn leaves flash for claude-sonnet-5-5" {
  run route '{"reason":"user","thinkingLevel":"high","previous":{"model":"opencode-go/deepseek-v4.1-flash","thinkingLevel":"low"}}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code/claude-sonnet-5-5 high" ]
}

@test "a continuation stays on the model and level of the previous response, even after the selection moves to high" {
  run route '{"reason":"continuation","thinkingLevel":"high","previous":{"model":"opencode-go/deepseek-v4.1-flash","thinkingLevel":"low"}}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "opencode-go/deepseek-v4.1-flash low" ]
}

@test "a retry stays on the model and level of the failed request, not the previous response" {
  run route '{"reason":"retry","thinkingLevel":"low","previous":{"model":"opencode-go/deepseek-v4.1-flash","thinkingLevel":"low"},"failed":{"model":"claude-code/claude-sonnet-5-5","thinkingLevel":"high"}}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code/claude-sonnet-5-5 high" ]
}

@test "a retry after routing itself failed stays on the previous response's model" {
  run route '{"reason":"retry","thinkingLevel":"low","previous":{"model":"claude-code/claude-sonnet-5-5","thinkingLevel":"high"}}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code/claude-sonnet-5-5 high" ]
}

@test "a direct request such as a compaction summary stays on the previous response's model" {
  run route '{"reason":"direct","thinkingLevel":"high","previous":{"model":"opencode-go/deepseek-v4.1-flash","thinkingLevel":"medium"}}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "opencode-go/deepseek-v4.1-flash medium" ]
}

@test "a continuation with no previous response is routed by thinking level" {
  run route '{"reason":"continuation","thinkingLevel":"high"}' "${both_routes}"
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code/claude-sonnet-5-5 high" ]
}
