const fs = require("fs");
const crypto = require("crypto");
const http = require("http");

// 从 ../../backup.conf 同步读取 callback_secret
const configPath = "../../backup.conf";
const configContent = fs.readFileSync(configPath, "utf8");
const callbackSecret = configContent.trim();

// 获取命令行参数（排除 node 和脚本路径）
const args = process.argv.slice(2);

// 构造 JSON 字符串
const requestBody = JSON.stringify({ args: args });

// 使用 HMAC-SHA256 生成签名
const signature = crypto
  .createHmac("sha256", callbackSecret)
  .update(requestBody)
  .digest("hex");

// 定义请求选项
const options = {
  hostname: "localhost",
  port: 47731,
  path: "/backup",
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-Signature": signature,
    "Content-Length": Buffer.byteLength(requestBody),
  },
};

// 发送 HTTP 请求
const req = http.request(options, (res) => {
  let data = "";

  // 监听数据接收
  res.on("data", (chunk) => {
    data += chunk;
  });

  // 监听响应结束
  res.on("end", () => {
    console.log("Response from server:");
    console.log(data);
  });
});

// 监听请求错误
req.on("error", (e) => {
  console.error(`Problem with request: ${e.message}`);
});

// 发送请求体
req.write(requestBody);
req.end();
