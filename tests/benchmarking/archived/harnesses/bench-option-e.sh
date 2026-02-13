#!/usr/bin/env bash
set -euo pipefail
# Benchmark: Option E - Compact bash (_R, _A, _V, _W)
source /tmp/yaml-benchmark/option-e/registry.sh
source /tmp/yaml-benchmark/option-e/rules/settings.sh
source /tmp/yaml-benchmark/option-e/rule-compact.sh

for f in /tmp/yaml-benchmark/option-e/rules/*.sh; do
    [[ "$(basename "$f")" == "settings.sh" ]] && continue
    source "$f"
done
