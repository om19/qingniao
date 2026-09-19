#!/usr/bin/env bash
# 青鸟：判定「当前这条消息是谁发来的」——身份的唯一真相来源。
#
# 为什么需要它：agent 会话会因闲置被重置，重置后没有任何历史上下文。
# 靠对话记忆猜身份会串人（把 B 当成 A），所以每轮都必须先跑这个脚本。
#
# 用法:
#   scripts/whoami.sh              # 从 CC_SESSION_KEY 自动解析
#   scripts/whoami.sh <userId>     # 显式指定 userId（调试用）
#
# 输出（key=value，可直接 eval）:
#   role / bot_name / pet_name / user_id / counterpart / counterpart_bot_name / thread
#
# 退出码:
#   0 已确定身份
#   3 无法确定 —— 此时必须先问对方是谁，禁止继续按猜测回复或传信
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

USER_ID="${1:-}"
if [[ -z "$USER_ID" ]]; then
  # CC_SESSION_KEY 形如 dingtalk:d:cidXXXX=:USER_ID，末段即发送者 userId
  if [[ -z "${CC_SESSION_KEY:-}" ]]; then
    echo "role=UNKNOWN" >&2
    echo "错误: 没有 CC_SESSION_KEY，也没有显式 userId，无法确定身份。" >&2
    echo "处理: 先问「你是哪位」，确认后再继续；禁止凭对话记忆假设 A/B。" >&2
    exit 3
  fi
  USER_ID="${CC_SESSION_KEY##*:}"
fi

if ! OUT="$(python3 "${ROOT}/scripts/_partners.py" resolve-user "$USER_ID" 2>/dev/null)"; then
  echo "role=UNKNOWN" >&2
  echo "user_id=${USER_ID}" >&2
  echo "错误: userId ${USER_ID} 不在 config/partners.yaml 中。" >&2
  echo "处理: 先问对方是谁并登记到 partners.yaml；在此之前禁止传信。" >&2
  exit 3
fi

echo "$OUT"
