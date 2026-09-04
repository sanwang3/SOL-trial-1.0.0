#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="Linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS_NAME=$NAME
            OS_VERSION=$VERSION_ID
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
        OS_NAME=$(sw_vers -productName)
        OS_VERSION=$(sw_vers -productVersion)
    else
        OS="Unknown"
        OS_NAME=$OSTYPE
        OS_VERSION=""
    fi
}

# 检测包管理器
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_INSTALL="apt-get install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
    elif command -v brew &> /dev/null; then
        PKG_MANAGER="brew"
        PKG_INSTALL="brew install"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
    else
        PKG_MANAGER="unknown"
        PKG_INSTALL=""
    fi
}

# 安装依赖
install_dependencies() {
    print_info "安装系统依赖..."
    
    case $PKG_MANAGER in
        apt)
            sudo apt-get update
            sudo apt-get install -y curl build-essential pkg-config libssl-dev
            ;;
        yum|dnf)
            sudo $PKG_INSTALL curl gcc gcc-c++ make openssl-devel
            ;;
        brew)
            brew install curl openssl
            ;;
        pacman)
            sudo pacman -Syu --noconfirm curl base-devel openssl
            ;;
        *)
            print_warning "未知包管理器，请手动安装: curl, build-essential, openssl"
            ;;
    esac
}

# 检测并安装Rust
check_rust() {
    print_info "检测Rust环境..."
    
    if command -v rustc &> /dev/null; then
        RUST_VERSION=$(rustc --version | awk '{print $2}')
        print_success "Rust已安装: $RUST_VERSION"
    else
        print_warning "Rust未安装，正在自动安装..."
        
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        # 加载环境变量
        source "$HOME/.cargo/env"
        
        print_success "Rust安装完成"
    fi
}

# 检测并安装Node.js
check_nodejs() {
    print_info "检测Node.js（可选）..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js已安装: $NODE_VERSION"
        NODE_AVAILABLE=1
    else
        print_warning "Node.js未安装（JavaScript版本需要）"
        NODE_AVAILABLE=0
        
        if [ "$PKG_MANAGER" != "unknown" ]; then
            read -p "是否安装Node.js? (y/N): " install_node
            if [[ $install_node =~ ^[Yy]$ ]]; then
                case $PKG_MANAGER in
                    apt)
                        sudo apt-get install -y nodejs npm
                        ;;
                    yum|dnf)
                        sudo $PKG_INSTALL nodejs npm
                        ;;
                    brew)
                        brew install node
                        ;;
                    pacman)
                        sudo pacman -S --noconfirm nodejs npm
                        ;;
                esac
                NODE_AVAILABLE=1
            fi
        fi
    fi
}

# 编译项目
build_project() {
    print_info "编译项目..."
    
    cd "$(dirname "$0")"
    
    # 检查是否已编译
    if [ -f "target/release/sol-monitor" ]; then
        print_success "检测到已编译的程序"
        read -p "是否重新编译? (y/N): " rebuild
        if [[ ! $rebuild =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    echo ""
    echo "这可能需要几分钟时间，请耐心等待..."
    echo ""
    
    cargo build --release
    
    if [ $? -ne 0 ]; then
        print_error "编译失败，请检查错误信息"
        exit 1
    fi
    
    print_success "编译完成"
}

# 配置环境变量
setup_env() {
    print_info "配置环境变量..."
    
    if [ ! -f ".env" ]; then
        print_warning "未检测到.env文件，正在从模板创建..."
        cp .env.example .env
        print_warning "请编辑.env文件配置你的Solana地址"
        
        if command -v nano &> /dev/null; then
            read -p "是否现在编辑配置文件? (y/N): " edit_env
            if [[ $edit_env =~ ^[Yy]$ ]]; then
                nano .env
            fi
        elif command -v vim &> /dev/null; then
            read -p "是否现在编辑配置文件? (y/N): " edit_env
            if [[ $edit_env =~ ^[Yy]$ ]]; then
                vim .env
            fi
        fi
    fi
    
    # 读取WATCH_ADDR
    WATCH_ADDR=$(grep "WATCH_ADDR" .env | cut -d'=' -f2 | tr -d ' "')
    
    if [ -z "$WATCH_ADDR" ]; then
        print_error "WATCH_ADDR未配置"
        print_warning "请编辑.env文件配置你的Solana地址"
        
        if command -v nano &> /dev/null; then
            nano .env
        elif command -v vim &> /dev/null; then
            vim .env
        fi
        
        exit 1
    fi
    
    print_success "配置已加载"
}

# 启动服务
start_service() {
    print_info "启动监控服务..."
    
    echo ""
    echo "========================================"
    echo "    Solana监控系统 - 监控服务"
    echo "========================================"
    echo ""
    echo "  Web管理面板: http://localhost:8080"
    echo "  按 Ctrl+C 停止服务"
    echo "========================================"
    echo ""
    
    # 启动程序
    ./target/release/sol-monitor
}

# 主函数
main() {
    echo ""
    echo "========================================"
    echo "    Solana监控系统 - 一键启动脚本"
    echo "========================================"
    echo ""
    
    # 检测操作系统
    detect_os
    print_info "操作系统: $OS $OS_NAME $OS_VERSION"
    
    # 检测包管理器
    detect_package_manager
    print_info "包管理器: $PKG_MANAGER"
    
    # 安装依赖
    install_dependencies
    
    # 检测Rust
    check_rust
    
    # 检测Node.js
    check_nodejs
    
    # 编译项目
    build_project
    
    # 配置环境变量
    setup_env
    
    # 启动服务
    start_service
}

# 捕获Ctrl+C
trap 'echo ""; print_info "正在停止服务..."; exit 0' INT

# 运行主函数
main
