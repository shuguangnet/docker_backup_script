#!/bin/bash

# 测试HTTP服务器功能的脚本

echo "测试Docker备份工具HTTP服务器功能"
echo "=================================="

# 检查依赖
echo "1. 检查系统依赖..."
for tool in python3 python zip unzip wget curl; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✓ $tool 已安装"
    else
        echo "  ✗ $tool 未安装"
    fi
done

echo ""

# 测试帮助信息
echo "2. 测试帮助信息..."
if ./install.sh --help | grep -q "start-http"; then
    echo "  ✓ HTTP服务器选项已添加"
else
    echo "  ✗ HTTP服务器选项缺失"
fi

if ./install.sh --help | grep -q "download-restore"; then
    echo "  ✓ 下载恢复选项已添加"
else
    echo "  ✗ 下载恢复选项缺失"
fi

echo ""

# 测试菜单功能
echo "3. 测试交互式菜单..."
if grep -q "启动HTTP服务器" docker-backup-menu.sh; then
    echo "  ✓ 菜单中已添加HTTP服务器选项"
else
    echo "  ✗ 菜单中缺少HTTP服务器选项"
fi

if grep -q "下载并恢复备份" docker-backup-menu.sh; then
    echo "  ✓ 菜单中已添加下载恢复选项"
else
    echo "  ✗ 菜单中缺少下载恢复选项"
fi

echo ""

# 测试快捷命令
echo "4. 测试快捷命令..."
if [[ -f "/usr/local/bin/docker-backup-server" ]]; then
    echo "  ✓ docker-backup-server 快捷命令已创建"
else
    echo "  ✗ docker-backup-server 快捷命令未创建"
fi

if [[ -f "/usr/local/bin/docker-backup-download" ]]; then
    echo "  ✓ docker-backup-download 快捷命令已创建"
else
    echo "  ✗ docker-backup-download 快捷命令未创建"
fi

echo ""

# 测试语法
echo "5. 测试脚本语法..."
if bash -n install.sh; then
    echo "  ✓ install.sh 语法正确"
else
    echo "  ✗ install.sh 语法错误"
fi

if bash -n docker-backup-menu.sh; then
    echo "  ✓ docker-backup-menu.sh 语法正确"
else
    echo "  ✗ docker-backup-menu.sh 语法错误"
fi

echo ""

echo "测试完成！"
echo ""
echo "使用说明："
echo "1. 在A机器上运行: ./install.sh --start-http"
echo "2. 在B机器上运行: ./install.sh --download-restore http://A机器IP:6886/docker-backup.zip"
echo "3. 或使用交互式菜单: ./docker-backup-menu.sh"
