#!/bin/bash

# 系统资源监控脚本依赖安装脚本
# 支持 Ubuntu 24.04 和 macOS

set -e

# 颜色定义
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_RESET="\033[0m"

# 打印信息
info() {
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $1"
}

warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            echo "$ID"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
info "检测到操作系统: $OS"

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# Ubuntu/Debian 安装
install_ubuntu() {
    info "更新软件包列表..."
    sudo apt-get update

    # 安装 bc
    if ! command_exists bc; then
        info "安装 bc..."
        sudo apt-get install -y bc
    else
        info "bc 已安装"
    fi

    # 安装 sysstat (包含 iostat)
    if ! command_exists iostat; then
        info "安装 sysstat..."
        sudo apt-get install -y sysstat
        # 启用 sysstat 数据收集
        sudo sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat 2>/dev/null || true
        sudo systemctl enable sysstat 2>/dev/null || true
        sudo systemctl start sysstat 2>/dev/null || true
    else
        info "sysstat 已安装"
    fi

    # 安装 iproute2 (包含 ip 命令)
    if ! command_exists ip; then
        info "安装 iproute2..."
        sudo apt-get install -y iproute2
    else
        info "iproute2 已安装"
    fi

    # 安装 procps (包含 top, free)
    if ! command_exists top || ! command_exists free; then
        info "安装 procps..."
        sudo apt-get install -y procps
    else
        info "procps 已安装"
    fi
}

# macOS 安装
install_macos() {
    # 检查是否安装了 Homebrew
    if ! command_exists brew; then
        warn "未检测到 Homebrew，正在安装..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # 安装 bc
    if ! command_exists bc; then
        info "安装 bc..."
        brew install bc
    else
        info "bc 已安装"
    fi

    # macOS 自带 top 和 netstat，不需要额外安装
    info "macOS 自带 top 和 netstat 命令"

    # 安装 iostat (通常已预装在 macOS 中)
    if ! command_exists iostat; then
        warn "iostat 未找到，但在 macOS 上通常已预装"
    else
        info "iostat 已安装"
    fi
}

# 验证安装
verify_installation() {
    info "验证安装..."
    local all_ok=true

    if command_exists bc; then
        info "✓ bc 已安装"
    else
        error "✗ bc 未安装"
        all_ok=false
    fi

    if command_exists top; then
        info "✓ top 已安装"
    else
        error "✗ top 未安装"
        all_ok=false
    fi

    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        if command_exists free; then
            info "✓ free 已安装"
        else
            error "✗ free 未安装"
            all_ok=false
        fi

        if command_exists ip; then
            info "✓ ip 已安装"
        else
            error "✗ ip 未安装"
            all_ok=false
        fi
    fi

    if command_exists iostat; then
        info "✓ iostat 已安装"
    else
        error "✗ iostat 未安装"
        all_ok=false
    fi

    if [ "$all_ok" = true ]; then
        info "所有依赖安装成功！"
        info "现在可以运行 ./main.sh 启动监控"
    else
        error "部分依赖安装失败，请检查错误信息"
        exit 1
    fi
}

# 主函数
main() {
    info "开始安装系统监控脚本依赖..."

    case "$OS" in
        ubuntu|debian)
            install_ubuntu
            ;;
        macos)
            install_macos
            ;;
        *)
            error "不支持的操作系统: $OS"
            error "本脚本仅支持 Ubuntu 24.04 和 macOS"
            exit 1
            ;;
    esac

    verify_installation
}

main
