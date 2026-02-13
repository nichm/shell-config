#!/usr/bin/env bash
set -euo pipefail
# Benchmark: Option B - Original bash rules (from main)
# This sources registry, settings, then all rule files and registers them

source /tmp/yaml-benchmark/option-b/registry.sh

# Source settings
source /tmp/yaml-benchmark/option-b/rules/settings.sh

# Source each rule file and call register function
for f in /tmp/yaml-benchmark/option-b/rules/*.sh; do
    [[ "$(basename "$f")" == "settings.sh" ]] && continue
    source "$f"
    if type _command_safety_register_rules &>/dev/null; then
        _command_safety_register_rules
        unset -f _command_safety_register_rules 2>/dev/null || true
    fi
done
