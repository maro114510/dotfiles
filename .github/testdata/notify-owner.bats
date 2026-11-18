#!/usr/bin/env bats
#
# Verifies that the chezmoi-managed git config hands orchestrate-epic's
# `oe wait` a working notification command, and that the command it names
# notifies through Herdr when Herdr is installed and through the macOS
# notification center when it is not.
#
# Herdr is not in the Brewfile, so a machine rebuilt from this repository can
# lack it. That is why skills.notify names notify-owner rather than
# `herdr notification show` directly.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/notify-owner.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  notify_owner="${repo_root}/dot_local/bin/executable_notify-owner"
  sandbox="$(mktemp -d)"

  HOME="${sandbox}" "${chezmoi_bin}" \
    --config "${repo_root}/.github/testdata/chezmoi-full.toml" \
    --source "${repo_root}" \
    execute-template < "${repo_root}/dot_config/git/config.tmpl" \
    > "${sandbox}/gitconfig"
}

teardown() {
  rm -rf "${sandbox}"
}

# Writes an executable stub at $1 that appends its arguments to $2 and exits $3.
write_stub() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<STUB
#!/bin/sh
printf '%s\\n' "\$@" >> "$2"
exit $3
STUB
  chmod +x "$1"
}

@test "the rendered config names the notification command oe wait runs" {
  run git config --file "${sandbox}/gitconfig" --get skills.notify
  [ "$status" -eq 0 ]
  [ "$output" = 'notify-owner "$1" "$2"' ]
}

@test "the rendered config is the only owner of the skills keys" {
  run git config --file "${sandbox}/gitconfig" --get skills.herdr
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run git config --file "${sandbox}/gitconfig" --get skills.lang
  [ "$status" -eq 0 ]
  [ "$output" = "en" ]
}

@test "notify-owner shows the message through herdr with the link as its body" {
  stub_dir="${sandbox}/bin"
  write_stub "${stub_dir}/herdr" "${sandbox}/herdr-args" 0
  message="Issue #220 in maro114510/dotfiles waits for your merge"
  link="https://github.com/maro114510/dotfiles/issues/220"

  PATH="${stub_dir}:/usr/bin:/bin" "${notify_owner}" "${message}" "${link}"

  run cat "${sandbox}/herdr-args"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "notification" ]
  [ "${lines[1]}" = "show" ]
  [ "${lines[2]}" = "${message}" ]
  [ "${lines[3]}" = "--body" ]
  [ "${lines[4]}" = "${link}" ]
}

@test "notify-owner falls back to osascript when herdr is not installed" {
  stub_dir="${sandbox}/bin"
  write_stub "${stub_dir}/osascript" "${sandbox}/osascript-args" 0
  message="Issue #220 in maro114510/dotfiles waits for your merge"
  link="https://github.com/maro114510/dotfiles/issues/220"

  PATH="${stub_dir}:/usr/bin:/bin" "${notify_owner}" "${message}" "${link}"

  run cat "${sandbox}/osascript-args"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "-e" ]
  [ "${lines[1]}" = "on run argv" ]
  [ "${lines[${#lines[@]} - 3]}" = "--" ]
  [ "${lines[${#lines[@]} - 2]}" = "${message}" ]
  [ "${lines[${#lines[@]} - 1]}" = "${link}" ]
}

@test "notify-owner falls back to osascript when herdr cannot show a notification" {
  stub_dir="${sandbox}/bin"
  write_stub "${stub_dir}/herdr" "${sandbox}/herdr-args" 1
  write_stub "${stub_dir}/osascript" "${sandbox}/osascript-args" 0
  message="Issue #220 in maro114510/dotfiles waits for your merge"
  link="https://github.com/maro114510/dotfiles/issues/220"

  PATH="${stub_dir}:/usr/bin:/bin" "${notify_owner}" "${message}" "${link}"

  run cat "${sandbox}/osascript-args"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]} - 2]}" = "${message}" ]
  [ "${lines[${#lines[@]} - 1]}" = "${link}" ]
}
