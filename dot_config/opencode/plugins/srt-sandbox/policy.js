// Pure policy of the srt sandbox plugin: what a sandboxed command may read and write, and which GitHub
// credential replaces the placeholder it holds. index.js wires this into OpenCode and srt.

export function repoFromRemote(url) {}

export function createBroker(options) {
  return {
    placeholderFor(repo) {},
    async filterRequest(request) {},
  }
}
