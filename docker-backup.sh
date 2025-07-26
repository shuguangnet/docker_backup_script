#!/bin/bash

# Docker容器备份脚本
# 作者: Docker Backup Tool
# 版本: 1.0
# 描述: 备份Docker容器的完整配置、挂载点和数据卷

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup-utils.sh"

# 默认配置
DEFAULT_BACKUP_DIR="/tmp/docker-backups"
DEFAULT_CONFIG_FILE="${SCRIPT_DIR}/backup.conf"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示使用说明
show_usage() {
    cat << EOF
用法: $0 [选项] [容器名称或ID...]

选项:
    -h, --help              显示此帮助信息
    -c, --config FILE       指定配置文件 (默认: ${DEFAULT_CONFIG_FILE})
    -o, --output DIR        指定备份输出目录 (默认: ${DEFAULT_BACKUP_DIR})
    -a, --all              备份所有运行中的容器
    -f, --full             完整备份模式（包含镜像）
    -v, --verbose          详细输出模式
    --exclude-volumes      排除数据卷备份
    --exclude-mounts       排除挂载点备份

示例:
    $0 nginx mysql                    # 备份指定容器
    $0 -a                            # 备份所有运行中的容器
    $0 -f nginx                      # 完整备份nginx容器（包含镜像）
    $0 -o /backup nginx              # 指定备份目录

EOF
}

# 解析命令行参数
parse_arguments() {
    BACKUP_DIR="${DEFAULT_BACKUP_DIR}"
    CONFIG_FILE="${DEFAULT_CONFIG_FILE}"
    CONTAINERS=()
    BACKUP_ALL=false
    FULL_BACKUP=false
    VERBOSE=false
    EXCLUDE_VOLUMES=false
    EXCLUDE_MOUNTS=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -o|--output)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -a|--all)
                BACKUP_ALL=true
                shift
                ;;
            -f|--full)
                FULL_BACKUP=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --exclude-volumes)
                EXCLUDE_VOLUMES=true
                shift
                ;;
            --exclude-mounts)
                EXCLUDE_MOUNTS=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
            *)
                CONTAINERS+=("$1")
                shift
                ;;
        esac
    done

    # 验证参数
    if [[ "${BACKUP_ALL}" == false && ${#CONTAINERS[@]} -eq 0 ]]; then
        log_error "请指定要备份的容器名称或使用 -a 选项备份所有容器"
        show_usage
        exit 1
    fi
}

# 获取容器列表
get_containers() {
    if [[ "${BACKUP_ALL}" == true ]]; then
        # 获取所有运行中的容器
        docker ps --format "{{.Names}}" | grep -v '^$' || true
    else
        # 验证指定的容器是否存在
        for container in "${CONTAINERS[@]}"; do
            if ! docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
                log_error "容器 '${container}' 不存在"
                exit 1
            fi
            echo "${container}"
        done
    fi
}

# 创建备份目录结构
create_backup_structure() {
    local backup_root="$1"
    local container_name="$2"
    
    local container_backup_dir="${backup_root}/${container_name}_${TIMESTAMP}"
    
    mkdir -p "${container_backup_dir}"/{config,volumes,mounts,logs}
    
    echo "${container_backup_dir}"
}

# 备份容器配置
backup_container_config() {
    local container_name="$1"
    local backup_dir="$2"
    
    log_info "备份容器 '${container_name}' 的配置信息..."
    
    # 容器详细信息
    docker inspect "${container_name}" > "${backup_dir}/config/container_inspect.json"
    
    # 提取关键配置信息
    cat > "${backup_dir}/config/container_info.txt" << EOF
容器名称: ${container_name}
容器ID: $(docker inspect --format='{{.Id}}' "${container_name}")
镜像: $(docker inspect --format='{{.Config.Image}}' "${container_name}")
创建时间: $(docker inspect --format='{{.Created}}' "${container_name}")
状态: $(docker inspect --format='{{.State.Status}}' "${container_name}")
端口映射: $(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}} {{end}}' "${container_name}" | tr -d '\n')
环境变量: $(docker inspect --format='{{range .Config.Env}}{{.}} {{end}}' "${container_name}")
EOF

    # 保存启动命令
    docker inspect --format='{{.Config.Cmd}}' "${container_name}" > "${backup_dir}/config/cmd.txt"
    docker inspect --format='{{.Config.Entrypoint}}' "${container_name}" > "${backup_dir}/config/entrypoint.txt"
    
    # 保存网络配置
    docker inspect --format='{{json .NetworkSettings}}' "${container_name}" > "${backup_dir}/config/network_settings.json"
    
    log_success "容器配置备份完成"
}

# 备份挂载点
backup_mounts() {
    local container_name="$1"
    local backup_dir="$2"
    
    if [[ "${EXCLUDE_MOUNTS}" == true ]]; then
        log_info "跳过挂载点备份（--exclude-mounts）"
        return
    fi
    
    log_info "备份容器 '${container_name}' 的挂载点..."
    
    # 获取挂载点信息
    local mounts_json="${backup_dir}/config/mounts.json"
    docker inspect --format='{{json .Mounts}}' "${container_name}" > "${mounts_json}"
    
    # 备份每个绑定挂载
    local mount_index=0
    while read -r mount_info; do
        local mount_type=$(echo "${mount_info}" | jq -r '.Type')
        local source=$(echo "${mount_info}" | jq -r '.Source')
        local destination=$(echo "${mount_info}" | jq -r '.Destination')
        
        if [[ "${mount_type}" == "bind" && -e "${source}" ]]; then
            log_info "  备份挂载点: ${source} -> ${destination}"
            local mount_backup_dir="${backup_dir}/mounts/mount_${mount_index}"
            mkdir -p "${mount_backup_dir}"
            
            # 保存挂载点信息
            echo "${mount_info}" > "${mount_backup_dir}/mount_info.json"
            
            # 备份数据
            if [[ -d "${source}" ]]; then
                tar -czf "${mount_backup_dir}/data.tar.gz" -C "$(dirname "${source}")" "$(basename "${source}")" 2>/dev/null || {
                    log_warning "无法备份目录: ${source}"
                }
            elif [[ -f "${source}" ]]; then
                cp "${source}" "${mount_backup_dir}/data.file"
            fi
            
            ((mount_index++))
        fi
    done < <(jq -c '.[]' "${mounts_json}")
    
    log_success "挂载点备份完成"
}

# 备份数据卷
backup_volumes() {
    local container_name="$1"
    local backup_dir="$2"
    
    if [[ "${EXCLUDE_VOLUMES}" == true ]]; then
        log_info "跳过数据卷备份（--exclude-volumes）"
        return
    fi
    
    log_info "备份容器 '${container_name}' 的数据卷..."
    
    # 获取容器使用的数据卷
    local volumes=$(docker inspect --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "${container_name}")
    
    if [[ -n "${volumes}" ]]; then
        for volume in ${volumes}; do
            log_info "  备份数据卷: ${volume}"
            local volume_backup_file="${backup_dir}/volumes/${volume}.tar.gz"
            
            # 使用临时容器备份数据卷
            docker run --rm -v "${volume}:/data" -v "${backup_dir}/volumes:/backup" \
                alpine:latest tar -czf "/backup/${volume}.tar.gz" -C /data . 2>/dev/null || {
                log_warning "无法备份数据卷: ${volume}"
            }
            
            # 保存数据卷信息
            docker volume inspect "${volume}" > "${backup_dir}/volumes/${volume}_info.json" 2>/dev/null || true
        done
    else
        log_info "  未发现数据卷"
    fi
    
    log_success "数据卷备份完成"
}

# 备份容器镜像
backup_image() {
    local container_name="$1"
    local backup_dir="$2"
    
    if [[ "${FULL_BACKUP}" != true ]]; then
        log_info "跳过镜像备份（使用 -f 选项启用完整备份）"
        return
    fi
    
    log_info "备份容器 '${container_name}' 的镜像..."
    
    local image=$(docker inspect --format='{{.Config.Image}}' "${container_name}")
    local image_file="${backup_dir}/${container_name}_image.tar"
    
    docker save "${image}" -o "${image_file}"
    gzip "${image_file}"
    
    log_success "镜像备份完成: ${image_file}.gz"
}

# 收集容器日志
backup_logs() {
    local container_name="$1"
    local backup_dir="$2"
    
    log_info "收集容器 '${container_name}' 的日志..."
    
    # 获取容器日志（最近1000行）
    docker logs --tail 1000 "${container_name}" > "${backup_dir}/logs/container.log" 2>&1 || true
    
    log_success "日志收集完成"
}

# 创建恢复脚本
create_restore_script() {
    local backup_dir="$1"
    local container_name="$2"
    
    log_info "创建恢复脚本..."
    
    cat > "${backup_dir}/restore.sh" << 'EOF'
#!/bin/bash

# Docker容器恢复脚本
# 此脚本由docker-backup.sh自动生成

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME=$(basename "$(dirname "${SCRIPT_DIR}")" | sed 's/_[0-9]*$//')

echo "开始恢复容器: ${CONTAINER_NAME}"

# 检查Docker是否运行
if ! docker info >/dev/null 2>&1; then
    echo "错误: Docker未运行或无法访问"
    exit 1
fi

# 停止并删除现有容器（如果存在）
if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "停止并删除现有容器..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# 恢复镜像（如果存在）
if [[ -f "${SCRIPT_DIR}/${CONTAINER_NAME}_image.tar.gz" ]]; then
    echo "恢复Docker镜像..."
    gunzip -c "${SCRIPT_DIR}/${CONTAINER_NAME}_image.tar.gz" | docker load
fi

# 恢复数据卷
if [[ -d "${SCRIPT_DIR}/volumes" ]]; then
    echo "恢复数据卷..."
    for volume_file in "${SCRIPT_DIR}/volumes"/*.tar.gz; do
        if [[ -f "${volume_file}" ]]; then
            volume_name=$(basename "${volume_file}" .tar.gz)
            echo "  恢复数据卷: ${volume_name}"
            
            # 创建数据卷
            docker volume create "${volume_name}" >/dev/null 2>&1 || true
            
            # 恢复数据
            docker run --rm -v "${volume_name}:/data" -v "${SCRIPT_DIR}/volumes:/backup" \
                alpine:latest tar -xzf "/backup/${volume_name}.tar.gz" -C /data
        fi
    done
fi

# 恢复挂载点
if [[ -d "${SCRIPT_DIR}/mounts" ]]; then
    echo "恢复挂载点..."
    for mount_dir in "${SCRIPT_DIR}/mounts"/mount_*; do
        if [[ -d "${mount_dir}" ]]; then
            mount_info="${mount_dir}/mount_info.json"
            if [[ -f "${mount_info}" ]]; then
                source_path=$(jq -r '.Source' "${mount_info}")
                
                echo "  恢复挂载点: ${source_path}"
                
                # 创建目录结构
                mkdir -p "$(dirname "${source_path}")"
                
                # 恢复数据
                if [[ -f "${mount_dir}/data.tar.gz" ]]; then
                    tar -xzf "${mount_dir}/data.tar.gz" -C "$(dirname "${source_path}")"
                elif [[ -f "${mount_dir}/data.file" ]]; then
                    cp "${mount_dir}/data.file" "${source_path}"
                fi
            fi
        fi
    done
fi

echo "数据恢复完成"
echo "请使用以下命令检查配置并手动启动容器:"
echo "  docker inspect \$(cat ${SCRIPT_DIR}/config/container_inspect.json | jq -r '.[0].Config')"
echo "或参考 ${SCRIPT_DIR}/config/ 目录中的配置文件"

EOF

    chmod +x "${backup_dir}/restore.sh"
    log_success "恢复脚本创建完成"
}

# 创建备份摘要
create_backup_summary() {
    local backup_dir="$1"
    local container_name="$2"
    
    cat > "${backup_dir}/backup_summary.txt" << EOF
Docker容器备份摘要
==================

备份时间: $(date)
容器名称: ${container_name}
备份目录: ${backup_dir}

备份内容:
- 容器配置信息 ✓
- 容器日志 ✓
$([ "${EXCLUDE_MOUNTS}" != true ] && echo "- 挂载点数据 ✓" || echo "- 挂载点数据 ✗ (已排除)")
$([ "${EXCLUDE_VOLUMES}" != true ] && echo "- 数据卷 ✓" || echo "- 数据卷 ✗ (已排除)")
$([ "${FULL_BACKUP}" == true ] && echo "- 容器镜像 ✓" || echo "- 容器镜像 ✗ (未启用完整备份)")

恢复说明:
1. 将整个备份目录复制到目标服务器
2. 执行 ./restore.sh 脚本恢复数据
3. 参考 config/ 目录中的配置手动创建容器

备份大小: $(du -sh "${backup_dir}" | cut -f1)
EOF
}

# 备份单个容器
backup_container() {
    local container_name="$1"
    
    log_info "开始备份容器: ${container_name}"
    
    # 检查容器状态
    local container_status=$(docker inspect --format='{{.State.Status}}' "${container_name}")
    log_info "容器状态: ${container_status}"
    
    # 创建备份目录
    local container_backup_dir=$(create_backup_structure "${BACKUP_DIR}" "${container_name}")
    
    # 执行各项备份任务
    backup_container_config "${container_name}" "${container_backup_dir}"
    backup_mounts "${container_name}" "${container_backup_dir}"
    backup_volumes "${container_name}" "${container_backup_dir}"
    backup_image "${container_name}" "${container_backup_dir}"
    backup_logs "${container_name}" "${container_backup_dir}"
    
    # 创建恢复脚本和摘要
    create_restore_script "${container_backup_dir}" "${container_name}"
    create_backup_summary "${container_backup_dir}" "${container_name}"
    
    log_success "容器 '${container_name}' 备份完成: ${container_backup_dir}"
    
    return 0
}

# 主函数
main() {
    log_info "Docker容器备份工具启动"
    
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
    
    # 加载配置文件
    if [[ -f "${CONFIG_FILE}" ]]; then
        log_info "加载配置文件: ${CONFIG_FILE}"
        source "${CONFIG_FILE}"
    fi
    
    # 创建备份根目录
    mkdir -p "${BACKUP_DIR}"
    
    # 获取要备份的容器列表
    local containers_to_backup
    mapfile -t containers_to_backup < <(get_containers)
    
    if [[ ${#containers_to_backup[@]} -eq 0 ]]; then
        log_warning "未找到要备份的容器"
        exit 0
    fi
    
    log_info "将备份 ${#containers_to_backup[@]} 个容器: ${containers_to_backup[*]}"
    
    # 备份每个容器
    local success_count=0
    local total_count=${#containers_to_backup[@]}
    
    for container in "${containers_to_backup[@]}"; do
        if backup_container "${container}"; then
            ((success_count++))
        else
            log_error "备份容器 '${container}' 失败"
        fi
    done
    
    # 显示备份结果
    log_info "备份完成: ${success_count}/${total_count} 个容器备份成功"
    log_info "备份文件保存在: ${BACKUP_DIR}"
    
    if [[ ${success_count} -eq ${total_count} ]]; then
        exit 0
    else
        exit 1
    fi
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 