#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Summarize Article in ChatGPT
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🧠
# @raycast.packageName Reading

# Documentation:
# @raycast.description Open a new ChatGPT chat with a summary prompt for the active Chrome tab
# @raycast.author maro114510
# @raycast.authorURL https://raycast.com/maro114510

set -euo pipefail

BROWSER="Google Chrome"

front="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')"
if [ "${front}" != "${BROWSER}" ]; then
    echo "Chrome is not frontmost"
    exit 1
fi

url="$(osascript -e "tell application \"${BROWSER}\" to get URL of active tab of front window")"

# Skip non-HTTP(S) pages, ChatGPT itself, search results, and local pages
case "${url}" in
    https://chatgpt.com/* | https://chat.openai.com/* | https://www.google.com/search* | http://localhost* | http://127.0.0.1*)
        echo "Unsupported page"
        exit 1
        ;;
    http://* | https://*) ;;
    *)
        echo "Not an HTTP(S) page"
        exit 1
        ;;
esac

prompt="$(cat <<EOF
目的
技術記事を、判断に使える内部メモと、はてなブックマークでそのまま公開できる要約コメント案に整理する。

入力
URL: ${url}

やること
1. 記事本文を実際に開いて読む。開けない、または本文を読めない場合は、記事を取得できませんでした とだけ答えて終了する。URLや検索結果から内容を推測しない。
2. 記事の核心を一文で言い切る。核心とは、記事が最も強く主張していること、または読者の思い込みを覆す点である。
3. 次の内部用と公開用を一度に作る。

出力
内部用：全体400字以内
結論：2文以内。1文目で核心を言い切る。
根拠：結論を支える記事内の事実を最大3点。数値・手法名・条件を残す。
実務示唆：最大2点
注意点：不確実性・前提・偏りを1点

公開用：はてブコメント案3つ、各100字以内
意外な発見：
技術的知見：
実務への示唆：

はてブ案の書き方
- 記事の要約に徹する。感想・評価・呼びかけ・自分の意見は書かず、記事の主張として書く。
- 2文で書く。1文目で核心を言い切り、2文目で記事が示す解決策・根拠・具体例を書く。
- 1文目は次のどちらかの型を優先する。型に合わない記事では、記事中で最も意外な数値や結果を1文目に置く。
  型1 対比: Aが進む一方、Bがボトルネックになる。
  型2 本質: Xの本質は、AではなくBにある。
- 記事中の固有の概念名・ツール名・数値を1つ以上入れる。
- 常体で言い切る。
- 3案は観点に沿って内容を変え、書き出しも互いに変える。
- 文体見本を次に示す。文体だけを参考にし、内容は流用しない。
  AIで制作速度が上がる一方、組織の判断やレビューがボトルネックになる。判断基準をデザインハーネスとして仕様化し、チームとAIで共有することを提案する。
  定期実行ジョブの本質は、スケジュール設定ではなく、実行状態・失敗・復旧の管理にある。開発者の意図と運用上の複雑さを分離するプラットフォームが重要。

制約
- 記事にない事実を補わない。
- 内部用では記事の主張と推論を区別し、推論は文頭に 推論： と付ける。公開用には推論を入れない。
- はてブ案は各90字から100字に収め、100字を超えない。短すぎる場合は2文目に記事中の具体例や条件を足す。
- 試した・使った・実感したなど、本人の実体験として書かない。
- 出力では丸括弧・角括弧・鉤括弧・二重鉤括弧・隅付き括弧など、あらゆる括弧を使わない。
- 見出しと本文以外の前置きや締めの言葉を書かない。

完了条件
内部用の結論だけで記事の核心が分かり、はてブ案は記事に忠実な要約のまま、1文目で読む理由が伝わること。
EOF
)"

# Also copy the prompt in case ?q= stops prefilling
printf '%s' "${prompt}" | pbcopy

# Percent-encode the prompt byte by byte
query="$(printf '%s' "${prompt}" | perl -pe 's/([^A-Za-z0-9\-._~])/sprintf("%%%02X", ord($1))/ge')"

# Open ChatGPT in a background tab and keep the article tab in front
osascript - "https://chatgpt.com/?q=${query}&hints=search" >/dev/null <<'APPLESCRIPT'
on run argv
    tell application "Google Chrome"
        set w to front window
        set articleIndex to active tab index of w
        make new tab at end of tabs of w with properties {URL:item 1 of argv}
        set active tab index of w to articleIndex
    end tell
end run
APPLESCRIPT
