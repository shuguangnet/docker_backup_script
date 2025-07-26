#!/bin/bash

# Docker容器备份工具 - 交互式菜单
# 作者: Docker Backup Tool
# 版本: 1.0
# 描述: 提供所有备份选项的快捷操作菜单

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup-utils.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 显示标题
show_title() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Docker容器备份工具                        ║"
    echo "║                    交互式操作菜单                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 显示主菜单
show_main_menu() {
    echo -e "${BLUE}请选择要执行的操作：${NC}"
    echo ""
    echo -e "${GREEN}📦 备份操作${NC}"
    echo "  1) 备份所有运行中的容器"
    echo "  2) 备份所有容器（排除镜像）"
    echo "  3) 备份所有容器（排除数据卷）"
    echo "  4) 备份所有容器（排除挂载点）"
    echo "  5) 备份所有容器（仅配置和日志）"
    echo "  6) 完整备份所有容器（包含镜像）"
    echo ""
    echo -e "${YELLOW}🎯 指定容器备份${NC}"
    echo "  7) 备份指定容器"
    echo "  8) 备份指定容器（排除镜像）"
    echo "  9) 备份指定容器（排除数据卷）"
    echo "  10) 备份指定容器（排除挂载点）"
    echo ""
    echo -e "${PURPLE}🔄 恢复操作${NC}"
    echo "  11) 恢复容器（交互式向导）"
    echo "  12) 列出可恢复的备份"
    echo ""
    echo -e "${RED}🧹 维护操作${NC}"
    echo "  13) 清理旧备份文件"
    echo "  14) 查看备份统计信息"
    echo "  15) 检查系统状态"
    echo ""
    echo -e "${CYAN}⚙️  配置和帮助${NC}"
    echo "  16) 编辑配置文件"
    echo "  17) 查看帮助信息"
    echo "  18) 查看版本信息"
    echo ""
    echo "  0) 退出"
    echo ""
}

# 获取容器列表
get_container_list() {
    local containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [[ -n "$containers" ]]; then
        echo "$containers"
    else
        echo ""
    fi
}

# 显示容器选择菜单
show_container_selection() {
    local containers
    mapfile -t containers < <(get_container_list)
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        log_error "未找到运行中的容器"
        return 1
    fi
    
    echo -e "${BLUE}请选择要备份的容器：${NC}"
    echo ""
    
    for i in "${!containers[@]}"; do
        echo "  $((i+1))) ${containers[i]}"
    done
    
    echo "  a) 选择所有容器"
    echo "  c) 自定义输入容器名称"
    echo "  0) 返回主菜单"
    echo ""
}

# 获取用户选择的容器
get_selected_containers() {
    local containers
    mapfile -t containers < <(get_container_list)
    
    while true; do
        read -p "请输入选择 (1-${#containers[@]}, a, c, 0): " choice
        
        case $choice in
            0)
                return 1
                ;;
            a)
                echo "all"
                return 0
                ;;
            c)
                read -p "请输入容器名称（多个用空格分隔）: " custom_containers
                if [[ -n "$custom_containers" ]]; then
                    echo "$custom_containers"
                    return 0
                else
                    log_error "请输入有效的容器名称"
                    continue
                fi
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#containers[@]} ]]; then
                    echo "${containers[$((choice-1))]}"
                    return 0
                else
                    log_error "无效选择，请重新输入"
                    continue
                fi
                ;;
        esac
    done
}

# 执行备份命令
execute_backup() {
    local command="$1"
    local description="$2"
    
    echo -e "${CYAN}执行操作: ${description}${NC}"
    echo -e "${YELLOW}命令: ${command}${NC}"
    echo ""
    
    if ask_confirmation "确认执行此操作吗？"; then
        echo ""
        log_info "开始执行..."
        echo ""
        
        # 执行命令
        if eval "$command"; then
            echo ""
            log_success "操作完成！"
        else
            echo ""
            log_error "操作失败！"
        fi
        
        echo ""
        read -p "按回车键继续..."
    fi
}

# 备份所有容器
backup_all_containers() {
    local exclude_options="$1"
    local description="$2"
    
    local command="docker-backup -a $exclude_options"
    execute_backup "$command" "$description"
}

# 备份指定容器
backup_specific_containers() {
    local exclude_options="$1"
    local description="$2"
    
    show_container_selection
    local selected_containers=$(get_selected_containers)
    
    if [[ $? -eq 0 ]] && [[ -n "$selected_containers" ]]; then
        local command="docker-backup -c \"$selected_containers\" $exclude_options"
        execute_backup "$command" "$description"
    fi
}

# 恢复容器
restore_container() {
    echo -e "${CYAN}恢复容器操作${NC}"
    echo ""
    echo "请选择恢复方式："
    echo "  1) 使用交互式恢复向导"
    echo "  2) 手动指定备份目录"
    echo "  0) 返回主菜单"
    echo ""
    
    read -p "请输入选择: " choice
    
    case $choice in
        1)
            execute_backup "docker-restore" "交互式恢复向导"
            ;;
        2)
            read -p "请输入备份目录路径: " backup_path
            if [[ -n "$backup_path" ]] && [[ -d "$backup_path" ]]; then
                local command="cd \"$backup_path\" && ./restore.sh"
                execute_backup "$command" "从指定目录恢复: $backup_path"
            else
                log_error "无效的备份目录路径"
                read -p "按回车键继续..."
            fi
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            read -p "按回车键继续..."
            ;;
    esac
}

# 列出可恢复的备份
list_backups() {
    echo -e "${CYAN}可恢复的备份列表${NC}"
    echo ""
    
    local backup_dir="/tmp/docker-backups"
    if [[ -d "$backup_dir" ]]; then
        echo "备份目录: $backup_dir"
        echo ""
        
        local backup_count=0
        while IFS= read -r -d '' backup; do
            if [[ -d "$backup" ]] && [[ -f "$backup/restore.sh" ]]; then
                ((backup_count++))
                local backup_name=$(basename "$backup")
                local backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)
                local backup_date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1)
                
                echo -e "${GREEN}$backup_count)${NC} $backup_name"
                echo "    大小: $backup_size, 日期: $backup_date"
                echo "    路径: $backup"
                echo ""
            fi
        done < <(find "$backup_dir" -maxdepth 1 -type d -print0 2>/dev/null)
        
        if [[ $backup_count -eq 0 ]]; then
            log_warning "未找到可恢复的备份"
        fi
    else
        log_warning "备份目录不存在: $backup_dir"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 清理旧备份
cleanup_backups() {
    echo -e "${CYAN}清理旧备份文件${NC}"
    echo ""
    echo "请选择清理方式："
    echo "  1) 清理30天前的备份"
    echo "  2) 清理7天前的备份"
    echo "  3) 清理所有备份"
    echo "  4) 自定义天数清理"
    echo "  0) 返回主菜单"
    echo ""
    
    read -p "请输入选择: " choice
    
    case $choice in
        1)
            execute_backup "docker-cleanup 30" "清理30天前的备份"
            ;;
        2)
            execute_backup "docker-cleanup 7" "清理7天前的备份"
            ;;
        3)
            if ask_confirmation "确定要删除所有备份文件吗？此操作不可恢复！"; then
                execute_backup "docker-cleanup 0" "清理所有备份"
            fi
            ;;
        4)
            read -p "请输入天数: " days
            if [[ "$days" =~ ^[0-9]+$ ]]; then
                execute_backup "docker-cleanup $days" "清理${days}天前的备份"
            else
                log_error "请输入有效的天数"
                read -p "按回车键继续..."
            fi
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            read -p "按回车键继续..."
            ;;
    esac
}

# 查看备份统计
show_backup_stats() {
    echo -e "${CYAN}备份统计信息${NC}"
    echo ""
    
    local backup_dir="/tmp/docker-backups"
    if [[ -d "$backup_dir" ]]; then
        local total_backups=$(find "$backup_dir" -maxdepth 1 -type d | wc -l)
        local total_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
        
        echo "备份目录: $backup_dir"
        echo "总备份数: $((total_backups - 1))"  # 减去目录本身
        echo "总大小: $total_size"
        echo ""
        
        echo "最近的备份:"
        find "$backup_dir" -maxdepth 1 -type d -name "*_*" -printf "%T@ %p\n" 2>/dev/null | \
            sort -nr | head -5 | while read timestamp path; do
            local name=$(basename "$path")
            local date=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")
            local size=$(du -sh "$path" 2>/dev/null | cut -f1)
            echo "  $name ($date) - $size"
        done
    else
        log_warning "备份目录不存在: $backup_dir"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 检查系统状态
check_system_status() {
    echo -e "${CYAN}系统状态检查${NC}"
    echo ""
    
    # 检查Docker
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Docker已安装"
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Docker服务运行正常"
            local container_count=$(docker ps -q | wc -l)
            echo "  运行中的容器: $container_count"
        else
            echo -e "${RED}✗${NC} Docker服务未运行"
        fi
    else
        echo -e "${RED}✗${NC} Docker未安装"
    fi
    
    echo ""
    
    # 检查工具
    local tools=("jq" "tar" "gzip")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $tool 已安装"
        else
            echo -e "${RED}✗${NC} $tool 未安装"
        fi
    done
    
    echo ""
    
    # 检查备份工具
    if command -v docker-backup >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} docker-backup 命令可用"
    else
        echo -e "${RED}✗${NC} docker-backup 命令不可用"
    fi
    
    if command -v docker-restore >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} docker-restore 命令可用"
    else
        echo -e "${RED}✗${NC} docker-restore 命令不可用"
    fi
    
    echo ""
    
    # 检查磁盘空间
    local backup_dir="/tmp/docker-backups"
    if [[ -d "$backup_dir" ]]; then
        local available_space=$(df -h "$backup_dir" | tail -1 | awk '{print $4}')
        echo "备份目录可用空间: $available_space"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 编辑配置文件
edit_config() {
    echo -e "${CYAN}编辑配置文件${NC}"
    echo ""
    echo "请选择要编辑的配置文件："
    echo "  1) 主配置文件 (/etc/docker-backup/backup.conf)"
    echo "  2) 本地配置文件 (/etc/docker-backup/backup.conf.local)"
    echo "  3) 查看当前配置"
    echo "  0) 返回主菜单"
    echo ""
    
    read -p "请输入选择: " choice
    
    case $choice in
        1)
            if [[ -f "/etc/docker-backup/backup.conf" ]]; then
                if command -v nano >/dev/null 2>&1; then
                    nano /etc/docker-backup/backup.conf
                elif command -v vim >/dev/null 2>&1; then
                    vim /etc/docker-backup/backup.conf
                elif command -v vi >/dev/null 2>&1; then
                    vi /etc/docker-backup/backup.conf
                else
                    log_error "未找到可用的文本编辑器"
                fi
            else
                log_error "配置文件不存在"
            fi
            ;;
        2)
            if [[ -f "/etc/docker-backup/backup.conf.local" ]]; then
                if command -v nano >/dev/null 2>&1; then
                    nano /etc/docker-backup/backup.conf.local
                elif command -v vim >/dev/null 2>&1; then
                    vim /etc/docker-backup/backup.conf.local
                elif command -v vi >/dev/null 2>&1; then
                    vi /etc/docker-backup/backup.conf.local
                else
                    log_error "未找到可用的文本编辑器"
                fi
            else
                log_error "本地配置文件不存在"
            fi
            ;;
        3)
            echo -e "${CYAN}当前配置信息${NC}"
            echo ""
            if [[ -f "/etc/docker-backup/backup.conf" ]]; then
                echo "主配置文件:"
                grep -E "^(DEFAULT_|BACKUP_|LOG_|COMPRESSION_)" /etc/docker-backup/backup.conf | head -10
                echo ""
            fi
            if [[ -f "/etc/docker-backup/backup.conf.local" ]]; then
                echo "本地配置文件:"
                grep -E "^(DEFAULT_|BACKUP_|LOG_|COMPRESSION_)" /etc/docker-backup/backup.conf.local | head -10
                echo ""
            fi
            read -p "按回车键继续..."
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            read -p "按回车键继续..."
            ;;
    esac
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}帮助信息${NC}"
    echo ""
    echo "Docker容器备份工具 - 交互式菜单"
    echo ""
    echo "主要功能："
    echo "  • 备份Docker容器的完整配置、数据卷、挂载点和镜像"
    echo "  • 支持选择性备份（排除镜像、数据卷、挂载点）"
    echo "  • 一键恢复容器到任意服务器"
    echo "  • 自动清理旧备份文件"
    echo ""
    echo "快捷操作："
    echo "  • 选项1-6: 备份所有容器的不同模式"
    echo "  • 选项7-10: 备份指定容器的不同模式"
    echo "  • 选项11-12: 恢复容器操作"
    echo "  • 选项13-15: 维护和状态检查"
    echo "  • 选项16-18: 配置和帮助"
    echo ""
    echo "更多信息请访问: https://github.com/shuguangnet/dcoker_backup_script"
    echo ""
    read -p "按回车键继续..."
}

# 显示版本信息
show_version() {
    echo -e "${CYAN}版本信息${NC}"
    echo ""
    echo "Docker容器备份工具"
    echo "版本: 1.0"
    echo "作者: Docker Backup Tool"
    echo "GitHub: https://github.com/shuguangnet/dcoker_backup_script"
    echo ""
    echo "功能特性："
    echo "  ✓ 完整容器备份和恢复"
    echo "  ✓ 选择性备份选项"
    echo "  ✓ 自动化恢复脚本"
    echo "  ✓ 交互式操作菜单"
    echo "  ✓ 配置文件支持"
    echo "  ✓ 日志和错误处理"
    echo ""
    read -p "按回车键继续..."
}

# 主循环
main() {
    while true; do
        show_title
        show_main_menu
        
        read -p "请输入选择 (0-18): " choice
        echo ""
        
        case $choice in
            0)
                echo -e "${GREEN}感谢使用Docker容器备份工具！${NC}"
                exit 0
                ;;
            1)
                backup_all_containers "" "备份所有运行中的容器"
                ;;
            2)
                backup_all_containers "--exclude-images" "备份所有容器（排除镜像）"
                ;;
            3)
                backup_all_containers "--exclude-volumes" "备份所有容器（排除数据卷）"
                ;;
            4)
                backup_all_containers "--exclude-mounts" "备份所有容器（排除挂载点）"
                ;;
            5)
                backup_all_containers "--exclude-images --exclude-volumes --exclude-mounts" "备份所有容器（仅配置和日志）"
                ;;
            6)
                backup_all_containers "-f" "完整备份所有容器（包含镜像）"
                ;;
            7)
                backup_specific_containers "" "备份指定容器"
                ;;
            8)
                backup_specific_containers "--exclude-images" "备份指定容器（排除镜像）"
                ;;
            9)
                backup_specific_containers "--exclude-volumes" "备份指定容器（排除数据卷）"
                ;;
            10)
                backup_specific_containers "--exclude-mounts" "备份指定容器（排除挂载点）"
                ;;
            11)
                restore_container
                ;;
            12)
                list_backups
                ;;
            13)
                cleanup_backups
                ;;
            14)
                show_backup_stats
                ;;
            15)
                check_system_status
                ;;
            16)
                edit_config
                ;;
            17)
                show_help
                ;;
            18)
                show_version
                ;;
            *)
                log_error "无效选择，请输入0-18之间的数字"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 