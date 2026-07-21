<#
.SYNOPSIS
  一键运行 2d_arpg 战斗系统测试套件（headless）并按结果返回退出码。

.DESCRIPTION
  本脚本用于：
    1) 本地快速回归验证
    2) CI 集成（GitHub Actions / Jenkins / etc）——通过进程退出码判断成败
    3) Git 预提交钩子——保证提交前所有战斗管线测试通过

  优先使用环境变量 $env:GODOT 指定 Godot 可执行文件路径；未设置时按
  常见路径列表自动查找。

.EXAMPLE
  # 直接运行
  pwsh tools/run_tests.ps1

.EXAMPLE
  # 指定 Godot 路径
  $env:GODOT = 'E:\Developer\Godot_v4.4.1-stable_mono_win64\godot.bat'
  pwsh tools/run_tests.ps1
#>

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

# 2. 确保输出编码为 UTF-8
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 3. 运行测试场景
Write-Host "`n运行战斗测试套件..." -ForegroundColor Yellow
& $godot --headless --path $projectRoot 'res://tests/combat/combat_test_scene.tscn'
$exitCode = $LASTEXITCODE

Write-Host "`n测试完成，退出码: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
exit $exitCode
