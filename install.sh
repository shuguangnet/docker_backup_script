#!/bin/bash

# Docker容器备份工具一键安装脚本
# 作者: Docker Backup Tool
# 版本: 1.0
# 描述: 自动安装依赖、配置环境并部署备份工具

set -euo pipefail

# 脚本信息
SCRIPT_NAME="Docker容器备份工具一键安装"
SCRIPT_VERSION="1.0"
INSTALL_DIR="/opt/docker-backup"
BACKUP_DIR="/var/backups/docker"
SERVICE_USER="docker-backup"

# GitHub仓库信息
GITHUB_REPO="shuguangnet/dcoker_backup_script"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main"
GITHUB_API_URL="https://api.github.com/repos/$GITHUB_REPO"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# 版本比较函数
version_compare() {
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # 填充空字段为0
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    return 0
}

# 获取最新版本信息
get_latest_version() {
    local version_info
    local retry_count=0
    local max_retries=3

    while [[ $retry_count -lt $max_retries ]]; do
        # 静默检查版本，避免日志输出干扰
        if [[ $retry_count -gt 0 ]]; then
            log_warning "获取版本信息失败，等待3秒后重试... ($((retry_count + 1))/$max_retries)"
        fi

        # 尝试从GitHub API获取最新版本
        if version_info=$(curl -fsSL "$GITHUB_API_URL/releases/latest" 2>/dev/null); then
            local latest_version
            latest_version=$(echo "$version_info" | jq -r '.tag_name' 2>/dev/null | sed 's/^v//')

            if [[ -n "$latest_version" && "$latest_version" != "null" ]]; then
                echo "$latest_version"
                return 0
            fi
        fi

        # 如果API失败，尝试从install.sh文件获取版本
        if version_info=$(curl -fsSL "$GITHUB_RAW_URL/install.sh" 2>/dev/null); then
            local latest_version
            latest_version=$(echo "$version_info" | grep '^SCRIPT_VERSION=' | head -1 | cut -d'"' -f2)

            if [[ -n "$latest_version" ]]; then
                echo "$latest_version"
                return 0
            fi
        fi

        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            sleep 3
        fi
    done

    return 1
}

# 检查是否有新版本
check_for_updates() {
    log_info "检查脚本更新..."

    local latest_version
    if ! latest_version=$(get_latest_version); then
        log_warning "无法检查更新，继续使用当前版本 $SCRIPT_VERSION"
        return 1
    fi

    log_info "当前版本: $SCRIPT_VERSION"
    log_info "最新版本: $latest_version"

    version_compare "$SCRIPT_VERSION" "$latest_version"
    local compare_result=$?

    case $compare_result in
        0)
            log_success "已是最新版本"
            return 0
            ;;
        1)
            log_warning "当前版本 ($SCRIPT_VERSION) 比最新版本 ($latest_version) 更新"
            return 0
            ;;
        2)
            log_warning "发现新版本: $latest_version"
            return 1
            ;;
    esac
}

# 升级脚本
upgrade_script() {
    log_info "开始升级脚本到最新版本..."

    local latest_version
    if ! latest_version=$(get_latest_version); then
        log_error "无法获取最新版本信息"
        return 1
    fi

    log_info "正在下载最新版本 $latest_version..."

    # 创建临时目录
    local temp_dir
    temp_dir=$(mktemp -d)

    # 下载最新版本的install.sh
    if ! curl -fsSL "$GITHUB_RAW_URL/install.sh" -o "$temp_dir/install.sh"; then
        log_error "下载最新版本失败"
        rm -rf "$temp_dir"
        return 1
    fi

    # 验证下载的文件
    if ! bash -n "$temp_dir/install.sh"; then
        log_error "下载的文件格式错误"
        rm -rf "$temp_dir"
        return 1
    fi

    # 备份当前脚本
    local backup_file
    backup_file="install.sh.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$0" "$backup_file"
    log_info "当前脚本已备份为: $backup_file"

    # 替换当前脚本
    if cp "$temp_dir/install.sh" "$0"; then
        chmod +x "$0"
        log_success "脚本升级完成！"
        log_info "新版本: $latest_version"
        rm -rf "$temp_dir"
        return 0
    else
        log_error "脚本替换失败"
        # 恢复备份
        cp "$backup_file" "$0"
        chmod +x "$0"
        rm -rf "$temp_dir"
        return 1
    fi
}

# 升级已安装的工具
upgrade_installed_tools() {
    if [[ "$DEV_MODE" == true ]]; then
        log_info "开发模式：跳过工具升级"
        return 0
    fi

    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_warning "安装目录不存在，跳过工具升级"
        return 0
    fi

    log_info "升级已安装的工具文件..."

    local files=(
        "docker-backup.sh"
        "docker-restore.sh"
        "backup-utils.sh"
        "docker-backup-menu.sh"
        "docker-cleanup.sh"
        "backup.conf"
        "README.md"
        "test-compose-detection.sh"
    )

    local failed_files=()

    for file in "${files[@]}"; do
        log_info "  更新: $file"
        if ! curl -fsSL "$GITHUB_RAW_URL/$file" -o "$INSTALL_DIR/$file"; then
            log_warning "更新失败: $file"
            failed_files+=("$file")
        else
            if [[ "$file" == *.sh ]]; then
                chmod +x "$INSTALL_DIR/$file"
            fi
        fi
    done

    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    if [[ ${#failed_files[@]} -eq 0 ]]; then
        log_success "所有工具文件更新完成"
    else
        log_warning "部分文件更新失败: ${failed_files[*]}"
    fi
}

# 启动HTTP服务器
start_http_server() {
    local backup_dir="$1"
    local port="${2:-6886}"

    log_info "启动HTTP服务器在端口 $port..."
    log_info "备份目录: $backup_dir"

    # 检查端口是否被占用
    if lsof -i ":$port" >/dev/null 2>&1; then
        log_warning "端口 $port 已被占用，尝试停止现有服务..."
        pkill -f "python.*$port" || true
        sleep 2
    fi

    # 检查是否是单个备份目录还是备份根目录
    local is_single_backup=false
    if [[ "$(basename "$backup_dir")" =~ ^.*_[0-9]{8}_[0-9]{6}$ ]]; then
        is_single_backup=true
        log_info "检测到单个备份目录，直接使用该目录"
    else
        log_info "检测到备份根目录，将创建包含所有备份的压缩包"
    fi

    # 创建ZIP压缩包
    local zip_file="$backup_dir/docker-backup.zip"
    log_info "创建备份压缩包: $zip_file"

    if command -v zip >/dev/null 2>&1; then
        cd "$backup_dir"
        if [[ "$is_single_backup" == true ]]; then
            # 单个备份目录，直接压缩当前目录
            if zip -r "docker-backup.zip" . -x "*.zip" >/dev/null 2>&1; then
                log_success "压缩包创建成功"
            else
                log_error "压缩包创建失败"
                return 1
            fi
        else
            # 备份根目录，压缩所有备份
            if zip -r "docker-backup.zip" . -x "*.zip" >/dev/null 2>&1; then
                log_success "压缩包创建成功"
            else
                log_error "压缩包创建失败"
                return 1
            fi
        fi
    else
        log_error "需要安装zip工具来创建压缩包"
        return 1
    fi

    # 获取本机IP地址
    local server_ip=""
    if command -v hostname >/dev/null 2>&1; then
        server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    else
        server_ip="localhost"
    fi

    # 启动HTTP服务器
    log_info "启动HTTP服务器..."
    log_info "下载地址: http://$server_ip:$port/docker-backup.zip"
    log_info "按 Ctrl+C 停止服务器"

    # 使用Python启动简单的HTTP服务器
    if command -v python3 >/dev/null 2>&1; then
        cd "$backup_dir"
        python3 -m http.server "$port" &
        local server_pid=$!
    elif command -v python >/dev/null 2>&1; then
        cd "$backup_dir"
        python -m SimpleHTTPServer "$port" &
        local server_pid=$!
    else
        log_error "需要安装Python来启动HTTP服务器"
        return 1
    fi

    # 保存PID
    echo "$server_pid" > "/tmp/docker-backup-http.pid"

    log_success "HTTP服务器已启动 (PID: $server_pid)"
    log_info "服务器地址: http://$server_ip:$port"
    log_info "下载命令: wget http://$server_ip:$port/docker-backup.zip"
    log_info "停止服务器: kill $server_pid 或按 Ctrl+C"

    # 等待用户中断
    trap "kill $server_pid 2>/dev/null; rm -f /tmp/docker-backup-http.pid; exit 0" INT TERM
    wait $server_pid
}

# 停止HTTP服务器
stop_http_server() {
    if [[ -f "/tmp/docker-backup-http.pid" ]]; then
        local pid=$(cat "/tmp/docker-backup-http.pid")
        if kill "$pid" 2>/dev/null; then
            log_success "HTTP服务器已停止"
        else
            log_warning "无法停止HTTP服务器 (PID: $pid)"
        fi
        rm -f "/tmp/docker-backup-http.pid"
    else
        log_warning "未找到HTTP服务器进程"
    fi
}

# 下载并恢复备份
download_and_restore() {
    local download_url="$1"
    local restore_dir="${2:-/tmp/docker-backup-restore}"

    log_info "下载备份文件: $download_url"

    # 创建恢复目录
    mkdir -p "$restore_dir"
    cd "$restore_dir"

    # 下载备份文件
    if command -v wget >/dev/null 2>&1; then
        if wget -O "docker-backup.zip" "$download_url"; then
            log_success "备份文件下载成功"
        else
            log_error "备份文件下载失败"
            return 1
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -L -o "docker-backup.zip" "$download_url"; then
            log_success "备份文件下载成功"
        else
            log_error "备份文件下载失败"
            return 1
        fi
    else
        log_error "需要安装wget或curl来下载文件"
        return 1
    fi

    # 解压备份文件
    log_info "解压备份文件..."
    if command -v unzip >/dev/null 2>&1; then
        if unzip -o "docker-backup.zip"; then
            log_success "备份文件解压成功"
        else
            log_error "备份文件解压失败"
            return 1
        fi
    else
        log_error "需要安装unzip工具来解压文件"
        return 1
    fi

    # 查找恢复脚本
    local restore_script=""
    for script in restore.sh */restore.sh; do
        if [[ -f "$script" && -x "$script" ]]; then
            restore_script="$script"
            break
        fi
    done

    if [[ -n "$restore_script" ]]; then
        log_info "找到恢复脚本: $restore_script"
        log_info "开始恢复容器..."

        if ./"$restore_script"; then
            log_success "容器恢复完成！"
        else
            log_error "容器恢复失败"
            return 1
        fi
    else
        log_error "未找到恢复脚本"
        return 1
    fi

    # 清理下载文件
    read -p "是否删除下载的备份文件? [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$restore_dir"
        log_info "备份文件已清理"
    else
        log_info "备份文件保留在: $restore_dir"
    fi
}

# 强制更新检查（在脚本执行前）
force_update_check() {
    # 如果指定了跳过更新检查，则直接返回
    if [[ "$SKIP_UPDATE_CHECK" == true ]]; then
        return 0
    fi

    log_info "检查脚本版本更新..."

    local latest_version
    if ! latest_version=$(get_latest_version); then
        log_warning "无法检查更新，继续使用当前版本 $SCRIPT_VERSION"
        return 0
    fi

    version_compare "$SCRIPT_VERSION" "$latest_version"
    local compare_result=$?

    case $compare_result in
        0)
            log_success "当前版本已是最新版本 ($SCRIPT_VERSION)"
            return 0
            ;;
        1)
            log_warning "当前版本 ($SCRIPT_VERSION) 比最新版本 ($latest_version) 更新"
            return 0
            ;;
        2)
            log_warning "发现新版本: $latest_version (当前: $SCRIPT_VERSION)"

            # 询问是否自动更新
            if [[ "$AUTO_UPDATE" == true ]]; then
                log_info "自动更新模式：开始升级脚本..."
                if upgrade_script; then
                    log_success "脚本已升级到最新版本，请重新运行命令"
                    exit 0
                else
                    log_error "自动更新失败，继续使用当前版本"
                    return 1
                fi
            else
                echo
                log_warning "发现新版本 $latest_version，当前版本为 $SCRIPT_VERSION"
                echo
                echo "建议升级到最新版本以获得更好的功能和修复。"
                echo
                read -p "是否立即升级脚本? [Y/n]: " -r
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    log_info "用户选择跳过更新，继续使用当前版本"
                    return 0
                else
                    log_info "开始升级脚本..."
                    if upgrade_script; then
                        log_success "脚本已升级到最新版本，请重新运行命令"
                        exit 0
                    else
                        log_error "升级失败，继续使用当前版本"
                        return 1
                    fi
                fi
            fi
            ;;
    esac
}

# 显示横幅
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                Docker容器备份工具一键安装                   ║
║                                                              ║
║  功能特性:                                                   ║
║  • 完整备份Docker容器配置和数据                             ║
║  • 支持数据卷和挂载点备份                                   ║
║  • 一键恢复到新服务器                                       ║
║  • 自动化备份计划                                           ║
║  • 安全加密和远程存储                                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 显示使用说明
show_usage() {
    cat << EOF
用法: $0 [选项]

选项:
    -h, --help              显示此帮助信息
    -d, --install-dir DIR   指定安装目录 (默认: ${INSTALL_DIR})
    -b, --backup-dir DIR    指定备份目录 (默认: ${BACKUP_DIR})
    -u, --user USER         指定服务用户 (默认: ${SERVICE_USER})
    --no-service           不创建系统服务
    --no-cron              不设置定时任务
    --dev-mode             开发模式（使用当前目录）
    --check-update         检查脚本更新
    --upgrade              升级脚本到最新版本
    --upgrade-tools        升级已安装的工具文件
    --auto-update          自动更新模式（发现新版本时自动升级）
    --skip-update-check    跳过版本更新检查
    --start-http           启动HTTP服务器提供备份下载
    --stop-http            停止HTTP服务器
    --download-restore URL 下载并恢复备份
    --uninstall            卸载工具

示例:
    $0                                    # 标准安装（会检查更新）
    $0 -d /usr/local/docker-backup       # 自定义安装目录
    $0 --dev-mode                        # 开发模式
    $0 --auto-update                     # 自动更新模式
    $0 --check-update                    # 检查更新
    $0 --upgrade                         # 升级脚本
    $0 --upgrade-tools                   # 升级工具文件
    $0 --skip-update-check               # 跳过更新检查
    $0 --start-http                      # 启动HTTP服务器
    $0 --stop-http                       # 停止HTTP服务器
    $0 --download-restore http://IP:6886/docker-backup.zip  # 下载并恢复
    $0 --uninstall                       # 卸载工具

EOF
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif command -v lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(lsb_release -sr)
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi

    log_info "检测到操作系统: $OS $OS_VERSION"
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."

    # 检查是否为root用户
    if [[ $EUID -ne 0 ]] && [[ "$DEV_MODE" != true ]]; then
        log_error "请使用sudo运行此脚本"
        exit 1
    fi

    # 检查Docker
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker未安装，请先安装Docker"
        log_info "安装Docker命令："
        case "$OS" in
            ubuntu|debian)
                echo "  curl -fsSL https://get.docker.com | sh"
                ;;
            centos|rhel|rocky|almalinux)
                echo "  curl -fsSL https://get.docker.com | sh"
                ;;
            *)
                echo "  请参考Docker官方文档: https://docs.docker.com/engine/install/"
                ;;
        esac
        exit 1
    fi

    # 检查Docker服务状态
    if ! docker info >/dev/null 2>&1; then
        log_warning "Docker服务未运行，尝试启动..."
        systemctl start docker || service docker start
        sleep 3
        if ! docker info >/dev/null 2>&1; then
            log_error "无法启动Docker服务"
            exit 1
        fi
    fi

    log_success "系统要求检查通过"
}

# 安装依赖包
install_dependencies() {
    log_info "安装必需的依赖包..."

    case "$OS" in
        ubuntu|debian)
            apt-get update
            apt-get install -y jq curl tar rsync gnupg cron
            ;;
        centos|rhel|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y epel-release
                dnf install -y jq curl tar rsync gnupg2 cronie
            else
                yum install -y epel-release
                yum install -y jq curl tar rsync gnupg2 cronie
            fi
            systemctl enable crond
            systemctl start crond
            ;;
        alpine)
            apk update
            apk add jq curl tar rsync gnupg dcron
            ;;
        *)
            log_warning "未知的操作系统，请手动安装: jq curl tar rsync gnupg"
            ;;
    esac

    # 验证关键工具
    local missing_tools=()
    for tool in jq curl tar docker; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "以下工具安装失败: ${missing_tools[*]}"
        exit 1
    fi

    log_success "依赖包安装完成"
}

# 创建服务用户
create_service_user() {
    if [[ "$DEV_MODE" == true ]]; then
        SERVICE_USER=$(whoami)
        log_info "开发模式：使用当前用户 $SERVICE_USER"
        return
    fi

    if ! id "$SERVICE_USER" >/dev/null 2>&1; then
        log_info "创建服务用户: $SERVICE_USER"
        useradd -r -s /bin/bash -d "$INSTALL_DIR" -c "Docker Backup Service" "$SERVICE_USER"
        usermod -aG docker "$SERVICE_USER"
    else
        log_info "服务用户已存在: $SERVICE_USER"
        usermod -aG docker "$SERVICE_USER"
    fi
}

# 安装工具文件
install_files() {
    log_info "安装工具文件到: $INSTALL_DIR"

    if [[ "$DEV_MODE" == true ]]; then
        INSTALL_DIR=$(pwd)
        log_info "开发模式：使用当前目录 $INSTALL_DIR"
        return
    fi

    # 创建安装目录
    mkdir -p "$INSTALL_DIR"

    # GitHub仓库基础URL
    local GITHUB_RAW_URL="https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main"

    # 下载必要文件
    log_info "从GitHub下载文件..."

    local files=(
        "docker-backup.sh"
        "docker-restore.sh"
        "backup-utils.sh"
        "docker-backup-menu.sh"
        "docker-cleanup.sh"
        "backup.conf"
        "README.md"
        "test-compose-detection.sh"
    )

    for file in "${files[@]}"; do
        log_info "  下载: $file"
        if ! curl -fsSL "$GITHUB_RAW_URL/$file" -o "$INSTALL_DIR/$file"; then
            log_error "下载失败: $file"
            exit 1
        fi
    done

    # 设置权限
    chmod +x "$INSTALL_DIR"/*.sh
    chmod 644 "$INSTALL_DIR"/backup.conf
    chmod 644 "$INSTALL_DIR"/README.md

    # 设置所有者
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    log_success "工具文件安装完成"
}

# 创建备份目录
create_backup_directory() {
    log_info "创建备份目录: $BACKUP_DIR"

    mkdir -p "$BACKUP_DIR"

    if [[ "$DEV_MODE" != true ]]; then
        chown "$SERVICE_USER:$SERVICE_USER" "$BACKUP_DIR"
    fi

    chmod 750 "$BACKUP_DIR"

    log_success "备份目录创建完成"
}

# 创建配置文件
create_config() {
    local config_file="$INSTALL_DIR/backup.conf.local"

    log_info "创建本地配置文件: $config_file"

    cat > "$config_file" << EOF
# Docker容器备份工具本地配置
# 此文件将覆盖默认配置

# 基础配置
DEFAULT_BACKUP_DIR="$BACKUP_DIR"
BACKUP_RETENTION_DAYS=30
VERBOSE_MODE=false
LOG_LEVEL=3

# 备份选项
DEFAULT_FULL_BACKUP=false
DEFAULT_EXCLUDE_VOLUMES=false
DEFAULT_EXCLUDE_MOUNTS=false
PAUSE_CONTAINERS_DURING_BACKUP=false

# 性能配置
MAX_CONCURRENT_BACKUPS=3
DISK_SPACE_BUFFER_MB=1024

# 安全配置
BACKUP_FILE_PERMISSIONS=600
BACKUP_DIR_PERMISSIONS=700
GENERATE_CHECKSUMS=true

# 通知配置（根据需要启用）
EMAIL_NOTIFICATIONS=false
WEBHOOK_NOTIFICATIONS=false
SLACK_NOTIFICATIONS=false

# 远程备份（根据需要启用）
REMOTE_BACKUP_ENABLED=false
UPLOAD_AFTER_BACKUP=false
EOF

    chmod 644 "$config_file"
    if [[ "$DEV_MODE" != true ]]; then
        chown "$SERVICE_USER:$SERVICE_USER" "$config_file"
    fi

    log_success "配置文件创建完成"
}

# 创建系统服务
create_systemd_service() {
    if [[ "$NO_SERVICE" == true ]] || [[ "$DEV_MODE" == true ]]; then
        log_info "跳过系统服务创建"
        return
    fi

    log_info "创建systemd服务..."

    cat > /etc/systemd/system/docker-backup.service << EOF
[Unit]
Description=Docker Container Backup Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/docker-backup.sh -a -c $INSTALL_DIR/backup.conf.local
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # 创建定时器
    cat > /etc/systemd/system/docker-backup.timer << EOF
[Unit]
Description=Run Docker Backup Daily
Requires=docker-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable docker-backup.timer

    log_success "系统服务创建完成"
}

# 创建定时任务
create_cron_job() {
    if [[ "$NO_CRON" == true ]] || [[ "$DEV_MODE" == true ]]; then
        log_info "跳过定时任务创建"
        return
    fi

    log_info "创建定时备份任务..."

    local cron_file="/etc/cron.d/docker-backup"

    cat > "$cron_file" << EOF
# Docker容器自动备份任务
# 每天凌晨2点执行备份
0 2 * * * $SERVICE_USER cd $INSTALL_DIR && ./docker-backup.sh -a -c $INSTALL_DIR/backup.conf.local >/dev/null 2>&1

# 每周日凌晨3点清理旧备份
0 3 * * 0 $SERVICE_USER find $BACKUP_DIR -type d -mtime +30 -exec rm -rf {} \; >/dev/null 2>&1
EOF

    chmod 644 "$cron_file"

    # 重启cron服务
    case "$OS" in
        ubuntu|debian)
            systemctl restart cron
            ;;
        centos|rhel|rocky|almalinux)
            systemctl restart crond
            ;;
    esac

    log_success "定时任务创建完成"
}

# 创建快捷命令
create_shortcuts() {
    if [[ "$DEV_MODE" == true ]]; then
        log_info "开发模式：跳过快捷命令创建"
        return
    fi

    log_info "创建快捷命令..."

    # 创建备份命令
    cat > /usr/local/bin/docker-backup << EOF
#!/bin/bash
cd $INSTALL_DIR
exec ./docker-backup.sh -c $INSTALL_DIR/backup.conf.local "\$@"
EOF

        # 创建恢复命令
    cat > /usr/local/bin/docker-restore << EOF
#!/bin/bash
cd $INSTALL_DIR
exec ./docker-restore.sh "\$@"
EOF

    # 创建菜单命令
    cat > /usr/local/bin/docker-backup-menu << EOF
#!/bin/bash
cd $INSTALL_DIR
exec ./docker-backup-menu.sh "\$@"
EOF

    # 创建清理命令
    cat > /usr/local/bin/docker-cleanup << EOF
#!/bin/bash
cd $INSTALL_DIR
exec ./docker-cleanup.sh "\$@"
EOF

    # 创建HTTP服务器命令
    cat > /usr/local/bin/docker-backup-server << EOF
#!/bin/bash
cd $INSTALL_DIR
exec ./install.sh --start-http "\$@"
EOF

    # 创建下载恢复命令
    cat > /usr/local/bin/docker-backup-download << EOF
#!/bin/bash
cd $INSTALL_DIR
exec ./install.sh --download-restore "\$@"
EOF

    chmod +x /usr/local/bin/docker-backup
    chmod +x /usr/local/bin/docker-restore
    chmod +x /usr/local/bin/docker-backup-menu
    chmod +x /usr/local/bin/docker-cleanup
    chmod +x /usr/local/bin/docker-backup-server
    chmod +x /usr/local/bin/docker-backup-download

    log_success "快捷命令创建完成"
    log_info "现在可以使用以下命令："
    log_info "  docker-backup -a              # 备份所有容器"
    log_info "  docker-backup nginx mysql     # 备份指定容器"
    log_info "  docker-restore /path/to/backup # 恢复容器"
    log_info "  docker-backup-menu            # 交互式菜单"
    log_info "  docker-cleanup 30             # 清理30天前的备份"
    log_info "  docker-backup-server          # 启动HTTP服务器"
    log_info "  docker-backup-download URL    # 下载并恢复备份"
}

# 运行测试
run_tests() {
    log_info "运行基础测试..."

    # 测试脚本执行权限
    if [[ -x "$INSTALL_DIR/docker-backup.sh" ]]; then
        log_success "备份脚本权限正常"
    else
        log_error "备份脚本权限异常"
        return 1
    fi

    # 测试依赖工具
    for tool in jq docker tar; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool 可用"
        else
            log_error "$tool 不可用"
            return 1
        fi
    done

    # 测试Docker连接
    if docker info >/dev/null 2>&1; then
        log_success "Docker连接正常"
    else
        log_error "Docker连接失败"
        return 1
    fi

    # 测试配置文件
    if [[ -f "$INSTALL_DIR/backup.conf.local" ]]; then
        log_success "配置文件存在"
    else
        log_error "配置文件缺失"
        return 1
    fi

    log_success "所有测试通过"
}

# 显示安装摘要
show_summary() {
    echo
    log_success "Docker容器备份工具安装完成！"
    echo
    echo "安装信息："
    echo "  安装目录: $INSTALL_DIR"
    echo "  备份目录: $BACKUP_DIR"
    echo "  服务用户: $SERVICE_USER"
    echo "  配置文件: $INSTALL_DIR/backup.conf.local"
    echo
    echo "使用方法："
    if [[ "$DEV_MODE" == true ]]; then
        echo "  ./docker-backup.sh -a                    # 备份所有容器"
        echo "  ./docker-backup.sh nginx mysql           # 备份指定容器"
        echo "  ./docker-restore.sh /path/to/backup      # 恢复容器"
    else
        echo "  docker-backup -a                         # 备份所有容器"
        echo "  docker-backup nginx mysql                # 备份指定容器"
        echo "  docker-restore /path/to/backup           # 恢复容器"
    fi
    echo
    echo "管理命令："
    if [[ "$NO_SERVICE" != true ]] && [[ "$DEV_MODE" != true ]]; then
        echo "  systemctl start docker-backup.timer     # 启动定时备份"
        echo "  systemctl status docker-backup.timer    # 查看定时任务状态"
        echo "  journalctl -u docker-backup.service     # 查看备份日志"
    fi
    echo "  crontab -l -u $SERVICE_USER             # 查看定时任务"
    echo
    echo "升级命令："
    echo "  $0 --check-update                    # 检查脚本更新"
    echo "  $0 --upgrade                         # 升级脚本到最新版本"
    echo "  $0 --upgrade-tools                   # 升级已安装的工具文件"
    echo "  $0 --auto-update                     # 自动更新模式"
    echo "  $0 --skip-update-check               # 跳过更新检查"
    echo
    echo "网络传输命令："
    echo "  $0 --start-http                      # 启动HTTP服务器"
    echo "  $0 --stop-http                       # 停止HTTP服务器"
    echo "  $0 --download-restore URL            # 下载并恢复备份"
    echo "  docker-backup-server                 # 快捷启动服务器"
    echo "  docker-backup-download URL           # 快捷下载恢复"
    echo
    echo "配置文件："
    echo "  编辑 $INSTALL_DIR/backup.conf.local 来自定义配置"
    echo
    echo "文档："
    echo "  查看 $INSTALL_DIR/README.md 获取详细说明"
    echo
    if [[ "$DEV_MODE" != true ]]; then
        echo "立即运行测试备份："
        echo "  docker-backup --help"
        echo "  docker-backup -v nginx  # 备份nginx容器（如果存在）"
    fi
    echo
}

# 卸载函数
uninstall() {
    log_info "开始卸载Docker备份工具..."

    # 停止并禁用服务
    if systemctl is-active docker-backup.timer >/dev/null 2>&1; then
        systemctl stop docker-backup.timer
        systemctl disable docker-backup.timer
    fi

    # 删除系统文件
    rm -f /etc/systemd/system/docker-backup.service
    rm -f /etc/systemd/system/docker-backup.timer
    rm -f /etc/cron.d/docker-backup
    rm -f /usr/local/bin/docker-backup
    rm -f /usr/local/bin/docker-restore

    # 删除安装目录（保留备份）
    if [[ -d "$INSTALL_DIR" ]] && [[ "$INSTALL_DIR" != "/" ]]; then
        read -p "是否删除安装目录 $INSTALL_DIR? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            log_success "安装目录已删除"
        fi
    fi

    # 可选删除备份目录
    if [[ -d "$BACKUP_DIR" ]] && [[ "$BACKUP_DIR" != "/" ]]; then
        read -p "是否删除备份目录 $BACKUP_DIR? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$BACKUP_DIR"
            log_success "备份目录已删除"
        else
            log_info "备份目录保留: $BACKUP_DIR"
        fi
    fi

    # 删除服务用户
    if [[ "$SERVICE_USER" != "root" ]] && id "$SERVICE_USER" >/dev/null 2>&1; then
        read -p "是否删除服务用户 $SERVICE_USER? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            userdel "$SERVICE_USER"
            log_success "服务用户已删除"
        fi
    fi

    systemctl daemon-reload

    log_success "卸载完成"
}

# 解析命令行参数
parse_arguments() {
    NO_SERVICE=false
    NO_CRON=false
    DEV_MODE=false
    UNINSTALL=false
    CHECK_UPDATE=false
    UPGRADE_SCRIPT=false
    UPGRADE_TOOLS=false
    AUTO_UPDATE=false
    SKIP_UPDATE_CHECK=false
    START_HTTP=false
    STOP_HTTP=false
    DOWNLOAD_RESTORE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -d|--install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -u|--user)
                SERVICE_USER="$2"
                shift 2
                ;;
            --no-service)
                NO_SERVICE=true
                shift
                ;;
            --no-cron)
                NO_CRON=true
                shift
                ;;
            --dev-mode)
                DEV_MODE=true
                NO_SERVICE=true
                NO_CRON=true
                SKIP_UPDATE_CHECK=true
                shift
                ;;
            --check-update)
                CHECK_UPDATE=true
                shift
                ;;
            --upgrade)
                UPGRADE_SCRIPT=true
                shift
                ;;
            --upgrade-tools)
                UPGRADE_TOOLS=true
                shift
                ;;
            --auto-update)
                AUTO_UPDATE=true
                shift
                ;;
            --skip-update-check)
                SKIP_UPDATE_CHECK=true
                shift
                ;;
            --start-http)
                START_HTTP=true
                shift
                ;;
            --stop-http)
                STOP_HTTP=true
                shift
                ;;
            --download-restore)
                DOWNLOAD_RESTORE="$2"
                shift 2
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    show_banner

    # 解析参数
    parse_arguments "$@"

    # 处理升级相关选项
    if [[ "$CHECK_UPDATE" == true ]]; then
        check_for_updates
        exit $?
    fi

    if [[ "$UPGRADE_SCRIPT" == true ]]; then
        if check_for_updates; then
            log_info "已是最新版本，无需升级"
            exit 0
        fi

        if upgrade_script; then
            log_success "脚本升级完成！请重新运行脚本"
            exit 0
        else
            log_error "脚本升级失败"
            exit 1
        fi
    fi

    if [[ "$UPGRADE_TOOLS" == true ]]; then
        # 检测系统环境
        detect_os
        check_requirements

        if upgrade_installed_tools; then
            log_success "工具文件升级完成！"
            exit 0
        else
            log_error "工具文件升级失败"
            exit 1
        fi
    fi

    # 处理HTTP服务器选项
    if [[ "$START_HTTP" == true ]]; then
        # 如果没有指定备份目录，使用默认目录
        if [[ -z "$BACKUP_DIR" ]]; then
            BACKUP_DIR="/tmp/docker-backups"
        fi

        if [[ ! -d "$BACKUP_DIR" ]]; then
            log_error "备份目录不存在: $BACKUP_DIR"
            log_info "请先运行备份命令创建备份文件"
            exit 1
        fi

        # 检查备份目录中是否有备份文件
        local backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "*_*" | wc -l)
        if [[ $backup_count -eq 0 ]]; then
            log_error "备份目录中没有找到备份文件: $BACKUP_DIR"
            exit 1
        fi

        log_info "找到 $backup_count 个备份文件"
        start_http_server "$BACKUP_DIR"
        exit 0
    fi

    if [[ "$STOP_HTTP" == true ]]; then
        stop_http_server
        exit 0
    fi

    if [[ -n "$DOWNLOAD_RESTORE" ]]; then
        download_and_restore "$DOWNLOAD_RESTORE"
        exit 0
    fi

    # 如果是卸载模式
    if [[ "$UNINSTALL" == true ]]; then
        uninstall
        exit 0
    fi

    # 强制更新检查（在开始执行前）
    force_update_check

    # 检测系统环境
    detect_os
    check_requirements

    # 安装依赖
    install_dependencies

    # 创建用户和目录
    create_service_user
    create_backup_directory

    # 安装文件
    install_files
    create_config

    # 创建服务和任务
    create_systemd_service
    create_cron_job
    create_shortcuts

    # 运行测试
    run_tests

    # 显示摘要
    show_summary

    log_success "安装完成！"
}

# 脚本入口点
# 兼容管道执行方式 (curl | bash)
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]] || [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    main "$@"
fi
