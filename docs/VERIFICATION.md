# 验收记录 · 2026-09-30

> 本文记录 C 方案迁移前的基线。后续原生视觉改动及其相关复验见 [C 方案原生验收](C-DESIGN-VERIFICATION.md)，请勿把此处旧截图当作当前外观。

## 环境与边界

- macOS 27.2 / Xcode 27；iOS 26.5。标准设备 iPhone 17（402×874 pt），另检查 375×667 pt 小屏与 iPhone 15 Pro Max（430×932 pt）大屏。
- 最低部署版本 iOS 18。当前未安装 iOS 18 模拟器；未声称最低版本运行验收通过。
- XCUITest 使用真实 SwiftUI、SwiftData 和本地文件分享；`DEBUG --ui-testing` 将存储隔离到 App 的 `Documents/UITestStore`。
- 加速通过 `--time-scale` 压缩阶段持续时间，生产 Release 固定为 1。截图中的累计逻辑分钟与真实起止钟点因此不一一对应，不能用这些测试票面证明经过了真实 15 / 100 分钟。
- 控制时钟单元测试验证边界；UI 测试验证用户动作与最终状态，二者证据分别列出。

## 复现

Git 仓库保留源码、结果摘要、源文件摘要及 `artifacts/showcase` 精选截图和录像。下文引用的原始 `.xcresult`、构建日志和完整附件目录保留在本地，不纳入版本控制；新克隆可用以下命令重新生成验收结果。

```sh
xcrun simctl list devices available
./scripts/verify.sh <你的模拟器UUID> acceptance
```

结果名应使用尚不存在的新目录；若已有 `artifacts/acceptance.xcresult`，将命令最后的 `acceptance` 换成新名称。无需联网服务、测试账号或预置业务数据。每个 UI 用例清理专用测试数据库；保留数据的进程重启步骤在用例中移除 `--reset-store`。运行日志、截图与录像保留在 `.xcresult`。打开结果：

```sh
open artifacts/acceptance.xcresult
# 或提取附件到指定空目录
xcrun xcresulttool export attachments --path artifacts/acceptance.xcresult --output-path artifacts/attachments
```

如仅验证四段旅程，在 `xcodebuild test` 加：
`-only-testing:MetroFocusUITests/JourneyFlowTests/testCompleteFourSegmentStandardJourneyWithManualTransfersAndLongPressPunch`。

## 断言内容

| 范围 | 可观察结果 |
|---|---|
| 首次发车 / 出票 | 输入任务、选择班次、进入运行舱、完成后未打孔票可见 |
| 暂停 / 进程重启 / 中止 | 暂停时间不减少，重启后恢复，终止没有完整票根 |
| 休息及后台追赶 | 休息结束停在 awaitingDeparture，不跨越手动确认 |
| 四段标准班次 | 三次手动换乘，100 分钟、4 站、票面长按盖章，票夹恰好一张 |
| 后台完成与恢复 | 在后台越过本段截止，终止再启动后恢复同一张未打孔票 |
| 导出 | 系统分享面板含正确 PNG 文件名、图片预览及原生图片操作 |
| 本地保存失败 | 注入保存错误时不展示未保存票，重试后仅一张；这是受控故障，不是磁盘耗尽实测 |
| 自定义 / 设置 / 空状态 | 自定义三个范围控件；试听八秒自动停止且不发车；空票夹和路网不伪造进度 |
| 辅助功能文字尺寸 | 最大 Dynamic Type 下核心动作可滚动到达，暂停恢复与结束仍可操作 |

## 实测结果

- **完整回归：16 / 16 通过，0 失败**。7 项状态／持久化契约测试、9 项 XCUITest。结果：`artifacts/acceptance-final.xcresult`，机器可读摘要：`artifacts/acceptance-final-summary.json`；原始日志：`artifacts/acceptance-final.log`。设备为 iPhone 15 Pro Max / iOS 26.5，约 487 秒。
- **Debug 测试构建与 Release 模拟器构建通过**；Release 日志为 `artifacts/release-final.log`。
- **最终辅助字号卡片调整复验通过**：`artifacts/large-type-cards.xcresult`，375×667 pt，验证卡片选择、输入、发车、暂停、恢复和结束，截图 `artifacts/showcase/station-small-xxxl-services.png`；Release 构建已重验。
- **小屏 375×667 pt 最大字号交互复验通过**：`artifacts/accessibility-hitarea.xcresult`；常规字号与实时跳过候车此前在 `artifacts/small-verified.xcresult` 通过。
- 标准 402×874 pt、大屏 430×932 pt、小屏 375×667 pt 均检查实际渲染；大屏与小屏均验证最大 Dynamic Type。最终大屏截图保存在 `artifacts/acceptance-final-captures`，精选结果在 `artifacts/showcase`。
- **真实 PNG 导出通过像素检查**：背景卡 1350×1975，全不透明；透明票根 1200×1511，317,429 个全透明像素，纸张、边缘及打孔抽样符合预期。

早期失败记录保留用于核对修复依据；不作为最终通过证据。完整回归没有跳过或删除失败用例。

本目录开始时没有 Git 仓库，因此使用 `artifacts/source-sha256.txt` 保存逐文件 SHA-256，`artifacts/source-identity.txt` 保存该清单的总摘要。完整回归对应 `acceptance-final-source-identity.txt` / `acceptance-final-source-sha256.txt`；此后仅加宽辅助字号班次卡，并在最窄屏幕重新执行受影响用例。可运行 `python3 scripts/source_identity.py` 重建并比对。

修复证据：早期日志 `artifacts/acceptance.log` 暴露班次卡空白区域点击未切换的问题。补齐 `contentShape` 后，`artifacts/export-diagnostic.xcresult` 的中文真实发车→打孔→历史→PNG 分享用例通过，发车前后保留选中状态与无障碍树附件。早期中断的 xcresult 不作为通过证据。

## 尚需真机或专门环境验收

- iOS 18 系统运行、真实 VoiceOver 朗读顺序和手势（当前仅验证语义元素与按钮）。
- 系统“降低动态效果”的实际开关与过渡呈现：实现已读取该环境设置，当前缺少 Simulator 图形应用，未完成系统开关的手动检查。
- Core Haptics 触感质量、票根陀螺仪反光、声景听感及实际扬声器音量。
- 来电中断、蓝牙／有线耳机断开后的音频恢复；模拟器编译不证明这些场景。
- 锁屏 Live Activity / Dynamic Island 的实际展示、过期提示及权限被拒绝时的系统行为；扩展已集成但需要单独实机验收。
- 实际通知投递、专注模式静音与操作系统终止情况下的系统策略。
- 磁盘写入失败的 UI 视觉状态尚未实机注入；已有状态机失败重试契约测试。

这些限制不等同于已知业务失败，也不应从模拟器构建成功推导为已通过。

最大字号修复证据：`artifacts/accessibility-final.xcresult` 捕捉到暂停按钮中心点击后仍为 focusing。共享按钮样式明确内容命中区域后，同一用例 `artifacts/accessibility-hitarea.xcresult` 通过（暂停、恢复、确认结束）；截图见 `artifacts/showcase/focus-small-xxxl.png` 与 `paused-small-xxxl.png`；该次应用与测试可执行文件摘要保存在 `artifacts/accessibility-hitarea-binary-sha256.txt`。

大屏导出定位证据：`artifacts/final-captures` 保留失败时原生分享面板的 PNG 截图和无障碍树。LinkPresentation 初始将完整文件名放在 BottomCaption，随后切为标题与 PNG 元信息；测试现验证文件名语义、PNG 信息、缩略图与原生图片操作，不依赖该异步内部节点位置。普通打孔按钮以单击验证，票面长按由四段流程单独验证。

实际媒体：`artifacts/showcase/four-stage-journey.mp4` 是 `artifacts/verified.xcresult` 中四段用例的实际 XCTest 录屏剪段（116.85 秒，源代码身份见 `verified-source-identity.txt`）；截图来自对应 xcresult 附件，导出图来自 App 生成文件。`artifacts/png-inspection.txt` 保存像素与透明通道检查，`artifacts/video-inspection.json` 保存录像属性。
