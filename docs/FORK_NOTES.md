# 分支说明

本仓库 fork 自 [JustLookAtNow/pt_mate](https://github.com/JustLookAtNow/pt_mate)，清理工作位于 `dev` 分支。

## 清理范围

- 移除关于页和文档中的 Telegram 群入口、作者展示及 Star History。
- 移除启动和关于页的自动更新检查、更新弹窗、应用内 APK 安装及第三方下载镜像。
- 移除设备 ID 生成和设备信息上报；新备份不再导出或恢复历史设备 ID。
- 移除仅用于更新与设备统计的 Go 后台、随仓库提交的后台二进制及原作者的服务器部署配置。
- 移除发布流程中的 Telegram 通知和更新服务器回调。
- 源码、文档、问题反馈和 Releases 入口指向本 fork；侧载源只描述本 fork 自己的发布包。

当前 fork 尚未发布安装包，因此侧载源的 `apps` 和 `news` 为空。后续发布 IPA 后可通过 `altsource/update_source.py` 生成源文件。

## 保留内容

PT 站点适配、种子浏览和搜索、下载器管理、本地下载、Cookie Cloud、WebDAV 和备份恢复保持原有功能。站点 API 文档中的用户资料、站点公告和赞助字段属于站点数据，不是客户端推广入口。

保留 Git 历史与 fork 来源、`LICENSE`、第三方许可证和现有版权声明。技术应用标识 `com.github.justlookatnow.ptmate` 及相关测试包名保留，用于安装、安全存储和历史配置兼容；它们不会连接原作者服务器。

如要重命名应用标识，应作为单独的迁移处理，同步所有平台与测试并说明旧安装数据如何恢复。

## 验证

```bash
flutter pub get
flutter analyze
flutter test
```

在关于页确认版本、文档、源码及 Releases 入口；启动或进入关于页不会触发更新请求或统计上报。

2026-10-06 本轮验证：

- `flutter analyze`：无问题。
- `flutter test`：456 项通过；5 项因缺少私有 HTML 夹具或 `JPOPSUKI_COOKIE` 按原配置跳过。
- 旧备份设备 ID 忽略与 Cookie Cloud/WebDAV 回归：24 项通过。
- `android/gradlew :app:testDebugUnitTest`：原生编译成功，40 项测试通过。
- GitHub 工作流 YAML、侧载 JSON、Python 脚本及 Android Manifest 语法检查通过。
