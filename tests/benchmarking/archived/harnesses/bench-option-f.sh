#!/usr/bin/env bash
set -euo pipefail
source /tmp/yaml-benchmark/option-f/registry.sh
source /tmp/yaml-benchmark/option-f/direct-register.sh
for f in /tmp/yaml-benchmark/option-f/rules/*.sh; do
    [[ "$(basename "$f")" == "settings.sh" ]] && continue
    source "$f"
done
