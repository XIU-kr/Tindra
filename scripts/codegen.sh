#!/usr/bin/env bash
# Regenerate flutter_rust_bridge bindings.
# Usage: scripts/codegen.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    echo "flutter_rust_bridge_codegen not installed."
    echo "Run: cargo install flutter_rust_bridge_codegen --version '^2'"
    exit 1
fi

cd bridge
flutter_rust_bridge_codegen generate
echo "Codegen complete. Generated Dart in apps/shared_ui/lib/src/bridge/"
