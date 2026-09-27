# 通知：只读 Omarchy 落盘的历史，不当守护进程

`org.freedesktop.Notifications` 同一时刻只能有一个持有者，现在是第一方插件 `omarchy.notifications`。它给插件的 API 只有勿扰，拿不到通知列表；但它把历史写在 `~/.local/state/omarchy/notifications/history/*.json`（每条一个文件，最多 10 条，含 `app`、`summary`、`body`、`appIcon`、`glyph`、`execArgv`、`urgency`、`timestamp`）。

决定：v1 不接管守护进程。弹窗仍由 Omarchy 画在主屏，副屏读这个目录做通知中心：点一条，有 `execArgv` 就执行它；没有就聚焦这个应用的窗口：app 名对得上桌面文件时先按它的 `StartupWMClass` 找（聊天的 summary 是联系人名，别的窗口标题可能也含有），再找标题里包含这条 summary 的窗口，否则按 app 名聚焦（去掉空格和标点后再比 class 和标题，所以「T3 Code」对得上 `com.t3tools.T3Code`）。勿扰走 `omarchy-shell notifications toggleDnd`，因为第三方插件读不到通知服务。清空删掉历史目录里的记录，并调用 `notifications clear`。删除一条就删对应文件。这个格式是 Omarchy 私有的，解析只放在一个模块里，Omarchy 改格式时只动那一处。`appIcon` 可能是 `file://` 路径、也可能是图标主题名（如微信的 `wechat`）。应用图标优先用这个名字，再用 app 名推出的桌面图标名（「T3 Code」→ `t3code`，`Quickshell.iconPath`），通知正文附带的 `image` 不当应用图标。都没有时画按 app 名着色的首字母方块。`omarchy-action`（Omarchy 自己的提示，如截图保存）和 `notify-send` 不是某个应用发的：图标用这条的 `glyph`，与 Omarchy 弹窗一致，没有就用 Omarchy 图标，不借用任何应用的图标；点击只执行 `execArgv`（截图通知即用 `tensaku-edit` 打开编辑），没有就什么都不做，不聚焦任何窗口。

放弃的方案：在 `disabledPlugins` 里关掉 `omarchy.notifications`、自己当守护进程。弹窗、历史、动作全能控制，但要自己实现整套守护进程，顶栏勿扰也会断开。等确认只读历史不够用（例如想让弹窗改到副屏、10 条不够）时再换，届时另写 ADR。
