<#
.SYNOPSIS
  跨平台测试入口的 PowerShell 包装器。需要 Python 3 和 Godot >= 4.5。
.EXAMPLE
  pwsh tools/run_tests.ps1 -Only combat
#>
param([string]$Only = "")
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_tests.py'
$runnerArgs = @($runner)
if ($Only) { $runnerArgs += @('--only', $Only) }
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    & python3 @runnerArgs
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python @runnerArgs
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 @runnerArgs
} else {
    Write-Error '找不到 Python 3。请先安装 Python 3。'
    exit 2
}
exit $LASTEXITCODE
