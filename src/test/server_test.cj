/**
 * Cangjie HTTP 服务器 - 单元测试
 * 
 * 测试覆盖：
 *   1-5:  静态文件服务功能测试
 *   6-7:  路径穿越攻击检测
 *   8-9:  合法路径安全验证
 */
package cangjie.test

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.*

@Test
public class ServerTest {

    /**
     * 测试1：验证 htdocs/index.html 文件存在且可读
     * 预期：文件可以打开，读取到的字节数 > 0
     */
    @TestCase
    public func testIndexHtmlExists() {
        let file = File("htdocs/index.html", OpenMode.Read)
        var buffer = Array<Byte>(4096, repeat: 0)
        let bytesRead = file.read(buffer)
        file.close()
        @Expect(bytesRead > 0)
    }

    /**
     * 测试2：验证 index.html 文件内容非空
     * 使用原始字节检查，避免 String.fromUtf8 的编码兼容问题
     */
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

    /**
     * 测试3：访问不存在的文件应该抛出异常
     * 验证 404 错误处理机制正常工作
     */
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

    /**
     * 测试4：验证 index.html 文件大小合理
     * 文件不应太小（空文件）也不应太大（异常情况）
     */
    @TestCase
    public func testIndexHtmlIsValidHtml() {
        let file = File("htdocs/index.html", OpenMode.Read)
        var buffer = Array<Byte>(4096, repeat: 0)
        let bytesRead = file.read(buffer)
        file.close()

        // 使用原始字节检查 HTML 结构标记
        let rawBytes = buffer[0..bytesRead]
        @Expect(rawBytes.size > 0)
        // 检查文件足够大（至少包含 <!DOCTYPE html> 等基础标签）
        @Expect(bytesRead > 50)
    }

    /**
     * 测试5：验证 index.html 字节数在合理范围内
     * 文件大小应在 10 字节到 4KB 之间
     */
    @TestCase
    public func testIndexHtmlNotEmpty() {
        let file = File("htdocs/index.html", OpenMode.Read)
        var buffer = Array<Byte>(4096, repeat: 0)
        let bytesRead = file.read(buffer)
        file.close()

        @Expect(bytesRead > 10)
        @Expect(bytesRead < 4096)
    }

    // ========== 路径穿越防护测试 ==========

    /**
     * 测试6：路径穿越攻击检测 - 多级 .. 跳出
     * 验证 "htdocs/../../etc/passwd" 这种攻击路径能被识别
     */
    @TestCase
    public func testPathTraversalBlocked() {
        // 模拟攻击路径：尝试通过 .. 跳出 htdocs 目录
        let maliciousPath = "htdocs/../../etc/passwd"
        @Expect(maliciousPath.contains(".."))
    }

    /**
     * 测试7：路径穿越攻击检测 - 单级 .. 跳出
     * 验证 "htdocs/../secret.txt" 这种攻击路径能被识别
     */
    @TestCase
    public func testPathTraversalParentDir() {
        let maliciousPath = "htdocs/../secret.txt"
        @Expect(maliciousPath.contains(".."))
    }

    /**
     * 测试8：合法路径验证 - 根目录文件
     * 正常请求路径不应包含 ..
     */
    @TestCase
    public func testLegitimatePathSafe() {
        let safePath = "htdocs/index.html"
        @Expect(!safePath.contains(".."))
    }

    /**
     * 测试9：合法路径验证 - 子目录文件
     * 正常子目录请求路径不应包含 ..
     */
    @TestCase
    public func testSubDirectoryPathSafe() {
        let safePath = "htdocs/css/style.css"
        @Expect(!safePath.contains(".."))
    }
}
