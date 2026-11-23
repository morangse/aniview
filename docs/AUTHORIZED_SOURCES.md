# 片源与订阅

在「我的 → 片源管理」可以单独添加 JSON、RSS 或 Web 视频目录，也可以用「导入订阅」预览并启用片源。自定义目录支持 HTTPS 和现有局域网 HTTP 地址，手动配置的请求头存入安全存储。

## 订阅清单

订阅指向目录，各目录再提供具体剧集的媒体。以下清单最多可以列 24 个片源。每项的 `id` 在同一清单内唯一，重新导入会跳过已有来源。在片源管理中可修改、禁用和移除已导入的来源。

```json
{
  "schemaVersion": 1,
  "sources": [
    {
      "id": "my-videos",
      "name": "家庭视频库",
      "format": "json",
      "endpoint": "https://media.example.org/catalog.json"
    }
  ]
}
```

订阅格式可填 `json`、`rss` 或 `web`。订阅预览只请求清单本身，清单只接受上例中的字段。

## JSON 目录

```json
{
  "schemaVersion": 1,
  "resources": [
    {
      "id": "ep1-720p",
      "title": "正片第 1 集",
      "bangumiSubjectId": 12345,
      "bangumiEpisodeId": 67890,
      "url": "/videos/ep1/master.m3u8",
      "width": 1280
    }
  ]
}
```

`id` 是稳定资源标识，长度 1 至 96 个 ASCII 字符，使用字母、数字、点、下划线或连字符。单集 ID 必须与条目 ID 一起提供。可选字段 `seriesTitle`、`episodeNumber`、`season`、`episodeKind`（`regular`、`special` 或 `extra`）用于核对剧集。媒体地址可相对目录地址。同源无扩展名地址可用 `mimeType` 声明 `video/mp4` 或 `application/vnd.apple.mpegurl`。

## RSS 2.0 视频目录

```xml
<rss version="2.0" xmlns:av="urn:aniview:catalog:v1">
  <channel>
    <title>家庭视频库</title>
    <item>
      <guid isPermaLink="false">ep1-720p</guid>
      <title>正片第 1 集</title>
      <av:subjectId>12345</av:subjectId>
      <av:episodeId>67890</av:episodeId>
      <enclosure url="/videos/ep1.mp4" type="video/mp4"/>
    </item>
  </channel>
</rss>
```

每项包含一个媒体 enclosure 和稳定 guid。可用 `av:seriesTitle` 提供原名或别名。BT 附件和磁力链接不会进入当前媒体候选。

## Web 视频目录

```html
<!doctype html>
<video data-aniview-id="ep1"
       data-title="正片第 1 集"
       data-bangumi-subject="12345"
       data-bangumi-episode="67890">
  <source data-aniview-id="ep1-720p"
          src="/videos/ep1.mp4" type="video/mp4">
</video>
```

网页由 Dart HTML 解析器读取明示标记的 `video` 及其直接 `source` 子元素。多条线路可各自指定稳定 ID。JavaScript、嵌入播放器和 Animeko 网页规则均在该协议之外。

## Animeko v2 订阅兼容

「导入订阅」接受 Animeko v2 的 JSON 订阅地址。输入 `sub.creamycake.org/v1/css1.json` 时应用自动补上 HTTPS。预览会显示成员数量、可导入项和具体的规则不兼容原因。可单独选择「稀饭动漫 Next」或批量选中可导入成员。

- JSON API 执行搜索、剧集和播放三个阶段，支持 GET、JSON POST、分组线路与基础 JSONPath，播放时按选定线路重新请求媒体地址。订阅中的公开 API 请求头只用于该 API。
- 网页规则支持基础搜索选择器、剧集列表及静态页面中的 MP4 / HLS。需要 WebView 执行脚本、嵌套播放器或额外页面交互的资源当前可能无法解析。
- RSS 支持同源 MP4 或未加密 HLS 附件。磁力和种子需要 Android 原生 BT 后端，仍待适配。

## 匹配与播放

- 将示例 ID 替换为实际 Bangumi 条目 ID 和单集 ID。首页和详情的「立即播放」通过现有匹配器筛选剧集并排序。API 返回的中日文标题、年份、总集数、集数与剧集类型一致时也可自动选源。证据不足时需要手动确认。
- 三种目录只解析同源 MP4 或明文 HLS。目录与播放中继限制重定向，HLS 分片沿用同一来源。播放时根据稳定标识重新解析媒体地址，带签名的地址不写入数据库。
- 已导入的 RSS 成员可以在片源管理里启用、停用、测试连接或删除。
- Android APK 当前通过 HTTP 播放。自托管 BT 网关若为已获授权的资源输出标准 MP4 或 HLS，可将对应地址放入上述目录。原生磁力和种子播放仍待接入。已核验的 jlibtorrent Android AAR 要求 API 26，AniView 当前最低 API 24。原生方案还需验证缓冲、Seek、做种设置和会话回收。[jlibtorrent Android](https://github.com/frostwire/frostwire-jlibtorrent#android-one-aar-recommended-20152-and-later)
