#!/usr/bin/env python3
"""Manage the shop's Game Pass and Developer Product ids.

Editing ShopConfig.luau by hand works, but a mistyped id fails silently:
the shop just shows a dead button and nothing says why. This sets ids
safely and checks them against Roblox before you find out in-game.

    python scripts/shop.py list
    python scripts/shop.py set SpeedCoil 123456789
    python scripts/shop.py check
"""

from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "src" / "shared" / "ShopConfig.luau"

ITEM_RE = re.compile(
    r'key\s*=\s*"(?P<key>\w+)",\s*id\s*=\s*(?P<id>\d+),\s*robux\s*=\s*(?P<robux>\d+),'
)
PASS_INFO = "https://apis.roblox.com/game-passes/v1/game-passes/{id}/product-info"

GREEN, RED, YELLOW, DIM, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"


def read_items():
    text = CONFIG.read_text(encoding="utf-8")
    # everything before ShopConfig.Products is a game pass
    split_at = text.find("ShopConfig.Products")
    items = []
    for m in ITEM_RE.finditer(text):
        items.append(
            {
                "key": m.group("key"),
                "id": int(m.group("id")),
                "robux": int(m.group("robux")),
                "kind": "pass" if m.start() < split_at else "product",
            }
        )
    return text, items


def cmd_list():
    _, items = read_items()
    width = max(len(i["key"]) for i in items)
    for item in items:
        if item["id"]:
            state = f"{GREEN}id {item['id']}{RESET}"
        else:
            state = f"{RED}not created{RESET}"
        print(
            f"  {item['key']:<{width}}  {item['kind']:<7}  "
            f"want R$ {item['robux']:<5}  {state}"
        )
    missing = [i["key"] for i in items if not i["id"]]
    if missing:
        print(f"\n{YELLOW}{len(missing)} item(s) still need creating on the "
              f"Creator Dashboard.{RESET}")
    else:
        print(f"\n{GREEN}All ids set. Run 'check' to verify them.{RESET}")


def cmd_set(key: str, new_id: str):
    if not new_id.isdigit():
        sys.exit(f"id must be a number, got {new_id!r}")

    text, items = read_items()
    match = next((i for i in items if i["key"].lower() == key.lower()), None)
    if not match:
        known = ", ".join(i["key"] for i in items)
        sys.exit(f"unknown key {key!r}. Known keys: {known}")

    pattern = re.compile(
        r'(key\s*=\s*"%s",\s*id\s*=\s*)\d+' % re.escape(match["key"])
    )
    updated, count = pattern.subn(r"\g<1>" + new_id, text)
    if count != 1:
        sys.exit(f"expected exactly one match for {match['key']}, found {count}")

    CONFIG.write_text(updated, encoding="utf-8", newline="\n")
    print(f"{GREEN}{match['key']}: id {match['id']} -> {new_id}{RESET}")
    print(f"{DIM}Rojo will push this to Studio within a second.{RESET}")


def fetch_pass(pass_id: int):
    request = urllib.request.Request(
        PASS_INFO.format(id=pass_id), headers={"User-Agent": "house-of-fighting"}
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.load(response)
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as exc:
        return {"_error": str(exc)}


def cmd_check():
    _, items = read_items()
    live = [i for i in items if i["id"]]
    if not live:
        sys.exit("No ids set yet. Create the items first, then use 'set'.")

    problems = 0
    for item in live:
        label = f"  {item['key']}"

        if item["kind"] == "product":
            # developer product lookup needs an authenticated session, so
            # there is nothing useful to verify from here
            print(f"{label}: {DIM}developer product, cannot verify without "
                  f"login. Test it in Studio instead (free there).{RESET}")
            continue

        info = fetch_pass(item["id"])
        if "_error" in info:
            print(f"{label}: {RED}lookup failed{RESET} ({info['_error']})")
            problems += 1
            continue

        name = info.get("Name")
        price = info.get("PriceInRobux")
        creator = (info.get("Creator") or {}).get("Name", "?")
        for_sale = info.get("IsForSale")

        if name is None:
            print(f"{label}: {RED}no such game pass ({item['id']}){RESET}")
            problems += 1
            continue

        notes = []
        if not for_sale:
            notes.append(f"{RED}not for sale — nobody can buy it{RESET}")
        if price is None:
            notes.append(f"{RED}no price set{RESET}")
        elif price != item["robux"]:
            notes.append(
                f"{YELLOW}priced R$ {price}, config expected R$ {item['robux']}{RESET}"
            )
        if notes:
            problems += 1

        head = f"{GREEN}ok{RESET}" if not notes else f"{YELLOW}check{RESET}"
        print(f"{label}: {head}  {name!r} by {creator}, R$ {price}")
        for note in notes:
            print(f"      {note}")

    print()
    if problems:
        print(f"{YELLOW}{problems} item(s) need attention.{RESET}")
        sys.exit(1)
    print(f"{GREEN}Everything checks out.{RESET}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    command = sys.argv[1]

    if command == "list":
        cmd_list()
    elif command == "set":
        if len(sys.argv) != 4:
            sys.exit("usage: shop.py set <key> <id>")
        cmd_set(sys.argv[2], sys.argv[3])
    elif command == "check":
        cmd_check()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
