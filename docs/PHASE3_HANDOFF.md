# 第三阶段交接

Android 代码入口是 `lib/main.dart`。保留 `app.aniview.android` 的包名和 v2 SQLite schema。源码冻结点、APK、可执行检查及未验证项目见 [验收](TESTING.md)。

## 当前边界

- Jellyfin、Emby 支持自托管服务器登录、检索和直接播放。转码、跨站 CDN 重定向与 DRM 超出当前能力。
- 「片源管理」可导入 CreamyCake 中兼容的 Animeko v2 JSON API、网页与 RSS 规则。网页目前读取静态资源，嵌套网页播放器和 Android 原生 BT 仍需单独适配。
- AniView v1 授权订阅可预览并导入 JSON、RSS 和静态 Web 媒体目录，通过同源直达 MP4 或明文 HLS。数据沿用 SQLite v2。Android 原生磁力和种子仍需独立引擎与实测。[目录契约](AUTHORIZED_SOURCES.md)
- 季度或标题缺少确定依据时需要人工确认。Bind 条目 ID 与剧集 ID 时请使用实际 Bangumi ID。媒体服务器的版本兼容性需要独立实测。
- 外挂字幕支持 SRT、WebVTT，UTF-8 和带 BOM 的 UTF-16。ASS/SSA 完整样式、复杂 WebVTT 布局和其他编码待处理。弹幕在线接入待弹弹play授权。
- 下载支持用户确认可离线保存的普通 MP4。暂使用应用私有目录，任务在应用重启后可手动恢复，未接入 Android 后台下载服务。
- 浏览器授权服务待配置部署及正式应用授权。远端写入由用户逐次确认选项；无需账号即可使用本地追番。
- 画中画、自动播放下一集、音轨偏好、亮度手势、横屏与控件锁定尚未验收。

## 接续顺序

1. 在 ARM64 Android 手机回归硬解、音频、系统手势、屏幕旋转、字幕和帧时。验证 MediaKit 原生库与 16KB 页设备兼容性。
2. 用经过许可的 Jellyfin 和 Emby 服务器验收反向代理前缀、局域网掉线、账号权限、跳转与直放版本差异。获取和配置 Bangumi OAuth 与弹弹play授权后验证真实互操作。
3. 将 Android 专属文件访问与全屏接口抽象成平台适配器，再做 iPad 的尺寸与交互验证。最后排 Windows 音视频后端、输入和安装；Android TV 无计划。

后续数据库升级继续追加非破坏性迁移。增加任何远端来源前先明确授权、协议、登录、离线保存和限额条件。
