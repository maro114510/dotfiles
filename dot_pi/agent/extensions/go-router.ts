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
    route() {
      throw new Error("go-router: routing is not implemented");
    },
  });
}
