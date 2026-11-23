# 第二阶段验收

## 已验证

| 项目 | 结果 |
|---|---|
| Flutter 静态分析与单元测试 | 0.2.2 通过。49 项 Flutter 测试，包含详情自动进入播放器、查询中返回、被阻断的片源不会自动选择、订阅清单和上一版功能回归。 |
| 360、390、430dp | Widget 尺寸、安全区与路由回归通过。 |
| Android Debug APK | 0.2.2 构建和签名校验通过，在 MuMu 覆盖安装并启动。包名 `app.aniview.android`，包含 ARM64 与 x86_64。 |
| Android v1 → v2 覆盖升级 | 通过。MuMu Android 12 模拟器上原有 1 条收藏和媒体完成记录的 34.021 秒位置均保留。 |
| 本地视频 | Android 文件选择、H.264/AAC 解码、MP4 内封字幕以及从升级前的历史重新打开已验证。 |
| 首集自动播放、HLS 切源与续播 | 0.2.2 MuMu 测试从首页点击「立即播放」，乱序列表中定位正片首集并排除优先级更高的错集直链。首源 HTTP 404，自动切换后实播 VOD HLS。保存并恢复 23.588 秒。 |
| 错季、错集、重名、特别篇 | 单元测试通过。缺失标识的同名候选需要确认，确认只对应当前剧集。 |
| 多源超时、全失败与手动修正 | 单元测试通过。查询有可读诊断，手动确认在再次查询后保留。 |
| 字幕偏移、编码与弹幕开关 | 单元测试通过。验证 SRT / WebVTT、UTF-8 / BOM UTF-16、位置偏移、弹幕模式、屏蔽词与上限。 |
| 下载中断、弱网、重启、磁盘不足、损坏 | Android 实测连接中断后保留 65,536 字节，限速 Range 续传至 2,321,044 字节，离线文件校验通过。Flutter 测试覆盖重启恢复、磁盘不足和损坏拒绝。 |
| Bangumi 同步失败和冲突 | 针对 v0 合约的模拟请求通过。429 保留本地数据，已看映射只写官方状态，保留远端丢弃及本地取消收藏。 |
| 授权桥加密 | 两项 Node 测试通过。验证证明摘要、会话与刷新密文用途隔离，服务脚本语法检查通过。 |

详见 [Flutter 分析](evidence/phase2-flutter-analyze.txt)、[Flutter 测试](evidence/phase2-flutter-test.txt)、[Android 构建](evidence/phase2-android-build.txt)、[Android 播放及下载](evidence/phase2-android-network.txt)。[实际首页](evidence/phase2-android-home-upgrade.png) · [实际播放器](evidence/phase2-player-local.png)

0.2.2 证据 [Flutter 分析](evidence/0.2.2-flutter-analyze.txt) · [Flutter 测试](evidence/0.2.2-flutter-test.txt) · [Android 构建](evidence/0.2.2-android-build.txt) · [Android 首集播放与下载](evidence/0.2.2-android-playback.txt)

## 0.2.3 授权订阅验收

| 项目 | 结果 |
|---|---|
| Flutter 分析与测试 | 通过，63 项。覆盖逐项授权导入、重复导入、JSON/RSS/Web 解析、同源 URL 校验、错集过滤和签名地址轮换。 |
| Android 联调 | MuMu 从本机 HTTP 服务导入并解析 JSON、RSS、Web 三种目录。首页自动定位正片首集，直链返回 404 后切换到 JSON 目录提供的 HLS 实播。保存和恢复位置均为 22.721 秒。 |
| Android Debug APK | 标准入口构建、签名校验、覆盖安装和冷启动通过。版本 0.2.3+5，包含 ARM64 与 x86_64，最低 API 24。 |
| 来源范围 | 实测使用自制视频和目录。CreamyCake 仍为只读目录。原生磁力与种子、第三方视频服务及自托管 BT 网关没有实际播放测试。 |

0.2.3 证据 [Flutter 分析](evidence/0.2.3-flutter-analyze.txt) · [Flutter 测试](evidence/0.2.3-flutter-test.txt) · [Android 构建](evidence/0.2.3-android-build.txt) · [Android 集成](evidence/0.2.3-android-playback.txt) · [测试服务请求](evidence/0.2.3-test-media-requests.txt)

## 0.2.4 订阅预览

Flutter 静态分析通过，68 项测试通过。回归覆盖省略协议的输入、地址归一化后的稳定标识、订阅地址的错误文案，以及导入前的确认。

在 MuMu 上原样输入 `sub.creamycake.org/v1/css1.json` 后点击「预览订阅」，实际 HTTPS 响应显示 21 个来源。当前发布的这些成员显示网页取源或 JSON API 规则待接入。[Android 实测](evidence/0.2.4-android-preview.txt) · [Flutter 测试](evidence/0.2.4-flutter-test.txt)

0.2.4+6 的标准入口 APK 已构建、校验签名并在 MuMu 覆盖安装，包含 ARM64 和 x86_64。[构建日志](evidence/0.2.4-android-build.txt)

## 0.2.5 社区订阅播放

Flutter 静态分析通过，71 项测试通过。模拟 HTTP 测试覆盖从 Animeko v2 订阅导入网页与 JSON API 规则、排除错集、匹配中日文标题和发行信息、解析播放地址及隔离 API 请求头。

Android MuMu 实测从线上 `css1.json` 导入「稀饭动漫 Next」，查阅 Bangumi 条目并点击「立即播放」，自动进入播放器并解码《魔法少女小圆》第 1 集 1920×1080 视频。当天订阅有 21 项，20 项符合导入规则。此次只对该公开 API 线路执行实播；网页适配使用测试响应验证。[Flutter 测试](evidence/0.2.5-flutter-test.txt) · [Android 实测](evidence/0.2.5-android-public-playback.txt)

Android 原始日志中 `duration=1540266s` 的数值是进度滑块的毫秒值，约 25 分 40 秒。测试脚本的输出单位已修正。

0.2.5+7 标准入口 APK 已签名校验并在 MuMu 覆盖安装，包含 ARM64 和 x86_64。[APK 构建日志](evidence/0.2.5-android-build.txt)

## 仍需验证或接入

| 项目 | 状态与原因 |
|---|---|
| Jellyfin / Emby 实服 | 适配层已实现。当前环境缺少已授权的两种测试服务器及账号，未做实服回归。 |
| Bangumi 账号实服写入与浏览器授权 | 同步合约以替身测试。OAuth 需要注册应用、回调域名和部署授权桥，实际用户账户读写未测试。 |
| 弹弹play 在线弹幕 | 待服务申请与配额授权。当前提供本地导入。 |
| ASS/SSA、复杂多样式 WebVTT | 当前外挂渲染器仅覆盖 SRT / WebVTT 的基础文本与时间轴。 |
| 物理 Android 设备、系统边缘手势 | 模拟器与 Widget 测试覆盖导航分发，未测物理手机手势、正式硬解和实际音频输出。 |
| 60fps 验收 | MuMu Android 12 模拟器（640dp）Profile 滚动采样 186 帧，raster p50 66.502ms、p90 67.156ms，total span p90 69.442ms。186/186 帧的 raster 超过 16.67ms，模拟器未达 60fps 预算。实体 Android 性能未测试。[原始测量](evidence/phase2-home-profile.txt) |

## 复现步骤

```powershell
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64,android-x64
adb install -r dist/AniView-0.2.5-android-debug.apk
node --test oauth_worker/test/crypto.test.mjs
```

生成并服务自有测试媒体。以下命令在 AniView 根目录执行，第二条保持运行。

```powershell
./tool/generate-test-media.ps1 -Ffmpeg ffmpeg
python tool/serve-test-media.py --port 8172
adb reverse tcp:8172 tcp:8172
flutter drive --debug --driver=test_driver/integration_test.dart --target=integration_test/android_playback_test.dart --dart-define=ANIVIEW_QA_SERVER=http://127.0.0.1:8172
```

公开订阅实播验收需要能够访问订阅、Bangumi 和提供播放的接口。

```powershell
flutter drive --debug --driver=test_driver/integration_test.dart --target=integration_test/animeko_public_playback_test.dart --dart-define=ANIVIEW_PUBLIC_SOURCE_QA=true
```

基准性能脚本采用 Flutter Profile 模式和 `FrameTiming`，包含真实目录加载、预热和固定次数滚动。保留 build、raster、total span 的分位与 16.67ms 超预算计数。设备端关闭调试浮层和截图轮询后采样。

```powershell
flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/home_performance_test.dart
```
