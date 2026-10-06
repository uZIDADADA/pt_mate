# 当前支持的网站

以下清单基于 `assets/sites/*.json`（共 43 个）。

## M-Team（1）
- M-Team

## Gazelle（1）
- DIC Music

## NexusPHP（13）
- 藏宝阁
- 天枢
- 自由农场
- 好学
- 垃圾堆
- 幸运
- momentpt
- PTFans
- PT GTK
- PTSKit
- PTZone
- 肉丝
- 织梦

## NexusPHPWeb（23）
- AFUN
- 末日
- Audiences
- 比特校园
- 财神
- FRDS
- HDDolby
- HDFans
- 麒麟
- HHanClub
- 老师
- 皇后
- OurBits
- ptt
- 青蛙
- SSD
- TTG
- U2Share
- UBits
- 星陨阁
- 杏坛
- 猪猪
- 海棠PT

## RousiPro（1）
- 肉丝Pro(beta)

## Web（3）
- JPopSuki
- HappyFappy (HF)
- Empornium (EMP)

## Unit3D（1）
- MonikaDesign

## HappyFappy / Empornium 使用说明

在「添加站点」中选择对应预设，通过网页登录获取 Cookie，或使用 Cookie Cloud 导入。HappyFappy 的默认地址是 `https://www.happyfappy.net/`，Empornium 的默认地址是 `https://www.empornium.sx/`；EMP 使用带 `www` 的地址以避免重定向。配置中的历史域名用于匹配已有配置与 Cookie Cloud，不保证仍可访问。

两个预设均使用 `Web` 类型，支持用户资料、浏览、标题搜索、分类搜索、分页、免费标记、封面、网页详情和下载。下载使用列表中站点生成的完整链接，保留 `authkey` 与 `torrent_pass`，详情组 ID 与下载种子 ID 分别提取。当前不开放收藏、下载历史、评论详情或 Gazelle FL Token 操作。

封面依赖站点的悬浮预览：若账户设置禁用了预览或未提供图片，列表不显示封面。上传时间支持「相对时间」和「绝对时间」两种显示形式；目前按 UTC 解析，请将站点账户时区设为 UTC 以保证时间准确。

适配规则核对自 [Luminance 源码](https://github.com/Empornium/Luminance)及 Jackett 的 [HappyFappy](https://github.com/Jackett/Jackett/blob/master/src/Jackett.Common/Definitions/happyfappy.yml)、[Empornium](https://github.com/Jackett/Jackett/blob/master/src/Jackett.Common/Definitions/empornium.yml) 定义。离线测试使用不含真实账户数据的模拟页面；尚未通过登录态进行实站验证。
