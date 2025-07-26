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
    --uninstall            卸载工具

示例:
    $0                                    # 标准安装
    $0 -d /usr/local/docker-backup       # 自定义安装目录
    $0 --dev-mode                        # 开发模式
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
        "backup.conf"
        "README.md"
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
    
    chmod +x /usr/local/bin/docker-backup
    chmod +x /usr/local/bin/docker-restore
    
    log_success "快捷命令创建完成"
    log_info "现在可以使用以下命令："
    log_info "  docker-backup -a              # 备份所有容器"
    log_info "  docker-backup nginx mysql     # 备份指定容器"
    log_info "  docker-restore /path/to/backup # 恢复容器"
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
                shift
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
    
    # 如果是卸载模式
    if [[ "$UNINSTALL" == true ]]; then
        uninstall
        exit 0
    fi
    
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
