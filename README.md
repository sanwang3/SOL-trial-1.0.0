# Solana区块链实时监控系统

一个完整的Solana区块链实时监控系统，支持监控链上转账交易，获取交易签名和区块哈希。

## 功能特性

- 实时监控Solana链上转账交易
- 支持多地址并发监控
- 提供WebSocket和Geyser gRPC两种数据源
- 支持Telegram和企业微信告警推送
- 支持PostgreSQL和ClickHouse数据持久化
- 内置自动重连、心跳保活、去重、队列削峰机制
- 支持SOL和SPL代币的精确解析
- **一键启动，自动检测和安装依赖**
- **Web管理界面，可视化配置**

## 项目结构

```
sol-monitor/
├── Cargo.toml                 # Rust工程配置
├── Dockerfile                 # Docker构建文件
├── docker-compose.yml         # 服务编排
├── .env.example               # 环境变量模板
├── start.bat                  # Windows一键启动脚本
├── start.sh                   # Linux/Mac一键启动脚本
├── sql/
│   └── clickhouse.sql         # ClickHouse建表语句
├── js/
│   └── sol-monitor.js         # JavaScript版本
├── web/
│   └── index.html             # Web管理界面
└── src/
    ├── main.rs                # 入口文件
    ├── config.rs              # 配置管理
    ├── env_check.rs           # 环境检测
    ├── lru.rs                 # LRU缓存
    ├── rpc.rs                 # HTTP RPC封装
    ├── parse.rs               # 交易解析
    ├── meta.rs                # 代币符号解析
    ├── sink.rs                # 数据持久化
    ├── notify.rs              # 告警推送
    ├── web.rs                 # Web服务器
    ├── ws_source.rs           # WebSocket数据源
    └── geyser_source.rs       # Geyser gRPC数据源
```

## 快速开始（一键启动）

### Windows用户

```bash
# 双击运行 start.bat 或在命令行执行：
start.bat
```

**脚本会自动：**
1. 检测操作系统
2. 检测并安装Rust（如果未安装）
3. 检测Node.js（可选）
4. 编译项目
5. 配置环境变量
6. 启动服务并打开Web管理界面

### Linux/Mac用户

```bash
# 添加执行权限
chmod +x start.sh

# 运行脚本
./start.sh
```

**脚本会自动：**
1. 检测操作系统和包管理器
2. 安装系统依赖（curl, build-essential等）
3. 检测并安装Rust
4. 检测Node.js（可选）
5. 编译项目
6. 配置环境变量
7. 启动服务

### Web管理界面

启动后浏览器会自动打开管理面板：`http://localhost:8080`

**Web管理界面功能：**
- 可视化配置所有环境变量
- 一键启动/停止监控
- 实时查看系统状态和交易记录
- 导出配置文件和日志

## 其他启动方式

### 方式一：直接运行编译后的程序

```bash
# 编译
cargo build --release

# 运行（自动检测环境和配置）
./target/release/sol-monitor

# 或直接指定环境变量运行
WATCH_ADDR=你的地址 ./target/release/sol-monitor
```

### 方式二：Docker部署

```bash
# 一键启动所有服务
docker compose up -d --build

# 查看日志
docker compose logs -f monitor

# 停止服务
docker compose down
```

### 方式三：JavaScript版本

```bash
cd js
npm install ws
WATCH_ADDR=你的地址 node sol-monitor.js
```

主要配置项：

```bash
# 监控的Solana地址（多个地址用逗号分隔）
WATCH_ADDR=你的Solana地址

# 数据源：ws 或 geyser
DATA_SOURCE=ws

# WebSocket端点
SOL_WS=wss://api.mainnet-beta.solana.com

# HTTP RPC端点
SOL_HTTP=https://api.mainnet-beta.solana.com

# Geyser端点（使用geyser数据源时必填）
GRPC_URL=
GRPC_X_TOKEN=

# 数据存储：postgres 或 clickhouse（留空不存储）
SINK=postgres

# PostgreSQL连接串
DATABASE_URL=postgres://sol:sol@postgres:5432/sol_monitor

# 告警推送配置
TG_BOT=
TG_CHAT=
WX_HOOK=
```

### 本地运行

#### Rust版本

```bash
# 安装依赖
cargo build --release

# 运行WebSocket版本
cargo run --release

# 运行Geyser版本（需要配置GRPC_URL）
cargo run --release --features geyser
```

#### JavaScript版本

```bash
cd js
npm install ws
WATCH_ADDR=你的Solana地址 node sol-monitor.js
```

### Docker部署

```bash
# 一键启动所有服务
docker compose up -d --build

# 查看日志
docker compose logs -f monitor

# 停止服务
docker compose down
```

## 技术架构

### 数据流

```
数据源 → 解析模块 → 符号解析 → 存储/通知
```

### 核心模块

1. **数据源模块**：负责从Solana网络获取数据
   - `ws_source.rs`：WebSocket数据源
   - `geyser_source.rs`：Geyser gRPC数据源

2. **解析模块**：负责解析交易数据
   - `parse.rs`：交易解析（余额差值法）
   - `meta.rs`：代币符号解析（Metaplex）

3. **存储模块**：负责数据持久化
   - `sink.rs`：PostgreSQL/ClickHouse存储

4. **通知模块**：负责告警推送
   - `notify.rs`：Telegram/企业微信推送

### 性能优化

- **多层去重**：签名LRU + slot单调递增 + blockhash LRU
- **自适应重连**：指数退避（1s→2s→...→30s封顶）
- **心跳保活**：15秒ping + pong超时检测
- **队列削峰**：RPC变慢时自动丢弃旧slot

## 部署方案

### 方案1：本地开发

适合开发和测试环境。

### 方案2：Docker部署

适合生产环境，包含监控程序、PostgreSQL和ClickHouse。

### 方案3：云服务器部署

建议使用云服务器，配置如下：

- CPU：2核+
- 内存：4GB+
- 存储：50GB+
- 网络：低延迟

## 扩展方向

1. **Grafana看板**：转账流水可视化
2. **ClickHouse物化视图**：地址资金流统计
3. **Web管理界面**：配置监控地址、查看统计
4. **告警规则引擎**：大额转账、异常行为检测
5. **多链支持**：扩展到其他区块链

## 许可证

MIT License
