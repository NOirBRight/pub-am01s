# pub-am01s

pub-am01s 是 PUB 在 Omarchy（Hyprland）+ AM01S 960×400 副屏上的 Shell：副屏整块显示 Plan Quota 和通知，主屏弹设置面板。它只适用于这块屏。

Provider、Plan Quota、Quota Window、Primary Window、Remaining、Meter、Enabled、Snapshot、Engine、Shell 等词沿用 PUB 的 `CONTEXT.md`，这里只补副屏上的新概念。

## Language

**AM01S**:
AM01S 类迷你主机里那块 960×400 的 USB 副屏（`345f:9133`，MS912C），驱动见 `NOirBRight/AM01S-SubScreen-Driver`。在 Hyprland 里显示为描述 `ChangHong Electric Co.Ltd 0x0030` 的一块普通 DRM 屏，触摸是单独的 `puya-touch--screen`。
_Avoid_: 小屏, extscreen, HDMI-A-3（接口名会变）

**Settings Overlay**:
在主屏弹出的设置面板：Enabled、Remaining 读法、CLI 登录、粘贴 API key。从副屏的设置入口或 Omarchy 菜单「PUB 设置」打开。一切写入都走 Engine CLI。
_Avoid_: Popover, 设置窗口

**Panel**:
AM01S 上整块画面：左边 Meter Bank，右边 Inbox。铺满整块屏，不进 workspace，不接受键盘焦点。
_Avoid_: 窗口, dashboard, widget

**Meter Bank**:
Panel 左区，按用户顺序列出全部 Enabled Provider（Pinned 在这里不用）。每个 Quota Window 分一份相同宽度，所以一个 Provider 的宽度取决于它有几个 Quota Window；剩下的宽度全给 Inbox。
_Avoid_: Strip（那是 GNOME 顶栏）, 用量卡片

**Level Bar**:
一个 Quota Window 的分段 LED 竖条：点亮段数 = Remaining，颜色按阈值（≤20% 警告、≤5% 危险并呼吸）。Meter Bank 和 Detail 都只用它，不用横条。
_Avoid_: progress bar, 圆环

**Wide / Compact**:
Meter Bank 的两种密度。每根 Level Bar 分得的宽度够（约 56 设计像素）时是 Wide：每个 Provider 画出全部 Quota Window；不够时是 Compact：每个 Provider 一根 Level Bar，只画 Primary Window。由宽度决定，不按 Provider 个数写死。
_Avoid_: 展开/收起（那是 Detail）

**Detail**:
点任一 Provider 后占满整个 Meter Bank 的放大视图：全部 Quota Window 的大号 Level Bar、完整周期名和重置时间，未登录时写原因并指向 Settings Overlay。从被点的那列放大出现，点任意处收回。其他 Provider 这时隐藏，不挤成窄条。
_Avoid_: Popover, 展开列

**Inbox**:
Panel 右区，只读 Omarchy 落盘的通知历史。点一条执行它的 `execArgv`，向左滑删除；标题栏有 DND 和打开 Settings Overlay 的圆按钮。
_Avoid_: 通知中心（口语可以）, notification daemon

**UI Scale**:
插件自己的整体缩放：设计画布 960×400 除以 UI Scale，再铺满 AM01S。默认 1.25，与 Hyprland 给 AM01S 的 monitor scale（保持 2）无关。
_Avoid_: monitor scale, GDK_SCALE
