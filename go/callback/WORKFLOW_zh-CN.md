# GitHub Actions 工作流文档: `go-test.yml`

## 概述

本文档详细解释了 `go-test.yml` GitHub Actions 工作流。其主要目的是自动化测试基于 Go 的回调处理应用程序 (`go/callback/`) 以及主 `docker-backup.sh` 脚本。

该工作流确保当回调处理程序接收到一个签名正确的 POST 请求（模拟外部系统的回调）时，它能够成功执行 `docker-backup.sh` 脚本并传递提供的参数，并且备份过程能够按预期完成。

## 工作流触发器 (`on`)

该工作流由以下事件触发：

- **`push`**: 推送到 `main` 或 `go-callback` 分支的任何内容。
- **`pull_request`**: 针对 `main` 或 `go-callback` 分支的任何拉取请求。

这确保了对 Go 应用程序或工作流本身的更改会自动进行测试。

## 作业: `build-and-test` (`jobs.build-and-test`)

这是工作流中定义的唯一作业。它在 `ubuntu-latest` 运行器环境中运行。

### 步骤

1.  **检出代码 (`actions/checkout@v4`)**

    - 将仓库代码检索到运行器的工作区。

2.  **设置 Go 环境 (`actions/setup-go@v5`)**

    - 在运行器上安装 Go 1.22 版本。

3.  **缓存 Go 模块和构建缓存 (`actions/cache@v4`)**

    - 缓存 Go 模块下载目录 (`~/go/pkg/mod`) 和 Go 构建缓存 (`~/.cache/go-build`)，以加速后续的工作流运行。

4.  **安装依赖项 (`go mod download`)**

    - 下载 `go.mod` 中指定的 Go 模块依赖项。

5.  **构建应用程序 (`go build`)**

    - 编译位于 `go/callback/` 的 Go 应用程序，将其编译成一个名为 `myapp` 的可执行文件，并放置在项目根目录中。

6.  **创建测试文件**

    - 动态生成测试所需的两个基本文件：
      - `backup.conf`：Go 应用程序和 `docker-backup.sh` 的配置文件。
        - `port=8080`：配置 Go 应用程序监听 8080 端口。
        - `callback_secret=my-test-secret`：设置用于验证传入回调签名的密钥。
        - `scriptpath=./docker-backup.sh`：指示 Go 应用程序在收到有效回调时执行 `./docker-backup.sh`。
      - 此步骤不再创建模拟的 `test-script.sh`，因为工作流现在使用真实的 `docker-backup.sh`。

7.  **运行集成测试**

    - 这是核心测试逻辑：
      a. **启动测试容器**：运行 `docker run -d --name test-container nginx:alpine` 来启动一个简单的 Nginx 容器。这为 `docker-backup.sh` 脚本提供了一个真实的备份目标。
      b. **启动应用程序**：在后台启动已编译的 `myapp` (`nohup ... &`)，并将其日志重定向到 `app.log`。
      c. **健康检查**：轮询 `http://localhost:8080` 最多 30 秒，以确保 Go 应用程序已启动并准备好接收请求。
      d. **准备并发送回调**：
      _ 为 JSON 负载 `{"args":["test-container"]}` 使用密钥 `my-test-secret` 构造一个 SHA256 HMAC 签名。
      _ 向 `http://localhost:8080/backup` 发送一个 `POST` 请求，包含：
      _ `Content-Type: application/json`
      _ `X-Signature: sha256=<calculated_signature>`
      _ 请求体: `{"args":["test-container"]}`
      _ 这模拟了外部系统调用回调端点。
      e. **验证应用程序响应**：
      _ 检查应用程序返回的 HTTP 状态码是否为 `200 OK`。
      _ 检查响应体是否包含字符串 `"Backup initiated successfully"`。 \* 如果任何一项检查失败，工作流会输出应用程序日志 (`app.log`) 和测试容器日志以供调试，然后以错误退出。
      f. **清理**：尝试终止 `myapp` 进程并强制删除 `test-container`。

8.  **输出应用程序日志 (`if: always()`)**

    - 无论之前的步骤是成功还是失败，此步骤都会打印 `app.log` 的内容。这对于调试应用程序执行过程中出现的任何问题都非常宝贵。

9.  **列出备份产物 (`if: always()`)**
    - 无论测试结果如何，此步骤都会检查默认的备份输出目录 (`/tmp/docker-backups/`)。
    - 它会列出该目录本身，如果其中存在任何备份目录，则会列出每个备份目录的内容。
    - 这验证了 `docker-backup.sh` 确实已被 Go 应用程序执行，并产生了预期的输出结构。

## 与 `go/callback` 应用程序的交互

- 工作流构建并配置 `go/callback/` 中的应用程序。
- 它依赖于应用程序的以下能力：
  1.  从 `backup.conf` 读取其配置。
  2.  监听 `/backup` 的 `POST` 请求。
  3.  使用 `callback_secret` 验证 `X-Signature` 头部与请求体。
  4.  解析 JSON 体以提取 `args` 数组。
  5.  执行由 `scriptpath` 指定的脚本 (`./docker-backup.sh`) 并附带提取的 `args` (例如, `["test-container"]`)。
  6.  在启动脚本后返回 `200 OK` 状态和成功消息。

## 与 `docker-backup.sh` 的交互

- 工作流配置 `go/callback` 应用程序以执行 `docker-backup.sh`。
- 它提供一个真实的 Docker 容器 (`test-container`) 作为 `docker-backup.sh` 的参数。
- 它通过列出目录内容来验证 `docker-backup.sh` 是否在 `/tmp/docker-backups/` 中创建了其备份输出。
