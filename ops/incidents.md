# 青鸟 · 运维备忘

本目录放**系统侧**记录：故障、修复、联调笔记。  
不要写进 `sessions/*/a_thread.md` / `b_thread.md`——那两份只服务调解私聊。

---

## 2026-08-13 · 闲置重置后身份串线

### 现象

B 在闲置约 41 分钟后发「你发他了吗？」。  
cc-connect 因 `reset_on_idle_mins=30` 起了新会话，agent 无历史；把 B 误判成 A，并按「A 问有没有发给 B」作答。

### 影响

- B 的长回应仍停在 `holding_b`：无草稿、无同意、**未发给 A**；原文未泄露。
- 对 B 造成错误称呼与答非所问；对人侧的补救话术写在 `sessions/current/b_thread.md`（只写「下一轮要对她说什么」），根因与代码修复只写本文件。

### 根因

身份依赖 agent 会话记忆；会话重置后记忆清空，仍凭印象猜 A/B。

### 修复

1. `scripts/whoami.sh` + `scripts/_partners.py`：每轮从 `CC_SESSION_KEY` 解析 userId → A/B。
2. `scripts/send_to.sh`：目标若等于当前发送者则退出码 4，禁止自发。
3. `AGENTS.md`：硬规则——先验身份；模糊指代先澄清；状态以文件为准；`*_thread.md` 禁止写入运维内容。
4. `scripts/e2e_dryrun.sh`：不再复制线上 `sessions/current`（phase 非 idle 会误失败）。
5. 新增本目录 `ops/incidents.md`：系统故障与修复备忘的落点。
