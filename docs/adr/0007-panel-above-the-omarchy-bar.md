# Panel 压过 Omarchy 顶栏

omarchy-shell 给每个 screen 都建一条 `omarchy-bar`，层是 `WlrLayer.Top`。Panel 原先也在 `Top`，又比顶栏晚画一点时也压不住它：顶栏的 workspace、时钟、托盘图标会画在 Panel 上方，点 Panel 最上面 26 像素还会落到顶栏上。副屏整块归 Panel（ADR 0002），顶栏在这里本来就不该出现。

决定：PanelWindow 用 `WlrLayer.Overlay`，铺满 AM01S 并盖住顶栏。顶栏 surface 仍在、仍占它的 exclusive zone，只是被 Panel 挡住；不卸顶栏、不改 omarchy-shell，也不依赖它以后是否加 per-monitor 开关。Settings Overlay 早就在 `Overlay`，两者不冲突：它只出现在非 AM01S 的屏。
