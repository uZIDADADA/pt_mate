# 分支说明与 Android 安装

本仓库 fork 自 [JustLookAtNow/pt_mate](https://github.com/JustLookAtNow/pt_mate)，维护分支为 `dev`。Git 历史、许可证与必要版权声明保留。

## 首次迁移

1. 如需保留原版配置，先在原应用导出本地备份。
2. 从[本仓库 Releases](https://github.com/uZIDADADA/pt_mate/releases) 安装版本化 `dev-*` 发布中的 `pt-mate-dev.apk`（ARM64）。应用名称为 **PT Mate Dev**，独立包名为 `com.github.uzidadada.ptmate`，可以与原版并存。
3. 在新应用的“备份与恢复”手动导入旧备份，核对站点、下载器和凭据后再卸载原版。旧版备份可能是明文，导入成功后删除。

原应用的数据不会因安装独立版自动转移。后续更新使用固定包名和固定签名直接覆盖本 fork；更新流程只写缓存目录中的 APK，不导入备份、不清空配置、不重置安全存储。不要通过卸载再安装来升级，卸载会删除应用数据。

## 更新与发布

- 每次推送 `dev`，`.github/workflows/dev-android.yml` 自动分析、测试、签名打包并发布 APK、`update.json` 和 SHA-256 校验文件。只允许 `uZIDADADA/pt_mate` 的 `dev` 分支发布。
- 每个构建有独立的 `dev-<versionCode>` 发布；`dev-latest` 提供更新清单。版本号递增，旧构建重跑不会让更新通道倒退。
- Android 发布版启动时检查更新，成功检查间隔至少 6 小时；关于页支持手动检查。检查是访问 GitHub 的公开 GET 请求，不发送设备 ID、Cookie、API Key、账户或站点配置。GitHub 作为网络服务仍可看到请求 IP。
- 下载只允许本仓库 Releases 和 GitHub 官方资源域名，限制大小并核验 SHA-256。安装前再次验证哈希、应用包名、递增版本号和与当前安装一致的签名。安装需由用户在 Android 系统界面确认；首次可能需要允许“安装未知应用”。
- 签名密钥由仓库 Secrets `PT_MATE_KEYSTORE_BASE64`、`PT_MATE_KEYSTORE_PASSWORD`、`PT_MATE_KEY_ALIAS` 提供，不在源码中。必须备份并持续使用同一密钥，丢失后无法继续覆盖升级。

## 安全修复

- 删除原作者统计上报、设备 UUID、更新服务、第三方 APK 镜像、后台服务器和群推广入口。
- 删除无认证的局域网调试 HTTP 服务。
- Cookie、站点 API Key、下载器及 WebDAV 凭据限制在配置地址的同源范围（协议、主机和端口均一致）；禁止携带凭据自动跨地址重定向，图片不再按根域猜测 Cookie 范围。
- 内嵌详情 WebView 限制站点同源页面和资源，使用 host-only Cookie，禁用第三方 Cookie 与混合内容。依赖外部脚本或图片的页面可能显示不完整。
- 下载种子时隔离下载器 API 的认证头，避免把下载器账号凭据发送给 PT 站点。
- 删除“接受任意自签名证书”选项及 TLS 校验绕过。敏感连接必须 HTTPS；仅本机或私有 IPv4 地址允许 HTTP。自签名服务需配置受信任证书。
- Cookie Cloud 仅请求密文并在本机解密，密码不再发送到服务器；只返回明文的旧服务会被拒绝。
- 新备份使用 AES-256-GCM、随机盐与 nonce，以及 PBKDF2-HMAC-SHA256（600000 次）派生密钥；必须输入至少 12 字符的备份密码。密码不保存、不上传，遗失后无法解密。旧明文备份可手动导入。
- 关闭启动时自动恢复 WebDAV 备份，避免旧云端备份覆盖新配置；导入恢复须由用户主动发起。Cookie Cloud 的主动/已启用定时同步仍按用户配置执行。

## 验证与边界

使用 `flutter analyze`、`flutter test`、Android 原生单元测试与签名 APK 构建验证。新增回归覆盖跨站 Cookie、WebDAV 内部重定向、下载器认证头隔离、Cookie Cloud 密码不外发、备份加密/篡改/取消及更新来源限制。

这些修复处理了源码审计中确认的风险；没有证据足以将所有风险称为故意后门，也不能凭静态审计保证不存在任何漏洞。真实手机首次迁移及覆盖升级仍需安装后核对。用户配置的 PT 站点、下载器、Cookie Cloud 和 WebDAV 是正常功能所需的网络连接。
