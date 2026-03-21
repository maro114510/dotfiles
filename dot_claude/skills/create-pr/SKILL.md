---
name: create-pr
description: >
  Pull Request を作成するスキル。ブランチの差分とコミット履歴を分析し、変更理由・影響範囲・
  改善点・懸念事項を含む高品質な PR description を生成して `gh pr create` で作成する。
  /create-pr で呼び出す。引数にはベースブランチやドラフト指定などを渡せる。
  PR を作りたい、プルリクエストを出したい、レビューに出したい、といった依頼でも使うこと。
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[draft] [base <branch>]"
---

# create-pr

ブランチの変更を分析し、レビュアーにとって価値ある PR を GitHub に作成する。

## 引数

`$ARGUMENTS` を解析する:

- 引数なし → ベースブランチ自動検出、通常PR
- `draft` → ドラフト PR
- `base <branch>` → ベースブランチ指定
- 組み合わせ可（例: `draft base develop`）

## 1. コンテキスト収集

以下を並列で実行する:

```bash
git branch --show-current
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "no upstream"
git remote show origin | grep 'HEAD branch'
git status --short
```

ベースブランチ確定後:

```bash
git log --oneline <base>..HEAD
git diff --stat <base>...HEAD
git diff <base>...HEAD
```

### 中断条件

以下のいずれかに該当したらユーザーに報告して停止する。メッセージはリポジトリの言語慣習に合わせる:

- 現在のブランチがベースブランチ自体（PR を作れない）→ ブランチ作成を提案
- コミットが 0 件（差分なし）→ コミット忘れがないか確認
- 未コミット変更がある → コミット忘れの可能性を確認（ユーザーの判断を仰ぐ）

## 2. 変更の分析

差分とコミット履歴（**最新コミットだけでなく全コミット**）から読み取る:

- **種類**: feat / fix / refactor / docs / chore / deps / perf
- **動機**: なぜこの変更が必要だったか（コミットメッセージ・コード変更・ブランチ名から推論）
- **影響範囲**: 変更されたモジュール・ページ・APIがアプリケーションのどこに波及するか
- **改善点**: 何が良くなるか
- **リスク**: 破壊的変更、エッジケース、パフォーマンス影響、将来の技術的負債
- **関連 issue**: ブランチ名・コミットメッセージから `#NNN` を抽出

差分が大きい場合（20ファイル超 or 1000行超）は論理グループに分けて整理する。

## 3. PR テンプレートの検出

以下の優先順で検索し、**見つかればその形式に必ず従う**（これはスキルの中核機能であり、テンプレートの無視は許容しない）:

1. `.github/PULL_REQUEST_TEMPLATE.md`
2. `.github/pull_request_template.md`
3. `docs/pull_request_template.md`
4. `PULL_REQUEST_TEMPLATE.md`

テンプレートが存在する場合:
- テンプレートの全セクションを埋める。各セクションのコメント指示があればそれに従う
- テンプレートにないが価値ある情報（懸念事項、将来の課題）は末尾に追加セクションとして付与
- チェックリストは変更内容に照らして適切にチェック/アンチェック

テンプレートがない場合はステップ 4 のデフォルト構造を使う。

## 4. PR description の生成

### 言語の決定

リポジトリの言語慣習を以下の順で判定し、PR description とユーザーへの全メッセージに適用する:
1. 既存 PR の description 言語（`gh pr list --limit 5` で確認）
2. コミットメッセージの言語
3. 判断つかなければ英語

### デフォルト構造（テンプレートがない場合）

```markdown
## Summary

<!-- 何を・なぜ変えたか。1-3文。diff の復唱ではなく変更の意図を書く -->

## Changes

<!-- 変更内容を箇条書き。大きな変更は論理グループに分ける -->

### [グループ名]
- 変更の意味を伝える説明（コードレベルの詳細ではなく）

## Impact

<!-- 影響を受けるページ・機能・API。破壊的変更があれば明示 -->

## Concerns

<!-- レビュアーに注目してほしい点、既知リスク、トレードオフ、代替案を検討した経緯 -->

## Future Considerations

<!-- この PR では対応しないが将来検討すべき事項。何を・なぜ・どう改善するか具体的に -->

## Test Plan

<!-- テスト方法と確認結果。UIなら before/after スクリーンショットも検討 -->
```

### 記述の原則

レビュアーは diff を読める。description の価値は diff からは読み取れない「意図」と「判断」を伝えること。

- **Summary**: 「〜を追加」ではなく「〜の問題を解決するために〜を追加」。問題 → 原因 → 解決策の流れで書く
- **Changes**: diff の復唱ではなく変更の"意味"を伝える。レビュアーが diff を読む前に全体像を掴める粒度で
- **Concerns**: 正直に書く。自信がない部分、代替案を捨てた理由、レビュアーが重点的に見るべき箇所。リスクやトレードオフがある変更では特に重要 — このセクションがないと、レビュアーは何に注意すべきか分からない
- **issue リンク**: `Closes #123`（自動クローズ）や `Related: #456` で紐付ける

### Concerns / Future Considerations が空の場合

懸念や将来課題が本当にない場合はセクションごと省略してよい。ただし、パフォーマンスに影響する変更、デフォルト値の変更、既存動作の変更がある場合は必ず Concerns に記載する。

## 5. PR タイトル

- **Conventional Commits 形式**: `feat:`, `fix:`, `refactor:` 等。スコープがあれば `fix(location):` のように付与
- **70文字以内**
- **命令形**: "add" not "added"
- **具体的に**: "fix: resolve crash" ではなく "fix(auth): handle expired JWT on refresh"
- リポジトリに既存 PR があればそのタイトル慣習を確認して合わせる

## 6. push と PR 作成

```bash
# push（upstream 未設定なら -u で設定）
git push -u origin <current-branch>

# PR 作成
gh pr create \
  --title "<title>" \
  --body "$(cat <<'EOF'
<description>
EOF
)" \
  [--draft] \
  [--base <base-branch>]
```

作成後、PR の URL を表示し `gh pr view --web` でブラウザを開く。
