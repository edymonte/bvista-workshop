#!/usr/bin/env bash
# .github/hooks/scripts/prod-guard.sh
#
# PreToolUse hook — Farmácia Boa Vista · bvista-dev/pdv-api
#
# Reads a JSON payload from stdin, extracts the tool name and target path,
# and denies any attempt to delete files under /prod/ without a PR.
#
# Expected stdin format (Copilot hook contract):
# {
#   "tool": "<tool_name>",
#   "input": {
#     "path": "<file_path>",
#     ...
#   }
# }
#
# Exit codes:
#   0 — decision emitted to stdout; hook executed successfully
#   1 — unexpected error (missing dependency, malformed input)

set -euo pipefail

# ── Dependency check ────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  # Fail open: if jq is unavailable, approve and warn via stderr so the
  # operator can install jq without blocking developers.
  >&2 echo "[prod-guard] WARNING: jq not found — hook running in pass-through mode. Install jq to enforce prod protections."
  printf '{"decision":"approve"}'
  exit 0
fi

# ── Read stdin ───────────────────────────────────────────────────────────────
input="$(cat)"

# ── Extract fields ───────────────────────────────────────────────────────────
tool="$(printf '%s' "$input" | jq -r '.tool // ""')"
path="$(printf '%s' "$input" | jq -r '.input.path // ""')"

# ── Guard logic ───────────────────────────────────────────────────────────────
if [[ "$tool" == "delete_file" && "$path" == *"/prod/"* ]]; then
  printf '%s' "$(jq -n \
    --arg msg "🚫 Deleção bloqueada: '$path' está sob /prod/. Alterações em ambiente de produção exigem um Pull Request aprovado por pelo menos um Tech Lead. Abra um PR na branch adequada e obtenha aprovação antes de prosseguir." \
    '{"decision":"deny","message":$msg}')"
  exit 0
fi

# ── Default: approve ─────────────────────────────────────────────────────────
printf '{"decision":"approve"}'
exit 0
