# Hyprland 片段随仓库走，按描述认屏

AM01S 需要两条 Hyprland 配置：触摸映射到这块屏（默认没映射，点副屏会落到错的坐标），workspace 11 留给副屏。接口名 `HDMI-A-3` 换线或换口就会变。

原型证实：触摸在 Hyprland 里是 `puya-touch--screen`，默认 `input:touchdevice:output` 是 `[[Auto]]`，点副屏会落到主屏；`hl.device({ name = "puya-touch--screen", output = <接口> })` 之后触摸和滑动都准。Hyprland 0.56 用 Lua 配置，`hyprctl keyword` 不可用，运行时要用 `hyprctl eval`。AM01S 的 monitor scale 保持 2，插件自己缩放（ADR 0006）。

决定：仓库带 `hypr/am01s.lua`（触摸 `output` 映射 + workspace 11 规则，后者从用户的 `monitors.lua` 挪进来），安装脚本在 `~/.config/hypr/` 入口里幂等补一行引用。插件按显示器描述 `ChangHong Electric Co.Ltd 0x0030` 加 960×400 认出 AM01S，认不到就不画副屏面板，Settings Overlay 照常可用。插件配置留一个手动指定接口名的覆盖项。
