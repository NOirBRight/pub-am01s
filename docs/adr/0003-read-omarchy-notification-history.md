# 通知：只读 Omarchy 落盘的历史，不当守护进程

`org.freedesktop.Notifications` 同一时刻只能有一个持有者，现在是第一方插件 `omarchy.notifications`。它给插件的 API 只有勿扰，拿不到通知列表；但它把历史写在 `~/.local/state/omarchy/notifications/history/*.json`（每条一个文件，最多 10 条，含 `app`、`summary`、`body`、`appIcon`、`execArgv`、`urgency`、`timestamp`）。

决定：v1 不接管守护进程。弹窗仍由 Omarchy 画在主屏，副屏读这个目录做通知中心：点一条执行 `execArgv`，删除就删对应文件。这个格式是 Omarchy 私有的，解析只放在一个模块里，Omarchy 改格式时只动那一处。`appIcon` 可能是 `file://` 路径、也可能是图标主题名（如微信的 `wechat`），后者用 `Quickshell.iconPath(name, true)` 解析；都没有时画按 app 名着色的首字母方块。

放弃的方案：在 `disabledPlugins` 里关掉 `omarchy.notifications`、自己当守护进程。弹窗、历史、动作全能控制，但要自己实现整套守护进程，顶栏勿扰也会断开。等确认只读历史不够用（例如想让弹窗改到副屏、10 条不够）时再换，届时另写 ADR。
