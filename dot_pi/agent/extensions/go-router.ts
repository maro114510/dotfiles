import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerVirtualModel({
    provider: "local",
    id: "go-auto",
    name: "Go Auto",
    thinkingLevels: ["low", "medium", "high"],
    // claude-sonnet-5-5 and deepseek-v4.1-flash both take 1M tokens; Sonnet's 128K output is the smaller limit.
    contextWindow: 1_000_000,
    maxTokens: 128_000,
    route(request, ctx) {
      const [provider, id] =
        request.thinkingLevel === "high"
          ? ["claude-code", "claude-sonnet-5-5"]
          : ["opencode-go", "deepseek-v4.1-flash"];
      return { model: ctx.modelRegistry.find(provider, id)!, thinkingLevel: request.thinkingLevel };
    },
  });
}
