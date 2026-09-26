# Omarchy shell 插件，副屏整块归它，顶栏不放

Omarchy 的顶栏和面板是 omarchy-shell（Quickshell）加插件系统。独立 GJS/GTK4 layer-shell 程序或 chromium kiosk 都要自己管进程、自启和主题；PUB 的 St UI 反正搬不过来。

决定：做成 Omarchy shell 插件 `noirbright.pub-am01s`（QML），用 layer-shell `PanelWindow` 铺满 AM01S，跟 Omarchy 主题走。副屏整块给它：Plan Quota（全部 Enabled，按顺序；Pinned 在这里不用）加通知。顶栏什么都不放；副屏没接就不显示，不做兜底。插件用 Quickshell `Process` 自己定时 spawn `pub-engine snapshot`（沿用 PUB 0004 的节奏），不加 systemd timer。副屏上可以：点 Meter 就地展开全部 Quota Window，点通知跳到应用，滑动删通知，切勿扰（Omarchy 插件 API 的 `setDoNotDisturb`）。现有的 `noirbright.agents` 顶栏插件在本插件验收后下线。
