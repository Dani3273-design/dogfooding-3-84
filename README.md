# System Resource Monitor

一个跨平台的系统资源监控脚本，支持 Ubuntu 24.04 和 macOS。

## 功能特性

- **CPU 监控**: 实时显示 CPU 使用率百分比
- **内存监控**: 实时显示内存使用率百分比
- **网络带宽监控**: 每个网卡单独显示上传/下载速率
- **磁盘 I/O 监控**: 实时显示磁盘读写速率
- **彩色显示**: 根据使用率自动变色
  - 白色: < 30%
  - 黄色: 30% - 80%
  - 黑底白字: 80% - 95%
  - 红色: 95% - 100%
- **可配置刷新间隔**: 通过命令行参数设置
- **无滚动刷新**: 数据直接覆盖，不滚动屏幕

## 系统要求

- Ubuntu 24.04 或 macOS
- Bash 4.0+

## 安装

### 1. 添加执行权限

```bash
chmod +x install.shell main.shell
```

### 2. 运行安装脚本

安装所需的依赖工具：

```bash
./install.shell
```

安装脚本会自动检测操作系统并安装以下依赖：

**Ubuntu 24.04:**
- `bc` - 计算器工具
- `sysstat` - 系统统计工具（包含 iostat）
- `net-tools` - 网络工具

**macOS:**
- `bc` - 计算器工具
- `sysstat` - 系统统计工具（包含 iostat）

## 使用方法

### 基本用法

```bash
./main.shell [刷新间隔秒数]
```

### 示例

使用默认刷新间隔（2秒）：

```bash
./main.shell
```

设置刷新间隔为 1 秒：

```bash
./main.shell 1
```

设置刷新间隔为 5 秒：

```bash
./main.shell 5
```

### 退出监控

按 `Ctrl+C` 退出程序。

## 输出示例

```
========================================
       System Resource Monitor
========================================
Refresh Interval: 2s
OS: macos
----------------------------------------

CPU Usage:
[████████████░░░░░░░░░░░░░░░░░░░░]  38.5%

Memory Usage:
[██████████████████████░░░░░░░░░░]  65.2%

----------------------------------------
Network Bandwidth (per interface):

  en0:       ↓ 125.50 KB/s  ↑ 45.20 KB/s
  en1:       ↓ 0.00 KB/s    ↑ 0.00 KB/s

----------------------------------------
Disk I/O:

  Read:  1.25 MB/s
  Write: 0.85 MB/s

----------------------------------------
Press Ctrl+C to exit
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `main.shell` | 主监控脚本 |
| `install.shell` | 依赖安装脚本 |
| `README.md` | 本说明文档 |

## 技术细节

### CPU 使用率计算

- **Linux**: 读取 `/proc/stat` 获取 CPU 时间片，计算差值得到使用率
- **macOS**: 使用 `top` 命令获取 CPU 使用率

### 内存使用率计算

- **Linux**: 使用 `free` 命令获取内存信息
- **macOS**: 使用 `vm_stat` 获取内存页面信息，计算实际使用量

### 网络带宽计算

- **Linux**: 读取 `/sys/class/net/[interface]/statistics/` 下的字节数
- **macOS**: 使用 `netstat -ibn` 获取网络接口统计信息

### 磁盘 I/O 计算

- **Linux**: 读取 `/proc/diskstats` 获取磁盘读写扇区数
- **macOS**: 使用 `iostat` 命令获取磁盘 I/O 统计

## 故障排除

### 问题: 提示 "command not found"

**解决方案**: 运行安装脚本安装依赖：

```bash
./install.shell
```

### 问题: macOS 上 iostat 不可用

**解决方案**: 使用 Homebrew 安装 sysstat：

```bash
brew install sysstat
```

### 问题: 权限被拒绝

**解决方案**: 添加执行权限：

```bash
chmod +x main.shell install.shell
```

## 许可证

MIT License
