#!/usr/bin/env bash
set -euo pipefail
# Benchmark: Option D - Declarative bash helpers (_rule, _alts, _verify, _ai)
source /tmp/yaml-benchmark/option-d/registry.sh
source /tmp/yaml-benchmark/option-d/rules/settings.sh
source /tmp/yaml-benchmark/option-d/rule-helpers.sh

for f in /tmp/yaml-benchmark/option-d/rules/*.sh; do
    [[ "$(basename "$f")" == "settings.sh" ]] && continue
    source "$f"
done
