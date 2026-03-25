## 作業原則

変更は常に最小限にとどめ、後方互換性を維持して実装する

## ワークツリー運用

- 作業は原則として [git-worktree-runner](https://github.com/coderabbitai/git-worktree-runner) を使いワークツリー上で実施する
- mainブランチへの直接変更は禁止。必ずワークツリー上で作業し、レビュー後にマージする
- ワークツリーの作成・管理は git-worktree-runner に委譲し、手動操作は避ける
- `EnterWorktree` ツールは使用しない

## このファイルの適用範囲

- このファイルはすべてのプロジェクトに適用されるため、汎用ルールのみを記載する
- プロジェクト固有のルールは各プロジェクトの `CLAUDE.md` または `.claude/rules/` に記載する
- プロジェクト側のCLAUDE.mdと競合するルールは非決定的に解決されるため、重複・矛盾を避ける

## Git操作の安全規則

### commit / amend / push の前に必ず確認する
- `git branch --show-current` でブランチを確認する
- `git status` でステージング状態を確認する
- 期待するブランチと一致しない場合は操作を中断してユーザーに報告する

### ファイルの復元・借用
- `git checkout <remote>/<branch> -- <file>` は使用禁止
  （ブランチを変えずにファイルだけ置き換えるため、誤ったブランチへのコミットを誘発する）
- 別ブランチのファイル内容が必要な場合は `git show <branch>:<path>` で内容を確認し、Read/Editツールで編集する

### コードレビュー・確認フェーズ
- 変更内容の確認は `git diff origin/main...<branch>` でリモートブランチを対象にする
- ローカルとリモートの一致は `git diff origin/<branch>` で確認する
- GitHub Actions の差分に `concurrency:` が含まれる場合、同一 `group:` 値を持つ他のジョブを検索して競合がないか確認する
