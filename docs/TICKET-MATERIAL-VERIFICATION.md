# 纸票凹印材质验收 · 2026-10-01

基于 `b3975f4`，按用户要求增加机械凹印字、凹刻虚线和纸张厚度。车站、票夹、详情共享 `TicketPaper` 与 `TicketPerforation`；完成票的任务、时间、分钟数及列表主要文字使用 `ticketImprint()`。未改计时、打孔、保存、导出流程及辅助功能标识。

- 印字：0.55 pt 上沿内暗部、0.65 pt 下缘纸色反光，保持深绿墨色。
- 撕线：暗槽与向下偏移 0.85 pt 的细亮边，沿用侧孔布局锚点。
- 厚度：1 / 2 pt 暖灰纸层、薄轮廓高光；孔位与纸面共享路径。固定低对比纤维纹理，不增加动画。

Xcode 27、iPhone 17 / iOS 26.5 模拟器：**2 / 2 UI 流程通过**，见 `artifacts/letterpress.xcresult` 和 [结果摘要](../artifacts/letterpress-summary.json)。包含完成旅程、打孔、透明 PNG 系统分享，以及中文车站输入校验、班次选择、编排、设置与空收藏检查。沿用既有 `STRING_CATALOG_GENERATE_SYMBOLS=NO` 绕过原有符号冲突；未修改项目配置。测试时钟与存储仍使用既有隔离、加速设置。未重跑全套或真机测试。

```sh
xcodebuild test -project MetroFocus.xcodeproj -scheme MetroFocus \
  -destination 'platform=iOS Simulator,id=DFA17101-5DB3-4FB2-B388-49E4B83DDA0C' \
  -derivedDataPath build/C-Design -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath artifacts/letterpress-replay.xcresult \
  -only-testing:MetroFocusUITests/JourneyFlowTests/testEnglishJourneyExportsTransparentTicket \
  -only-testing:MetroFocusUITests/VisualAcceptanceTests/testChineseStationRouteSettingsAndEmptyCollections \
  CODE_SIGNING_ALLOWED=NO STRING_CATALOG_GENERATE_SYMBOLS=NO
```

源码身份：[逐文件 SHA-256](../artifacts/letterpress-source-sha256.txt)、[清单摘要](../artifacts/letterpress-source-identity.txt)。

[原生车票](../artifacts/showcase/letterpress-ticket-native.png) · [原生车站](../artifacts/showcase/letterpress-station-native.png) · [真实透明 PNG](../artifacts/showcase/letterpress-ticket-export.png)。导出票号 `CBD60071` 与 UI 附件一致；1200×1455，302,152 个全透明像素、1,443,268 个全不透明像素。ImageIO 检查外角与孔中心 alpha=0、纸面 alpha=255，底部纸层在导出边距内完整保留。

实际导出图经独立视觉复核：压印光向、槽口、侧孔及底边一致，文字、条码和印章清晰，无明显双字或轮廓接缝。实际原生截图亦已检查；不以截图代替真机触感与陀螺仪体验验收。

补查车站底边：首屏处在可滚动内容的中段，底边位于视窗下方；向下滚动后，完整圆角、厚度与累计行正常显示，见 [完整纸边](../artifacts/showcase/letterpress-station-edge.png)。已有用例仅增加滚动截图，`letterpress-edge.xcresult` 1 / 1 再次通过；生产代码与首次材质验收一致，测试文件增量身份见 [补查身份](../artifacts/letterpress-edge-source-identity.txt)。未为压入首屏而缩小字号或挤压票面布局。

## 字体凹印补齐 · 2026-10-01

后续按用户要求，将票面编号、线路、日期、标签、说明、印章及票夹文字补齐凹印，并覆盖车站的输入文字和班次。主要文字下缘深度为 0.9 pt，小字为 0.45–0.6 pt，反白班次为 0.3 pt；保留各自墨色与字号，避免给整个纸面叠加文字阴影。

`letterpress-type.xcresult` 两项既有 UI 流程通过（英文出票、打孔、透明 PNG 分享；中文输入与班次、编排、设置和空收藏）。源码见 `artifacts/letterpress-type-source-sha256.txt`。导出票号 `8965F422`，1200×1455，透明／不透明像素数及外角、孔中心、纸面 alpha 均与前轮一致。原生截图与真实导出均已查看；独立导出图评审未见双字、过重描边或凹印方向错误。

[字体凹印原生截图](../artifacts/showcase/letterpress-type-native.png) · [完整导出票](../artifacts/showcase/letterpress-type-ticket.png)。复验沿用本文命令，将结果包名称改为 `letterpress-type-replay.xcresult`。构建绕过及真机边界与前文相同。

最终车站标签消除嵌套阴影后，`letterpress-type-station.xcresult` 同一中文流程再次通过（1 / 1）；差异文件 SHA-256 见 `artifacts/letterpress-type-station-source-identity.txt`。[最终中文票面](../artifacts/showcase/letterpress-type-station.png) 可核对输入字、班次字和小字压印。
