# 安全回调服务器

## 功能简介

此工具提供了一个带签名验证的安全回调接口，用于触发 Docker 容器和卷的备份操作。

## 完整使用指南

有关如何安装、配置和使用此回调服务器的完整指南，请参阅 [USAGE.md](USAGE.md) 文件。

## 配置

在使用此回调服务器之前，您需要在项目根目录下的 `backup.conf` 文件中配置 `callback_secret`。

```bash
# backup.conf
callback_secret=your_secret_key_here
```

## 编译服务器

在 `go/callback/` 目录中运行以下命令来编译服务器：

```bash
go build -o callback_server.exe .
```

这将生成一个名为 `callback_server.exe` 的可执行文件（在 Windows 上）。

## 运行服务器

在 `go/callback/` 目录中运行生成的可执行文件：

```bash
./callback_server.exe
```

服务器将在 `localhost:47731` 启动。

## API 端点

### `POST /backup`

此端点用于触发备份操作。

**Headers:**

- `X-Signature`: 请求签名，用于验证请求来源。签名是使用配置的 `callback_secret` 对请求体进行 HMAC-SHA256 计算得出的。

**Request Body:**

```json
{
  "args": ["arg1", "arg2"]
}
```

- `args`: 传递给备份脚本的参数数组。

## 编译并使用客户端示例

在 `go/callback/` 目录中运行以下命令来编译客户端示例：

```bash
go build -o client_example.exe client_example.go
```

由于 `client_example.go` 文件被构建标签 `//go:build ignore` 标记，所以编译时必须显式指定文件名。

然后可以使用以下命令来调用回调接口：

```bash
./client_example.exe -a --volumes
```

## Client Examples

### Python 示例

依赖安装: `pip install requests`，运行命令: `python client_example.py [args...]`

### JavaScript (Node.js) 示例

依赖安装: 无需额外依赖，运行命令: `node client_example.js [args...]`

### TypeScript 示例

依赖安装: `npm install -g typescript ts-node`，运行命令: `ts-node client_example.ts [args...]`

### cURL 示例 (Linux/macOS)

您也可以使用 `curl` 和其他命令行工具直接触发回调。这是一个一键执行的示例，它会自动从 `backup.conf` 读取密钥、生成签名并发起请求：

```shell
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

## 文档导航

- [完整使用指南 (USAGE.md)](USAGE.md)
- [GitHub Actions 工作流文档 (WORKFLOW_zh-CN.md)](WORKFLOW_zh-CN.md)
