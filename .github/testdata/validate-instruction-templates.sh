#!/usr/bin/env bash
set -euo pipefail

source_dir=${1:-.}
common_template="${source_dir}/.chezmoitemplates/agents/common.md"
chezmoi_bin=${CHEZMOI:-chezmoi}
tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

"${chezmoi_bin}" execute-template --source "${source_dir}" -f "${common_template}" > "${tmp_dir}/common.md"

for template in \
  dot_claude/CLAUDE.md.tmpl \
  dot_codex/AGENTS.md.tmpl \
  dot_config/opencode/AGENTS.md.tmpl; do
  output="${tmp_dir}/$(basename "${template}").rendered"
  "${chezmoi_bin}" execute-template --source "${source_dir}" -f "${source_dir}/${template}" > "${output}"
  if [[ ! -s "${output}" ]]; then
    echo "ERROR: ${template} rendered an empty file" >&2
    exit 1
  fi

  python3 - "${tmp_dir}/common.md" "${output}" "${template}" <<'PY'
from pathlib import Path
import sys

common = Path(sys.argv[1]).read_text().rstrip()
rendered = Path(sys.argv[2]).read_text()
if not common or common not in rendered:
    raise SystemExit(f"ERROR: {sys.argv[3]} does not contain the common body")
PY

  echo "${template}: OK"
done
