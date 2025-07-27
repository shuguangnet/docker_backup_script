# Docker容器备份和恢复工具

一个功能完整的Docker容器备份和恢复解决方案，专为Linux系统设计，能够自动识别并备份Docker容器的完整配置、挂载点和数据卷，支持在新服务器上一键恢复。

## 🚀 一键安装

```bash
# 立即安装使用
curl -fsSL https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/install.sh | sudo bash
```

**GitHub仓库**: https://github.com/shuguangnet/dcoker_backup_script





**就是这么简单！** 🎉

备份
![image](https://minio.933999.xyz/images-lankong/lankong/2025/07/26/6884da1341465.jpg)

恢复
![image](https://minio.933999.xyz/images-lankong/lankong/2025/07/26/6884da159e26a.jpg)

定时备份
![image](https://minio.933999.xyz/images-lankong/lankong/2025/07/26/6884db36378d6.png)



## 🖥️ 交互式菜单

安装完成后，你可以使用交互式菜单进行所有操作：

```bash
# 启动交互式菜单
docker-backup-menu
```
![Snipaste_2025-07-27_00-25-51.png](https://minio.933999.xyz/images-lankong/lankong/2025/07/27/688501a4020c2.png)


**就是这么简单！** 🎉

## 🚀 功能特性

### 核心功能
- **完整备份**：备份容器配置、环境变量、端口映射、网络设置
- **数据保护**：支持Docker volumes和bind mounts的完整备份
- **镜像备份**：可选择性备份容器镜像（完整备份模式）
- **一键恢复**：在新服务器上快速恢复容器和数据
- **增量支持**：智能识别和备份变更的数据
- **交互式菜单**：图形化操作界面，新手友好
- **Docker Compose支持**：自动检测并备份docker-compose项目
- **HTTP回调API**：提供RESTful API接口，支持外部系统触发备份

### 高级特性
- **灵活配置**：支持配置文件和命令行参数
- **批量操作**：支持备份所有容器或指定容器列表
- **容器过滤**：支持按名称、标签等条件过滤容器
- **并发备份**：支持多容器并发备份提高效率
- **安全加密**：支持GPG加密备份文件
- **远程存储**：支持备份到远程服务器
- **通知机制**：支持邮件、Webhook、Slack通知
- **定时备份**：支持cron定时任务自动备份
- **智能清理**：自动清理过期备份文件
- **API安全**：HMAC-SHA256签名验证，确保API调用安全

### 高级特性
- **灵活配置**：支持配置文件和命令行参数
- **批量操作**：支持备份所有容器或指定容器列表
- **容器过滤**：支持按名称、标签等条件过滤容器
- **并发备份**：支持多容器并发备份提高效率
- **安全加密**：支持GPG加密备份文件
- **远程存储**：支持备份到远程服务器
- **通知机制**：支持邮件、Webhook、Slack通知
- **定时备份**：支持cron定时任务自动备份
- **智能清理**：自动清理过期备份文件

## 📋 系统要求

### 必需工具
- **Docker**: 18.06+ (支持Docker API v1.38+)
- **Bash**: 4.0+ 
- **jq**: 1.5+ (用于JSON解析)
- **tar**: GNU tar (用于文件压缩)

### 可选工具
- **curl**: 用于远程上传和通知
- **gpg**: 用于备份加密
- **rsync**: 用于高效数据同步

### 安装依赖

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install jq curl tar rsync gnupg
```

#### CentOS/RHEL/Rocky Linux
```bash
sudo yum install epel-release
sudo yum install jq curl tar rsync gnupg2
```

#### Alpine Linux
```bash
apk add jq curl tar rsync gnupg
```

## 🛠️ 安装部署

### 🚀 一键安装（推荐）

#### 方法1：直接下载并安装
```bash
# 一键下载并安装（推荐）
curl -fsSL https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/install.sh | sudo bash

# 或者使用wget
wget -qO- https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/install.sh | sudo bash
```

#### 方法2：下载脚本后查看再执行（更安全）
```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/install.sh -o install.sh

# 查看脚本内容（确保安全）
cat install.sh

# 执行安装
chmod +x install.sh
sudo ./install.sh
```

#### 方法3：克隆整个仓库
```bash
# 克隆仓库
git clone https://github.com/shuguangnet/dcoker_backup_script.git

# 进入目录并安装
cd dcoker_backup_script
sudo ./install.sh
```

#### 安装选项
```bash
# 标准安装
sudo ./install.sh

# 自定义安装目录
sudo ./install.sh -d /usr/local/docker-backup

# 自定义备份目录
sudo ./install.sh -b /backup/docker

# 开发模式（使用当前目录，不需要sudo）
./install.sh --dev-mode

# 不创建系统服务
sudo ./install.sh --no-service

# 不设置定时任务
sudo ./install.sh --no-cron

# 卸载工具
sudo ./install.sh --uninstall
```

### 📦 手动安装

如果你需要手动安装或自定义部署：

#### 1. 下载脚本
```bash
# 克隆仓库
git clone https://github.com/shuguangnet/dcoker_backup_script.git
cd dcoker_backup_script

# 或者直接下载脚本文件
wget https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/docker-backup.sh
wget https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/docker-restore.sh
wget https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/backup-utils.sh
wget https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/backup.conf
```

#### 2. 设置权限
```bash
chmod +x docker-backup.sh
chmod +x docker-restore.sh
chmod +x backup-utils.sh
```

#### 3. 配置文件
```bash
# 复制并编辑配置文件
cp backup.conf backup.conf.local
vim backup.conf.local
```

#### 4. 创建备份目录
```bash
sudo mkdir -p /var/backups/docker
sudo chown $(whoami):$(whoami) /var/backups/docker
```

## 📖 使用指南

### 🎯 快捷命令（一键安装后）

如果你使用了一键安装脚本，系统会自动创建全局快捷命令：

#### 交互式菜单（推荐新手）
```bash
# 启动交互式菜单
docker-backup-menu
```

#### 备份操作
```bash
# 备份单个容器
docker-backup nginx

# 备份多个容器
docker-backup nginx mysql redis

# 备份所有运行中的容器
docker-backup -a

# 备份所有容器（排除镜像，节省空间）
docker-backup -a --exclude-images

# 完整备份（包含镜像）
docker-backup -f nginx

# 详细输出模式
docker-backup -v nginx
```

#### 恢复操作
```bash
# 恢复容器
docker-restore /var/backups/docker/nginx_20231201_120000

# 强制恢复（覆盖现有容器）
docker-restore -f /var/backups/docker/nginx_20231201_120000

# 恢复到新名称
docker-restore --container-name new-nginx /var/backups/docker/nginx_20231201_120000
```

#### 管理命令
```bash
# 查看定时备份状态
systemctl status docker-backup.timer

# 启动定时备份
systemctl start docker-backup.timer

# 查看备份日志
journalctl -u docker-backup.service

# 手动触发备份
systemctl start docker-backup.service

# 清理旧备份文件
docker-cleanup 30

# 查看备份统计
docker-cleanup --preview 30
```

### 🌐 HTTP回调API

Docker备份工具提供了基于Go的HTTP回调API服务，支持外部系统通过RESTful接口触发备份操作。

#### 启动回调服务
```bash
# 进入Go应用目录
cd go/callback

# 编译应用
go build -o myapp .

# 启动服务
./myapp
```

#### 配置回调服务
在 `backup.conf` 中添加以下配置：
```bash
# 回调服务配置
port=8080
callback_secret=your-secret-key
scriptpath=./docker-backup.sh
```

#### API接口说明

**端点**: `POST /backup`

**请求头**:
- `Content-Type: application/json`
- `X-Signature: sha256=<hmac-signature>`

**请求体**:
```json
{
  "args": ["container-name1", "container-name2"]
}
```

**示例调用**:
```bash
# 使用提供的客户端示例
go run client_example.go nginx mysql

# 或使用curl
curl -X POST http://localhost:8080/backup \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=<calculated-signature>" \
  -d '{"args":["nginx"]}'
```

#### 安全特性
- **HMAC-SHA256签名验证**：确保请求来源可信
- **配置文件密钥管理**：密钥存储在配置文件中
- **参数验证**：验证请求参数的有效性

#### 使用场景
- **CI/CD集成**：部署完成后自动触发备份
- **监控系统**：检测到重要变更时触发备份
- **外部调度器**：定时调用API进行备份
- **多系统集成**：允许其他系统通过API触发备份

### 📋 手动模式（脚本直接使用）

如果你是手动安装或开发模式：

#### 备份单个容器
```bash
# 备份nginx容器
./docker-backup.sh nginx

# 备份nginx和mysql容器
./docker-backup.sh nginx mysql
```

#### 备份所有容器
```bash
# 备份所有运行中的容器
./docker-backup.sh -a

# 完整备份所有容器（包含镜像）
./docker-backup.sh -a -f
```

#### 高级备份选项
```bash
# 指定备份目录
./docker-backup.sh -o /custom/backup/path nginx

# 排除数据卷和挂载点
./docker-backup.sh --exclude-volumes --exclude-mounts nginx

# 使用自定义配置文件
./docker-backup.sh -c /path/to/custom.conf nginx

# 详细输出模式
./docker-backup.sh -v nginx
```

### 容器恢复操作

#### 基础恢复
```bash
# 恢复容器（基础模式）
./docker-restore.sh /path/to/backup/nginx_20231201_120000

# 强制恢复（覆盖现有容器）
./docker-restore.sh -f /path/to/backup/nginx_20231201_120000
```

#### 高级恢复选项
```bash
# 恢复但不启动容器
./docker-restore.sh -n /path/to/backup/nginx_20231201_120000

# 指定新的容器名称
./docker-restore.sh --container-name new-nginx /path/to/backup/nginx_20231201_120000

# 跳过特定组件恢复
./docker-restore.sh --no-volumes --no-mounts /path/to/backup/nginx_20231201_120000
```

## 🖥️ 交互式菜单详解

### Docker Compose自动检测

备份脚本会自动检测容器是否由docker-compose管理：

#### 检测方法
1. **容器标签检测**：检查`com.docker.compose.project`和`com.docker.compose.service`标签
2. **容器名称模式**：识别`project_service_number`命名模式
3. **网络名称检测**：查找`project_default`网络模式

#### 检测结果
- **Docker Compose容器**：自动备份compose文件、环境配置，生成compose恢复脚本
- **普通容器**：使用传统的docker run命令恢复

#### 备份内容差异
| 内容 | 普通容器 | Docker Compose容器 |
|------|----------|-------------------|
| 容器配置 | ✓ | ✓ |
| 数据卷 | ✓ | ✓ |
| 挂载点 | ✓ | ✓ |
| 镜像 | ✓ | ✓ |
| docker-compose.yml | ✗ | ✓ |
| .env文件 | ✗ | ✓ |
| 恢复方式 | docker run | docker-compose up |

### 菜单功能概览

运行 `docker-backup-menu` 后，你将看到一个包含18个选项的交互式菜单：

#### 📦 备份操作 (选项1-6)
- **选项1**: 备份所有运行中的容器
- **选项2**: 备份所有容器（排除镜像）
- **选项3**: 备份所有容器（排除数据卷）
- **选项4**: 备份所有容器（排除挂载点）
- **选项5**: 备份所有容器（仅配置和日志）
- **选项6**: 完整备份所有容器（包含镜像）

#### 🎯 指定容器备份 (选项7-10)
- **选项7**: 备份指定容器
- **选项8**: 备份指定容器（排除镜像）
- **选项9**: 备份指定容器（排除数据卷）
- **选项10**: 备份指定容器（排除挂载点）

#### 🔄 恢复操作 (选项11-12)
- **选项11**: 恢复容器（交互式向导）
- **选项12**: 列出可恢复的备份

#### 🧹 维护操作 (选项13-15)
- **选项13**: 清理旧备份文件
- **选项14**: 查看备份统计信息
- **选项15**: 检查系统状态

#### ⚙️ 配置和帮助 (选项16-18)
- **选项16**: 编辑配置文件
- **选项17**: 查看帮助信息
- **选项18**: 查看版本信息



## ⚙️ 配置选项

### 主要配置参数

#### 基础配置
```bash
# 默认备份目录
DEFAULT_BACKUP_DIR="/var/backups/docker"

# 备份保留天数
BACKUP_RETENTION_DAYS=30

# 压缩格式（gzip, bzip2, xz）
COMPRESSION_FORMAT="gzip"

# 详细日志模式
VERBOSE_MODE=false
```

#### 备份选项
```bash
# 默认完整备份（包含镜像）
DEFAULT_FULL_BACKUP=false

# 排除数据卷备份
DEFAULT_EXCLUDE_VOLUMES=false

# 排除挂载点备份
DEFAULT_EXCLUDE_MOUNTS=false

# 备份前暂停容器
PAUSE_CONTAINERS_DURING_BACKUP=false
```

#### 性能配置
```bash
# 并发备份数量
MAX_CONCURRENT_BACKUPS=3

# 最大备份文件大小（MB）
MAX_BACKUP_SIZE_MB=0

# 磁盘空间缓冲区（MB）
DISK_SPACE_BUFFER_MB=1024
```

### 容器过滤配置
```bash
# 排除容器名称模式
EXCLUDE_CONTAINER_PATTERNS=".*-temp .*-test"

# 只备份特定标签的容器
INCLUDE_CONTAINER_LABELS="backup=true"

# 排除特定标签的容器
EXCLUDE_CONTAINER_LABELS="backup=false"
```

## 📁 备份目录结构

### 普通Docker容器
```
backup_dir/
├── config/                    # 容器配置文件
│   ├── container_inspect.json # 完整容器配置
│   ├── container_info.txt     # 关键配置信息
│   ├── cmd.txt               # 启动命令
│   ├── entrypoint.txt        # 入口点
│   ├── network_settings.json # 网络配置
│   └── mounts.json           # 挂载信息
├── volumes/                   # 数据卷备份
│   ├── volume1.tar.gz        # 数据卷压缩包
│   └── volume1_info.json     # 数据卷信息
├── mounts/                    # 挂载点备份
│   ├── mount_0/              # 挂载点0
│   │   ├── mount_info.json   # 挂载信息
│   │   └── data.tar.gz       # 挂载数据
│   └── mount_1/              # 挂载点1
├── logs/                      # 容器日志
│   └── container.log         # 容器运行日志
├── nginx_image.tar.gz        # 容器镜像（完整备份）
├── restore.sh                # 自动恢复脚本
├── generated_run_command.sh  # Docker运行命令
└── backup_summary.txt        # 备份摘要
```

### Docker Compose容器
```
backup_dir/
├── config/                    # 容器配置文件
├── volumes/                   # 数据卷备份
├── mounts/                    # 挂载点备份
├── logs/                      # 容器日志
├── compose/                   # Docker Compose文件
│   ├── docker-compose.yml    # 主配置文件
│   ├── .env                  # 环境变量文件
│   ├── compose_info.txt      # 项目和服务信息
│   └── compose_directory.txt # 原始目录路径
├── project_service_image.tar.gz # 容器镜像（完整备份）
├── restore.sh                # 自动恢复脚本（支持docker-compose）
└── backup_summary.txt        # 备份摘要
```

## 🔧 实际使用示例

### 场景1：Web应用备份

```bash
# 1. 备份nginx和mysql容器
./docker-backup.sh -f nginx mysql

# 2. 在新服务器恢复
scp -r nginx_20231201_120000/ user@new-server:/tmp/
ssh user@new-server "cd /tmp && ./docker-restore.sh nginx_20231201_120000"
```

### 场景2：Docker Compose项目备份

```bash
# 1. 备份docker-compose项目（自动检测）
./docker-backup.sh -f myproject_web_1

# 2. 备份会包含：
#    - 容器配置和数据
#    - docker-compose.yml文件
#    - .env环境文件
#    - 其他配置文件

# 3. 在新服务器恢复
scp -r myproject_web_1_20231201_120000/ user@new-server:/tmp/
ssh user@new-server "cd /tmp/myproject_web_1_20231201_120000 && ./restore.sh"
# 恢复脚本会自动使用docker-compose启动服务
```

### 场景3：定期自动备份

#### 方法1：使用系统服务（推荐）
```bash
# 启用定时备份服务
sudo systemctl enable docker-backup.timer
sudo systemctl start docker-backup.timer

# 查看服务状态
sudo systemctl status docker-backup.timer
```

#### 方法2：自定义cron任务
```bash
# 创建定时任务脚本
cat > /usr/local/bin/docker-auto-backup.sh << 'EOF'
#!/bin/bash
cd /opt/docker-backup
./docker-backup.sh -a --exclude-images -o /var/backups/docker
docker-cleanup 30  # 清理30天前的备份
EOF

chmod +x /usr/local/bin/docker-auto-backup.sh

# 添加crontab任务（每天凌晨2点备份）
echo "0 2 * * * /usr/local/bin/docker-auto-backup.sh" | sudo crontab -
```

#### 方法3：rsync同步到远程存储
```bash
# 创建备份同步脚本
cat > /usr/local/bin/docker-backup-sync.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/docker"
REMOTE_HOST="backup-server.company.com"
REMOTE_USER="backup"
REMOTE_PATH="/backups/docker"

# 执行备份
cd /opt/docker-backup
./docker-backup.sh -a --exclude-images -o $BACKUP_DIR

# 同步到远程服务器
rsync -avz --delete $BACKUP_DIR/ $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/

# 清理本地旧备份
docker-cleanup 7  # 保留7天本地备份
EOF

chmod +x /usr/local/bin/docker-backup-sync.sh

# 添加到crontab（每天凌晨3点备份并同步）
echo "0 3 * * * /usr/local/bin/docker-backup-sync.sh" | sudo crontab -
```

### 场景4：生产环境迁移

```bash
# 1. 在源服务器备份所有容器
./docker-backup.sh -a -f

# 2. 打包备份文件
tar -czf docker-backup-$(date +%Y%m%d).tar.gz /var/backups/docker/*

# 3. 传输到目标服务器
rsync -avz docker-backup-$(date +%Y%m%d).tar.gz user@target-server:/tmp/

# 4. 在目标服务器解压并恢复
ssh user@target-server << 'EOF'
cd /tmp
tar -xzf docker-backup-$(date +%Y%m%d).tar.gz
cd var/backups/docker
for backup_dir in */; do
    if [[ -d "$backup_dir" ]]; then
        ./docker-restore.sh -f "$backup_dir"
    fi
done
EOF
```

### 场景5：容器迁移到新名称

```bash
# 备份原容器
./docker-backup.sh old-app

# 恢复为新名称
./docker-restore.sh --container-name new-app old-app_20231201_120000/
```

## 🛡️ 安全最佳实践

### 1. 备份加密
```bash
# 在backup.conf中启用加密
ENCRYPT_BACKUPS=true
GPG_RECIPIENT="backup@company.com"

# 生成GPG密钥
gpg --gen-key
gpg --export backup@company.com > public.key
```

### 2. 权限控制
```bash
# 设置适当的文件权限
BACKUP_FILE_PERMISSIONS=600
BACKUP_DIR_PERMISSIONS=700

# 限制备份目录访问
sudo chown backup:backup /var/backups/docker
sudo chmod 700 /var/backups/docker
```

### 3. 远程备份
```bash
# 配置SSH密钥认证
ssh-keygen -t rsa -b 4096
ssh-copy-id backup@backup-server

# 配置远程备份
REMOTE_BACKUP_ENABLED=true
REMOTE_BACKUP_HOST="backup-server.company.com"
REMOTE_BACKUP_USER="backup"
REMOTE_BACKUP_PATH="/backups/docker"
```

## 🚨 故障排除

### 常见问题及解决方案

#### 1. Docker权限问题
```bash
# 错误: permission denied while trying to connect to Docker daemon
# 解决: 将用户添加到docker组
sudo usermod -aG docker $USER
newgrp docker
```

#### 2. jq工具缺失
```bash
# 错误: jq: command not found
# 解决: 安装jq工具
sudo apt install jq  # Ubuntu/Debian
sudo yum install jq  # CentOS/RHEL
```

#### 3. 磁盘空间不足
```bash
# 错误: No space left on device
# 解决: 清理旧备份或增加磁盘空间
find /var/backups/docker -type d -mtime +30 -exec rm -rf {} \;
```

#### 4. 容器启动失败
```bash
# 检查容器日志
docker logs container-name

# 检查端口冲突
netstat -tulpn | grep :port

# 手动启动容器调试
docker run -it --rm image-name /bin/bash
```

#### 5. 挂载点权限问题
```bash
# 检查文件权限
ls -la /path/to/mount

# 修复权限
sudo chown -R user:group /path/to/mount
sudo chmod -R 755 /path/to/mount
```

### 调试模式

#### 启用详细日志
```bash
# 使用-v选项启用详细输出
./docker-backup.sh -v nginx

# 或在配置文件中设置
VERBOSE_MODE=true
LOG_LEVEL=4
```

#### 试运行模式
```bash
# 在配置文件中启用试运行
DRY_RUN=true

# 或者使用测试容器
docker run --name test-container hello-world
./docker-backup.sh test-container
```

## 📊 监控和通知

### 邮件通知配置
```bash
EMAIL_NOTIFICATIONS=true
EMAIL_SMTP_SERVER="smtp.gmail.com"
EMAIL_SMTP_PORT=587
EMAIL_USERNAME="backup@company.com"
EMAIL_PASSWORD="app-password"
EMAIL_FROM="backup@company.com"
EMAIL_TO="admin@company.com"
```

### Slack通知配置
```bash
SLACK_NOTIFICATIONS=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
```

### Webhook通知配置
```bash
WEBHOOK_NOTIFICATIONS=true
WEBHOOK_URL="https://api.company.com/backup-notifications"
WEBHOOK_TIMEOUT=30
```

## 🔄 定期维护

### 定时备份最佳实践

#### 1. 设置定时备份
```bash
# 启用系统定时服务
sudo systemctl enable docker-backup.timer
sudo systemctl start docker-backup.timer

# 查看下次执行时间
sudo systemctl list-timers docker-backup.timer
```

#### 2. 配置rsync同步
```bash
# 设置SSH密钥认证
ssh-keygen -t rsa -b 4096 -f ~/.ssh/backup_key
ssh-copy-id -i ~/.ssh/backup_key.pub backup@backup-server

# 创建同步脚本
cat > /usr/local/bin/docker-backup-sync.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/docker"
REMOTE_HOST="backup-server.company.com"
REMOTE_USER="backup"
REMOTE_PATH="/backups/docker"
SSH_KEY="~/.ssh/backup_key"

# 执行备份
cd /opt/docker-backup
./docker-backup.sh -a --exclude-images -o $BACKUP_DIR

# 同步到远程服务器
rsync -avz --delete -e "ssh -i $SSH_KEY" $BACKUP_DIR/ $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/

# 清理本地旧备份
docker-cleanup 7  # 保留7天本地备份

# 发送通知
echo "Docker backup completed at $(date)" | mail -s "Backup Status" admin@company.com
EOF

chmod +x /usr/local/bin/docker-backup-sync.sh
```

#### 3. 添加到crontab
```bash
# 编辑crontab
crontab -e

# 添加以下内容
# 每天凌晨2点执行备份
0 2 * * * /usr/local/bin/docker-backup-sync.sh

# 每周日凌晨3点清理远程旧备份
0 3 * * 0 ssh backup@backup-server "find /backups/docker -type d -mtime +30 -exec rm -rf {} \;"
```

### 清理旧备份
```bash
# 手动清理30天前的备份
find /var/backups/docker -type d -mtime +30 -exec rm -rf {} \;

# 使用清理工具
docker-cleanup 30

# 自动清理（在配置文件中设置）
BACKUP_RETENTION_DAYS=30
```

### 验证备份完整性
```bash
# 启用备份验证
RUN_BACKUP_VERIFICATION=true
GENERATE_CHECKSUMS=true
CHECKSUM_ALGORITHM="sha256"
```

### 性能优化
```bash
# 调整并发数量
MAX_CONCURRENT_BACKUPS=3

# 使用更快的压缩算法
COMPRESSION_FORMAT="gzip"  # 最快
# COMPRESSION_FORMAT="xz"  # 最小文件
```

## 📞 支持和贡献

### 🌟 项目信息
- **GitHub仓库**: https://github.com/shuguangnet/dcoker_backup_script
- **主分支**: main
- **许可证**: MIT License
- **语言**: Bash Shell

### 🚀 快速开始
```bash
# 一键安装
curl -fsSL https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/install.sh | sudo bash

# 立即使用
docker-backup-menu  # 启动交互式菜单
docker-backup -a    # 备份所有容器
docker-cleanup 30   # 清理30天前的备份
```

### 获取帮助
- 查看内置帮助：`docker-backup --help` 或 `./docker-backup.sh --help`
- 检查配置文件：`backup.conf`
- 查看完整文档：[README.md](https://github.com/shuguangnet/dcoker_backup_script/blob/main/README.md)
- 一键安装脚本：[install.sh](https://github.com/shuguangnet/dcoker_backup_script/blob/main/install.sh)

### 报告问题
如果遇到问题，请在GitHub提交Issue并提供以下信息：
1. 操作系统版本
2. Docker版本
3. 错误信息和日志
4. 使用的命令和配置

**GitHub Issues**: https://github.com/shuguangnet/dcoker_backup_script/issues

### 贡献代码
欢迎提交Pull Request，请确保：
1. 代码遵循现有风格
2. 添加适当的注释
3. 更新相关文档
4. 测试新功能

**GitHub Pull Requests**: https://github.com/shuguangnet/dcoker_backup_script/pulls

## 📁 项目结构

```
docker-backup/
├── docker-backup.sh              # 主备份脚本
├── docker-restore.sh             # 恢复脚本
├── docker-backup-menu.sh         # 交互式菜单
├── docker-cleanup.sh             # 清理工具
├── backup-utils.sh               # 工具函数库
├── backup.conf                   # 配置文件
├── install.sh                    # 一键安装脚本
├── README.md                     # 项目文档
├── go/                           # Go语言应用目录
│   └── callback/                 # HTTP回调API服务
│       ├── main.go               # 主程序入口
│       ├── client_example.go     # 客户端示例
│       ├── WORKFLOW_zh-CN.md     # 工作流文档
│       └── internal/             # 内部模块
│           ├── config/           # 配置管理
│           ├── handler/          # HTTP处理器
│           ├── logger/           # 日志记录
│           └── signature/        # 签名验证
└── test-compose-detection*.sh    # 测试脚本
```

### 核心组件说明

- **docker-backup.sh**: 主要的Docker容器备份脚本
- **docker-restore.sh**: 容器恢复脚本
- **docker-backup-menu.sh**: 交互式操作菜单
- **docker-cleanup.sh**: 备份文件清理工具
- **go/callback/**: 基于Go的HTTP回调API服务，支持外部系统触发备份

## 📝 版本历史

### v1.0.0

🎉 **主要特性**:
✅ 完整的Docker容器备份和恢复功能
✅ 智能Docker Compose检测和备份
✅ 交互式菜单操作界面
✅ 定时备份和rsync同步支持
✅ 排除镜像备份选项
✅ 自动生成恢复脚本
✅ **HTTP回调API服务** - 支持外部系统通过RESTful接口触发备份

🔧 **技术改进**:
• 增强的Docker Compose检测算法（6种检测方法）
• 智能compose文件查找和备份
• 改进的错误处理和日志记录
• 兼容性优化（支持macOS和Linux）
• 模块化代码结构
• **基于Go的HTTP回调服务** - 提供安全的API接口

📦 **备份内容**:
• 容器配置信息
• 挂载点数据
• 数据卷
• 容器日志
• Docker Compose文件
• 环境配置文件

🚀 **新增功能**:
• docker-backup-menu: 交互式菜单
• docker-cleanup: 备份清理工具
• 一键安装脚本
• 定时备份配置
• rsync同步脚本
• **go/callback**: HTTP回调API服务

🐛 **问题修复**:
• 修复语法错误
• 解决容器备份循环问题
• 改进恢复脚本自动执行
• 优化文件查找逻辑

📚 **文档完善**:
• 详细的使用说明
• 快速开始指南
• 论坛介绍帖子
• 示例和最佳实践
- 初始版本发布
- 支持完整的容器备份和恢复
- 包含配置文件和命令行选项
- 支持数据卷和挂载点备份
- 提供详细的使用文档

## 📄 许可证

本项目采用MIT许可证，详见LICENSE文件。

---

**免责声明**：在生产环境使用前，请务必在测试环境中验证备份和恢复流程。定期测试备份的完整性和可恢复性。 
