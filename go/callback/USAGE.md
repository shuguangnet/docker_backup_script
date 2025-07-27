# 回调服务器使用完整指南

## 目录

1. [简介](#简介)
2. [系统要求](#系统要求)
3. [安装和配置](#安装和配置)
4. [编译和运行](#编译和运行)
5. [API 接口说明](#api-接口说明)
6. [客户端使用示例](#客户端使用示例)
7. [错误处理和日志](#错误处理和日志)
8. [安全注意事项](#安全注意事项)

## 简介

回调服务器是一个安全的 HTTP 服务，用于接收经过签名验证的请求以触发 Docker 容器和卷的备份操作。它使用 HMAC-SHA256 签名验证来确保请求的安全性。

## 系统要求

- Go 1.21 或更高版本
- Docker 环境
- Windows、Linux 或 macOS 操作系统

## 安装和配置

### 1. 配置文件设置

在项目根目录下的 `backup.conf` 文件中配置 `callback_secret`：

```bash
# backup.conf
callback_secret=your_secret_key_here
```

确保该密钥足够安全，建议使用随机生成的字符串。

### 2. 其他配置选项

`backup.conf` 文件还包含许多其他配置选项，用于控制备份行为：

- `DEFAULT_BACKUP_DIR`: 默认备份目录
- `BACKUP_RETENTION_DAYS`: 备份文件保留天数
- `COMPRESSION_FORMAT`: 备份压缩格式
- 等等...

## 编译和运行

### 1. 编译服务器

在 `go/callback/` 目录中运行以下命令来编译服务器：

```bash
go build -o callback_server .
```

这将生成一个名为 `callback_server` 的可执行文件。

### 2. 运行服务器

在 `go/callback/` 目录中运行生成的可执行文件：

```bash
./callback_server
```

服务器将在 `localhost:47731` 启动，并显示类似以下的日志信息：

```json
{
  "time": "2025-07-27T11:29:59.8830471+08:00",
  "level": "INFO",
  "msg": "Starting server",
  "port": "47731"
}
```

## API 接口说明

### `POST /backup`

此端点用于触发备份操作。

#### 请求头 (Headers)

- `X-Signature`: 请求签名，用于验证请求来源。签名是使用配置的 `callback_secret` 对请求体进行 HMAC-SHA256 计算得出的。

#### 请求体 (Request Body)

```json
{
  "args": ["arg1", "arg2"]
}
```

- `args`: 传递给备份脚本的参数数组。

#### 响应格式

成功响应：

```json
{
  "message": "Backup initiated successfully",
  "output": "备份脚本的输出内容"
}
```

错误响应：

```json
{
  "error": "错误描述信息"
}
```

## 客户端使用示例

### 1. Go 客户端示例

编译客户端示例：

```bash
go build -o client_example.exe client_example.go
```

运行客户端：

```bash
./client_example.exe -a --volumes
```

### 2. Python 客户端示例

依赖安装：

```bash
pip install requests
```

运行命令：

```bash
python client_example.py -a --volumes
```

### 3. JavaScript (Node.js) 客户端示例

无需额外依赖，直接运行：

```bash
node client_example.js -a --volumes
```

### 4. TypeScript 客户端示例

依赖安装：

```bash
npm install -g typescript ts-node
```

运行命令：

```bash
ts-node client_example.ts -a --volumes
```

### 5. cURL 客户端示例

您也可以使用 `curl` 和其他命令行工具直接触发回调。这是一个一键执行的示例，它会自动从 `backup.conf` 读取密钥、生成签名并发起请求：

```bash
# 注意：请在 go/callback 目录下运行此命令
SECRET=$(grep 'callback_secret' ../../backup.conf | cut -d '"' -f 2)
BODY='{"args": ["-a", "--volumes"]}'
SIGNATURE=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY" \
  http://localhost:47731/backup
```

## 错误处理和日志

### 日志格式

服务器使用结构化的 JSON 日志格式，包含以下字段：

- `time`: 时间戳
- `level`: 日志级别（INFO, ERROR, WARN, DEBUG）
- `msg`: 日志消息
- 其他上下文信息

示例：

```json
{
  "time": "2025-07-27T11:29:59.8830471+08:00",
  "level": "ERROR",
  "msg": "Error loading config",
  "error": "failed to read config file: open backup.conf: The system cannot find the file specified."
}
```

### 常见错误

1. **配置文件未找到**：

   - 确保 `backup.conf` 文件存在于 `go/callback/` 目录中
   - 日志会显示相应的错误信息

2. **签名验证失败**：

   - 响应：`{"error": "Invalid signature"}`
   - 确保客户端使用了正确的 `callback_secret` 生成签名

3. **请求方法不允许**：

   - 响应：`{"error": "Method not allowed"}`
   - 确保使用 POST 方法请求 `/backup` 端点

4. **JSON 解析错误**：
   - 响应：`{"error": "Invalid JSON in request body"}`
   - 确保请求体是有效的 JSON 格式

## 安全注意事项

1. **密钥保护**：

   - 确保 `callback_secret` 足够复杂且安全
   - 不要在代码中硬编码密钥
   - 定期更换密钥

2. **网络访问控制**：

   - 在生产环境中，应限制对回调服务器的网络访问
   - 使用防火墙规则只允许特定 IP 地址访问

3. **HTTPS**：

   - 在生产环境中，建议使用 HTTPS 而不是 HTTP
   - 这可以防止签名在传输过程中被截获

4. **参数验证**：
   - 客户端传递的参数会直接传递给备份脚本
   - 确保备份脚本对输入参数进行了适当的验证和清理

通过遵循以上指南，您可以安全有效地使用回调服务器来触发 Docker 备份操作。
