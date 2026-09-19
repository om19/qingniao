# 能力验证记录

日期：YYYY-MM-DD  
组织：（填写本机调试所用组织，勿提交真实公司名）

## 1. 发送者身份透传

- cc-connect 支持多用户；管理指令可用 `/whoami`、`/status` 查看当前 User ID。
- 青鸟协议：每轮先跑 `scripts/whoami.sh`，对照 `config/partners.yaml` 判定 A/B；`admin_from` 限制管理指令。
- **实测要求**：双方分别私聊青鸟发 `/whoami`，把各自 userId 写入本地 `partners.yaml`（该文件含隐私，勿公开仓库提交真实 ID）。

## 2. 主动推送通道选型

| 通道 | 结论 |
|------|------|
| `cc-connect send` | 只能发到**当前活跃会话**，不能指定另一半。不适合跨人转述。 |
| 机器人 `oToMessages/batchSend` | **首选**。`scripts/send_to.sh` 已实现；需 `Robot.SingleChat.ReadWrite` 等权限随版本发布生效。 |
| `dws chat +dm` | 以**个人号**名义发单聊，不是机器人身份；仅作人工兜底，不进调解协议默认路径。 |

## 3. Runner 切换

- 本机需已安装：`agent`（Cursor）与/或 `codex`。
- 实测：`~/.cc-connect/config.toml` 改 `type = "codex"` / `mode = "yolo"` 重启后日志应出现对应 agent；改回 `type = "cursor"` / `mode = "force"` 同理。
- 按你本机偏好选择默认 runner。

## 4. 版本发布门禁

企业内部应用版本通常需审批后才能被同事搜到完整能力。Stream 本地调试可先起 `cc-connect`，创建者常可提前测通。
