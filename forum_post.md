# 🐳 【开源分享】超强Docker容器备份恢复工具 - 一键备份迁移整个容器环境

## 🎯 项目简介

还在为Docker容器迁移而头疼吗？手动导出镜像、备份数据卷、记录配置参数...太繁琐了！

我开发了一个**一键式Docker容器备份恢复工具**，能够完整备份容器的：
- ✅ 容器配置（端口映射、环境变量、启动命令等）
- ✅ 数据卷内容
- ✅ 本地挂载目录
- ✅ 容器镜像（可选）
- ✅ 运行日志

**最重要的是**：备份后可以在任何服务器上**完全自动化恢复**，无需手动配置！

---

## 🚀 快速上手（30秒）

### 一键安装
```bash
curl -fsSL https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/install.sh | sudo bash
```

### 立即使用
```bash
# 方式一：交互式菜单（推荐新手）
docker-backup-menu

# 方式二：命令行操作
docker-backup -a                                    # 备份所有运行中的容器
docker-backup -c container_name                     # 备份指定容器
docker-backup --exclude-images nginx                # 备份容器但排除镜像（节省空间）

# 恢复操作
cd /path/to/backup && ./restore.sh                  # 进入备份目录，一键恢复
docker-cleanup 30                                   # 清理30天前的备份
```

**就是这么简单！** 🎉

---

## 📦 项目地址

🔗 **GitHub**: https://github.com/shuguangnet/dcoker_backup_script

⭐ 觉得有用的话给个Star支持一下~

---

## 💡 使用场景

### 🔄 服务器迁移
- 老服务器要下线？一键备份，新服务器一键恢复
- 换云服务商？带着整个Docker环境走

### 🛡️ 数据保护  
- 定期自动备份重要容器
- 升级前备份，出问题秒恢复

### 🚀 环境复制
- 开发环境快速复制到测试环境
- 生产环境配置快速部署到新节点

### 📚 学习研究
- 备份别人分享的容器环境
- 快速恢复实验环境

---

## 📖 详细使用教程

### 🛠️ 安装方式

#### 方式一：一键安装（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/shuguangnet/dcoker_backup_script/main/install.sh | sudo bash
```

#### 方式二：手动安装
```bash
git clone https://github.com/shuguangnet/dcoker_backup_script.git
cd dcoker_backup_script
sudo ./install.sh
```

### 🎮 基本命令

安装完成后，你将拥有以下命令：

```bash
# 交互式菜单（推荐新手使用）
docker-backup-menu            # 启动交互式操作菜单

# 备份相关
docker-backup -a                    # 备份所有运行容器
docker-backup -c nginx              # 备份指定容器  
docker-backup -c "web db redis"     # 备份多个容器
docker-backup -l                    # 列出可备份的容器

# 排除选项（节省空间和时间）
docker-backup --exclude-images nginx    # 备份nginx但排除镜像
docker-backup --exclude-volumes mysql   # 备份mysql但排除数据卷
docker-backup --exclude-mounts app      # 备份app但排除挂载点

# 恢复相关
docker-restore                      # 交互式恢复向导
# 或直接在备份目录执行 ./restore.sh

# 维护工具
docker-cleanup 30                   # 清理30天前的备份
docker-cleanup 0                    # 清理所有备份
docker-cleanup -h                   # 查看清理帮助

# 实用工具
docker-backup -h                    # 查看帮助
```

### 🖥️ 交互式菜单功能

运行 `docker-backup-menu` 启动交互式菜单，包含：

#### 📦 备份操作
- **选项1-6**: 备份所有容器的不同模式
  - 1) 备份所有运行中的容器
  - 2) 备份所有容器（排除镜像）
  - 3) 备份所有容器（排除数据卷）
  - 4) 备份所有容器（排除挂载点）
  - 5) 备份所有容器（仅配置和日志）
  - 6) 完整备份所有容器（包含镜像）

#### 🎯 指定容器备份
- **选项7-10**: 备份指定容器的不同模式
  - 7) 备份指定容器
  - 8) 备份指定容器（排除镜像）
  - 9) 备份指定容器（排除数据卷）
  - 10) 备份指定容器（排除挂载点）

#### 🔄 恢复操作
- **选项11-12**: 恢复容器操作
  - 11) 恢复容器（交互式向导）
  - 12) 列出可恢复的备份

#### 🧹 维护操作
- **选项13-15**: 维护和状态检查
  - 13) 清理旧备份文件
  - 14) 查看备份统计信息
  - 15) 检查系统状态

#### ⚙️ 配置和帮助
- **选项16-18**: 配置和帮助
  - 16) 编辑配置文件
  - 17) 查看帮助信息
  - 18) 查看版本信息

### 📂 备份内容详解

每个容器备份包含完整信息：

```
container_backup_20240126_123456/
├── config/                         # 容器配置
│   ├── container_inspect.json      # 完整容器信息
│   ├── dockerfile                  # 重建用Dockerfile
│   └── docker_run_command.sh       # 原始运行命令
├── volumes/                        # 数据卷备份
│   ├── volume1.tar.gz
│   └── volume2.tar.gz  
├── mounts/                         # 挂载目录备份
│   ├── mount_1/
│   └── mount_2/
├── logs/                           # 容器日志
│   └── container.log
├── container_image.tar.gz          # 容器镜像（可选）
├── restore.sh                     # 一键恢复脚本
└── backup_summary.txt             # 备份摘要信息
```

### 🔧 高级配置

编辑配置文件 `/etc/docker-backup/backup.conf`：

```bash
# 备份存储位置
BACKUP_DIR="/opt/docker-backups"

# 日志级别 (DEBUG, INFO, WARNING, ERROR)  
LOG_LEVEL="INFO"

# 是否默认排除镜像备份（节省空间）
DEFAULT_EXCLUDE_IMAGES=false

# 是否默认排除数据卷备份
DEFAULT_EXCLUDE_VOLUMES=false

# 是否默认排除挂载点备份
DEFAULT_EXCLUDE_MOUNTS=false

# 备份保留天数
RETENTION_DAYS=30

# 并发备份数量
MAX_PARALLEL=3
```

### 📋 实际使用示例

#### 示例1：网站环境迁移（排除镜像）
```bash
# 旧服务器 - 备份Web环境（排除镜像节省空间）
docker-backup --exclude-images "nginx mysql redis wordpress"

# 打包传输（文件更小）
tar -czf web_backup.tar.gz /tmp/docker-backups/

# 新服务器 - 解压恢复  
tar -xzf web_backup.tar.gz
cd nginx_backup_xxx && ./restore.sh
cd mysql_backup_xxx && ./restore.sh
cd redis_backup_xxx && ./restore.sh  
cd wordpress_backup_xxx && ./restore.sh
```

#### 示例2：定时自动备份（排除镜像）
```bash
# 添加定时任务
crontab -e

# 每天凌晨2点备份所有容器（排除镜像）
0 2 * * * /usr/local/bin/docker-backup -a --exclude-images

# 每周日清理30天前的备份
0 3 * * 0 /usr/local/bin/docker-cleanup 30
```

#### 示例3：容器升级保险
```bash
# 升级前备份（排除镜像）
docker-backup --exclude-images myapp

# 升级操作
docker pull myapp:latest
docker stop myapp
docker rm myapp
docker run -d --name myapp myapp:latest

# 如果有问题，立即恢复
cd /tmp/docker-backups/myapp_xxx
./restore.sh
```

### 🔍 故障排除

#### 常见问题

1. **权限问题**
```bash
sudo chmod +x /usr/local/bin/docker-*
```

2. **jq工具缺失**
```bash
# Ubuntu/Debian
sudo apt install jq

# CentOS/RHEL  
sudo yum install jq
```

3. **Docker权限**
```bash
sudo usermod -aG docker $USER
# 重新登录生效
```

#### 查看详细日志
```bash
# 调试模式运行
LOG_LEVEL=DEBUG docker-backup -c container_name

# 查看系统日志
journalctl -u docker-backup
```

---

## 🌟 特色功能

### ⚡ 智能备份
- 自动识别容器依赖关系
- 增量备份节省空间
- 并发处理提升速度
- **可选择排除镜像备份**（节省大量空间）

### 🔒 数据完整性
- MD5校验确保数据完整
- 备份前后状态对比
- 详细的备份报告

### 🎯 精确恢复
- 一键恢复到任意服务器
- 自动处理端口冲突
- 智能镜像拉取

### 📊 监控管理
- 备份进度实时显示
- 存储空间统计
- 备份历史记录

### 🖥️ 交互式操作
- **图形化菜单界面**
- 一键选择操作模式
- 实时状态反馈
- 新手友好设计

---

## 🆕 最新功能

### 🚫 排除镜像备份
```bash
# 排除镜像备份，大幅节省空间和时间
docker-backup --exclude-images nginx mysql

# 在配置文件中设置默认排除
DEFAULT_EXCLUDE_IMAGES=true
```

### 🖥️ 交互式菜单
```bash
# 启动交互式菜单
docker-backup-menu

# 提供18种快捷操作选项
# 无需记忆复杂命令
```

**优势：**
- 📦 **节省空间**：镜像通常占用大量空间
- ⚡ **提升速度**：跳过镜像备份，速度更快
- 🌐 **网络友好**：恢复时自动从Docker Hub拉取最新镜像
- 🖥️ **操作简单**：交互式菜单，新手也能轻松使用

---

## 🤝 贡献与反馈

这个项目还在持续改进中，欢迎：

- 🐛 **Bug反馈**：遇到问题请提issue
- 💡 **功能建议**：有好想法请告诉我  
- 🔧 **代码贡献**：欢迎提PR
- ⭐ **点个Star**：你的支持是我继续开发的动力

---

## 📄 开源协议

本项目采用 MIT 协议开源，可自由使用、修改和分发。

---

**如果这个工具对你有帮助，请给个⭐Star支持！**

有任何问题欢迎在下方留言讨论~ 🎈 