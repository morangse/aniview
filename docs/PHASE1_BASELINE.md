# 第一阶段基线

AniView 工程位于 Dust2 工作区下的独立目录。第 1 版 SQLite 数据库包含收藏、片源、观看记录、设置和 Bangumi 缓存。升级时使用原 Android 包名 `app.aniview.android` 和原数据库路径 `aniview.sqlite`。

- **通过** Flutter 3.47.0 的静态分析与 26 项测试。证据在 [分析日志](evidence/flutter-analyze.txt) 和 [测试日志](evidence/flutter-test.txt)。
- **通过** x86_64 Debug APK 在 MuMu Android 12 模拟器安装并启动。已查看真实 Bangumi 首页与封面加载。[Android 截图](evidence/home-390-settled.png)
- **通过** 360、390、430dp 的 Widget 布局、模拟安全区域、导航和返回分发测试。
- **进入第二阶段时待补测** Android 文件选择与解码续播闭环、ARM64 APK、实体手机系统手势和 60fps 实测。交付目录尚无第一阶段 APK，README 当时仍为 Flutter 模板。

第二阶段验证前补跑了 v1 Android 文件选择和解码，随后在同一安装上覆盖升级到 v2。[v1 文件选择](evidence/phase1-saf-picker.png) · [v1 实际视频](evidence/phase1-local-playback.png) · [第二阶段验收](TESTING.md)

首页根据用户提供的 Android 视觉稿制作。Hero 中的番剧资料和封面经 Bangumi API 加载。本地播放空态使用项目生成的原创湖畔插画。播放器采用 media_kit 1.2.6、media_kit_video 2.0.1 和 Android libmpv 适配。
