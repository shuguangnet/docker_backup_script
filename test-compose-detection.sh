#!/bin/bash

# Docker Compose检测测试脚本
# 用于测试备份脚本的docker-compose检测功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# 检测容器是否由docker-compose管理
detect_docker_compose() {
    local container_name="$1"
    
    # 方法1: 检查容器标签
    local compose_project=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}' "${container_name}" 2>/dev/null || echo "")
    local compose_service=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.service"}}' "${container_name}" 2>/dev/null || echo "")
    
    if [[ -n "${compose_project}" && -n "${compose_service}" ]]; then
        echo "${compose_project}:${compose_service}"
        return 0
    fi
    
    # 方法2: 检查容器名称模式 (project_service_number)
    if [[ "${container_name}" =~ ^([a-zA-Z0-9_-]+)_([a-zA-Z0-9_-]+)_[0-9]+$ ]]; then
        local project="${BASH_REMATCH[1]}"
        local service="${BASH_REMATCH[2]}"
        echo "${project}:${service}"
        return 0
    fi
    
    # 方法3: 检查网络名称
    local networks=$(docker inspect --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' "${container_name}" 2>/dev/null || echo "")
    for network in ${networks}; do
        if [[ "${network}" =~ ^([a-zA-Z0-9_-]+)_default$ ]]; then
            local project="${BASH_REMATCH[1]}"
            echo "${project}:unknown"
            return 0
        fi
    done
    
    return 1
}

# 主函数
main() {
    log_info "Docker Compose检测测试"
    log_info "======================"
    
    # 检查Docker是否可用
    if ! command -v docker >/dev/null 2>&1; then
        log_error "未找到Docker命令"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker未运行或无法访问"
        exit 1
    fi
    
    # 获取所有运行中的容器
    local containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [[ -z "$containers" ]]; then
        log_warning "未找到运行中的容器"
        exit 0
    fi
    
    log_info "检测结果："
    echo ""
    
    local compose_count=0
    local normal_count=0
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "容器: $container -> "
            
            if compose_info=$(detect_docker_compose "$container"); then
                local project_name=$(echo "$compose_info" | cut -d: -f1)
                local service_name=$(echo "$compose_info" | cut -d: -f2)
                
                log_success "Docker Compose (项目: $project_name, 服务: $service_name)"
                ((compose_count++))
            else
                log_info "普通Docker容器"
                ((normal_count++))
            fi
        fi
    done <<< "$containers"
    
    echo ""
    log_info "统计结果："
    log_info "  Docker Compose容器: $compose_count"
    log_info "  普通Docker容器: $normal_count"
    log_info "  总计: $((compose_count + normal_count))"
    
    if [[ $compose_count -gt 0 ]]; then
        echo ""
        log_info "Docker Compose容器详情："
        while IFS= read -r container; do
            if [[ -n "$container" ]]; then
                if compose_info=$(detect_docker_compose "$container"); then
                    local project_name=$(echo "$compose_info" | cut -d: -f1)
                    local service_name=$(echo "$compose_info" | cut -d: -f2)
                    
                    echo "  $container -> $project_name:$service_name"
                    
                    # 显示compose标签
                    local compose_project=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}' "$container" 2>/dev/null || echo "")
                    local compose_service=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.service"}}' "$container" 2>/dev/null || echo "")
                    
                    if [[ -n "$compose_project" ]]; then
                        echo "    标签: com.docker.compose.project=$compose_project"
                    fi
                    if [[ -n "$compose_service" ]]; then
                        echo "    标签: com.docker.compose.service=$compose_service"
                    fi
                    
                    # 显示网络信息
                    local networks=$(docker inspect --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' "$container" 2>/dev/null || echo "")
                    if [[ -n "$networks" ]]; then
                        echo "    网络: $networks"
                    fi
                    echo ""
                fi
            fi
        done <<< "$containers"
    fi
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 