<#
.SYNOPSIS
    ai-goofish-monitor - Windows one-click dependency installer
.DESCRIPTION
    Installs Git / Python / Node.js / Chrome via winget, then installs Playwright + Chromium
    and project Python dependencies (requirements.txt). Idempotent: rerunnable.
.NOTES
    Requires: Windows 10 1709+ / Windows 11 (winget built-in)
    If execution policy blocks, run:
      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
#>

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$msg) Write-Host ""; Write-Host "[INSTALL] $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$msg) Write-Host "  [ERR] $msg" -ForegroundColor Red }

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

# 0. Check winget
Write-Step "Checking winget..."
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $wingetCmd) {
    Write-Err "winget not found. Install 'App Installer' from Microsoft Store first, or upgrade to Windows 10 1709+."
    exit 1
}
Write-Ok "winget available"

# 1. Git for Windows (provides Git Bash, required to run start.sh)
Write-Step "Checking Git..."
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($null -ne $gitCmd) {
    $gitVer = git --version 2>&1
    Write-Ok "Git already installed: $gitVer"
} else {
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    Refresh-Path
    Write-Ok "Git installed"
}

# 2. Python 3.10+
Write-Step "Checking Python 3.10+..."
$pyCmd = $null
foreach ($c in @("python", "py")) {
    $cmdInfo = Get-Command $c -ErrorAction SilentlyContinue
    if ($null -ne $cmdInfo) {
        try {
            $ver = & $c --version 2>&1
            $verStr = "$ver"
            if ($verStr -match "3\.(\d+)\.") {
                $minorNum = [int]$Matches[1]
                if ($minorNum -ge 10) {
                    $pyCmd = $c
                    Write-Ok "Python already installed: $verStr (using $c)"
                    break
                }
            }
        } catch {
            # ignore version detection failure, try next
        }
    }
}
if ($null -eq $pyCmd) {
    winget install --id Python.Python.3.11 -e --source winget --accept-source-agreements --accept-package-agreements
    Refresh-Path
    $pyCmd = "python"
    $pythonCheck = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $pythonCheck) {
        $pyCmd = "py"
    }
    Write-Ok "Python installed (using $pyCmd)"
}

# 3. Node.js + npm (LTS)
Write-Step "Checking Node.js..."
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($null -ne $nodeCmd) {
    $nodeVer = node --version 2>&1
    Write-Ok "Node.js already installed: $nodeVer"
} else {
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
    Refresh-Path
    Write-Ok "Node.js installed"
}

# 4. Browser: Chrome or Edge (at least one)
Write-Step "Checking browser (Chrome / Edge)..."
$hasBrowser = $false
$chromePaths = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
)
$edgePaths = @(
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
)
foreach ($p in $chromePaths) {
    if (Test-Path $p) {
        Write-Ok "Chrome already installed: $p"
        $hasBrowser = $true
        break
    }
}
if (-not $hasBrowser) {
    foreach ($p in $edgePaths) {
        if (Test-Path $p) {
            Write-Ok "Edge already installed: $p"
            $hasBrowser = $true
            break
        }
    }
}
if (-not $hasBrowser) {
    winget install --id Google.Chrome -e --source winget --accept-source-agreements --accept-package-agreements
    Write-Ok "Chrome installed"
}

# 5. Playwright + Chromium
Write-Step "Installing Playwright and Chromium..."
& $pyCmd -m pip install --upgrade pip
& $pyCmd -m pip install playwright
& $pyCmd -m playwright install chromium
Write-Ok "Playwright + Chromium ready"

# 6. Project Python runtime dependencies
Write-Step "Installing project Python dependencies (requirements.txt)..."
if (Test-Path "requirements.txt") {
    & $pyCmd -m pip install -r requirements.txt
    Write-Ok "requirements.txt installed"
} else {
    Write-Warn "requirements.txt not found, skipped (run this script from project root)"
}

# 7. Optional: prepare config files
Write-Step "Preparing config files..."
if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item .env.example .env
        Write-Ok "Created .env from .env.example"
    }
} else {
    Write-Ok ".env already exists, skipped"
}
if (-not (Test-Path "config.json")) {
    if (Test-Path "config.json.example") {
        Copy-Item config.json.example config.json
        Write-Ok "Created config.json from config.json.example"
    }
} else {
    Write-Ok "config.json already exists, skipped"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "All dependencies installed!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  1. Reopen terminal to refresh PATH" -ForegroundColor Green
Write-Host "  2. Edit .env to fill OPENAI_API_KEY etc." -ForegroundColor Green
Write-Host "  3. Right-click project root -> Open Git Bash here" -ForegroundColor Green
Write-Host "  4. Run in Git Bash: ./start.sh" -ForegroundColor Green
Write-Host "  5. Visit http://localhost:8801" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
