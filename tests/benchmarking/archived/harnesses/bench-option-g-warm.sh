#!/usr/bin/env bash
set -euo pipefail
# Option G warm: cache hit, source cached bash
source /tmp/yaml-benchmark/option-g/registry.sh
source /tmp/yaml-benchmark/option-g/cached-yaml.sh
load_yaml_cached /tmp/yaml-benchmark/option-g/yaml
