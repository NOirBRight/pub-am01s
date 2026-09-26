# Panel 视觉：Meter Bank + Inbox，LED Level Bar，自带 UI Scale，跟 Omarchy 主题

原型比过三种排法（竖条 | 通知列表、横条网格 + 单条通知、图标栏 + 常开 Detail），在真屏上选了左竖条、右 Inbox，然后迭代了少订阅、详情可读性、字号和动效。原型保存在分支 `prototype/layout`（`bash prototype/run.sh A2`），A2 为定稿，A/B/C 为对照。

决定：

- 布局：Meter Bank 在左、Inbox 在右，中间一条细分隔线。Meter Bank 按 Quota Window 数分宽（每份约 84 设计像素，上限约画布宽 61%），剩下全给 Inbox；1 个订阅时 Meter Bank 很窄、Inbox 很宽。
- 密度：每根 Level Bar 分得 ≥56 设计像素时 Wide（全部 Quota Window，短周期名 + 缩写重置时间），否则 Compact（只 Primary Window，图标 + 短名）。所有 Level Bar 同宽（20 设计像素），间距一致；Primary Window 只用更大更亮的百分比区分，不加 ★、不加粗条。
- Detail：占满 Meter Bank，其他 Provider 隐藏；大号 Level Bar（34）、全名周期、完整重置时间、套餐胶囊、圆形关闭钮；未登录写原因并指向 Settings Overlay。
- 视觉：不给 Provider 画卡片，用细竖线分组；背景上浅下深的渐变；百分比用等宽粗体、% 缩小；Inbox 无卡片，分隔线列表，应用名 / 标题 / 正文三级，10 分钟内新通知带强调色圆点；DND 和设置是圆形触摸按钮，DND 开时填警告色。
- 动效：列依次淡入上移，Level Bar 逐段点亮、百分比同步计数；按下缩到 96%；Detail 从被点的列放大出现、其他列淡出，关闭反向；通知从右滑入、左滑时变淡并露出红色删除底、删除后其余补位；DND 铃铛摆动、设置齿轮转 90°；≤5% 的 Level Bar 呼吸。
- UI Scale：设计画布 960×400，插件自己按 UI Scale（默认 1.25，可设 1–1.4）缩放铺满，不依赖 Hyprland monitor scale（AM01S 保持 2）。代价：1.25 下 Inbox 一屏约 3 条，正文 1 行，接受截断。
- 配色：插件用 omarchy-shell 的 `qs.Commons` `Color` / `Style`，主题切换即时生效。角色映射：背景 / 深背景 / 浅背景 / 选中 / 前景 / 亮前景 / 暗前景 / 强调；Level Bar 正常用强调色，警告用主题 orange，危险用主题 red。浅色主题尚未在真屏上验收。
- 短名：窄处用 Provider 短名和 Quota Window 短名（Cursor Models → Cursor），由 Engine 在 catalog / Snapshot 里提供（PUB ADR 0011），插件不自己缩写。
