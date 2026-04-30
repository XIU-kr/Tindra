# Regenerate flutter_rust_bridge bindings (Windows).
# Usage: pwsh scripts/codegen.ps1

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot/.."

if (-not (Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
    Write-Host "flutter_rust_bridge_codegen not installed."
    Write-Host "Run: cargo install flutter_rust_bridge_codegen --version '^2'"
    exit 1
}

Set-Location bridge
flutter_rust_bridge_codegen generate
Write-Host "Codegen complete. Generated Dart in apps/shared_ui/lib/src/bridge/"
