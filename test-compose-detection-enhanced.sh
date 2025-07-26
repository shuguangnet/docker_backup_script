#!/bin/bash

# 增强版Docker Compose检测测试脚本
# 用于测试改进后的docker-compose检测功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }

# 检测容器是否由docker-compose管理（复制自docker-backup.sh）
detect_docker_compose() {
    local container_name="$1"
    
    # 方法1: 检查容器标签（最准确的方法）
    local compose_project=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}' "${container_name}" 2>/dev/null || echo "")
    local compose_service=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.service"}}' "${container_name}" 2>/dev/null || echo "")
    
    if [[ -n "${compose_project}" && -n "${compose_service}" ]]; then
        echo "${compose_project}:${compose_service}"
        return 0
    fi
    
    # 方法2: 检查其他compose相关标签
    local compose_version=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.version"}}' "${container_name}" 2>/dev/null || echo "")
    local compose_config_files=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.config_files"}}' "${container_name}" 2>/dev/null || echo "")
    
    if [[ -n "${compose_version}" || -n "${compose_config_files}" ]]; then
        # 尝试从容器名称推断项目和服务名
        if [[ "${container_name}" =~ ^([a-zA-Z0-9_-]+)_([a-zA-Z0-9_-]+)_[0-9]+$ ]]; then
            local project="${BASH_REMATCH[1]}"
            local service="${BASH_REMATCH[2]}"
            echo "${project}:${service}"
            return 0
        elif [[ "${container_name}" =~ ^([a-zA-Z0-9_-]+)_([a-zA-Z0-9_-]+)$ ]]; then
            local project="${BASH_REMATCH[1]}"
            local service="${BASH_REMATCH[2]}"
            echo "${project}:${service}"
            return 0
        fi
    fi
    
    # 方法3: 检查容器名称模式（更宽松的匹配）
    if [[ "${container_name}" =~ ^([a-zA-Z0-9_-]+)_([a-zA-Z0-9_-]+)_[0-9]+$ ]]; then
        local project="${BASH_REMATCH[1]}"
        local service="${BASH_REMATCH[2]}"
        echo "${project}:${service}"
        return 0
    elif [[ "${container_name}" =~ ^([a-zA-Z0-9_-]+)_([a-zA-Z0-9_-]+)$ ]]; then
        local project="${BASH_REMATCH[1]}"
        local service="${BASH_REMATCH[2]}"
        echo "${project}:${service}"
        return 0
    fi
    
    # 方法4: 检查网络名称（更全面的网络检测）
    local networks=$(docker inspect --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' "${container_name}" 2>/dev/null || echo "")
    for network in ${networks}; do
        # 检查常见的compose网络模式
        if [[ "${network}" =~ ^([a-zA-Z0-9_-]+)_default$ ]]; then
            local project="${BASH_REMATCH[1]}"
            echo "${project}:unknown"
            return 0
        elif [[ "${network}" =~ ^([a-zA-Z0-9_-]+)_network$ ]]; then
            local project="${BASH_REMATCH[1]}"
            echo "${project}:unknown"
            return 0
        elif [[ "${network}" =~ ^([a-zA-Z0-9_-]+)_([a-zA-Z0-9_-]+)_network$ ]]; then
            local project="${BASH_REMATCH[1]}"
            local service="${BASH_REMATCH[2]}"
            echo "${project}:${service}"
            return 0
        fi
    done
    
    # 方法5: 检查容器的工作目录和挂载点
    local working_dir=$(docker inspect --format='{{.Config.WorkingDir}}' "${container_name}" 2>/dev/null || echo "")
    if [[ -n "${working_dir}" ]]; then
        # 检查工作目录是否包含compose相关路径
        if [[ "${working_dir}" =~ /([a-zA-Z0-9_-]+)/?$ ]]; then
            local project="${BASH_REMATCH[1]}"
            # 尝试从容器名称提取服务名
            if [[ "${container_name}" =~ ^.*_([a-zA-Z0-9_-]+)(_[0-9]+)?$ ]]; then
                local service="${BASH_REMATCH[1]}"
                echo "${project}:${service}"
                return 0
            else
                echo "${project}:unknown"
                return 0
            fi
        fi
    fi
    
    # 方法6: 检查挂载点路径
    local mounts=$(docker inspect --format='{{json .Mounts}}' "${container_name}" 2>/dev/null || echo "[]")
    if [[ -n "${mounts}" && "${mounts}" != "[]" ]]; then
        # 从挂载点路径推断项目名
        local mount_paths=$(echo "${mounts}" | jq -r '.[].Source' 2>/dev/null || echo "")
        for mount_path in ${mount_paths}; do
            if [[ "${mount_path}" =~ /([a-zA-Z0-9_-]+)/[a-zA-Z0-9_-]+/?$ ]]; then
                local project="${BASH_REMATCH[1]}"
                # 检查这个项目是否真的有compose文件
                if find /opt /home /root /app /srv /var/www -maxdepth 3 -name "*${project}*" -type d 2>/dev/null | grep -q .; then
                    if [[ "${container_name}" =~ ^.*_([a-zA-Z0-9_-]+)(_[0-9]+)?$ ]]; then
                        local service="${BASH_REMATCH[1]}"
                        echo "${project}:${service}"
                        return 0
                    else
                        echo "${project}:unknown"
                        return 0
                    fi
                fi
            fi
        done
    fi
    
    return 1
}

# 显示容器详细信息
show_container_details() {
    local container_name="$1"
    
    echo "  ┌─ 容器名称: $container_name"
    
    # 显示compose标签
    local compose_project=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}' "$container_name" 2>/dev/null || echo "")
    local compose_service=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.service"}}' "$container_name" 2>/dev/null || echo "")
    local compose_version=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.version"}}' "$container_name" 2>/dev/null || echo "")
    local compose_config_files=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.config_files"}}' "$container_name" 2>/dev/null || echo "")
    
    if [[ -n "$compose_project" ]]; then
        echo "  ├─ Compose项目: $compose_project"
    fi
    if [[ -n "$compose_service" ]]; then
        echo "  ├─ Compose服务: $compose_service"
    fi
    if [[ -n "$compose_version" ]]; then
        echo "  ├─ Compose版本: $compose_version"
    fi
    if [[ -n "$compose_config_files" ]]; then
        echo "  ├─ Compose配置文件: $compose_config_files"
    fi
    
    # 显示网络信息
    local networks=$(docker inspect --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' "$container_name" 2>/dev/null || echo "")
    if [[ -n "$networks" ]]; then
        echo "  ├─ 网络: $networks"
    fi
    
    # 显示工作目录
    local working_dir=$(docker inspect --format='{{.Config.WorkingDir}}' "$container_name" 2>/dev/null || echo "")
    if [[ -n "$working_dir" && "$working_dir" != "/" ]]; then
        echo "  ├─ 工作目录: $working_dir"
    fi
    
    # 显示挂载点
    local mounts=$(docker inspect --format='{{json .Mounts}}' "$container_name" 2>/dev/null || echo "[]")
    if [[ -n "$mounts" && "$mounts" != "[]" ]]; then
        local mount_count=$(echo "$mounts" | jq '. | length' 2>/dev/null || echo "0")
        echo "  ├─ 挂载点数量: $mount_count"
        
        # 显示前几个挂载点
        local mount_paths=$(echo "$mounts" | jq -r '.[0:3][].Source' 2>/dev/null || echo "")
        if [[ -n "$mount_paths" ]]; then
            echo "$mount_paths" | while IFS= read -r mount_path; do
                if [[ -n "$mount_path" ]]; then
                    echo "  │  └─ $mount_path"
                fi
            done
        fi
    fi
    
    echo "  └─"
}

# 主函数
main() {
    log_info "增强版Docker Compose检测测试"
    log_info "============================"
    
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
    local detection_methods=()
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "容器: $container -> "
            
            if compose_info=$(detect_docker_compose "$container"); then
                local project_name=$(echo "$compose_info" | cut -d: -f1)
                local service_name=$(echo "$compose_info" | cut -d: -f2)
                
                log_success "Docker Compose (项目: $project_name, 服务: $service_name)"
                ((compose_count++))
                
                # 记录检测方法
                local method=""
                local compose_project=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}' "$container" 2>/dev/null || echo "")
                if [[ -n "$compose_project" ]]; then
                    method="标签检测"
                elif [[ "$container" =~ ^([a-zA-Z0-9_-]+)_([a-zA-Z0-9_-]+)_[0-9]+$ ]]; then
                    method="名称模式匹配"
                elif [[ "$container" =~ ^([a-zA-Z0-9_-]+)_([a-zA-Z0-9_-]+)$ ]]; then
                    method="名称模式匹配"
                else
                    method="其他方法"
                fi
                detection_methods+=("$container: $method")
                
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
                    show_container_details "$container"
                    echo ""
                fi
            fi
        done <<< "$containers"
        
        echo ""
        log_info "检测方法分析："
        for method in "${detection_methods[@]}"; do
            echo "  $method"
        done
    fi
    
    echo ""
    log_info "检测方法说明："
    echo "  1. 标签检测: 检查com.docker.compose.*标签（最准确）"
    echo "  2. 名称模式匹配: 匹配project_service_number或project_service模式"
    echo "  3. 网络检测: 检查project_default等网络模式"
    echo "  4. 工作目录检测: 从容器工作目录推断项目名"
    echo "  5. 挂载点检测: 从挂载路径推断项目名"
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 