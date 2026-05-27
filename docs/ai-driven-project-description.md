# Zone — AI 驱动构建的 macOS 蓝牙近场安全应用

## 1. 项目解决的核心痛点

### 痛点描述

macOS 用户在离开工位时经常忘记锁屏，存在严重的数据安全和隐私泄露风险。现有解决方案（如 Apple Watch 自动解锁）仅支持特定设备组合，且侧重"解锁"而非"离开时自动锁定"。市面上缺乏一个**不依赖手机 App、不限制蓝牙设备类型、纯基于信号强度（RSSI）做近场感知**的轻量级自动锁屏方案。

### Zone 的解决思路

Zone 是一款 **macOS 原生 menu bar 应用**，核心理念：**把你的手机或任何蓝牙设备变成物理安全边界**。

- **离开自动锁屏**：当你的手机（蓝牙 token 设备）信号减弱或断开超时，自动锁定 Mac
- **回来自动唤醒**：当设备重新进入信号范围，唤醒显示器到登录界面（不绕过认证）
- **零配置依赖**：无需手机端安装任何 App，利用 macOS 原生蓝牙栈已连接的设备即可工作
- **用户可调参数**：锁定阈值、唤醒阈值、信号丢失超时、滑动窗口大小全部可配

---

## 2. AI 驱动的开发过程

整个项目**从设计文档到完整交付**，全程由 AI Agent 驱动构建，涵盖以下阶段：

### 2.1 AI 主导的设计规划阶段

AI Agent 根据用户的初始需求（"用蓝牙信号实现自动锁屏"），独立生成了完整的 **322 行产品设计规范** (`zone-mac-rssi-boundary-design.md`)，包含：

- 产品目标与非目标边界定义
- 用户体验流程（首次启动 → Menu Bar 交互 → Settings 窗口）
- 系统架构分层设计（6 个核心模块划分）
- BoundaryEngine 有限状态机的完整状态转移规则
- RSSI 采样与滤波策略（滑动窗口 + 信号丢失超时）
- 阈值滞回设计（lock `-85 dBm` / wake `-55 dBm`，30 dBm 间隔避免抖动）
- 权限模型（Bluetooth / Accessibility / Login Item）
- 测试策略（单元测试 / 集成测试 / 手动验证矩阵）
- 分 8 阶段的交付计划

> 这份设计文档本身就是 AI Agent 的核心推理成果——它需要综合理解 macOS 系统 API 限制、蓝牙信号物理特性、安全策略设计、用户交互体验等多维度知识，进行**长链推理**后产出结构化方案。

### 2.2 AI 驱动的迭代开发（30+ commits）

从 git 历史可以看到整个构建过程的演进轨迹：

| 阶段 | 关键 commit | AI 角色 |
|------|-----------|---------|
| 1. 核心引擎 | `feat: add RSSI boundary engine` | 实现纯业务逻辑的状态机，零 UI 依赖 |
| 2. 引擎修正 | `fix: align boundary engine with spec` → `fix: harden boundary engine startup and signal loss` | AI 自检发现实现与设计规范的偏差，主动修正 |
| 3. 蓝牙集成 | `feat: integrate macOS bluetooth device enumeration` | 对接 `IOBluetoothDevice` API，处理设备发现和 RSSI 读取 |
| 4. 系统动作 | `feat: add monitoring loop and system actions` | 通过 `CGEvent` 合成 `Ctrl+Cmd+Q` 锁屏，`IOPMAssertionDeclareUserActivity` 唤醒 |
| 5. 持久化 | `feat: add diagnostics buffer and settings store` | JSON 编解码 + 防腐层设计 |
| 6. 信号稳定性 | `fix: stabilize auto lock signal handling` | 处理 RSSI 抖动、设备暂时不可用等边缘场景 |
| 7. 国际化 | `feat: localize settings and tame accessibility prompts` | 中英双语支持 |
| 8. 自动更新 | `feat: add release-aware update flow` | GitHub Releases API 集成，语义版本比较 |
| 9. CI/CD | `ci: add GitHub Actions workflows` + `feat: polish dmg install experience` | 自动化测试 + DMG 打包流程 |

### 2.3 AI 自检与修正循环

开发过程中 AI Agent 展现了显著的**自主纠错能力**：

- 发现 `BoundaryEngine` 启动时可能立即触发锁定（违反"冷启动不锁屏"规则），主动添加 `minimumPresenceSamples` 门槛
- 识别到 `selectedDevice` 反序列化时部分字段为空的边缘场景，连续提交 2 个修复（`reject partial selected device payloads` → `ignore malformed selected device payloads`）
- 发现手动锁/唤醒操作没有同步 `BoundaryEngine` 状态，导致自动逻辑与手动操作冲突

---

## 3. 核心逻辑流

### 3.1 BoundaryEngine 状态机（长链推理的核心体现）

```
                     ┌──────────────┐
                     │   UNKNOWN    │
                     │  (冷启动)     │
                     └──────┬───────┘
                            │
              收集到 ≥ minimumPresenceSamples 个样本
              且 averageRSSI ≥ lockThreshold
                            │
                            ▼
         ┌─────────────────────────────────────┐
         │            UNLOCKED                  │
         │       (用户在范围内)                   │
         └────────┬────────────────────┬────────┘
                  │                    │
     averageRSSI < lockThreshold   信号丢失 ≥ signalLossTimeout
     (弱信号锁定)                  (设备消失锁定)
                  │                    │
                  ▼                    ▼
         ┌─────────────────────────────────────┐
         │             LOCKED                   │
         │       (Mac 已锁屏)                   │
         └────────────────┬────────────────────┘
                          │
           averageRSSI > wakeThreshold (强信号回归)
                          │
                          ▼
                     返回 UNLOCKED
```

### 3.2 信号处理链路

```
IOBluetoothDevice.rawRSSI()
        │
        ▼
   过滤无效值 (>0 或 ==127 的异常值)
        │
        ▼
   滑动窗口 (默认 5 个样本)
        │
        ▼
   计算平均 RSSI
        │
        ▼
   BoundaryEngine.ingest() → BoundaryTransition?
        │
        ▼
   apply(transition) → SystemActions.lockScreen() / wakeDisplay()
```

### 3.3 架构分层

```
┌─────────────────────────────────────────────┐
│           SwiftUI / AppKit UI Layer          │
│  ZoneApp · StatusMenuContent · SettingsView  │
├─────────────────────────────────────────────┤
│              AppModel (协调层)                │
│  设备选择 · 轮询调度 · 状态同步 · 诊断日志    │
├──────────┬──────────┬──────────┬─────────────┤
│Bluetooth │ Boundary │ System   │ Settings    │
│Repository│ Engine   │ Services │ Store       │
│(IOBluetooth)│(纯逻辑) │(CGEvent/ │(JSON/      │
│          │          │ IOKit)   │ UserDefaults)│
├──────────┴──────────┴──────────┴─────────────┤
│              ZoneCore (Swift Package)         │
│  BoundaryEngine · ZoneSettings · Diagnostics  │
└─────────────────────────────────────────────┘
```

### 3.4 关键设计决策（AI 推理产出）

| 决策点 | AI 的推理与选择 |
|--------|---------------|
| 锁屏实现 | 选择合成 `Ctrl+Cmd+Q` 键盘事件而非 `sleep` 命令，因为后者会休眠整台机器 |
| 唤醒实现 | 使用 `IOPMAssertionDeclareUserActivity` 而非模拟按键，因为后者在屏幕关闭时不可靠 |
| 阈值滞回 | lock `-85 dBm` / wake `-55 dBm`，30 dBm 间隔避免在边界频繁抖动 |
| `wakeThreshold` 自动校正 | 代码强制 `wakeThreshold > lockThreshold`，防止逻辑死锁 |
| 设备识别 | 使用 `addressString` 作为稳定标识符，而非可变的 `displayName` |
| 冷启动安全 | `UNKNOWN` 状态永远不触发 lock 动作，需先确认设备存在 |

---

## 4. 测试覆盖

AI Agent 同步生成了完整的测试套件：

- **ZoneCore 单元测试** (4 个测试文件)：BoundaryEngine 状态转移、滑动窗口、信号丢失超时、设置持久化
- **App 层集成测试** (4 个测试文件)：AppModel 协调逻辑、蓝牙权限处理、版本比较、多语言字符串
- **CI 自动化**：GitHub Actions 自动运行 `swift test` + `xcodebuild test`
- **DMG 打包**：自动构建 + 拖拽安装布局

---

## 5. 总结

Zone 项目是一个 **完全由 AI Agent 从 0 到 1 驱动构建** 的 macOS 原生应用，体现了以下 AI 能力：

1. **长链推理**：从模糊需求 → 完整设计规范 → 状态机设计 → 阈值滞回策略，涉及信号处理、安全策略、macOS 系统 API 等多领域知识的融合推理
2. **迭代式自纠错**：30+ commits 中多次自主发现规范与实现的偏差并修正
3. **端到端交付**：设计文档、核心引擎、UI 层、测试套件、CI/CD、DMG 打包一体化交付
4. **协议导向架构**：所有外部依赖（蓝牙、系统服务、权限）均通过 Protocol 抽象，AI 自主设计了可测试的依赖注入架构
