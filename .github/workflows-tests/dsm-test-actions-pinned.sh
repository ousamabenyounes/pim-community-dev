#!/usr/bin/env bash
# Regression guard for issue #20636: every third-party action reference in
# dsm-test.yml must be pinned to a full 40-char commit SHA (mutable @main /
# @vX tags allow silent upstream code swaps — see CVE-2025-30066).
set -euo pipefail

readonly WORKFLOW="$(cd "$(dirname "$0")/.." && pwd)/workflows/dsm-test.yml"
readonly FIRST_PARTY_ORG="actions/"
readonly SHA_LEN=40
readonly SHA_REGEX="^[0-9a-f]{${SHA_LEN}}$"

if [[ ! -f "${WORKFLOW}" ]]; then
  echo "FAIL: workflow not found at ${WORKFLOW}" >&2
  exit 1
fi

mapfile -t refs < <(grep -E '^\s*-?\s*uses:\s*[^[:space:]]+' "${WORKFLOW}" \
  | sed -E 's/^\s*-?\s*uses:\s*([^[:space:]]+).*/\1/')

violations=0
for ref in "${refs[@]}"; do
  action="${ref%@*}"
  pin="${ref#*@}"
  if [[ "${action}" == "${FIRST_PARTY_ORG}"* ]]; then
    continue
  fi
  if [[ ! "${pin}" =~ ${SHA_REGEX} ]]; then
    echo "FAIL: ${action} is pinned to mutable ref '${pin}' (need 40-char SHA)" >&2
    violations=$((violations + 1))
  fi
done

if (( violations > 0 )); then
  echo "FAIL: ${violations} third-party action(s) not SHA-pinned in dsm-test.yml" >&2
  exit 1
fi

echo "OK: all third-party actions in dsm-test.yml are SHA-pinned"
