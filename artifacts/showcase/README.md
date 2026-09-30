# 真实输出与截图

这里的 PNG 来自实际 SwiftUI 页面或 App 内真实导出；不是绘图模型生成的界面效果图。

`export-card.png`：带背景分享卡，1350×1975，无透明通道。
`export-ticket.png`：透明票根，1200×1511，带透明通道；边缘、侧孔和打孔均透明。

测试将计时压缩，以较短运行完成完整流程。票面的“专注分钟”是逻辑时间，起止钟点是实际墙钟时间。它们用于验证界面与流程，不能作为真实经过该时长的证据。截图与录像的环境、断言和复现步骤见 `../../docs/VERIFICATION.md`。

## 文件索引

- `station-standard.png` / `focus-standard.png` / `ticket-standard.png`：402×874 pt 标准屏核心界面。
- `station-large.png` / `focus-large.png` / `atlas-large.png`：430×932 pt 大屏实测。
- `station-small.png` / `focus-small.png`：375×667 pt 小屏；`focus-small-xxxl.png` / `paused-small-xxxl.png` 为最大辅助字号，最终加宽班次卡见 `station-small-xxxl-services.png`。
- `four-stage-journey.mp4`：真实四段流程录制，测试时间加速，包含三次手动继续与票面长按打孔。
- `export-card.png` / `export-ticket.png`：App 实际生成的文件，尺寸和透明通道见上文；来源见 `../png-export-provenance.json`。

完整测试原始附件与结果保存在各次 `.xcresult` 和附件目录中。完整回归以 `../acceptance-final.xcresult` 为准；最后的辅助字号卡片调整复验见 `../large-type-cards.xcresult`；早期失败结果保留用于核对修复依据。
