<#
.SYNOPSIS
  一键运行 godot-arpg-kit 所有模块的测试套件（headless）并按结果返回退出码。

.DESCRIPTION
  按模块依次执行：Combat / Items / Loot / Quest / Stats。
  聚合每个模块的退出码，任一模块失败则整体退出码为 1。

  优先使用环境变量 $env:GODOT 指定 Godot 可执行文件路径；未设置时按
  常见路径列表自动查找。

.EXAMPLE
  pwsh tools/run_tests.ps1

.EXAMPLE
  # 只跑一个模块
  pwsh tools/run_tests.ps1 -Only combat
#>

param(
    [string]$Only = ""   # 只跑指定模块（combat / items / loot / quest / stats）
)

$ErrorActionPreference = 'Stop'

# 项目根：脚本所在目录的上一级
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

# 1. 定位 Godot
$godot = $env:GODOT
if (-not $godot) {
    $candidates = @(
        (Get-Command godot -ErrorAction SilentlyContinue).Source,
        (Get-Command godot.bat -ErrorAction SilentlyContinue).Source,
        'E:\Developer\Godot_v4.4.1-stable_mono_win64\godot.bat',
        'C:\Program Files\Godot\godot.exe'
    )
    $godot = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error "找不到 Godot 可执行文件。请设置 `$env:GODOT` 环境变量指向 godot.exe/godot.bat"
    exit 2
}

Write-Host "使用 Godot: $godot" -ForegroundColor Cyan
Write-Host "项目路径:  $projectRoot" -ForegroundColor Cyan

# 2. UTF-8 输出
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 3. 模块 -> 测试场景 映射
$suites = [ordered]@{
    'combat' = 'res://tests/combat/combat_test_scene.tscn'
    'items'  = 'res://tests/items/item_system_test_scene.tscn'
    'loot'   = 'res://tests/loot/loot_system_test_scene.tscn'
    'quest'  = 'res://tests/quest/test_scene.tscn'
    'stats'  = 'res://tests/stats/test_scene.tscn'
}

if ($Only) {
    if (-not $suites.Contains($Only)) {
        Write-Error "未知模块 '$Only'。可选：$($suites.Keys -join ', ')"
        exit 2
    }
    $suites = [ordered]@{ $Only = $suites[$Only] }
}

# 4. 依次跑
$overallExit = 0
$moduleResults = @()

foreach ($name in $suites.Keys) {
    $scene = $suites[$name]
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host " Running suite: $name  ($scene)" -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Yellow
    
    & $godot --headless --path $projectRoot $scene
    $code = $LASTEXITCODE
    
    $moduleResults += [pscustomobject]@{
        Module   = $name
        ExitCode = $code
        Passed   = ($code -eq 0)
    }
    
    if ($code -ne 0) {
        $overallExit = 1
    }
}

# 5. 汇总
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host " 汇总" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
$moduleResults | Format-Table -AutoSize

Write-Host ""
if ($overallExit -eq 0) {
    Write-Host "所有模块测试通过 OK" -ForegroundColor Green
} else {
    Write-Host "有模块测试失败 FAILED (exit=$overallExit)" -ForegroundColor Red
}
exit $overallExit
