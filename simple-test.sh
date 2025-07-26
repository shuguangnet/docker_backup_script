#!/bin/bash

# 简化的测试脚本，逐步模拟备份过程
set -e

# 基本设置
BACKUP_DIR="/tmp/docker-backups-test"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# 获取容器列表
get_containers() {
    local containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [[ -n "$containers" ]]; then
        echo "$containers"
    else
        log_error "未找到运行中的容器"
        return 1
    fi
}

# 模拟备份单个容器的关键步骤
test_backup_container() {
    local container_name="$1"
    local container_backup_dir="$2"
    
    log_info "测试备份容器: ${container_name}"
    
    # 步骤1：创建备份目录
    echo "  步骤1: 创建备份目录"
    mkdir -p "${container_backup_dir}"/{config,volumes,mounts,logs}
    
    # 步骤2：备份配置
    echo "  步骤2: 备份容器配置"
    if docker inspect "${container_name}" > "${container_backup_dir}/config/container_inspect.json" 2>/dev/null; then
        echo "  ✓ 配置备份成功"
    else
        echo "  ✗ 配置备份失败"
        return 1
    fi
    
    # 步骤3：获取挂载信息
    echo "  步骤3: 获取挂载信息"
    if docker inspect --format='{{json .Mounts}}' "${container_name}" > "${container_backup_dir}/config/mounts.json" 2>/dev/null; then
        echo "  ✓ 挂载信息获取成功"
    else
        echo "  ✗ 挂载信息获取失败"
    fi
    
    # 步骤4：收集日志
    echo "  步骤4: 收集容器日志"
    if docker logs --tail 100 "${container_name}" > "${container_backup_dir}/logs/container.log" 2>&1; then
        echo "  ✓ 日志收集成功"
    else
        echo "  ✗ 日志收集失败"
    fi
    
    # 步骤5：创建恢复脚本
    echo "  步骤5: 创建恢复脚本"
    cat > "${container_backup_dir}/restore.sh" << 'EOF'
#!/bin/bash
echo "这是一个测试恢复脚本"
EOF
    chmod +x "${container_backup_dir}/restore.sh"
    echo "  ✓ 恢复脚本创建成功"
    
    # 步骤6：创建摘要（这里是问题可能出现的地方）
    echo "  步骤6: 创建备份摘要"
    cat > "${container_backup_dir}/backup_summary.txt" << EOF
Docker容器备份摘要
==================

备份时间: $(date)
容器名称: ${container_name}
备份目录: ${container_backup_dir}

备份大小: $(du -sh "${container_backup_dir}" 2>/dev/null | cut -f1 || echo "计算中...")
EOF
    echo "  ✓ 备份摘要创建成功"
    
    log_success "容器 '${container_name}' 测试备份完成"
    echo "  → 函数正常返回"
    
    return 0
}

# 主函数
main() {
    log_info "开始简化备份测试..."
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 获取容器列表
    local containers_to_backup
    mapfile -t containers_to_backup < <(get_containers)
    
    if [[ ${#containers_to_backup[@]} -eq 0 ]]; then
        log_error "未找到要备份的容器"
        exit 1
    fi
    
    log_info "找到 ${#containers_to_backup[@]} 个容器: ${containers_to_backup[*]}"
    
    # 处理每个容器
    local success_count=0
    local total_count=${#containers_to_backup[@]}
    
    for container in "${containers_to_backup[@]}"; do
        local container_backup_dir="${BACKUP_DIR}/${container}_${TIMESTAMP}"
        
        log_info "[$((success_count + 1))/$total_count] 开始处理: $container"
        
        if test_backup_container "$container" "$container_backup_dir"; then
            ((success_count++))
            log_info "✓ 容器 '$container' 处理成功 ($success_count/$total_count)"
        else
            log_error "✗ 容器 '$container' 处理失败"
        fi
        
        echo "---"
        
        # 为了调试，只处理前3个容器
        if [[ $success_count -ge 3 ]]; then
            log_info "调试模式：只处理前3个容器"
            break
        fi
    done
    
    echo
    log_success "测试完成!"
    log_info "成功处理: $success_count/$total_count 个容器"
    log_info "测试结果保存在: $BACKUP_DIR"
    
    echo
    echo "如果这个测试脚本能正常处理多个容器，说明问题在原脚本的某个特定函数中。"
    echo "如果这个测试也只处理一个容器，说明是系统级别的问题。"
}

# 运行测试
main "$@" 