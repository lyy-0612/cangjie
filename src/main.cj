/**
 * Cangjie HTTP 静态文件服务器
 * 
 * 功能：
 *   - 监听 8080 端口，提供 htdocs 目录下的静态文件服务
 *   - 支持 HTML、PNG、JPG 文件类型
 *   - 路径穿越攻击防护
 *   - 自动处理 favicon.ico 请求
 */
package cangjie

import std.net.*
import std.fs.*

main() {
    // 服务器监听端口
    let port: UInt16 = 8080
    let serverSocket = TcpServerSocket(bindAt: port)
    
    // 必须显式调用 bind() 才能真正绑定 socket
    serverSocket.bind()
    
    println("Serving HTTP on port ${port}...")

    // 主循环：持续接受客户端连接
    while (true) {
        // 阻塞等待客户端连接
        let socket = serverSocket.accept()

        try {
            // 读取 HTTP 请求（最大 4KB）
            var reqBuffer = Array<Byte>(4096, repeat: 0)
            let bytesRead = socket.read(reqBuffer)

            if (bytesRead > 0) {
                // 将字节流解析为 HTTP 请求字符串
                let requestStr = String.fromUtf8(reqBuffer[0..bytesRead])
                println("Request:\n${requestStr}")

                // 解析 HTTP 请求行，提取请求路径
                let lines = requestStr.split("\r\n")
                var filePath = "htdocs/index.html"  // 默认首页

                if (lines.size > 0) {
                    let parts = lines[0].split(" ")
                    if (parts.size > 1 && parts[1] != "/") {
                        // 去掉开头的 / 并加上 htdocs 目录前缀
                        let rawPath = parts[1]
                        if (rawPath.startsWith("/")) {
                            filePath = "htdocs" + rawPath
                        } else {
                            filePath = "htdocs/" + rawPath
                        }
                    }
                }

                // ========== 路径穿越防护 ==========
                // 规范化路径（消除 .. 和 .），防止攻击者访问 htdocs 外的文件
                // 例如 "htdocs/../../etc/passwd" → "etc/passwd"
                // 规范化后不以 "htdocs" 开头 → 判定为攻击 → 返回 403
                filePath = normalizePath(filePath)
                if (!filePath.startsWith("htdocs")) {
                    println("Blocked path traversal attempt: ${filePath}")
                    let forbiddenBody = "<h1>403 Forbidden</h1>".toArray()
                    let forbiddenHeader = "HTTP/1.1 403 Forbidden\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: ${forbiddenBody.size}\r\nConnection: close\r\n\r\n"
                    socket.write(forbiddenHeader.toArray())
                    socket.write(forbiddenBody)
                    socket.close()
                    println("Client disconnected (blocked)")
                    continue
                }

                // favicon.ico 请求静默处理，返回 204 不输出日志
                if (filePath == "htdocs/favicon.ico") {
                    let noContent = "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n"
                    socket.write(noContent.toArray())
                    socket.close()
                    continue
                }

                // ========== 读取文件并构建响应 ==========
                // 默认 404 响应
                var contentBytes = "<h1>404 Not Found</h1>".toArray()
                var statusCode = "404 Not Found"
                var contentType = "text/html; charset=utf-8"

                try {
                    // 尝试打开请求的文件
                    let file = File(filePath, OpenMode.Read)
                    let bufferSize = 1024 * 1024  // 最大 1MB 文件
                    var fileBuffer = Array<Byte>(bufferSize, repeat: 0)
                    let fileBytesRead = file.read(fileBuffer)
                    file.close()

                    if (fileBytesRead > 0) {
                        // 文件读取成功，设置 200 响应
                        contentBytes = fileBuffer[0..fileBytesRead]
                        statusCode = "200 OK"

                        // 根据文件扩展名设置 MIME 类型
                        if (filePath.endsWith(".png")) {
                            contentType = "image/png"
                        } else if (filePath.endsWith(".jpg") || filePath.endsWith(".jpeg")) {
                            contentType = "image/jpeg"
                        }
                    }
                } catch (e: Exception) {
                    // 文件不存在，使用默认的 404 响应
                    println("File not found: ${filePath}, Error: ${e}")
                }

                // ========== 发送 HTTP 响应 ==========
                let responseHeader = "HTTP/1.1 ${statusCode}\r\n" +
                                     "Content-Type: ${contentType}\r\n" +
                                     "Content-Length: ${contentBytes.size}\r\n" +
                                     "Connection: close\r\n" +
                                     "\r\n"

                let headerBytes = responseHeader.toArray()
                socket.write(headerBytes)     // 先发响应头
                socket.write(contentBytes)    // 再发响应体
                println("Response sent")
            }

            // 关闭连接（HTTP/1.1 短连接模式）
            socket.close()
            println("Client disconnected")

        } catch (e: Exception) {
            println("Error handling client: ${e}")
        }
    }
}

/**
 * 规范化路径：将路径中的 .. 和 . 折叠处理
 * 
 * 示例：
 *   "htdocs/a/../b/./c" → "htdocs/b/c"
 *   "htdocs/../../etc/passwd" → "etc/passwd"
 * 
 * 用于路径穿越防护，消除攻击者插入的 .. 目录跳转
 */
func normalizePath(path: String): String {
    // 按 / 分割路径
    let parts = path.split("/")
    let maxParts = parts.size
    var result = Array<String>(maxParts, repeat: "")
    var resultLen = 0

    for (part in parts) {
        if (part == "" || part == ".") {
            // 忽略空段（连续的 /）和 .（当前目录）
            continue
        } else if (part == "..") {
            // .. 回到上级目录（但不能超过根目录）
            if (resultLen > 0) {
                resultLen -= 1
            }
        } else {
            // 普通路径段，加入结果
            result[resultLen] = part
            resultLen += 1
        }
    }

    // 重新拼接为规范路径
    var normalized = ""
    for (i in 0..resultLen) {
        if (i > 0) {
            normalized += "/"
        }
        normalized += result[i]
    }
    normalized
}
