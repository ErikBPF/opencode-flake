#!/usr/bin/env bash
set -euo pipefail

workflow="$(git rev-parse --show-toplevel)/.github/workflows/check.yml"
grep -Fq 'needs: [check, package-build, flakehub-publish, flakehub-verify]' "$workflow"
grep -Fq "contains(needs.*.result, 'failure')" "$workflow"
