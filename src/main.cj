package cangjie

import std.console.*
import std.net.*
import std.io.*
import std.fs.*

main() {
    let port: UInt16 = 8080 // 建议改为 8080，避免权限问题
    let serverSocket = TcpServerSocket(bindAt: port)
    println("Serving HTTP on port ${port}...")

    while (true) {
        try {
            let socket = serverSocket.accept()

            // 3. 读取请求数据
            var reqBuffer = Array<Byte>(4096, repeat: 0)
            let bytesRead = socket.read(reqBuffer)

            if (bytesRead > 0) {
                let requestStr = String.fromUtf8(reqBuffer[0..bytesRead])
                println("Request:\n${requestStr}")

                // 4. 解析文件路径
                let lines = requestStr.split("\r\n")
                var filePath = "index.html" // 默认文件

                if (lines.size > 0) {
                    let parts = lines[0].split(" ")
                    if (parts.size > 1 && parts[1] != "/") {
                        filePath = parts[1]
                    }
                }

                // 5. 读取文件内容并构建响应
                var contentBytes = "<h1>404 Not Found</h1>".toArray()
                var statusCode = "404 Not Found"
                var contentType = "text/html; charset=utf-8"

                // 尝试读取本地文件
                try {
                    let file = File(filePath, OpenMode.Read)
                    let bufferSize = 1024 * 1024
                    // 使用 fileBuffer 避免与 reqBuffer 冲突
                    var fileBuffer = Array<UInt8>(bufferSize, repeat: 0)
                    let fileBytesRead = file.read(fileBuffer)
                    file.close()

                    if (fileBytesRead > 0) {
                        contentBytes = fileBuffer[0..fileBytesRead]
                        statusCode = "200 OK"
                        // 简单的 MIME 类型判断
                        if (filePath.endsWith(".png")) {
                            contentType = "image/png"
                        } else if (filePath.endsWith(".jpg") || filePath.endsWith(".jpeg")) {
                            contentType = "image/jpeg"
                        }
                    }
                } catch (e: Exception) {
                    println("File not found: ${filePath}, Error: ${e}")
                }

                // 6. 发送 HTTP 响应
                // 关键修复：必须使用 \r\n 结尾，且不能有多余的缩进空格
                let responseHeader = "HTTP/1.1 ${statusCode}\r\n" +
                                     "Content-Type: ${contentType}\r\n" +
                                     "Content-Length: ${contentBytes.size}\r\n" +
                                     "Connection: close\r\n" +
                                     "\r\n" // 空行表示头部结束

                // 将 Header 转为字节数组
                let headerBytes = responseHeader.toArray()

                // 组合 Header 和 Body
                // 注意：这里需要确保 contentBytes 也是 Array<Byte> 或兼容类型
                // 如果 contentBytes 是 Array<UInt8>，可能需要转换，但在 Cangjie 中 Byte 通常是 Int8，UInt8 需小心处理
                // 为简化，这里假设 String.toArray() 返回的是 Byte[]，而文件读取是 UInt8[]
                // 实际发送时，我们可以分两次写，或者合并
                socket.write(headerBytes)
                socket.write(contentBytes) // 直接写入文件原始字节，支持图片
            }

            // 7. 关闭连接
            socket.close()

        } catch (e: Exception) {
            println("Error handling client: ${e}")
        }
    }
}