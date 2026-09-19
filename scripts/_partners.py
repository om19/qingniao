#!/usr/bin/env python3
"""解析 config/partners.yaml（本机可能没有 PyYAML，故内置极简解析）。

用法:
  _partners.py resolve-user <userId>   # 打印该 userId 对应的角色档案
  _partners.py get <A|B> <field>       # 打印指定字段
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PARTNERS = os.path.join(ROOT, "config", "partners.yaml")


def _strip_inline_comment(raw: str) -> str:
    in_quote = False
    out = []
    for ch in raw:
        if ch in "\"'":
            in_quote = not in_quote
        if ch == "#" and not in_quote:
            break
        out.append(ch)
    return "".join(out).strip().strip('"').strip("'")


def load_partners(path: str = PARTNERS) -> dict:
    try:
        import yaml  # type: ignore

        data = yaml.safe_load(open(path, encoding="utf-8")) or {}
        return data.get("partners") or {}
    except Exception:
        pass

    partners: dict = {}
    role = None
    in_partners = False
    for line in open(path, encoding="utf-8").read().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        if indent == 0:
            in_partners = stripped.startswith("partners:")
            role = None
            continue
        if not in_partners:
            continue
        if indent == 2 and stripped.endswith(":"):
            role = stripped[:-1].strip()
            partners[role] = {}
            continue
        if role and ":" in stripped:
            key, raw = stripped.split(":", 1)
            partners[role][key.strip()] = _strip_inline_comment(raw)
    return partners


def resolve_user(user_id: str) -> dict:
    partners = load_partners()
    for role, info in partners.items():
        if info.get("dingtalk_user_id") and info["dingtalk_user_id"] == user_id:
            other = "B" if role == "A" else "A"
            return {
                "role": role,
                "bot_name": info.get("bot_name") or info.get("display_name") or "",
                "pet_name": info.get("pet_name", ""),
                "user_id": user_id,
                "counterpart": other,
                "counterpart_bot_name": (partners.get(other) or {}).get("bot_name", ""),
                "thread": "sessions/current/%s_thread.md" % role.lower(),
            }
    return {}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2

    cmd = sys.argv[1]
    if cmd == "resolve-user" and len(sys.argv) == 3:
        info = resolve_user(sys.argv[2])
        if not info:
            return 3
        for key, value in info.items():
            print("%s=%s" % (key, value))
        return 0

    if cmd == "get" and len(sys.argv) == 4:
        role, field = sys.argv[2], sys.argv[3]
        info = (load_partners().get(role) or {})
        print(info.get(field, ""))
        return 0

    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
