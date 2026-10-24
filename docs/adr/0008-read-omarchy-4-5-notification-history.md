# 通知历史读 Omarchy 4.5 的单文件，逐条删除记在本地

Omarchy 4.5 把通知历史从「`notifications/history/*.json` 一条一个文件」换成「`notifications/history.json` 一个数组，最新在前，最多 100 条」，`ts` 用秒。Inbox 还在读旧目录，所以升级后右边一直是「没有新通知」。

决定：Inbox 两份都读。`history.json` 里每条用 `history.json#<key>` 做行标识，`ts × 1000` 当时间；旧目录里的单文件保持原样。

Omarchy 没有「删一条」的 IPC，只有 `notifications clear` 清空；而 `history.json` 归通知服务所有，服务进程内存里也有一份，外部改文件会被下一次保存覆盖。因此逐条左滑删除改成：把这条的标识写进 `~/.local/state/pub-am01s/inbox-hidden.json`，Inbox 读历史时过滤掉它；清空按钮仍走 `notifications clear`，并同时清掉本地记录。代价：Omarchy 自己的通知面板仍会显示被 Inbox 隐藏的那条；等 Omarchy 提供逐条删除的 IPC 后改回直接删。

格式仍是 Omarchy 私有的；解析只在 `inbox-model.mjs` 里，Omarchy 再换格式时只动那一处。
