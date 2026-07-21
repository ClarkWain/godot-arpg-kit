#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Git 预提交钩子：提交前先跑一遍战斗系统测试，未通过则拒绝提交。

.DESCRIPTION
  安装方式（在项目根目录）：

    # 方式 A：符号链接（推荐，可跟随脚本更新自动生效）
    New-Item -ItemType SymbolicLink -Path .git/hooks/pre-commit `
        -Target (Resolve-Path tools/pre-commit.ps1)

    # 方式 B：手动复制
    Copy-Item tools/pre-commit.ps1 .git/hooks/pre-commit

  Windows 下需确保 .git/hooks/pre-commit 无扩展名，且 Git for Windows
  自带的 sh 会通过 shebang 转发到 pwsh；若不生效，可改写 hook 为：

    #!/bin/sh
    pwsh -File tools/pre-commit.ps1
    exit $?

  跳过：`git commit --no-verify`
#>

$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Host "[pre-commit] 不在 Git 仓库中，跳过。" -ForegroundColor Yellow
    exit 0
}

Write-Host "[pre-commit] 运行战斗系统测试..." -ForegroundColor Cyan
& (Join-Path $repoRoot 'tools/run_tests.ps1')
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "[pre-commit] 测试未通过（退出码=$exitCode），提交被拒绝。" -ForegroundColor Red
    Write-Host "  - 修复失败测试后重新 commit"
    Write-Host "  - 或使用 'git commit --no-verify' 强制跳过"
    exit $exitCode
}

Write-Host "[pre-commit] 全部测试通过，允许提交。" -ForegroundColor Green
exit 0
