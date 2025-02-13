#!/bin/bash

set -eu

# Disable the startup chime
sudo nvram StartupMute=%01

# Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true  # 拡張子まで表示する設定
defaults write com.apple.Finder AppleShowAllFiles -bool true     # 隠しファイルを表示する設定
defaults write com.apple.finder ShowPathbar -bool true           # Finderウィンドウ下部のパスバーを表示する設定
defaults write com.apple.LaunchServices LSQuarantine -bool false # 未確認ファイルを開く際の警告を無効化する設定

# Mouse
defaults write com.apple.mouse.doubleClickThreshold -float 0.5 # ダブルクリックの反応速度（間隔）を設定する
defaults write com.apple.mouse.scaling -int 8                  # マウスカーソルの移動速度（加速度）を設定する
defaults write com.apple.scrollwheel.scaling -int 4            # マウスホイールによるスクロール速度を設定する
defaults write com.apple.springing.delay -float 0              # スプリングローディングの起動遅延を無効化して高速化する

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 3                      # キーリピートの速度（押し続けたときの反復間隔）を高速に設定する
defaults write NSGlobalDomain InitialKeyRepeat -int 20              # キーリピート開始までの待機時間を短く設定する
