package cangjie

import std.net.*
import std.fs.*

main() {
    let port: UInt16 = 8080
    let serverSocket = TcpServerSocket(bindAt: port)
    
    // 必须显式调用 bind() 才能真正绑定 socket
    serverSocket.bind()
    
    println("Serving HTTP on port ${port}...")

    while (true) {
        let socket = serverSocket.accept()

        try {
            var reqBuffer = Array<Byte>(4096, repeat: 0)
            let bytesRead = socket.read(reqBuffer)

            if (bytesRead > 0) {
                let requestStr = String.fromUtf8(reqBuffer[0..bytesRead])
                println("Request:\n${requestStr}")

                let lines = requestStr.split("\r\n")
                var filePath = "htdocs/index.html"

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

                // 路径穿越防护：规范化路径（消除 .. 和 .）并确保不逃离 htdocs 目录
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

                // favicon.ico 请求静默处理，不输出日志
                if (filePath == "htdocs/favicon.ico") {
                    let noContent = "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n"
                    socket.write(noContent.toArray())
                    socket.close()
                    continue
                }

                var contentBytes = "<h1>404 Not Found</h1>".toArray()
                var statusCode = "404 Not Found"
                var contentType = "text/html; charset=utf-8"

                try {
                    let file = File(filePath, OpenMode.Read)
                    let bufferSize = 1024 * 1024
                    var fileBuffer = Array<Byte>(bufferSize, repeat: 0)
                    let fileBytesRead = file.read(fileBuffer)
                    file.close()

                    if (fileBytesRead > 0) {
                        contentBytes = fileBuffer[0..fileBytesRead]
                        statusCode = "200 OK"
                        if (filePath.endsWith(".png")) {
                            contentType = "image/png"
                        } else if (filePath.endsWith(".jpg") || filePath.endsWith(".jpeg")) {
                            contentType = "image/jpeg"
                        }
                    }
                } catch (e: Exception) {
                    println("File not found: ${filePath}, Error: ${e}")
                }

                let responseHeader = "HTTP/1.1 ${statusCode}\r\n" +
                                     "Content-Type: ${contentType}\r\n" +
                                     "Content-Length: ${contentBytes.size}\r\n" +
                                     "Connection: close\r\n" +
                                     "\r\n"

                let headerBytes = responseHeader.toArray()
                socket.write(headerBytes)
                socket.write(contentBytes)
                println("Response sent")
            }

            socket.close()
            println("Client disconnected")

        } catch (e: Exception) {
            println("Error handling client: ${e}")
        }
    }
}

// 规范化路径：将 path/../ 折叠为上级目录，去除 ./
// 例如 "htdocs/a/../b/./c" → "htdocs/b/c"
func normalizePath(path: String): String {
    // 统一使用 / 作为分隔符
    let parts = path.split("/")
    let maxParts = parts.size
    var result = Array<String>(maxParts, repeat: "")
    var resultLen = 0

    for (part in parts) {
        if (part == "" || part == ".") {
            // 忽略空段和 .（当前目录）
            continue
        } else if (part == "..") {
            // .. 回到上级目录（但不能超过根）
            if (resultLen > 0) {
                resultLen -= 1
            }
        } else {
            result[resultLen] = part
            resultLen += 1
        }
    }

    // 重新拼接路径
    var normalized = ""
    for (i in 0..resultLen) {
        if (i > 0) {
            normalized += "/"
        }
        normalized += result[i]
    }
    normalized
}
