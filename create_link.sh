#!/bin/bash

# ソースディレクトリとターゲットディレクトリのパスを指定
source_dir="/Users/nohira/.config/nvim"
target_dir="/Users/nohira/ghq/github.com/maro114510/setting_list/mac_mini/nvim"

# ソースディレクトリ内のファイルを再帰的に処理
find "$source_dir" -type f -exec sh -c '
    for file do
        # ターゲットディレクトリ内にハードリンクを作成
        target_file="$target_dir/$(basename "$file")"
        ln "$file" "$target_file"
    done
' sh {} +

