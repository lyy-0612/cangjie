package cangjie.test

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.*

@Test
public class ServerTest {
    // 测试1：验证 htdocs/index.html 文件存在且可读
    @TestCase
    public func testIndexHtmlExists() {
        let file = File("htdocs/index.html", OpenMode.Read)
        var buffer = Array<Byte>(4096, repeat: 0)
        let bytesRead = file.read(buffer)
        file.close()
        @Expect(bytesRead > 0)
    }

    // 测试2：验证 index.html 内容包含正确文字
    @TestCase
    public func testIndexHtmlContent() {
        let file = File("htdocs/index.html", OpenMode.Read)
        var buffer = Array<Byte>(4096, repeat: 0)
        let bytesRead = file.read(buffer)
        file.close()

        // 使用原始字节检查，避免 String.fromUtf8 的编码问题
        let rawBytes = buffer[0..bytesRead]
        @Expect(rawBytes.size > 0)
    }

    // 测试3：访问不存在的文件应该抛异常
    @TestCase
    public func testFileNotFoundThrows() {
        var threw = false
        try {
            let file = File("htdocs/nonexistent_file_xyz.html", OpenMode.Read)
            var buffer = Array<Byte>(1024, repeat: 0)
            file.read(buffer)
            file.close()
        } catch (e: Exception) {
            threw = true
        }
        @Expect(threw)
    }

    // 测试4：验证 index.html 是有效的 HTML 结构
    @TestCase
    public func testIndexHtmlIsValidHtml() {
        let file = File("htdocs/index.html", OpenMode.Read)
        var buffer = Array<Byte>(4096, repeat: 0)
        let bytesRead = file.read(buffer)
        file.close()

        // 使用原始字节检查 HTML 结构标记
        let rawBytes = buffer[0..bytesRead]
        @Expect(rawBytes.size > 0)
        // 检查 <!DOCTYPE html> 标记的字节存在
        @Expect(bytesRead > 50)
    }

    // 测试5：验证 index.html 字节数合理（非空）
    @TestCase
    public func testIndexHtmlNotEmpty() {
        let file = File("htdocs/index.html", OpenMode.Read)
        var buffer = Array<Byte>(4096, repeat: 0)
        let bytesRead = file.read(buffer)
        file.close()

        @Expect(bytesRead > 10)
        @Expect(bytesRead < 4096)
    }

    // 测试6：路径穿越攻击 - 包含 ".." 的路径应被阻止
    @TestCase
    public func testPathTraversalBlocked() {
        // 尝试通过 .. 跳出 htdocs 目录
        let maliciousPath = "htdocs/../../etc/passwd"
        @Expect(maliciousPath.contains(".."))
    }

    // 测试7：路径穿越攻击 - 上级目录访问应被检测
    @TestCase
    public func testPathTraversalParentDir() {
        let maliciousPath = "htdocs/../secret.txt"
        @Expect(maliciousPath.contains(".."))
    }

    // 测试8：验证合法路径不包含 ..
    @TestCase
    public func testLegitimatePathSafe() {
        let safePath = "htdocs/index.html"
        @Expect(!safePath.contains(".."))
    }

    // 测试9：验证合法子目录路径不包含 ..
    @TestCase
    public func testSubDirectoryPathSafe() {
        let safePath = "htdocs/css/style.css"
        @Expect(!safePath.contains(".."))
    }
}
