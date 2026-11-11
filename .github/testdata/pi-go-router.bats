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
