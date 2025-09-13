# Docker容器备份工具 - HTTP服务器功能使用指南

## 功能概述

新增的HTTP服务器功能允许您通过HTTP协议快速传输Docker容器备份文件，实现跨服务器的便捷备份和恢复。

## 主要特性

- 🌐 **HTTP服务器**: 在6886端口启动HTTP服务器提供备份下载
- 📦 **ZIP压缩**: 自动将备份文件压缩为ZIP格式
- ⬇️ **一键下载**: 支持wget/curl快速下载备份文件
- 🔄 **自动恢复**: 下载后自动解压并恢复容器
- 🎯 **交互式菜单**: 集成到交互式操作菜单中

## 使用方法

### 1. 在A机器（源服务器）上操作

#### 方法一：使用交互式菜单
```bash
# 启动交互式菜单
docker-backup-menu

# 选择选项16：启动HTTP服务器（提供备份下载）
# 系统会列出所有可用的备份，选择要提供下载的备份
```

#### 方法二：使用命令行
```bash
# 启动HTTP服务器（使用默认备份目录）
./install.sh --start-http

# 或指定特定备份目录
./install.sh --start-http -b /path/to/backup/dir
```

#### 方法三：使用快捷命令
```bash
# 启动HTTP服务器
docker-backup-server
```

### 2. 获取下载地址

启动HTTP服务器后，系统会显示：
```
[SUCCESS] HTTP服务器已启动 (PID: 12345)
[INFO] 服务器地址: http://192.168.1.100:6886
[INFO] 下载命令: wget http://192.168.1.100:6886/docker-backup.zip
[INFO] 停止服务器: kill 12345 或按 Ctrl+C
```

### 3. 在B机器（目标服务器）上操作

#### 方法一：使用交互式菜单
```bash
# 启动交互式菜单
docker-backup-menu

# 选择选项18：下载并恢复备份
# 输入下载地址：http://192.168.1.100:6886/docker-backup.zip
```

#### 方法二：使用命令行
```bash
# 下载并恢复备份
./install.sh --download-restore http://192.168.1.100:6886/docker-backup.zip
```

#### 方法三：使用快捷命令
```bash
# 下载并恢复备份
docker-backup-download http://192.168.1.100:6886/docker-backup.zip
```

#### 方法四：手动下载（传统方式）
```bash
# 下载备份文件
wget http://192.168.1.100:6886/docker-backup.zip

# 解压备份文件
unzip docker-backup.zip

# 运行恢复脚本
./restore.sh
```

## 完整工作流程示例

### 步骤1：在A机器备份容器
```bash
# 备份所有容器
docker-backup -a

# 或备份指定容器
docker-backup nginx mysql redis
```

### 步骤2：在A机器启动HTTP服务器
```bash
# 启动HTTP服务器
docker-backup-server

# 系统输出：
# [SUCCESS] HTTP服务器已启动 (PID: 12345)
# [INFO] 服务器地址: http://192.168.1.100:6886
# [INFO] 下载命令: wget http://192.168.1.100:6886/docker-backup.zip
```

### 步骤3：在B机器下载并恢复
```bash
# 一键下载并恢复
docker-backup-download http://192.168.1.100:6886/docker-backup.zip

# 系统会自动：
# 1. 下载备份文件
# 2. 解压备份文件
# 3. 运行恢复脚本
# 4. 启动容器
```

### 步骤4：停止HTTP服务器
```bash
# 在A机器上停止服务器
./install.sh --stop-http

# 或使用快捷键 Ctrl+C
```

## 高级功能

### 1. 指定端口
```bash
# 使用自定义端口启动HTTP服务器
./install.sh --start-http -b /backup/dir
# 默认使用6886端口
```

### 2. 选择特定备份
```bash
# 在交互式菜单中可以选择特定的备份文件
# 而不是所有备份的压缩包
```

### 3. 网络配置
```bash
# 确保防火墙允许6886端口
sudo ufw allow 6886

# 或使用iptables
sudo iptables -A INPUT -p tcp --dport 6886 -j ACCEPT
```

## 故障排除

### 1. 端口被占用
```bash
# 检查端口占用
lsof -i :6886

# 停止占用进程
sudo kill -9 <PID>
```

### 2. 网络连接问题
```bash
# 检查网络连通性
ping 192.168.1.100

# 检查端口是否开放
telnet 192.168.1.100 6886
```

### 3. 权限问题
```bash
# 确保有足够的权限
sudo chmod +x /usr/local/bin/docker-backup-*

# 检查文件权限
ls -la /usr/local/bin/docker-backup-*
```

## 安全注意事项

1. **网络安全**: HTTP服务器仅用于内网传输，不建议在公网使用
2. **访问控制**: 确保只有授权的机器可以访问HTTP服务器
3. **数据安全**: 备份文件可能包含敏感数据，注意传输安全
4. **资源管理**: 及时停止HTTP服务器，避免资源浪费

## 支持的备份类型

- ✅ 普通Docker容器备份
- ✅ Docker Compose容器备份
- ✅ 包含数据卷的备份
- ✅ 包含挂载点的备份
- ✅ 包含镜像的完整备份

## 系统要求

- Python 2.7+ 或 Python 3.x（用于HTTP服务器）
- zip/unzip 工具（用于压缩/解压）
- wget 或 curl（用于下载）
- Docker（用于容器操作）

## 更新日志

- v1.0: 初始版本，支持基本的HTTP服务器和下载恢复功能
- 新增功能：ZIP压缩、交互式菜单集成、快捷命令
