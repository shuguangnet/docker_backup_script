#!/bin/bash

# Docker容器备份清理脚本
# 作者: Docker Backup Tool
# 版本: 1.0
# 描述: 清理旧的备份文件

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup-utils.sh"

# 默认配置
DEFAULT_BACKUP_DIR="/tmp/docker-backups"
DEFAULT_RETENTION_DAYS=30

# 显示使用说明
show_usage() {
    cat << EOF
用法: $0 [选项] [天数]

选项:
    -h, --help              显示此帮助信息
    -d, --directory DIR     指定备份目录 (默认: ${DEFAULT_BACKUP_DIR})
    -f, --force             强制删除，不询问确认
    -v, --verbose          详细输出模式

参数:
    天数                    保留天数，0表示删除所有备份 (默认: ${DEFAULT_RETENTION_DAYS})

示例:
    $0                      # 删除30天前的备份
    $0 7                    # 删除7天前的备份
    $0 0                    # 删除所有备份
    $0 -d /backup 14        # 删除指定目录14天前的备份

EOF
}

# 解析命令行参数
parse_arguments() {
    BACKUP_DIR="${DEFAULT_BACKUP_DIR}"
    RETENTION_DAYS="${DEFAULT_RETENTION_DAYS}"
    FORCE=false
    VERBOSE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -d|--directory)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    RETENTION_DAYS="$1"
                else
                    log_error "无效的天数: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# 检查备份目录
check_backup_directory() {
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        log_warning "备份目录不存在: ${BACKUP_DIR}"
        return 1
    fi
    
    local backup_count=$(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "*_*" | wc -l)
    if [[ $backup_count -eq 0 ]]; then
        log_info "备份目录为空，无需清理"
        return 1
    fi
    
    return 0
}

# 显示清理预览
show_cleanup_preview() {
    local days="$1"
    
    log_info "清理预览 (删除${days}天前的备份):"
    echo ""
    
    local total_size=0
    local count=0
    
    while IFS= read -r -d '' backup; do
        if [[ -d "$backup" ]]; then
            ((count++))
            local backup_name=$(basename "$backup")
            local backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)
            local backup_date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1)
            local backup_age=$(( ( $(date +%s) - $(stat -c %Y "$backup" 2>/dev/null) ) / 86400 ))
            
            echo "  $count) $backup_name"
            echo "      大小: $backup_size, 日期: $backup_date, 年龄: ${backup_age}天"
            
            # 计算总大小（以字节为单位）
            local size_bytes=$(du -sb "$backup" 2>/dev/null | cut -f1)
            total_size=$((total_size + size_bytes))
        fi
    done < <(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "*_*" -mtime +${days} -print0 2>/dev/null)
    
    if [[ $count -eq 0 ]]; then
        log_info "没有找到需要清理的备份"
        return 1
    fi
    
    echo ""
    local total_size_human=$(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "${total_size}B")
    log_info "将删除 $count 个备份，释放空间: $total_size_human"
    
    return 0
}

# 执行清理
perform_cleanup() {
    local days="$1"
    
    log_info "开始清理${days}天前的备份..."
    
    local deleted_count=0
    local deleted_size=0
    
    while IFS= read -r -d '' backup; do
        if [[ -d "$backup" ]]; then
            local backup_name=$(basename "$backup")
            local backup_size=$(du -sb "$backup" 2>/dev/null | cut -f1)
            
            if [[ "${VERBOSE}" == true ]]; then
                log_info "删除备份: $backup_name"
            fi
            
            if rm -rf "$backup" 2>/dev/null; then
                ((deleted_count++))
                deleted_size=$((deleted_size + backup_size))
                
                if [[ "${VERBOSE}" == true ]]; then
                    log_success "已删除: $backup_name"
                fi
            else
                log_error "删除失败: $backup_name"
            fi
        fi
    done < <(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "*_*" -mtime +${days} -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
        local deleted_size_human=$(numfmt --to=iec-i --suffix=B $deleted_size 2>/dev/null || echo "${deleted_size}B")
        log_success "清理完成: 删除了 $deleted_count 个备份，释放空间: $deleted_size_human"
    else
        log_info "没有备份被删除"
    fi
}

# 主函数
main() {
    log_info "Docker容器备份清理工具启动"
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 检查备份目录
    if ! check_backup_directory; then
        exit 0
    fi
    
    # 显示清理预览
    if ! show_cleanup_preview "${RETENTION_DAYS}"; then
        exit 0
    fi
    
    # 确认删除
    if [[ "${FORCE}" != true ]]; then
        if ! ask_confirmation "确认删除这些备份文件吗？"; then
            log_info "操作已取消"
            exit 0
        fi
    fi
    
    # 执行清理
    perform_cleanup "${RETENTION_DAYS}"
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 