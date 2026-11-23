# AniView 架构

## 模块

| 目录 | 责任 |
|---|---|
| `lib/app` | Riverpod 依赖、go_router 和四个导航分支 |
| `lib/core/theme` 与 `lib/core/widgets` | Midnight Mist Token、软按钮、悬浮导航、背景与封面缓存 |
| `lib/features` | 首页、发现、详情、追番、历史、播放器和管理界面 |
| `lib/data/bangumi` | 公开 v0 目录、缓存及手动账号同步 |
| `lib/media/sources` | 适配器、注册表、匹配、探测、排序、播放准备及短期媒体转发 |
| `lib/media/overlays` | 外挂字幕、弹幕解析及每集设置 |
| `lib/media/downloads` | 可恢复任务、文件校验和离线资源 |
| `lib/core/database` | Drift 数据库、凭据仓库 |
| `oauth_worker` | 可独立部署的 Bangumi 授权桥接 |

## 查询和播放

`AnimeSubject` 是 Bangumi 条目，`Episode` 带独立的章节 ID 与类型。资源适配器返回 `SourceOffer`，这个对象表示候选和来源元数据。用户选择后，`MediaResolver` 持久化一个供历史和播放器引用的 `MediaCandidate`。媒体服务器 token 和新建直链的完整地址在 Android Keystore 支撑的安全存储内，Drift 链接保存资源 ID。

`MediaSourceRegistry` 筛选已启用来源。`MediaFetcher` 并行查询，逐源捕获超时、权限与服务错误。`EpisodeMatcher` 先校验显式 ID、季度、集数和正片分类。只有稳定绑定或同一剧集的用户确认才有自动播放资格。标题解析保留确定和不确定的证据，支持中文名、原文及官方别名。确认记录以条目、剧集和资源的组合保存。

`MediaSelector` 结合可用性、用户优先级、上次成功来源和实际解码统计排序。媒体时长与编解码验证由 `PlaybackController` 处理。`PlaybackSession` 一次最多尝试四个不同资源，记录失败原因，切换时尝试复用当前时间。同一集的外挂字幕和弹幕独立于具体媒体链接。

首页和番剧详情的首次播放使用编号最小的正片剧集建立查询。点选单集时沿用该集，明确标注的剧场版主入口按条目查询。Jellyfin 和 Emby 若提供 Bangumi 单集 ID，会将其纳入匹配依据。可自动选择的候选直接进入播放器，无候选或匹配待确认时显示片源面板。查找期间返回会取消页面跳转。

「内置订阅」独立于播放注册表。应用附带两份 CreamyCake 目录的名称与类型快照，用户可从固定 HTTPS 地址刷新当前清单。刷新仅提取新版清单的名称和类型。目录查看不涉及 SQLite 迁移。

AniView v1 授权订阅预览后以事务插入已确认的来源。JSON、RSS 和 Web 目录复用 `MediaSourceAdapter`、匹配及排序。资源标识由来源地址与稳定剧集标记生成，播放时重新解析最新地址。新来源类型沿用 v2 配置表。授权请求头存入现有安全存储，媒体请求经回环中继。[目录契约](AUTHORIZED_SOURCES.md)

Animeko v2 的兼容规则以规范化文本写入同一张 v2 配置表。网页和 API 适配器产生常规 `SourceOffer`，以他们各自的站点条目、剧集或页面标识恢复播放。解析后的媒体地址不持久化。

Android 通过 Storage Access Framework 读取本地媒体的持久化 `content://` URI。需要请求头或带签名查询串的媒体使用短期回环 HTTP 转发，访问范围固定为用户配置的原始站点。媒体服务器直接播放原始文件，授权头只交给指定服务器。受保护 HLS 只处理同源、未加密清单。

## 本地数据与迁移

SQLite 位于 Android 应用私有 `files/aniview.sqlite`。v1 的表、列、索引、主键和 URI 原样保留。v2 在迁移事务中增加以下表。

| 表 | 内容 |
|---|---|
| `configured_sources`、`media_links` | 启用状态、连接类型、排序优先级、授权下载标记和资源关联 |
| `resource_matches`、`source_health_rows` | 匹配依据、置信度、用户确认及可用性统计 |
| `episode_attachments` | 本地字幕与弹幕的文件内容和绑定 |
| `download_tasks` | 下载状态、字节数、HTTP 版本标记、SHA-256 |
| `sync_snapshots` | 本地取消收藏标记、同步结果、已推送章节的记录 |

`preferences` 保留原有自动播放设置，并记录字幕、弹幕和选源偏好。播放进度每 4 秒检查一次，暂停、完成、退出时也会保存。SQLite 按更新时间保护已提交的较新记录。

下载使用应用私有 `downloads-v1` 目录。通过 `Range` 与强 ETag 或 Last-Modified 续传，服务器完整返回新版本时从头写入。重启后将中断任务标为暂停。只有已检查容器和 SHA-256 的文件可离线打开。

## 账号、冲突与授权

公开目录直接访问 Bangumi v0，使用带版本的 User-Agent、分页、缓存和有上限的重试。主动绑定后，账号请求用 Bearer 头，令牌进入安全存储。用户可导入远端收藏，并分别批准上传本地新增收藏与已完成剧集。写入收藏时保留远端现有状态，新条目默认私密。标记已看使用官方章节状态。秒数始终保存在本机。远端丢弃和本地取消收藏的冲突按原记录保留，同步报告给出数量。

浏览器 OAuth 采用授权码和一次性配对。Workers 保管客户端密钥和短期加密结果，应用持有配对证明并领取令牌。发布构建需要单独注册应用、配置回调和部署 Worker。个人访问令牌可经 `/v0/me` 验证后绑定。

## 官方依据

- Media Framework 提供来源、候选、选择、解析的概念参考。[Animeko Media Framework](https://github.com/open-ani/animeko/blob/main/docs/contributing/code/media-framework.md)
- Bangumi 的公开端点、OAuth 和 User-Agent。[OpenAPI v0](https://github.com/bangumi/api/blob/master/open-api/v0.yaml) · [OAuth 指南](https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md) · [User-Agent 指南](https://github.com/bangumi/api/blob/master/docs-raw/user%20agent.md)
- 自托管媒体鉴权与播放信息。[Jellyfin SDK](https://github.com/jellyfin/jellyfin-sdk-typescript) · [Emby REST API](https://dev.emby.media/doc/restapi/index.html) · [Emby PlaybackInfo](https://dev.emby.media/reference/RestAPI/MediaInfoService/getItemsByIdPlaybackinfo.html)
- 弹弹play 开放服务需完成开发者入驻、应用审核，并遵守分配额度。当前运行本地弹幕。[开发者中心](https://dev.dandanplay.com/)
- OAuth 配对采用每个会话一个 SQLite Durable Object，并由告警清理超时状态。[Cloudflare Durable Object 存储](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/)
