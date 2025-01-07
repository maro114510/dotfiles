#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title memo
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔫
# @raycast.packageName memo

# Documentation:
# @raycast.description memo
# @raycast.author maro114510
# @raycast.authorURL https://raycast.com/maro114510

DATE_FILE="$(date '+%Y-%m-%d').md"
MEMO_DIR="$HOME/memo"

# メモディレクトリが存在しない場合は作成
mkdir -p "$MEMO_DIR"

# ファイルが存在しない場合は作成
if [ ! -f "$MEMO_DIR/$DATE_FILE" ]; then
    touch "$MEMO_DIR/$DATE_FILE"
fi

# CotEditorでファイルを開く
open -a CotEditor.app "$MEMO_DIR/$DATE_FILE"