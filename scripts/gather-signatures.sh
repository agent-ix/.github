#!/usr/bin/env bash
# Consolidated CLA signature export across the org.
#
# Signatures are stored per-repo (signatures/version1/legal-names.json in
# each repo that carries the CLA Assistant Lite caller workflow) rather than
# centrally, per the PLAT-862 follow-up ruling: "PAT and all that comes with
# it isn't worth what we save from having it per repo." This script is the
# one thing that makes that acceptable -- a single `gh`-based walk that
# produces one consolidated list for IP diligence, on demand, with no
# standing credential or scheduled job required.
#
# Usage:
#   scripts/gather-signatures.sh [org] > all-signatures.json
#
# Requires: gh (authenticated), jq. No other tooling.
set -euo pipefail

org="${1:-agent-ix}"

repos="$(gh repo list "$org" --limit 1000 --no-archived --json name --jq '.[].name')"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

count=0
for repo in $repos; do
  out="$tmp/$repo.json"
  if gh api "repos/$org/$repo/contents/signatures/version1/legal-names.json" \
       --jq '.content' 2>/dev/null | base64 -d > "$out" 2>/dev/null; then
    if [ -s "$out" ] && jq -e 'type == "array"' "$out" >/dev/null 2>&1; then
      count=$((count + 1))
    else
      rm -f "$out"
    fi
  else
    rm -f "$out"
  fi
done

>&2 echo "Found signature records in $count repo(s) under $org"

jq -s 'add // []' "$tmp"/*.json 2>/dev/null || echo '[]'
