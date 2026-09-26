# 独立仓库，只面向 AM01S；Engine 按 tag 拷单文件

副屏版只适用于 AM01S 这块 960×400 屏，其他设备用不上，不放进 PUB 仓库。AM01S 的内核驱动也有自己的仓库（`AM01S-SubScreen-Driver`），但那是内核层，跟着内核与发行版走；这里是桌面层，跟着 Omarchy 和 PUB 走，发版节奏不同，也不合并。

决定：`pub-am01s` 是独立仓库。驱动是前提，README 指过去。Engine 不复制源码、不做 git 依赖：脚本按 PUB 的 tag 下载 Release 附件 `pub-engine.mjs`（单文件、只依赖 `node:`），版本号写在仓库里。与 PUB 的契约只有 Engine CLI 和带 `schemaVersion` 的 Snapshot（PUB ADR 0011）；不认识的 `schemaVersion` 显示「需要更新」。
