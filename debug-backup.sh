#!/bin/bash

# Docker备份调试脚本
# 用于快速测试和诊断问题

set -e

# 基本变量
BACKUP_DIR="/tmp/docker-backups-debug"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# 获取所有容器
get_all_containers() {
    log_info "获取容器列表..."
    local containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [[ -n "$containers" ]]; then
        echo "$containers"
    else
        log_error "未找到运行中的容器"
        return 1
    fi
}

# 简化的备份函数（只备份配置）
backup_container_simple() {
    local container_name="$1"
    local backup_dir="$2"
    
    log_info "备份容器配置: $container_name"
    
    # 创建备份目录
    mkdir -p "$backup_dir"
    
    # 备份配置
    if docker inspect "$container_name" > "$backup_dir/config.json" 2>/dev/null; then
        log_success "✓ 配置备份完成: $container_name"
        return 0
    else
        log_error "✗ 配置备份失败: $container_name"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始调试备份流程..."
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 获取容器列表
    local containers_to_backup
    mapfile -t containers_to_backup < <(get_all_containers)
    
    log_info "找到 ${#containers_to_backup[@]} 个容器:"
    for i in "${!containers_to_backup[@]}"; do
        echo "  $((i+1)). ${containers_to_backup[i]}"
    done
    
    echo
    log_info "开始逐个备份..."
    
    # 备份每个容器
    local success_count=0
    local total_count=${#containers_to_backup[@]}
    
    for container in "${containers_to_backup[@]}"; do
        local container_backup_dir="$BACKUP_DIR/${container}_$TIMESTAMP"
        
        log_info "[$((success_count + 1))/$total_count] 处理: $container"
        
        if backup_container_simple "$container" "$container_backup_dir"; then
            ((success_count++))
            log_info "当前进度: $success_count/$total_count 完成"
        else
            log_error "备份失败: $container"
        fi
        
        echo "---"
    done
    
    echo
    log_success "调试备份完成!"
    log_info "成功: $success_count/$total_count"
    log_info "备份位置: $BACKUP_DIR"
    
    # 显示备份结果
    echo
    echo "备份文件列表:"
    ls -la "$BACKUP_DIR"
}

# 运行
main "$@" 