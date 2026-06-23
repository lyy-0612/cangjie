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
