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
      const sticky = request.failed ?? request.previous;
      if (request.reason !== "user" && sticky) {
        return { model: sticky.model, thinkingLevel: sticky.thinkingLevel ?? request.thinkingLevel };
      }
      const [provider, id] =
        request.thinkingLevel === "high"
          ? ["claude-code", "claude-sonnet-5-5"]
          : ["opencode-go", "deepseek-v4.1-flash"];
      const model = ctx.modelRegistry.find(provider, id);
      // Falling back to the other route would bill another provider without the user choosing it.
      if (!model) throw new Error(`go-router: ${provider}/${id} is not in the model catalog`);
      return { model, thinkingLevel: request.thinkingLevel };
    },
  });
}
