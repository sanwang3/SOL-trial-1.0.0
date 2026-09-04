# Solana Monitor 正式版许可证分发指南

## 目录

1. [许可证系统说明](#许可证系统说明)
2. [密钥对生成](#密钥对生成)
3. [生成客户许可证](#生成客户许可证)
4. [分发给客户](#分发给客户)
5. [客户激活流程](#客户激活流程)
6. [常见问题](#常见问题)

---

## 许可证系统说明

### 安全架构

本系统使用 **Ed25519数字签名** 技术确保许可证的安全性：

- **私钥**：由开发者保管，用于签名许可证
- **公钥**：编译到程序中，用于验证许可证签名
- **签名验证**：程序运行时验证许可证的完整性和真实性

### 许可证格式

```
SLMN-user_id-expiry-nonce-signature
```

- **SLMN**: 产品前缀，表示 Solana Monitor
- **user_id**: Base64编码的用户标识
- **expiry**: Base64编码的过期时间（Unix时间戳）
- **nonce**: Base64编码的16字节随机数
- **signature**: Base64编码的Ed25519签名（64字节）

### 版本区别

| 版本 | 试用期 | 许可证 | 说明 |
|------|--------|--------|------|
| 试用版 | 15天 | 不需要 | 首次运行自动开始计时 |
| 正式版 | 无限制 | 需要 | 需要有效的签名许可证才能运行 |

---

## 密钥对生成

### 首次使用

在分发正式版之前，您需要生成一对密钥：

```bash
# 编译密钥生成工具
cargo build --release --bin generate_keypair

# 运行密钥生成工具
cargo run --release --bin generate_keypair
```

### 输出文件

工具会生成以下文件：

1. **public_key.txt** - 公钥（Base64格式）
2. **private_key.txt** - 私钥（Base64格式）
3. **private_key.der** - 私钥（DER格式）

### 更新公钥

将 `public_key.txt` 中的内容复制到 `src/license.rs` 的 `PUBLIC_KEY` 常量中：

```rust
const PUBLIC_KEY: &[u8] = &[
    // 替换为实际生成的公钥
    0x00, 0x00, 0x00, 0x00, // ...
];
```

然后重新编译程序。

### 重要安全提示

⚠️ **私钥必须妥善保管！**

- 不要将私钥文件包含在发布包中
- 不要将私钥提交到版本控制系统
- 建议将私钥存储在安全的离线位置

---

## 生成客户许可证

### 方法一：使用Rust工具（推荐）

```bash
# 格式：cargo run --release --bin generate_keypair -- <用户ID> <过期时间> <私钥文件>

# 示例：为customer123生成有效期到2025-12-31的许可证
cargo run --release --bin generate_keypair -- customer123 2025-12-31 private_key.der
```

### 方法二：使用JavaScript工具（仅用于验证）

```bash
# 验证许可证格式
node tools/generate_license.js validate SLMN-XXXX-XXXX-XXXX-XXXX

# 解析许可证信息
node tools/generate_license.js parse SLMN-XXXX-XXXX-XXXX-XXXX
```

⚠️ **注意**：JavaScript工具仅用于验证和演示，不能生成有效的签名许可证！

---

## 分发给客户

### 方式一：邮件发送

将以下内容发送给客户：

```
主题：Solana Monitor 正式版许可证

您好，

您的正式版许可证密钥为：

SLMN-XXXX-XXXX-XXXX-XXXX-XXXX

激活步骤：
1. 解压程序包
2. 在程序目录创建文件 .sol_monitor.license
3. 将许可证密钥写入该文件
4. 运行程序

命令行激活：
echo "SLMN-XXXX-XXXX-XXXX-XXXX-XXXX" > .sol_monitor.license

如有问题请联系：564306731@qq.com
```

### 方式二：程序内激活

客户也可以通过Web管理界面激活：

1. 打开 http://localhost:8080/license.html
2. 在"激活许可证"部分输入许可证密钥
3. 点击"激活"按钮

---

## 客户激活流程

### Windows用户

```cmd
:: 创建许可证文件
echo SLMN-XXXX-XXXX-XXXX-XXXX-XXXX > .sol_monitor.license

:: 或者使用记事本
notepad .sol_monitor.license
:: 粘贴许可证密钥并保存
```

### Linux/macOS用户

```bash
# 创建许可证文件
echo "SLMN-XXXX-XXXX-XXXX-XXXX-XXXX" > .sol_monitor.license

# 或者使用编辑器
nano .sol_monitor.license
:: 粘贴许可证密钥并保存
```

### 验证激活

程序启动时会显示许可证状态：

```
╔══════════════════════════════════════════════════════════╗
║              正式版 - 无试用期限制                       ║
║  用户: customer123                                       ║
║  Copyright (C) 2024 Solana Monitor. All rights reserved. ║
╚══════════════════════════════════════════════════════════╝
```

---

## 常见问题

### Q: 如何获取许可证密钥？

A: 联系开发者购买正式版，提供您的用户ID和期望的有效期。

### Q: 许可证有效期是多久？

A: 由您购买时选择的有效期决定，通常为1年或永久。

### Q: 许可证可以转移吗？

A: 许可证与用户ID绑定，不可转移。

### Q: 试用版到期后怎么办？

A: 试用版到期后程序无法使用，需要购买正式版许可证。

### Q: 如何续期？

A: 联系开发者获取新的许可证密钥。

### Q: 程序提示"许可证无效"怎么办？

A: 检查以下几点：
1. 许可证文件是否正确创建
2. 许可证密钥是否完整复制
3. 许可证是否已过期
4. 用户ID是否匹配

### Q: 可以在多台电脑上使用吗？

A: 正式版许可证与用户ID绑定，可以在任何电脑上使用，但需要有效的许可证文件。

---

## 技术支持

如有问题或需要购买正式版，请联系：

- **邮箱**: 564306731@qq.com
- **文档**: https://github.com/your-repo/sol-monitor

---

## 版本历史

### v1.0.0 (2024)
- 初始版本
- 支持Ed25519数字签名
- 支持离线许可证激活
