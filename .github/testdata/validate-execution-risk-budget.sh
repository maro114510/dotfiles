#!/usr/bin/env bash
set -euo pipefail

source_dir=${1:-.}
record="${source_dir}/dot_config/agents/execution-risk-budget.md.tmpl"
common="${source_dir}/.chezmoitemplates/agents/common.md"
chezmoi_bin=${CHEZMOI:-chezmoi}
tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

if [[ ! -f "${record}" ]]; then
  echo "ERROR: ${record} is missing" >&2
  exit 1
fi

"${chezmoi_bin}" execute-template --source "${source_dir}" -f "${record}" > "${tmp_dir}/record.md"
if [[ ! -s "${tmp_dir}/record.md" ]]; then
  echo "ERROR: the execution risk budget rendered an empty file" >&2
  exit 1
fi

for tool in "Codex" "Claude Code" "OpenCode"; do
  if ! grep -F -x -q "## ${tool}" "${tmp_dir}/record.md"; then
    echo "ERROR: the execution risk budget has no '## ${tool}' section" >&2
    exit 1
  fi
done

# shellcheck disable=SC2088 # the record is referenced by its literal ~ path
if ! grep -F -q '~/.config/agents/execution-risk-budget.md' "${common}"; then
  echo "ERROR: the common instruction body does not reference the execution risk budget" >&2
  exit 1
fi

echo "execution risk budget: OK"
