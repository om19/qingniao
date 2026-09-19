# 青鸟 · 接入与部署

## 1. 钉钉应用

在目标组织创建企业内部应用「青鸟」，机器人模式选 **STREAM**，发布版本后成员可搜到并单聊。

记下：`unifiedAppId`、`appKey` / `robotCode`、`client_secret`。

凭证写入本机 `~/.qingniao/credentials.env`（或项目 `.env`），**不要提交到 git**。  
本机私密部署笔记可写在 `docs/setup.local.md`（已 gitignore）。

## 2. 安装依赖

```bash
npm install -g cc-connect
# Agent 二选一（或都装，靠 config 切换）
# Cursor Agent CLI：通常随 Cursor 安装，命令为 `agent`
# Codex：npm i -g @openai/codex
```

## 3. cc-connect 配置

```bash
cp docs/cc-connect.config.example.toml ~/.cc-connect/config.toml
# 编辑：admin_from、work_dir、client_id、client_secret
```

```toml
[[projects]]
name = "qingniao"
admin_from = "YOUR_DINGTALK_USER_ID"
reset_on_idle_mins = 30

[projects.agent]
type = "cursor"                       # 或 "codex"

[projects.agent.options]
work_dir = "/ABS/PATH/TO/qingniao"
mode = "force"                        # cursor: force≈yolo；codex 用 yolo / full-auto
cmd = "agent"

[[projects.platforms]]
type = "dingtalk"

[projects.platforms.options]
client_id = "YOUR_APP_KEY"
client_secret = "YOUR_APP_SECRET"
reaction_emoji = "none"
done_emoji = "none"
```

切换 runner：只改 `type = "codex"` 或 `"cursor"`，并确认本机 CLI 可用。

## 4. 双方身份

```bash
cp config/partners.example.yaml config/partners.yaml
# 编辑 A/B 的 dingtalk_user_id、bot_name、pet_name
```

- 双方私聊青鸟后发 `/whoami`（或看 cc-connect 日志）拿到 userId
- `bot_name`：青鸟当面称呼；`pet_name`：双方互称昵称（青鸟不当面用）
- 同一人在不同组织的 userId 不同
- `partners.yaml` 已 gitignore，仅本机使用

## 5. 会话目录

```bash
cp -R sessions/template sessions/current
```

`sessions/current/` 已 gitignore，调解私聊只落本机。

## 6. 启动

```bash
cc-connect
# 或
cc-connect -config ~/.cc-connect/config.toml
```

日志出现 `dingtalk: stream connected` 即表示 Stream 已连上。

## 7. 主动推送（同意后转述）

```bash
scripts/send_to.sh B <<'EOF'
【青鸟传信】
……
EOF
```

通道：钉钉机器人 `oToMessages/batchSend`。凭证从 `.env` / `~/.qingniao/credentials.env` 读取。  
说明：`cc-connect send` 只发给当前活跃会话，跨人推送必须用 `send_to.sh`。

## 8. 自测清单

1. 搜「青鸟」→ 私聊「你好」→ 应收到开场回复  
2. 发 `/whoami` → 记下 userId，写入本机 `partners.yaml` 的 A  
3. 另一方同样操作，写入 B  
4. A 倾诉 → 同意转述 → B 收到【青鸟传信】  
5. （可选）改 `type = "codex"` 重启，确认同样可聊  

## 9. 飞书（后续）

cc-connect 原生支持飞书 WebSocket：在同一 `config.toml` 增加 `[[projects.platforms]] type = "feishu"` 即可。
