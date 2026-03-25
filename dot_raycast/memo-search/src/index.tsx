import { List, ActionPanel, Action } from "@raycast/api";
import { useCachedPromise } from "@raycast/utils";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

const MEMO_DIR = path.join(os.homedir(), "ghq/github.com/maro114510/Obsidian/memo");

interface MemoFile {
  name: string;
  title: string;
  path: string;
  mtime: Date;
}

async function listMemoFiles(): Promise<MemoFile[]> {
  const entries = await fs.promises.readdir(MEMO_DIR, { withFileTypes: true });
  const mdFiles = entries.filter((e) => e.isFile() && e.name.endsWith(".md"));

  const files: MemoFile[] = await Promise.all(
    mdFiles.map(async (e) => {
      const filePath = path.join(MEMO_DIR, e.name);
      const stat = await fs.promises.stat(filePath);
      return {
        name: e.name,
        title: e.name.replace(/\.md$/, ""),
        path: filePath,
        mtime: stat.mtime,
      };
    })
  );

  files.sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
  return files;
}

export default function Command() {
  const { data: memoFiles, isLoading } = useCachedPromise(listMemoFiles);

  return (
    <List isLoading={isLoading} filtering={true}>
      {(memoFiles ?? []).map((memo) => (
        <List.Item
          key={memo.path}
          title={memo.title}
          subtitle={memo.mtime.toLocaleString("ja-JP")}
          actions={
            <ActionPanel>
              <Action.Open
                title="CotEditorで開く"
                target={memo.path}
                application="CotEditor"
              />
              <Action.OpenInBrowser
                title="Obsidianで開く"
                url={`obsidian://open?path=${encodeURIComponent(memo.path)}`}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
