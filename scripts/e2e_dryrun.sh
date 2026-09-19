#!/usr/bin/env bash
# 青鸟 · 离线状态机演练（不依赖钉钉双账号）
# 验证：idle → listening_a → draft_pending_a → awaiting_reply_b → converging → summary_pending → resolved
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/sessions/e2e-dryrun"
rm -rf "$S"
mkdir -p "$S"

# 从零播种一个干净的 idle 状态：离线演练不能依赖线上 sessions/current 的当前 phase
cat > "$S/state.json" <<'JSON'
{
  "topic": "e2e-dryrun",
  "phase": "idle",
  "updated_at": "2026-01-01T00:00:00+08:00",
  "facts": { "A": "", "B": "" },
  "feelings": { "A": "", "B": "" },
  "needs": { "A": "", "B": "" },
  "pending_draft": null,
  "consents": [],
  "summary_acks": { "A": false, "B": false },
  "notes": ""
}
JSON
printf '# A 私聊线程\n' > "$S/a_thread.md"
printf '# B 私聊线程\n' > "$S/b_thread.md"
printf '# 共识卡\n' > "$S/shared_summary.md"

python3 - "$S" <<'PY'
import json, datetime
from pathlib import Path
sdir = Path(__import__("sys").argv[1])
state_path = sdir / "state.json"

def load():
    return json.loads(state_path.read_text(encoding="utf-8"))

def save(st, phase):
    st["phase"] = phase
    st["updated_at"] = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    state_path.write_text(json.dumps(st, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"→ phase={phase}")

st = load()
assert st["phase"] == "idle"

# A 倾诉
(sdir / "a_thread.md").write_text(
    "# A 私聊线程\n\n## 2026-08-13 e2e\n- 事实：昨晚洗碗没人做\n- 情绪：委屈、被忽视\n- 诉求：希望有固定轮值\n",
    encoding="utf-8",
)
st["facts"]["A"] = "昨晚洗碗无人做"
st["feelings"]["A"] = "委屈、被忽视"
st["needs"]["A"] = "希望家务有固定轮值"
save(st, "listening_a")

# 起草
st["pending_draft"] = {
    "from": "A",
    "to": "B",
    "text": "昨晚洗碗没人做时我感到委屈。我希望我们能约定洗碗轮值。你愿意一起定个规则吗？",
    "created_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
}
save(st, "draft_pending_a")

# 同意
st["consents"].append({
    "who": "A",
    "what": "send_draft_to_B",
    "at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
})
# 模拟已推送
(sdir / "push_log.txt").write_text("SENT_TO_B:\n" + st["pending_draft"]["text"] + "\n", encoding="utf-8")
st["pending_draft"] = None
save(st, "awaiting_reply_b")

# B 回应
(sdir / "b_thread.md").write_text(
    "# B 私聊线程\n\n## 2026-08-13 e2e\n- 事实：那天加班很晚\n- 情绪：压力大、也想被理解\n- 诉求：愿意轮值，但加班日可换\n",
    encoding="utf-8",
)
st["facts"]["B"] = "那天加班很晚"
st["feelings"]["B"] = "压力大"
st["needs"]["B"] = "愿意轮值，加班日可换"
save(st, "converging")

# 共识卡
summary = """# 共识卡 · e2e-dryrun

## 各自的需求
- A：固定洗碗轮值
- B：愿意轮值，加班日可换

## 各自「有道理之处」
- A：家务需要可见的公平
- B：加班消耗需要被看见

## 和解动作（尽量具体、可执行、有时限）
1. 本周内共同列出洗碗轮值表
2. 加班日提前说一声，由另一方顶上或次日补

## 暂搁 / 下次再聊
- 其他家务分工下次再议
"""
(sdir / "shared_summary.md").write_text(summary, encoding="utf-8")
st["summary_acks"] = {"A": False, "B": False}
save(st, "summary_pending")

st["summary_acks"] = {"A": True, "B": True}
save(st, "resolved")

st = load()
assert st["phase"] == "resolved"
assert st["summary_acks"]["A"] and st["summary_acks"]["B"]
assert "SENT_TO_B" in (sdir / "push_log.txt").read_text(encoding="utf-8")
print("OK e2e dry-run passed:", sdir)
PY
