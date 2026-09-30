# C「随身通行证」原生迁移验收

2026-09-30 至 2026-10-01。用户选择 C 并确认车站、票夹的第二页迁移后，将纸票视觉应用到原生车站、票夹、车票详情与相关按钮。三案原型及选型记录保留在 [设计竞赛](prototypes/station-tournament-v1/README.md)。

## 实现及验证边界

- 车站：四线路、浅纸表单、三班次同时呈现、撕线摘要、尚未发车印章、固定出发按钮。空任务显示错误并聚焦，合法输入清除错误。最大辅助字号时线路两列、班次纵向，完整时长摘要进入可滚动票面。
- 票夹：真实票据数与分钟合计、日期分组、任务、线路、抵达时间、班次代码及验票状态；空状态可返回车站。没有将原型三张样例写入存储。
- 详情：统一纸色、墨色、撕线和按钮；保留打孔、长按、历史、里程碑和导出。大字日期不会被分隔线压缩成逐字竖排；阴影作用于整体纸票，避免正文出现阴影。
- 路网、运行舱、旅程引擎、持久化及感官服务没有本轮业务改动。项目原有四个其他已修改文件的 SHA-256 保持一致；主字符串表的原有 192 项完整保留，只新增 15 项。

环境：Xcode 27 / iOS 26.5 Simulator；iPhone 17（402×874 pt）及 QA Small（375×667 pt），英文最大 Dynamic Type `UICTContentSizeCategoryAccessibilityXXXL`。测试经真实 SwiftUI 和 SwiftData 运行，使用独立 `Documents/UITestStore`；旅程时间按 DEBUG 参数加速，不能作为真实经过 15 / 100 分钟的证据。无网络或测试账号需求。

源码基线 `d2ffc96`；最终源码逐文件身份：[c-native-source-sha256.txt](../artifacts/c-native-source-sha256.txt)，清单 SHA-256：[c-native-source-identity.txt](../artifacts/c-native-source-identity.txt)。原始结果和日志留在本地，摘要及精选截图纳入可交付证据。

## 构建前置问题

**2026-10-01 已修复：** 两个大写标牌键改为 `journey.arrivedLabel` 和 `atlas.hereNowLabel`，调用与本地化生成脚本同步更新，原有中英文显示值保留。新建 DerivedData 后，默认 `STRING_CATALOG_GENERATE_SYMBOLS=YES` 的 Debug 模拟器 arm64 / x86_64 构建通过（`artifacts/symbol-fix-debug.log`）；无需下文旧验收采用的符号生成绕过。生成脚本在临时目录复验通过，未重写现有字符串表。以下段落保留当时的历史诊断。

当前项目已有 `STRING_CATALOG_GENERATE_SYMBOLS=YES`；原有 `ARRIVED` / `Arrived` 与 `HERE & NOW` / `Here & now` 会生成同名符号，默认构建因此失败。已从本轮开始前的字符串表确认这些冲突存在。本轮验证均以命令行 `STRING_CATALOG_GENERATE_SYMBOLS=NO` 临时绕过，不改用户项目配置和旧文案。新增相似文案使用 `wallet.footer`、`wallet.ticketCount` 独立 key，未增加此类冲突。

最新 Debug 测试构建及 Release 模拟器构建通过；Release 日志为 `artifacts/c-release-final.log`。这不代表默认构建冲突已被修复，也不代表签名或真机运行通过。

## 相关流程结果

| 结果包 | 检查内容 | 结果 |
| --- | --- | --- |
| `c-station-native.xcresult` | 中文首屏三班次可达、任务校验、编排、自定义范围、八秒试听、空路网及空票夹 | 1 / 1 通过 |
| `c-journey-native.xcresult` | 中文首次旅程→打孔→历史→背景 PNG 分享；四段100分钟、手动换乘、长按打孔且只一张票；英文透明 PNG 分享 | 3 / 3 通过 |
| `c-small-final.xcresult` | 375 pt 最大字号下选择班次、阅读15分钟总时长、返回输入框、键盘提交、发车、暂停恢复及结束；真实出票、打孔、票夹、历史详情 | 2 / 2 通过 |
| `c-small-reading-final.xcresult` | 更严格的票夹与详情任务可见范围断言、滚动后阅读截图；使用单次 accessibility snapshot 避免读取 LazyVGrid 已回收元素的多个快照 | 1 / 1 通过 |
| `c-export-diagnostic.xcresult` | 最新详情→单次菜单点击→背景 PNG 系统分享；保留菜单AX、按钮frame、图片预览与原生图片操作证据 | 1 / 1 通过 |

初次小屏检查中，固定方向滚动在返回任务输入时越过了目标。测试改为根据目标与可见视窗的位置做有界慢速滚动，并保留控件中心及可见高度断言；同一路径复验通过。未据此修改布局或弱化可用性断言。额外截图检查区分日期分组、票面内容与详情滚动位置，不把屏外内容当成截断。

最后一次标准详情复验 `c-ticket-final.xcresult` 曾在菜单中心点击后未响应，且未生成对应 PNG。保留该失败；加入点击前菜单 AX 和目标 frame 的附件后，同一单次点击流程在 `c-export-diagnostic.xcresult` 通过，未改生产导出实现或自动重试点击。现有证据尚不能解释这次偶发菜单不响应，不能声称已修复其根因。成功复验产生的 PNG 经 ImageIO 解码与不透明度检查，结果为 **1350×1918，全不透明**，见 `artifacts/c-native-png-inspection.txt`；原生分享画面见 [导出截图](../artifacts/showcase/c-export-native.png)。

## 复现命令

从仓库根目录执行，下例结果目录必须尚不存在。标准设备 ID 为 `DFA17101-5DB3-4FB2-B388-49E4B83DDA0C`；小屏为 `9B2B8A87-EC0B-439C-B7AF-79ED76E0EFDA`，其他机器应替换为其 iOS Simulator ID。

```sh
xcodebuild test -project MetroFocus.xcodeproj -scheme MetroFocus \
  -destination 'platform=iOS Simulator,id=DFA17101-5DB3-4FB2-B388-49E4B83DDA0C' \
  -derivedDataPath build/C-Design -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath artifacts/c-replay-standard.xcresult \
  -only-testing:MetroFocusUITests/VisualAcceptanceTests/testChineseStationRouteSettingsAndEmptyCollections \
  -only-testing:MetroFocusUITests/JourneyFlowTests/testChineseFirstJourneyTicketPunchHistoryAndCardExport \
  -only-testing:MetroFocusUITests/JourneyFlowTests/testCompleteFourSegmentStandardJourneyWithManualTransfersAndLongPressPunch \
  -only-testing:MetroFocusUITests/JourneyFlowTests/testEnglishJourneyExportsTransparentTicket \
  CODE_SIGNING_ALLOWED=NO STRING_CATALOG_GENERATE_SYMBOLS=NO

xcodebuild test -project MetroFocus.xcodeproj -scheme MetroFocus \
  -destination 'platform=iOS Simulator,id=9B2B8A87-EC0B-439C-B7AF-79ED76E0EFDA' \
  -derivedDataPath build/C-Design -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath artifacts/c-replay-small.xcresult \
  -only-testing:MetroFocusUITests/VisualAcceptanceTests/testLargestDynamicTypeEnglishControlsRemainUsable \
  -only-testing:MetroFocusUITests/VisualAcceptanceTests/testLargestDynamicTypeTicketWalletAndDetails \
  CODE_SIGNING_ALLOWED=NO STRING_CATALOG_GENERATE_SYMBOLS=NO

xcodebuild build -project MetroFocus.xcodeproj -scheme MetroFocus -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/C-Release \
  CODE_SIGNING_ALLOWED=NO STRING_CATALOG_GENERATE_SYMBOLS=NO
```

查看与提取证据：

```sh
open artifacts/c-small-final.xcresult
xcrun xcresulttool get test-results summary --path artifacts/c-small-final.xcresult --format json
xcrun xcresulttool export attachments --path artifacts/c-small-final.xcresult --output-path artifacts/c-replay-captures
```

## 原生画面与剩余边界

[车站](../artifacts/showcase/c-station-native.png) · [真实票夹](../artifacts/showcase/c-wallet-native.png) · [已验票详情](../artifacts/showcase/c-ticket-native.png) · [最大字号行程摘要](../artifacts/showcase/c-station-small-xxxl-summary.png) · [最大字号票夹](../artifacts/showcase/c-wallet-small-xxxl.png) · [最大字号详情](../artifacts/showcase/c-ticket-small-xxxl.png)。截图来自对应 XCUITest 附件；系统导航及底部 Tab 保持原生样式。标准车站、真实票夹已通过独立截图评审；最大字号日期、滚动后的任务阅读与清晰文字修复亦经独立复核。

本轮没有执行真机、iOS 18、真实 VoiceOver 会话、触感/陀螺仪、音频中断、Live Activity 或通知实机验收。没有运行全仓库测试；旅程业务源码未变，以受影响的用户流程及大字布局检查为本轮证据。此前的完整基线和真机缺口见 [既有验收记录](VERIFICATION.md)。
