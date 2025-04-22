#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title memo
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔫
# @raycast.packageName memo
# @raycast.argument1 { "type": "text", "placeholder": "Suffix", "optional": true }

# Documentation:
# @raycast.description memo
# @raycast.author maro114510
# @raycast.authorURL https://raycast.com/maro114510

DATE_FILE="$(date '+%Y-%m-%d')"

# 引数が指定されていたら、ファイル名に追加
if [ -n "$1" ]; then
    DATE_FILE="${DATE_FILE}-$1"
fi

# 最終的なファイル名に拡張子を追加
DATE_FILE="${DATE_FILE}.md"
MEMO_DIR="${HOME}/memo"

# メモディレクトリが存在しない場合は作成
mkdir -p "${MEMO_DIR}"

# ファイルが存在しない場合は作成
if [ ! -f "${MEMO_DIR}/${DATE_FILE}" ]; then
    touch "${MEMO_DIR}/${DATE_FILE}"
fi

# CotEditorでファイルを開く
open -a CotEditor.app "${MEMO_DIR}/${DATE_FILE}"
