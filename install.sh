#!/usr/bin/env bash
# 闲鱼智能监控系统 - Linux 一键依赖安装脚本
# 幂等可重复执行：已安装的依赖会自动跳过
# 支持：Debian/Ubuntu、RHEL/CentOS/Fedora、Arch Linux、macOS (Homebrew)
set -e

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step()  { echo -e "\n${CYAN}[INSTALL] $1${NC}"; }
ok()    { echo -e "  ${GREEN}[OK] $1${NC}"; }
warn()  { echo -e "  ${YELLOW}[WARN] $1${NC}"; }
err()   { echo -e "  ${RED}[ERR] $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检测发行版
OS_FAMILY="unknown"
PKG_MGR=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian|linuxmint|pop)            OS_FAMILY="debian"; PKG_MGR="apt" ;;
        rhel|centos|fedora|rocky|alma|amzn)     OS_FAMILY="rhel";   PKG_MGR="dnf" ;;
        arch|manjaro|endeavouros)               OS_FAMILY="arch";   PKG_MGR="pacman" ;;
    esac
fi
case "$(uname -s)" in
    Darwin) OS_FAMILY="macos"; PKG_MGR="brew" ;;
esac

if [ "$OS_FAMILY" = "unknown" ]; then
    err "无法识别的操作系统：$(uname -s)。请手动安装 Python3.10+ / Node.js LTS / Chrome 或 Edge / Playwright。"
    exit 1
fi

step "检测到系统：$OS_FAMILY （包管理器：$PKG_MGR）"

# 1. Python 3.10+
step "检查 Python 3.10+..."
PY_CMD=""
for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then
        ver=$("$c" -c 'import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)
        major=$(echo "$ver" | cut -d. -f1)
        minor=$(echo "$ver" | cut -d. -f2)
        if [ "${major:-0}" -eq 3 ] && [ "${minor:-0}" -ge 10 ] 2>/dev/null; then
            PY_CMD="$c"; ok "Python 已安装：$ver （$c）"; break
        fi
    fi
done
if [ -z "$PY_CMD" ]; then
    case "$OS_FAMILY" in
        debian) sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv ;;
        rhel)   sudo dnf install -y python3 python3-pip ;;
        arch)   sudo pacman -S --noconfirm python python-pip ;;
        macos)
            if ! command -v brew >/dev/null 2>&1; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install python@3.11
            ;;
    esac
    PY_CMD="python3"
    ok "Python 安装完成"
fi

# 2. Node.js + npm (LTS)
step "检查 Node.js + npm..."
if command -v node >/dev/null 2>&1; then
    ok "Node.js 已安装：$(node --version)"
else
    case "$OS_FAMILY" in
        debian)
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        rhel)
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo -E bash -
            sudo dnf install -y nodejs
            ;;
        arch)   sudo pacman -S --noconfirm nodejs npm ;;
        macos)  brew install node ;;
    esac
    ok "Node.js 安装完成：$(node --version)"
fi

# 3. 浏览器 Chrome / Chromium / Edge
step "检查浏览器..."
HAS_BROWSER=false
for b in google-chrome google-chrome-stable chromium chromium-browser microsoft-edge microsoft-edge-stable; do
    if command -v "$b" >/dev/null 2>&1; then HAS_BROWSER=true; ok "浏览器已安装：$b"; break; fi
done
if [ "$HAS_BROWSER" = false ]; then
    case "$OS_FAMILY" in
        debian)
            sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium
            ;;
        rhel)   sudo dnf install -y chromium ;;
        arch)   sudo pacman -S --noconfirm chromium ;;
        macos)  brew install --cask google-chrome ;;
    esac
    ok "浏览器安装完成"
fi

# 4. Playwright + Chromium（Python 包）
step "安装 Playwright 与 Chromium..."
$PY_CMD -m pip install --upgrade pip
$PY_CMD -m pip install playwright
$PY_CMD -m playwright install chromium
# Linux 需要额外装系统依赖
if [ "$OS_FAMILY" = "debian" ] || [ "$OS_FAMILY" = "rhel" ] || [ "$OS_FAMILY" = "arch" ]; then
    $PY_CMD -m playwright install-deps chromium || warn "playwright install-deps 失败，若 chromium 已能正常启动可忽略"
fi
ok "Playwright + Chromium 就绪"

# 5. 项目 Python 依赖
step "安装项目 Python 依赖 (requirements.txt)..."
if [ -f requirements.txt ]; then
    $PY_CMD -m pip install -r requirements.txt
    ok "requirements.txt 安装完成"
else
    warn "未找到 requirements.txt，请确认在项目根目录运行"
fi

# 6. 配置文件
step "准备配置文件..."
[ -f .env ] || { [ -f .env.example ] && cp .env.example .env && ok "已从 .env.example 创建 .env"; }
[ -f config.json ] || { [ -f config.json.example ] && cp config.json.example config.json && ok "已从 config.json.example 创建 config.json"; }
[ -f .env ] && ok ".env 已存在，跳过"
[ -f config.json ] && ok "config.json 已存在，跳过"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}所有依赖安装完成！${NC}"
echo -e "${GREEN}下一步：${NC}"
echo -e "${GREEN}  1. 编辑 .env 填写 OPENAI_API_KEY 等必填项${NC}"
echo -e "${GREEN}  2. 一键启动：chmod +x start.sh && ./start.sh${NC}"
echo -e "${GREEN}  3. 访问 http://localhost:8801${NC}"
echo -e "${GREEN}========================================${NC}"
