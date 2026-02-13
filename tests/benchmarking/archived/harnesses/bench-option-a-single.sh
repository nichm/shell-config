#!/usr/bin/env bash
set -euo pipefail
# Benchmark: Option A (single-call) - ONE yq invocation for all YAML files
source /tmp/yaml-benchmark/option-a/registry.sh
source /tmp/yaml-benchmark/option-a/yaml-loader-single-call.sh
load_all_yaml_rules_single_call /tmp/yaml-benchmark/option-a/yaml
