# =============================================================================
#  MBT Meta Clothes - Deploy to FiveM server
#
#  Syncs the resource from the dev folder to your FiveM server's resources
#  folder using robocopy. Excludes dev-only artifacts (node_modules, .git,
#  web/src, pnpm-lock, etc.) so only runtime files are copied.
#
#  Runs `pnpm build` by DEFAULT before the sync — deploying a stale NUI
#  bundle is one of the top debugging time-sinks. Use -SkipBuild only when
#  you KNOW the dist is current (e.g. back-to-back Lua-only edits).
#
#  Usage examples:
#     .\deploy-to-server.ps1                  # build + deploy (default)
#     .\deploy-to-server.ps1 -SkipBuild       # skip pnpm build (Lua-only edit)
#     .\deploy-to-server.ps1 -DryRun          # list what would change, don't write
#     .\deploy-to-server.ps1 -Dest 'C:\FXServer\server-data\resources\[mbt]\mbt_meta_clothes'
#
#  First run: edit the $DefaultDest below to point to your server, then you
#  can just run `.\deploy-to-server.ps1` without arguments.
# =============================================================================

param(
    [string]$Src  = 'D:\Projects\FiveM\MBT\mbt_meta_clothes',
    [string]$Dest = '',
    # Build is now ON by default — see header comment. Pass -SkipBuild to
    # skip the pnpm build step for Lua-only iterations.
    [switch]$SkipBuild,
    # NOTE: named -DryRun (not -WhatIf) to avoid collision with PowerShell's
    # common ShouldProcess -WhatIf parameter, which on some hosts leaks into
    # child cmdlet invocations and poisons parameter-set resolution.
    [switch]$DryRun
)

# ---- Edit this line once with your server path, then forget it -------------
$DefaultDest = 'D:\Projects\FiveM\MalibuESX\server-data\resources\[wip]\mbt_meta_clothes'
# ----------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Dest)) { $Dest = $DefaultDest }

# Resource name derived from the destination folder leaf — used in the final
# "restart" hint. Avoids hardcoding a stale name from a copy/pasted script.
$resourceName = [System.IO.Path]::GetFileName($Dest.TrimEnd('\','/'))
if ([string]::IsNullOrWhiteSpace($resourceName)) { $resourceName = 'mbt_meta_clothes' }

Write-Host "=== $resourceName - deploy ===" -ForegroundColor Cyan
Write-Host "Source : $Src"
Write-Host "Target : $Dest"
if ($DryRun) { Write-Host "DRY RUN (no files will be written)" -ForegroundColor Yellow }
Write-Host ""

# --- Sanity: source exists --------------------------------------------------
if (-not (Test-Path -LiteralPath $Src -PathType Container)) {
    Write-Error "Source folder not found: $Src"
    exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $Src 'fxmanifest.lua'))) {
    Write-Error "No fxmanifest.lua in $Src - is this really the resource root?"
    exit 1
}

# --- Rebuild NUI (default: ON) ---------------------------------------------
# Deploying a stale `web/dist` is the #1 source of "I fixed it but the server
# still shows the old version" — so we run `pnpm build` by default. Pass
# -SkipBuild only when you're iterating on Lua and KNOW the NUI is already
# current.
if (-not $SkipBuild) {
    Write-Host "[build] pnpm build..." -ForegroundColor Cyan
    Push-Location (Join-Path $Src 'web')
    try {
        & pnpm build
        if ($LASTEXITCODE -ne 0) { throw "pnpm build failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
    Write-Host ""
} else {
    Write-Host "[build] skipped (-SkipBuild)" -ForegroundColor DarkGray
    Write-Host ""
}

# --- Sanity: dist exists ----------------------------------------------------
$distPath = Join-Path $Src 'web\dist\index.html'
if (-not (Test-Path -LiteralPath $distPath)) {
    Write-Error "web/dist/index.html not found. Run without -SkipBuild or execute 'pnpm build' manually first."
    exit 1
}

# --- Ensure target parent exists -------------------------------------------
$destParent = [System.IO.Path]::GetDirectoryName($Dest.TrimEnd('\','/'))
if (-not (Test-Path -LiteralPath $destParent)) {
    Write-Error "Target parent folder does not exist: $destParent"
    exit 1
}

# --- Robocopy options -------------------------------------------------------
# /MIR  - mirror (sync, remove stale files in dest)
# /NFL  - no file list in log (cleaner output)
# /NDL  - no directory list
# /NP   - no progress percent per file
# /R:1  - retry once on failure (instead of default 1 million)
# /W:1  - 1 second wait between retries
# /L    - list only (dry run)
$robocopyOpts = @('/MIR', '/NFL', '/NDL', '/NP', '/R:1', '/W:1')
if ($DryRun) { $robocopyOpts += '/L' }

# --- Exclusions -------------------------------------------------------------
$excludeDirs = @(
    'node_modules',
    '.git',
    '.github',
    '.vite',
    '.vscode',
    '.idea',
    "$Src\web\src",
    "$Src\web\public"
)

$excludeFiles = @(
    'pnpm-lock.yaml',
    'package.json',
    'package-lock.json',
    'yarn.lock',
    'tsconfig.json',
    'tsconfig.*.json',
    'tsconfig.tsbuildinfo',
    'vite.config.*',
    '.gitignore',
    '.gitattributes',
    'rename-resource.ps1',
    'deploy-to-server.ps1',
    'cfx_release_post.md',
    'video_showcase_script.md',
    '*.tmp',
    '*.bak',
    '*.swp',
    '.DS_Store',
    'Thumbs.db'
)

$robocopyArgs = @($Src, $Dest) + $robocopyOpts
$robocopyArgs += '/XD'
$robocopyArgs += $excludeDirs
$robocopyArgs += '/XF'
$robocopyArgs += $excludeFiles

Write-Host "[sync] robocopy..." -ForegroundColor Cyan
& robocopy @robocopyArgs | Out-Host
$rc = $LASTEXITCODE

# Robocopy exit codes: 0-7 are success (0 = no change, 1 = files copied, ...)
# 8+ is an actual failure
if ($rc -ge 8) {
    Write-Error "robocopy failed with exit code $rc"
    exit $rc
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Exit code: $rc (robocopy: 0=no changes, 1-7=files copied)"

if (-not $DryRun) {
    Write-Host ""
    Write-Host "In the FiveM server console:" -ForegroundColor Cyan
    Write-Host "   ensure $resourceName"
    Write-Host "or:" -ForegroundColor Cyan
    Write-Host "   restart $resourceName"
}
