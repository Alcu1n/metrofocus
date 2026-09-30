# MetroFocus · 专注列车

原生 iPhone 专注 App。以夜行地铁和实体硬卡票组织一次完整的专注：选线路与班次 → 候车 → 专注 → 换乘休息 → 手动继续 → 到站出票 → 打孔收藏。

支持 iOS 18+，简体中文与英文，固定深色外观，本地 SwiftData 存储。无账号、网络后端、订阅或第三方运行时依赖。

## 运行

1. 用 Xcode 打开 `MetroFocus.xcodeproj`，选择 `MetroFocus` scheme 和 iPhone 模拟器，运行。
2. 真机运行时，为主 App 和 `MetroFocusLiveActivity` 扩展选择同一个开发团队；如有标识冲突，同时修改主 App 和扩展的 Bundle ID 前缀。
3. 输入任务名称，选 15 / 25 / 50 分钟班次；“编排”可设置自定义区间及站点。

工程已生成，无需安装 Ruby gem 才能打开。仅重新生成工程时需要本机 `xcodeproj` Ruby gem：

```sh
python3 scripts/build_localizations.py
ruby scripts/generate_project.rb
```

## 已实现

- 四条任务线路；任务名称最多 24 字；预设班次及 5–120 分钟、1–8 段自定义旅程。
- 30 秒可跳过候车、暂停恢复、确认中止、切后台计时、进程重启恢复；休息结束等待明确发车。
- 持久化时间锚点，等待与休息不计入专注；已保存后才展示票根，按旅程 ID 幂等结算。
- 打孔和盖章、票夹及历史详情、透明 PNG / 背景卡片系统分享；完成后可选放松。
- 按真实专注时间成长的可拖动缩放路网，每小时 10 km / 一站；中止保留投入时间。
- 三种原创离线声景及八秒独立试听；报站、操作音、声景和触感独立控制。
- 本地通知、Live Activity / Dynamic Island、深链回到当前旅程；拒绝权限不阻断计时。
- Dynamic Type、语义化按钮、长按打孔的等价按钮、降低动态效果支持。

## 代码入口

- `MetroFocus/Domain`：状态机、时间计算、版本化 SwiftData 模型及保存失败重试。
- `MetroFocus/App`：生命周期、呈现及系统服务协调。
- `MetroFocus/Features`：车站、运行舱、票根、路网、设置。
- `MetroFocus/UI`：主题、线路色、组件与原创轨道图形。
- `MetroFocus/Services`：音频、触感、倾斜、通知、实时活动。
- `MetroFocusLiveActivity`：锁屏及灵动岛扩展。
- `MetroFocusTests` / `MetroFocusUITests`：时间边界、持久化契约及真实 UI 流程。

设计取舍见 [设计说明](docs/DESIGN.md)，测试结果、复现步骤与尚未实测的边界见 [验收记录](docs/VERIFICATION.md)。原创音频的生成方法及信号测量见 [音频说明](MetroFocus/Resources/Audio/README.md)。

## 实际体验记录

[完整四段旅程录像](artifacts/showcase/four-stage-journey.mp4) · [车站](artifacts/showcase/station-standard.png) · [运行舱](artifacts/showcase/focus-standard.png) · [车票](artifacts/showcase/ticket-standard.png) · [最大字号](artifacts/showcase/focus-small-xxxl.png)

录像为实际 UI 测试录制，阶段时长经过测试加速；票面的逻辑分钟不代表录像经过的真实时间。
