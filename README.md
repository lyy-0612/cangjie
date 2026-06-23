# Cangjie HTTP 静态文件服务器

基于仓颉（Cangjie）语言实现的轻量级 HTTP 静态文件服务器，仓颉移植期末大作业。

## 功能特性

- HTTP/1.1 静态文件服务
- 默认端口 8080
- 支持 HTML、PNG、JPG 等文件类型
- **路径穿越攻击防护**（Path Traversal Protection）
- 自动返回 404 / 403 状态码
- 完整的单元测试覆盖

## 项目结构

```
cangjie/
├── src/
│   ├── main.cj              # 服务器主程序
│   └── test/
│       └── server_test.cj   # 单元测试（9个测试用例）
├── htdocs/
│   └── index.html           # 静态页面根目录
├── screenshots/             # 测试结果截图
├── cjpm.toml                # 项目配置文件
└── README.md
```

## 快速开始

### 环境要求

- 仓颉编译器 1.1.0+
- Windows 操作系统

### 运行服务器

```bash
cjpm run
```

启动后在浏览器中访问：**http://localhost:8080**

### 运行测试

```bash
cjpm test
```

## 路径穿越防护

本项目实现了路径规范化算法（`normalizePath`），防止攻击者通过 `../` 路径访问服务器上的任意文件。

### 测试方法

```bash
# 正常访问
curl.exe http://localhost:8080

# 路径穿越攻击测试（应返回 403）
curl.exe --path-as-is http://localhost:8080/../../Windows/System32/drivers/etc/hosts
```

### 防护原理

```
请求: /../../Windows/System32/drivers/etc/hosts
拼接: htdocs/../../Windows/System32/drivers/etc/hosts
规范化: Windows/System32/drivers/etc/hosts
检查: 不以 "htdocs" 开头 → 返回 403 Forbidden
```

## 测试覆盖

| 测试用例 | 说明 |
|----------|------|
| testIndexHtmlExists | 验证 index.html 文件存在 |
| testIndexHtmlContent | 验证文件内容非空 |
| testFileNotFoundThrows | 验证不存在文件抛异常 |
| testIndexHtmlIsValidHtml | 验证文件大小合理 |
| testIndexHtmlNotEmpty | 验证文件大小在范围内 |
| testPathTraversalBlocked | 验证 `..` 路径被检测 |
| testPathTraversalParentDir | 验证上级目录访问被检测 |
| testLegitimatePathSafe | 验证合法路径不含 `..` |
| testSubDirectoryPathSafe | 验证子目录路径安全 |

## 技术栈

- **语言**: 仓颉（Cangjie）
- **标准库**: `std.net`（TCP 网络）、`std.fs`（文件系统）
- **构建工具**: cjpm
- **测试框架**: `std.unittest` + `@Test` / `@TestCase`
