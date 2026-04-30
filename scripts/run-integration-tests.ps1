# Run all Tindra desktop integration tests.
#
# Each test file is launched in its own `flutter test` process: running the
# whole directory at once leaves the Windows desktop device locked between
# tests ("Unable to start the app on the device") because the previous
# tindra_desktop.exe hasn't fully released yet.
#
# Pre-requisites (one-time):
#   - Local OpenSSH Server running on localhost:22
#   - %USERPROFILE%\.ssh\id_ed25519 registered as an authorized key
#   - Flutter on PATH, Rust on PATH, Visual Studio 2022 Build Tools installed
#
# Usage:
#   pwsh scripts/run-integration-tests.ps1
#   pwsh scripts/run-integration-tests.ps1 smoke_test       # single file

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot/.."

# Pull in flutter and cargo from the canonical install dirs in case the
# invoking shell didn't inherit the user PATH.
foreach ($p in @("C:\dev\flutter\bin", "$env:USERPROFILE\.cargo\bin")) {
    if ((Test-Path $p) -and ($env:Path -notlike "*$p*")) {
        $env:Path = "$p;$env:Path"
    }
}

$desktop = "apps/desktop"
if (-not (Test-Path "$desktop/integration_test")) {
    Write-Host "ERROR: $desktop/integration_test not found." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: flutter not on PATH (looked for C:\dev\flutter\bin)." -ForegroundColor Red
    exit 1
}

# Sanity-check that the local SSH server is up — the keystroke and tab tests
# both connect to localhost:22.
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshd -and $sshd.Status -ne "Running") {
    Write-Host "WARNING: sshd service is $($sshd.Status). Keystroke / tab tests will fail." -ForegroundColor Yellow
}

$filter = if ($args.Length -gt 0) { $args[0] } else { $null }

$tests = Get-ChildItem -Path "$desktop/integration_test" -Filter "*_test.dart" |
    Where-Object { -not $filter -or $_.BaseName -like "*$filter*" } |
    Sort-Object Name

if ($tests.Count -eq 0) {
    Write-Host "No matching tests found." -ForegroundColor Yellow
    exit 1
}

Push-Location $desktop
try {
    $results = @()
    foreach ($test in $tests) {
        Write-Host ""
        Write-Host "==> $($test.Name)" -ForegroundColor Cyan
        $relative = "integration_test/$($test.Name)"
        $start = Get-Date
        & flutter test $relative -d windows
        $exit = $LASTEXITCODE
        $duration = (Get-Date) - $start
        $results += [pscustomobject]@{
            Test     = $test.Name
            Status   = if ($exit -eq 0) { "PASS" } else { "FAIL" }
            Duration = "{0:0.0}s" -f $duration.TotalSeconds
            Exit     = $exit
        }
        # Brief pause to let the previous process release the device.
        Start-Sleep -Seconds 1
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$failed = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
if ($failed -gt 0) {
    Write-Host "$failed test(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "All tests passed." -ForegroundColor Green
