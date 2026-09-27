# pub-am01s

PUB 在 Omarchy（Hyprland）上的 AM01S 副屏。副屏整块显示 Plan Quota 和通知，设置在主屏弹出。

## 前提

安装 [AM01S-SubScreen-Driver](https://github.com/NOirBRight/AM01S-SubScreen-Driver)，并让这块屏作为一块 960×400 的 DRM 显示器出现（`ChangHong Electric Co.Ltd 0x0030`）。

## 安装

```bash
python3 scripts/install.py
```

脚本按仓库里的 `engine.tag` 下载 PUB 的 Release 附件，钉在 `plugin/bin/pub-engine.mjs`，再把插件、Hyprland 片段和菜单项装进当前用户的配置目录。再跑一次不会重复添加。插件只跑这份钉住的文件。

## 升级

改 `engine.tag`，然后重新运行 `python3 scripts/install.py`。安装会按新 tag 换成对应的 PUB Release 附件 `plugin/bin/pub-engine.mjs`。
