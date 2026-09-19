# 青鸟 · 端到端演练清单

## A. 离线状态机（已自动化）

```bash
scripts/e2e_dryrun.sh
```

覆盖：idle → listening_a → draft_pending → awaiting_reply_b → converging → summary_pending → resolved。

## B. 钉钉双账号（需版本发布 + 双方 userId）

前置：

1. 应用版本已发布（RELEASE）  
2. 本机 `config/partners.yaml` 已填 A/B 的 `dingtalk_user_id`  
3. `cc-connect` 已启动且 `dingtalk: stream connected`

剧本：

| 步 | 角色 | 动作 | 期望 |
|----|------|------|------|
| 1 | A | 私聊青鸟：「我们吵起来了」 | 开场 + 免责声明 |
| 2 | A | 简述事实与感受 | 共情 + 澄清追问；写入 `a_thread.md` |
| 3 | A | 补全诉求 | 收到转述草稿确认 |
| 4 | A | 「同意」 | `send_to.sh B` 推送；phase=`awaiting_reply_b` |
| 5 | B | 收到【青鸟传信】并回应 | 倾听 B；不泄露 A 原文 |
| 6 | 双方 | 诉求清晰后确认共识卡 | `shared_summary.md`；phase=`resolved` |

## C. 本机实测状态

真实组织、版本、双方 userId 写在 `docs/e2e-checklist.local.md`（已 gitignore），此处不提交。
