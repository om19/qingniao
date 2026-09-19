#!/usr/bin/env bash
# 青鸟：主动推送消息给指定一方（A 或 B）
# 用法:
#   scripts/send_to.sh A <<'EOF'
#   消息正文
#   EOF
#   echo "你好" | scripts/send_to.sh B
#
# 通道优先级（由环境变量 / 凭证决定）:
#   1. DINGTALK_CLIENT_ID + DINGTALK_CLIENT_SECRET → 机器人单聊 oToMessages
#   2. dws chat （若已登录且可发个人消息）
#   3. cc-connect send（仅当当前会话上下文可用时）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARTNERS="${ROOT}/config/partners.yaml"
ROLE="${1:-}"

if [[ -z "$ROLE" || ! "$ROLE" =~ ^[ABab]$ ]]; then
  echo "用法: $0 <A|B>  < 消息正文" >&2
  exit 2
fi
ROLE="$(echo "$ROLE" | tr 'ab' 'AB')"

if [[ -t 0 ]]; then
  echo "请通过 stdin 或 heredoc 传入消息正文" >&2
  exit 2
fi
MSG="$(cat)"
if [[ -z "${MSG//[[:space:]]/}" ]]; then
  echo "消息正文为空" >&2
  exit 2
fi

# --- 从 partners.yaml 取对方 userId（尽量少依赖外部工具）---
read_partner_field() {
  local role="$1" field="$2"
  python3 - "$PARTNERS" "$role" "$field" <<'PY'
import sys
path, role, field = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    import yaml  # type: ignore
    data = yaml.safe_load(open(path, encoding="utf-8"))
    print((data.get("partners") or {}).get(role, {}).get(field) or "")
except Exception:
    # 无 PyYAML 时做极简解析（去掉行内注释与引号）
    text = open(path, encoding="utf-8").read().splitlines()
    in_role = False
    for line in text:
        if line.strip().startswith(f"{role}:"):
            in_role = True
            continue
        if in_role:
            if line and not line.startswith(" ") and not line.startswith("\t"):
                break
            if line.strip().startswith("B:") or line.strip().startswith("A:"):
                if not line.strip().startswith(f"{role}:"):
                    break
            key = field + ":"
            if key in line:
                raw = line.split(":", 1)[1]
                # 去掉 # 注释（不在引号内的简单情况）
                if "#" in raw:
                    in_q = False
                    out = []
                    for ch in raw:
                        if ch in "\"'":
                            in_q = not in_q
                        if ch == "#" and not in_q:
                            break
                        out.append(ch)
                    raw = "".join(out)
                print(raw.strip().strip('"').strip("'"))
                break
PY
}

USER_ID="$(read_partner_field "$ROLE" "dingtalk_user_id")"
# 日志/兜底称呼优先 bot_name（青鸟对外称呼），兼容旧字段 display_name
DISPLAY="$(read_partner_field "$ROLE" "bot_name")"
if [[ -z "$DISPLAY" ]]; then
  DISPLAY="$(read_partner_field "$ROLE" "display_name")"
fi
if [[ -z "$USER_ID" ]]; then
  echo "错误: partners.yaml 中 ${ROLE}.dingtalk_user_id 为空，无法推送" >&2
  exit 1
fi

# --- 防串线护栏：绝不把内容推给「当前正在说话的人」---
# 传信永远是发给另一方。若目标等于当前发送者，说明 agent 认错了人，此时必须中止。
if [[ -n "${CC_SESSION_KEY:-}" && "${QINGNIAO_ALLOW_SELF_SEND:-0}" != "1" ]]; then
  SENDER_ID="${CC_SESSION_KEY##*:}"
  if [[ "$SENDER_ID" == "$USER_ID" ]]; then
    echo "已阻止: 目标 ${ROLE} 就是当前发送者本人（userId=${SENDER_ID}）。" >&2
    echo "这通常意味着身份判断出错了。请先跑 scripts/whoami.sh 重新确认，再决定发给谁。" >&2
    exit 4
  fi
fi

# 加载本地凭证（优先项目 .env，再 ~/.qingniao/credentials.env）
load_env() {
  local f
  for f in "${ROOT}/.env" "${HOME}/.qingniao/credentials.env"; do
    if [[ -f "$f" ]]; then
      # shellcheck disable=SC1090
      set -a; source "$f"; set +a
    fi
  done
}
load_env

CLIENT_ID="${DINGTALK_CLIENT_ID:-${DINGTALK_APP_KEY:-}}"
CLIENT_SECRET="${DINGTALK_CLIENT_SECRET:-${DINGTALK_APP_SECRET:-}}"

get_access_token() {
  local resp
  resp="$(curl -sS -X POST "https://api.dingtalk.com/v1.0/oauth2/accessToken" \
    -H "Content-Type: application/json" \
    -d "{\"appKey\":\"${CLIENT_ID}\",\"appSecret\":\"${CLIENT_SECRET}\"}")"
  python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("accessToken") or d.get("access_token") or "")' <<<"$resp"
}

send_via_robot_api() {
  local token="$1"
  local robot_code="${DINGTALK_ROBOT_CODE:-$CLIENT_ID}"
  # 钉钉机器人单聊：batchSendOTO / oToMessages
  local payload
  payload="$(python3 - "$USER_ID" "$MSG" "$robot_code" <<'PY'
import json, sys
uid, msg, robot = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
  "robotCode": robot,
  "userIds": [uid],
  "msgKey": "sampleText",
  "msgParam": json.dumps({"content": msg}, ensure_ascii=False),
}, ensure_ascii=False))
PY
)"
  local resp
  resp="$(curl -sS -X POST "https://api.dingtalk.com/v1.0/robot/oToMessages/batchSend" \
    -H "Content-Type: application/json" \
    -H "x-acs-dingtalk-access-token: ${token}" \
    -d "$payload")"
  echo "$resp"
  python3 -c 'import json,sys; d=json.load(sys.stdin); 
ok = (d.get("processQueryKey") or d.get("success") is True or "errorCode" not in d and "code" not in d)
# 有 processQueryKey 即成功；否则看错误字段
err = d.get("code") or d.get("errorCode") or d.get("message") or d.get("errorMsg")
if d.get("processQueryKey"):
  sys.exit(0)
if err and str(err) not in ("0", "ok", "OK"):
  print("API error:", err, file=sys.stderr); sys.exit(1)
' <<<"$resp"
}

send_via_dws() {
  # 兜底：以个人号名义发单聊（非机器人身份；仅联调/紧急）
  if ! command -v dws >/dev/null 2>&1; then
    return 1
  fi
  if [[ -n "${DISPLAY:-}" ]]; then
    if dws chat +dm --to "$DISPLAY" --text "$MSG" --yes --format json 2>/dev/null; then
      echo "注意: 此条经 dws 个人号发出，不是青鸟机器人身份" >&2
      return 0
    fi
  fi
  return 1
}

echo "【青鸟】准备推送给 ${ROLE}（${DISPLAY:-$USER_ID}）…" >&2

if [[ -n "$CLIENT_ID" && -n "$CLIENT_SECRET" ]]; then
  TOKEN="$(get_access_token)"
  if [[ -z "$TOKEN" ]]; then
    echo "错误: 获取 accessToken 失败，检查 DINGTALK_CLIENT_ID/SECRET" >&2
    exit 1
  fi
  if send_via_robot_api "$TOKEN"; then
    echo "【青鸟】已通过机器人 API 送达 ${ROLE}" >&2
    exit 0
  fi
  echo "警告: 机器人 API 发送失败，尝试 dws 兜底…" >&2
fi

if send_via_dws; then
  echo "【青鸟】已通过 dws chat 送达 ${ROLE}" >&2
  exit 0
fi

echo "错误: 无法推送。请配置 DINGTALK_CLIENT_ID + DINGTALK_CLIENT_SECRET（写入 .env），并确保 partners.yaml 中 ${ROLE}.dingtalk_user_id 正确；同时机器人需具备「企业内机器人发送单聊消息」权限。" >&2
exit 1
