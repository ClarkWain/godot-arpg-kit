<#
.SYNOPSIS
  一键运行 godot-arpg-kit 所有模块的测试套件（headless）并按结果返回退出码。

.DESCRIPTION
  按模块依次执行：Combat / Items / Loot / Quest / Stats。
  聚合每个模块的通过/失败数（通过解析输出而非 Godot 进程退出码，
  因为 headless 下 Godot 可能因资源泄漏 ERROR 而返回非 0，与测试成败无关）。

.EXAMPLE
  pwsh tools/run_tests.ps1

.EXAMPLE
  pwsh tools/run_tests.ps1 -Only combat
#>

param(
    [string]$Only = ""
)

$ErrorActionPreference = 'Stop'

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

$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 2. 模块清单
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

# 3. 跑
$overallFailed = 0
$moduleResults = @()

foreach ($name in $suites.Keys) {
    $scene = $suites[$name]
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host " Running suite: $name  ($scene)" -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Yellow

    # 捕获输出（stderr 一并 merge），实时打印同时保存全文
    $lines = New-Object System.Collections.Generic.List[string]
    & $godot --headless --path $projectRoot $scene 2>&1 | ForEach-Object {
        $line = "$_"
        $lines.Add($line)
        Write-Host $line
    }
    $godotExit = $LASTEXITCODE

    # 每个 test_runner 在结尾会打印一行机器可读汇总：
    #   [RESULT] suite=<name> passed=<P> failed=<F> total=<T>
    # 用它作为唯一权威来源（Godot 进程退出码在 headless 下会因资源泄漏
    # ERROR 而波动，与测试成败无关，不能依赖）。
    $suitePassed = 0
    $suiteFailed = 0
    $found = $false
    foreach ($ln in $lines) {
        if ($ln -match '\[RESULT\]\s+suite=(\S+)\s+passed=(\d+)\s+failed=(\d+)\s+total=(\d+)') {
            $suitePassed = [int]$Matches[2]
            $suiteFailed = [int]$Matches[3]
            $found = $true
            # 不 break：允许 combat 这类多 suite 汇总在同一进程内多次打印，
            # 但目前每个 test scene 只对应一个 runner 只打一次。
        }
    }
    if (-not $found) {
        # 找不到 [RESULT] 说明 runner 未升级，退回 Godot exit code
        $suitePassed = 0
        $suiteFailed = if ($godotExit -eq 0) { 0 } else { 1 }
        Write-Host "  [WARN] 未找到 [RESULT] 汇总行，退回 Godot 退出码=$godotExit" -ForegroundColor Yellow
    }

    $moduleResults += [pscustomobject]@{
        Module     = $name
        Passed     = $suitePassed
        Failed     = $suiteFailed
        GodotExit  = $godotExit
        Ok         = ($suiteFailed -eq 0 -and ($suitePassed -gt 0 -or -not $found))
    }
    $overallFailed += $suiteFailed
}

# 4. 汇总
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host " 汇总" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
$moduleResults | Format-Table -AutoSize

$totalPassed = ($moduleResults | Measure-Object -Property Passed -Sum).Sum
$totalFailed = ($moduleResults | Measure-Object -Property Failed -Sum).Sum
Write-Host ""
Write-Host "总计: $totalPassed 通过 / $totalFailed 失败" -ForegroundColor $(if ($totalFailed -eq 0) { 'Green' } else { 'Red' })

if ($totalFailed -eq 0) {
    Write-Host "所有模块测试通过 OK" -ForegroundColor Green
    exit 0
} else {
    Write-Host "有模块测试失败 FAILED (fails=$totalFailed)" -ForegroundColor Red
    exit 1
}
