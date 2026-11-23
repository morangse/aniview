# AniView Bangumi OAuth Worker

本项目用于已注册的 AniView Bangumi OAuth 应用。持有者先在 Bangumi 注册完整 HTTPS 回调 `/auth/callback`，然后给 Worker 注入环境值。

| 配置 | 作用 |
|---|---|
| `BANGUMI_APP_ID` | Bangumi 分配的应用 ID |
| `BANGUMI_REDIRECT_URI` | 与 Bangumi 登记完全一致的回调 |
| `BANGUMI_APP_SECRET` | Worker Secret |
| `TOKEN_KEY` | Worker Secret，32 字节随机密钥的 Base64URL 编码 |

保持这些配置与实验账号分离。Android 构建参数 `--dart-define=ANIVIEW_BANGUMI_OAUTH_URL=https://你的部署域名` 只包含服务地址。`/auth/start` 发起配对，浏览器完成授权，客户端以本地证明向 `/auth/claim` 领取一次性结果。刷新使用加密封装的凭据。手机和服务端均不记录凭据。

可用 `node --test test/crypto.test.mjs` 验证加密与证明校验。Worker 逻辑可用 `node --check src/worker.mjs` 检查语法。在生产部署之前，使用测试环境和注册应用验证回调、过期与重复领取。

[Bangumi 应用注册](https://bgm.tv/dev/app) · [Cloudflare Worker Secrets](https://developers.cloudflare.com/workers/configuration/secrets/) · [Durable Objects](https://developers.cloudflare.com/durable-objects/)
