#!/usr/bin/env bash
# Fails unless the execution posture record renders through chezmoi, covers every
# tool with every dimension and the widening rule, and the common instructions
# point to it.
set -euo pipefail

source_dir=${1:-.}
chezmoi_bin=${CHEZMOI:-chezmoi}
record_source="${source_dir}/dot_agents/execution-posture.md"
common_template="${source_dir}/.chezmoitemplates/agents/common.md"
tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

if [[ ! -f "${record_source}" ]]; then
  echo "ERROR: ${record_source} does not exist" >&2
  exit 1
fi

: > "${tmp_dir}/chezmoi.toml"
rendered="${tmp_dir}/execution-posture.md"
"${chezmoi_bin}" --config "${tmp_dir}/chezmoi.toml" --source "${source_dir}" --destination "${tmp_dir}/home" \
  cat "${tmp_dir}/home/.agents/execution-posture.md" > "${rendered}"
if [[ ! -s "${rendered}" ]]; then
  echo "ERROR: the record rendered an empty file" >&2
  exit 1
fi

for tool in "Claude Code" "Codex" "OpenCode"; do
  section=$(awk -v heading="## ${tool}" '
    $0 == heading { in_section = 1; next }
    /^## / { in_section = 0 }
    in_section { print }
  ' "${rendered}")
  if [[ -z "${section}" ]]; then
    echo "ERROR: the record has no section for ${tool}" >&2
    exit 1
  fi
  for dimension in "Write scope" "Approval" "Network" "Without confirmation"; do
    if ! grep -q "^| ${dimension} |" <<<"${section}"; then
      echo "ERROR: the ${tool} section omits ${dimension}" >&2
      exit 1
    fi
  done
done

if ! grep -q '^## Widening$' "${rendered}"; then
  echo "ERROR: the record has no Widening section" >&2
  exit 1
fi

if ! grep -q 'execution-posture\.md' "${common_template}"; then
  echo "ERROR: the common instructions do not point to the record" >&2
  exit 1
fi

echo "execution posture record: OK"
