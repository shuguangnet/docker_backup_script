#!/bin/bash

# Docker备份工具函数库
# 作者: Docker Backup Tool
# 版本: 1.0
# 描述: 提供备份脚本使用的通用函数

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志级别
LOG_LEVEL_ERROR=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_INFO=3
LOG_LEVEL_DEBUG=4

# 默认日志级别
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# 获取时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 日志记录函数
log() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp=$(get_timestamp)
    
    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}" >&2
}

# 错误日志
log_error() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_ERROR ]]; then
        log "ERROR" "$RED" "$1"
    fi
}

# 警告日志
log_warning() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_WARNING ]]; then
        log "WARN" "$YELLOW" "$1"
    fi
}

# 信息日志
log_info() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        log "INFO" "$BLUE" "$1"
    fi
}

# 成功日志
log_success() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        log "SUCCESS" "$GREEN" "$1"
    fi
}

# 调试日志
log_debug() {
    if [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]]; then
        log "DEBUG" "$CYAN" "$1"
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查文件是否存在且可读
file_readable() {
    [[ -f "$1" && -r "$1" ]]
}

# 检查目录是否存在且可写
dir_writable() {
    [[ -d "$1" && -w "$1" ]]
}

# 创建目录（如果不存在）
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            log_error "无法创建目录: $dir"
            return 1
        }
        log_debug "创建目录: $dir"
    fi
}

# 获取文件大小（人类可读格式）
get_file_size() {
    if [[ -f "$1" ]]; then
        if command_exists du; then
            du -sh "$1" 2>/dev/null | cut -f1
        else
            ls -lh "$1" 2>/dev/null | awk '{print $5}'
        fi
    else
        echo "0B"
    fi
}

# 获取目录大小（人类可读格式）
get_dir_size() {
    if [[ -d "$1" ]]; then
        if command_exists du; then
            du -sh "$1" 2>/dev/null | cut -f1
        else
            echo "unknown"
        fi
    else
        echo "0B"
    fi
}

# 检查磁盘空间是否足够
check_disk_space() {
    local path="$1"
    local required_mb="$2"  # 以MB为单位
    
    if command_exists df; then
        local available_kb=$(df "$path" | tail -1 | awk '{print $4}')
        local available_mb=$((available_kb / 1024))
        
        if [[ $available_mb -lt $required_mb ]]; then
            log_warning "磁盘空间不足: 需要 ${required_mb}MB，可用 ${available_mb}MB"
            return 1
        fi
        
        log_debug "磁盘空间检查通过: 需要 ${required_mb}MB，可用 ${available_mb}MB"
        return 0
    else
        log_warning "无法检查磁盘空间：df命令不可用"
        return 0  # 假设有足够空间
    fi
}

# 验证Docker容器名称
validate_container_name() {
    local name="$1"
    
    # Docker容器名称规则：只能包含字母、数字、下划线、点和连字符
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        log_error "无效的容器名称: $name"
        return 1
    fi
    
    return 0
}

# 检查容器是否存在
container_exists() {
    local container="$1"
    docker ps -a --format "{{.Names}}" | grep -q "^${container}$"
}

# 检查容器是否正在运行
container_running() {
    local container="$1"
    docker ps --format "{{.Names}}" | grep -q "^${container}$"
}

# 获取容器状态
get_container_status() {
    local container="$1"
    docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not found"
}

# 安全删除文件
safe_remove() {
    local file="$1"
    if [[ -f "$file" ]]; then
        rm -f "$file" && log_debug "删除文件: $file"
    fi
}

# 安全删除目录
safe_remove_dir() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        rm -rf "$dir" && log_debug "删除目录: $dir"
    fi
}

# 创建临时目录
create_temp_dir() {
    local prefix="${1:-docker-backup}"
    local temp_dir
    
    if command_exists mktemp; then
        temp_dir=$(mktemp -d -t "${prefix}.XXXXXX")
    else
        temp_dir="/tmp/${prefix}.$$"
        mkdir -p "$temp_dir"
    fi
    
    echo "$temp_dir"
}

# 清理临时文件和目录
cleanup_temp() {
    local temp_path="$1"
    if [[ -n "$temp_path" && "$temp_path" == /tmp/* ]]; then
        safe_remove_dir "$temp_path"
        log_debug "清理临时目录: $temp_path"
    fi
}

# 压缩文件或目录
compress_path() {
    local source="$1"
    local target="$2"
    local compression="${3:-gzip}"  # gzip, bzip2, xz
    
    if [[ ! -e "$source" ]]; then
        log_error "压缩源不存在: $source"
        return 1
    fi
    
    local tar_opts=""
    case "$compression" in
        gzip|gz)
            tar_opts="-czf"
            [[ "$target" != *.tar.gz ]] && target="${target}.tar.gz"
            ;;
        bzip2|bz2)
            tar_opts="-cjf"
            [[ "$target" != *.tar.bz2 ]] && target="${target}.tar.bz2"
            ;;
        xz)
            tar_opts="-cJf"
            [[ "$target" != *.tar.xz ]] && target="${target}.tar.xz"
            ;;
        *)
            log_error "不支持的压缩格式: $compression"
            return 1
            ;;
    esac
    
    if [[ -d "$source" ]]; then
        tar $tar_opts "$target" -C "$(dirname "$source")" "$(basename "$source")" 2>/dev/null
    else
        tar $tar_opts "$target" -C "$(dirname "$source")" "$(basename "$source")" 2>/dev/null
    fi
    
    if [[ $? -eq 0 ]]; then
        log_debug "压缩完成: $source -> $target"
        return 0
    else
        log_error "压缩失败: $source"
        return 1
    fi
}

# 解压文件
decompress_file() {
    local archive="$1"
    local target_dir="$2"
    
    if [[ ! -f "$archive" ]]; then
        log_error "压缩文件不存在: $archive"
        return 1
    fi
    
    ensure_dir "$target_dir" || return 1
    
    local tar_opts=""
    case "$archive" in
        *.tar.gz|*.tgz)
            tar_opts="-xzf"
            ;;
        *.tar.bz2|*.tbz2)
            tar_opts="-xjf"
            ;;
        *.tar.xz|*.txz)
            tar_opts="-xJf"
            ;;
        *.tar)
            tar_opts="-xf"
            ;;
        *)
            log_error "不支持的压缩格式: $archive"
            return 1
            ;;
    esac
    
    tar $tar_opts "$archive" -C "$target_dir" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log_debug "解压完成: $archive -> $target_dir"
        return 0
    else
        log_error "解压失败: $archive"
        return 1
    fi
}

# 计算文件哈希值
calculate_hash() {
    local file="$1"
    local algorithm="${2:-sha256}"  # md5, sha1, sha256, sha512
    
    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    case "$algorithm" in
        md5)
            if command_exists md5sum; then
                md5sum "$file" | cut -d' ' -f1
            elif command_exists md5; then
                md5 -q "$file"
            else
                log_error "MD5工具不可用"
                return 1
            fi
            ;;
        sha1)
            if command_exists sha1sum; then
                sha1sum "$file" | cut -d' ' -f1
            elif command_exists shasum; then
                shasum -a 1 "$file" | cut -d' ' -f1
            else
                log_error "SHA1工具不可用"
                return 1
            fi
            ;;
        sha256)
            if command_exists sha256sum; then
                sha256sum "$file" | cut -d' ' -f1
            elif command_exists shasum; then
                shasum -a 256 "$file" | cut -d' ' -f1
            else
                log_error "SHA256工具不可用"
                return 1
            fi
            ;;
        sha512)
            if command_exists sha512sum; then
                sha512sum "$file" | cut -d' ' -f1
            elif command_exists shasum; then
                shasum -a 512 "$file" | cut -d' ' -f1
            else
                log_error "SHA512工具不可用"
                return 1
            fi
            ;;
        *)
            log_error "不支持的哈希算法: $algorithm"
            return 1
            ;;
    esac
}

# 验证JSON格式
validate_json() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "JSON文件不存在: $file"
        return 1
    fi
    
    if command_exists jq; then
        jq empty "$file" >/dev/null 2>&1
        return $?
    elif command_exists python3; then
        python3 -m json.tool "$file" >/dev/null 2>&1
        return $?
    elif command_exists python; then
        python -m json.tool "$file" >/dev/null 2>&1
        return $?
    else
        log_warning "无法验证JSON格式：缺少jq或python工具"
        return 0  # 假设格式正确
    fi
}

# 格式化字节大小
format_bytes() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB" "PB")
    local unit_index=0
    
    while [[ $bytes -ge 1024 && $unit_index -lt $((${#units[@]} - 1)) ]]; do
        bytes=$((bytes / 1024))
        ((unit_index++))
    done
    
    echo "${bytes}${units[$unit_index]}"
}

# 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local prefix="${4:-Progress}"
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r%s: [" "$prefix"
    printf "%*s" "$filled" | tr ' ' '='
    printf "%*s" "$empty" | tr ' ' '-'
    printf "] %d%%" "$percentage"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# 等待用户确认
ask_confirmation() {
    local message="$1"
    local default="${2:-n}"  # y或n
    
    while true; do
        if [[ "$default" == "y" ]]; then
            echo -n "$message [Y/n]: "
        else
            echo -n "$message [y/N]: "
        fi
        
        read -r response
        response=${response,,}  # 转换为小写
        
        case "$response" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            "")
                if [[ "$default" == "y" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            *)
                echo "请回答 y 或 n"
                ;;
        esac
    done
}

# 设置陷阱函数进行清理
setup_cleanup_trap() {
    local cleanup_function="$1"
    
    # 在脚本退出时执行清理
    trap "$cleanup_function" EXIT
    trap "$cleanup_function" INT
    trap "$cleanup_function" TERM
}

# 检查必需的工具
check_required_tools() {
    local tools=("$@")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "缺少必需的工具: ${missing_tools[*]}"
        log_info "请安装缺失的工具后重试"
        return 1
    fi
    
    return 0
}

# 打印分割线
print_separator() {
    local char="${1:--}"
    local width="${2:-60}"
    printf "%*s\n" "$width" | tr ' ' "$char"
} 