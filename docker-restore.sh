#!/bin/bash

# Docker容器恢复脚本
# 作者: Docker Backup Tool
# 版本: 1.0
# 描述: 从备份包恢复Docker容器、挂载点和数据卷

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查是否存在工具函数库
if [[ -f "${SCRIPT_DIR}/backup-utils.sh" ]]; then
    source "${SCRIPT_DIR}/backup-utils.sh"
else
    # 如果没有工具库，定义基本的日志函数
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warning() { echo "[WARNING] $1" >&2; }
fi

# 颜色定义（如果没有工具库）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示使用说明
show_usage() {
    cat << EOF
用法: $0 [选项] <备份目录路径>

选项:
    -h, --help                  显示此帮助信息
    -f, --force                 强制恢复（覆盖现有容器和数据）
    -v, --verbose              详细输出模式
    -n, --no-start             恢复后不自动启动容器
    --no-volumes               跳过数据卷恢复
    --no-mounts                跳过挂载点恢复
    --no-images                跳过镜像恢复
    --container-name NAME      指定恢复后的容器名称
    --backup-name PATTERN      指定要恢复的备份模式

示例:
    $0 /path/to/backup/nginx_20231201_120000        # 恢复指定备份
    $0 -f /path/to/backup/nginx_20231201_120000     # 强制恢复（覆盖现有）
    $0 --no-start /path/to/backup/nginx_20231201_120000  # 恢复但不启动
    $0 --container-name new-nginx /path/to/backup/nginx_20231201_120000  # 指定新名称

备份目录结构:
    backup_dir/
    ├── config/          # 容器配置文件
    ├── volumes/         # 数据卷备份
    ├── mounts/          # 挂载点备份
    ├── logs/            # 容器日志
    ├── restore.sh       # 自动生成的恢复脚本
    └── backup_summary.txt  # 备份摘要

EOF
}

# 解析命令行参数
parse_arguments() {
    BACKUP_DIR=""
    FORCE=false
    VERBOSE=false
    NO_START=false
    NO_VOLUMES=false
    NO_MOUNTS=false
    NO_IMAGES=false
    CUSTOM_CONTAINER_NAME=""
    BACKUP_PATTERN=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--no-start)
                NO_START=true
                shift
                ;;
            --no-volumes)
                NO_VOLUMES=true
                shift
                ;;
            --no-mounts)
                NO_MOUNTS=true
                shift
                ;;
            --no-images)
                NO_IMAGES=true
                shift
                ;;
            --container-name)
                CUSTOM_CONTAINER_NAME="$2"
                shift 2
                ;;
            --backup-name)
                BACKUP_PATTERN="$2"
                shift 2
                ;;
            -*)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$BACKUP_DIR" ]]; then
                    BACKUP_DIR="$1"
                else
                    log_error "只能指定一个备份目录"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # 验证参数
    if [[ -z "$BACKUP_DIR" ]]; then
        log_error "请指定备份目录路径"
        show_usage
        exit 1
    fi
}

# 验证备份目录
validate_backup_dir() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    # 检查必需的目录结构
    local required_dirs=("config")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$backup_dir/$dir" ]]; then
            log_error "备份目录结构不完整，缺少: $dir"
            return 1
        fi
    done
    
    # 检查关键配置文件
    if [[ ! -f "$backup_dir/config/container_inspect.json" ]]; then
        log_error "备份目录缺少容器配置文件"
        return 1
    fi
    
    return 0
}

# 获取容器信息
get_container_info() {
    local backup_dir="$1"
    local config_file="$backup_dir/config/container_inspect.json"
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "需要安装 jq 工具来解析配置文件"
        exit 1
    fi
    
    # 从备份目录名提取原始容器名
    ORIGINAL_CONTAINER_NAME=$(basename "$backup_dir" | sed 's/_[0-9]*_[0-9]*$//')
    
    # 使用自定义名称或原始名称
    CONTAINER_NAME="${CUSTOM_CONTAINER_NAME:-$ORIGINAL_CONTAINER_NAME}"
    
    # 获取镜像信息
    CONTAINER_IMAGE=$(jq -r '.[0].Config.Image' "$config_file" 2>/dev/null || echo "")
    
    # 获取端口配置
    CONTAINER_PORTS=$(jq -r '.[0].NetworkSettings.Ports // {} | to_entries[] | "\(.key):\(.value[0].HostPort // "")"' "$config_file" 2>/dev/null | tr '\n' ' ' || echo "")
    
    # 获取环境变量
    CONTAINER_ENV=$(jq -r '.[0].Config.Env[]?' "$config_file" 2>/dev/null | tr '\n' ' ' || echo "")
    
    # 获取挂载信息
    CONTAINER_MOUNTS=$(jq -c '.[0].Mounts[]?' "$config_file" 2>/dev/null || echo "")
    
    log_info "容器信息:"
    log_info "  原始名称: $ORIGINAL_CONTAINER_NAME"
    log_info "  恢复名称: $CONTAINER_NAME"
    log_info "  镜像: $CONTAINER_IMAGE"
    [[ -n "$CONTAINER_PORTS" ]] && log_info "  端口: $CONTAINER_PORTS"
}

# 检查容器冲突
check_container_conflicts() {
    local container_name="$1"
    
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        if [[ "$FORCE" == true ]]; then
            log_warning "强制模式：将删除现有容器 '$container_name'"
            
            # 停止容器
            if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
                log_info "停止现有容器..."
                docker stop "$container_name" >/dev/null 2>&1 || true
            fi
            
            # 删除容器
            log_info "删除现有容器..."
            docker rm "$container_name" >/dev/null 2>&1 || true
            
        else
            log_error "容器 '$container_name' 已存在，使用 -f 选项强制覆盖"
            exit 1
        fi
    fi
}

# 恢复镜像
restore_image() {
    local backup_dir="$1"
    
    if [[ "$NO_IMAGES" == true ]]; then
        log_info "跳过镜像恢复（--no-images）"
        return 0
    fi
    
    # 查找镜像备份文件
    local image_file=""
    for file in "$backup_dir"/*.tar.gz; do
        if [[ -f "$file" && "$(basename "$file")" == *"_image.tar.gz" ]]; then
            image_file="$file"
            break
        fi
    done
    
    if [[ -n "$image_file" ]]; then
        log_info "恢复Docker镜像: $(basename "$image_file")"
        
        if gunzip -c "$image_file" | docker load; then
            log_success "镜像恢复成功"
        else
            log_warning "镜像恢复失败，将尝试从Docker Hub拉取"
            if [[ -n "$CONTAINER_IMAGE" ]]; then
                docker pull "$CONTAINER_IMAGE" || {
                    log_error "无法拉取镜像: $CONTAINER_IMAGE"
                    return 1
                }
            fi
        fi
    else
        log_info "未找到镜像备份文件"
        if [[ -n "$CONTAINER_IMAGE" ]]; then
            log_info "尝试从Docker Hub拉取镜像: $CONTAINER_IMAGE"
            docker pull "$CONTAINER_IMAGE" || {
                log_warning "无法拉取镜像，请手动处理"
            }
        fi
    fi
    
    return 0
}

# 恢复数据卷
restore_volumes() {
    local backup_dir="$1"
    local volumes_dir="$backup_dir/volumes"
    
    if [[ "$NO_VOLUMES" == true ]]; then
        log_info "跳过数据卷恢复（--no-volumes）"
        return 0
    fi
    
    if [[ ! -d "$volumes_dir" ]]; then
        log_info "未找到数据卷备份"
        return 0
    fi
    
    log_info "恢复数据卷..."
    
    for volume_file in "$volumes_dir"/*.tar.gz; do
        if [[ -f "$volume_file" ]]; then
            local volume_name=$(basename "$volume_file" .tar.gz)
            log_info "  恢复数据卷: $volume_name"
            
            # 如果卷已存在且不是强制模式，跳过
            if docker volume ls --format "{{.Name}}" | grep -q "^${volume_name}$"; then
                if [[ "$FORCE" == true ]]; then
                    log_warning "  强制删除现有数据卷: $volume_name"
                    docker volume rm "$volume_name" >/dev/null 2>&1 || true
                else
                    log_warning "  数据卷已存在，跳过: $volume_name"
                    continue
                fi
            fi
            
            # 创建数据卷
            docker volume create "$volume_name" >/dev/null 2>&1
            
            # 恢复数据
            if docker run --rm -v "$volume_name:/data" -v "$volumes_dir:/backup" \
                alpine:latest tar -xzf "/backup/$(basename "$volume_file")" -C /data 2>/dev/null; then
                log_success "  数据卷 '$volume_name' 恢复成功"
            else
                log_error "  数据卷 '$volume_name' 恢复失败"
            fi
        fi
    done
}

# 恢复挂载点
restore_mounts() {
    local backup_dir="$1"
    local mounts_dir="$backup_dir/mounts"
    
    if [[ "$NO_MOUNTS" == true ]]; then
        log_info "跳过挂载点恢复（--no-mounts）"
        return 0
    fi
    
    if [[ ! -d "$mounts_dir" ]]; then
        log_info "未找到挂载点备份"
        return 0
    fi
    
    log_info "恢复挂载点..."
    
    for mount_dir in "$mounts_dir"/mount_*; do
        if [[ -d "$mount_dir" ]]; then
            local mount_info="$mount_dir/mount_info.json"
            
            if [[ -f "$mount_info" ]]; then
                local source_path=$(jq -r '.Source' "$mount_info" 2>/dev/null || echo "")
                local destination=$(jq -r '.Destination' "$mount_info" 2>/dev/null || echo "")
                
                if [[ -n "$source_path" ]]; then
                    log_info "  恢复挂载点: $source_path -> $destination"
                    
                    # 检查目标路径是否已存在
                    if [[ -e "$source_path" ]] && [[ "$FORCE" != true ]]; then
                        log_warning "  挂载点目标已存在，跳过: $source_path"
                        continue
                    fi
                    
                    # 创建目录结构
                    mkdir -p "$(dirname "$source_path")"
                    
                    # 恢复数据
                    if [[ -f "$mount_dir/data.tar.gz" ]]; then
                        if tar -xzf "$mount_dir/data.tar.gz" -C "$(dirname "$source_path")" 2>/dev/null; then
                            log_success "  挂载点目录恢复成功: $source_path"
                        else
                            log_error "  挂载点目录恢复失败: $source_path"
                        fi
                    elif [[ -f "$mount_dir/data.file" ]]; then
                        if cp "$mount_dir/data.file" "$source_path" 2>/dev/null; then
                            log_success "  挂载点文件恢复成功: $source_path"
                        else
                            log_error "  挂载点文件恢复失败: $source_path"
                        fi
                    else
                        log_warning "  未找到挂载点数据文件"
                    fi
                fi
            fi
        fi
    done
}

# 生成Docker运行命令
generate_docker_command() {
    local backup_dir="$1"
    local config_file="$backup_dir/config/container_inspect.json"
    
    log_info "生成Docker运行命令..."
    
    # 基础命令
    local docker_cmd="docker run -d --name $CONTAINER_NAME"
    
    # 添加端口映射
    while IFS= read -r port_mapping; do
        if [[ -n "$port_mapping" ]]; then
            local container_port=$(echo "$port_mapping" | cut -d: -f1)
            local host_port=$(echo "$port_mapping" | cut -d: -f2)
            if [[ -n "$host_port" ]]; then
                docker_cmd="$docker_cmd -p $host_port:$container_port"
            fi
        fi
    done <<< "$CONTAINER_PORTS"
    
    # 添加环境变量
    while IFS= read -r env_var; do
        if [[ -n "$env_var" ]]; then
            docker_cmd="$docker_cmd -e '$env_var'"
        fi
    done <<< "$CONTAINER_ENV"
    
    # 添加挂载点和数据卷
    while IFS= read -r mount_info; do
        if [[ -n "$mount_info" ]]; then
            local mount_type=$(echo "$mount_info" | jq -r '.Type' 2>/dev/null || echo "")
            local source=$(echo "$mount_info" | jq -r '.Source' 2>/dev/null || echo "")
            local destination=$(echo "$mount_info" | jq -r '.Destination' 2>/dev/null || echo "")
            
            if [[ "$mount_type" == "bind" ]]; then
                docker_cmd="$docker_cmd -v $source:$destination"
            elif [[ "$mount_type" == "volume" ]]; then
                local volume_name=$(echo "$mount_info" | jq -r '.Name' 2>/dev/null || echo "")
                if [[ -n "$volume_name" ]]; then
                    docker_cmd="$docker_cmd -v $volume_name:$destination"
                fi
            fi
        fi
    done <<< "$CONTAINER_MOUNTS"
    
    # 添加镜像
    docker_cmd="$docker_cmd $CONTAINER_IMAGE"
    
    # 保存命令到文件
    echo "$docker_cmd" > "$backup_dir/generated_run_command.sh"
    chmod +x "$backup_dir/generated_run_command.sh"
    
    log_info "Docker运行命令已保存到: $backup_dir/generated_run_command.sh"
    
    echo "$docker_cmd"
}

# 启动容器
start_container() {
    local docker_cmd="$1"
    
    if [[ "$NO_START" == true ]]; then
        log_info "跳过容器启动（--no-start）"
        log_info "手动启动命令: $docker_cmd"
        return 0
    fi
    
    log_info "启动容器: $CONTAINER_NAME"
    
    # 执行Docker命令
    if eval "$docker_cmd"; then
        log_success "容器启动成功: $CONTAINER_NAME"
        
        # 等待几秒钟检查容器状态
        sleep 3
        
        local status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
        log_info "容器状态: $status"
        
        if [[ "$status" == "running" ]]; then
            log_success "容器正在正常运行"
        else
            log_warning "容器可能未正常启动，请检查日志"
            log_info "查看日志命令: docker logs $CONTAINER_NAME"
        fi
        
    else
        log_error "容器启动失败"
        log_info "请检查Docker运行命令: $docker_cmd"
        return 1
    fi
}

# 显示恢复摘要
show_restore_summary() {
    local backup_dir="$1"
    
    print_separator "=" 60
    log_success "Docker容器恢复完成"
    print_separator "=" 60
    
    echo "恢复摘要:"
    echo "  备份来源: $backup_dir"
    echo "  原始容器: $ORIGINAL_CONTAINER_NAME"
    echo "  恢复名称: $CONTAINER_NAME"
    echo "  容器镜像: $CONTAINER_IMAGE"
    
    if [[ "$NO_START" != true ]]; then
        echo ""
        echo "容器管理命令:"
        echo "  查看状态: docker ps -a | grep $CONTAINER_NAME"
        echo "  查看日志: docker logs $CONTAINER_NAME"
        echo "  停止容器: docker stop $CONTAINER_NAME"
        echo "  启动容器: docker start $CONTAINER_NAME"
        echo "  删除容器: docker rm $CONTAINER_NAME"
    else
        echo ""
        echo "容器已准备就绪但未启动"
        echo "手动启动: bash $backup_dir/generated_run_command.sh"
    fi
    
    print_separator "=" 60
}

# 清理函数
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "恢复过程中发生错误"
    fi
    
    exit $exit_code
}

# 主函数
main() {
    log_info "Docker容器恢复工具启动"
    
    # 设置清理陷阱
    trap cleanup EXIT INT TERM
    
    # 检查Docker是否可用
    if ! command -v docker >/dev/null 2>&1; then
        log_error "未找到Docker命令"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker未运行或无法访问"
        exit 1
    fi
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 验证备份目录
    validate_backup_dir "$BACKUP_DIR"
    
    # 获取容器信息
    get_container_info "$BACKUP_DIR"
    
    # 检查容器冲突
    check_container_conflicts "$CONTAINER_NAME"
    
    # 恢复各个组件
    restore_image "$BACKUP_DIR"
    restore_volumes "$BACKUP_DIR"
    restore_mounts "$BACKUP_DIR"
    
    # 生成并执行Docker命令
    local docker_cmd=$(generate_docker_command "$BACKUP_DIR")
    start_container "$docker_cmd"
    
    # 显示恢复摘要
    show_restore_summary "$BACKUP_DIR"
    
    return 0
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 