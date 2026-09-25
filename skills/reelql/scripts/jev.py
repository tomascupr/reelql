"""Judge ReelQL results against a brief with Jev (TypeSafe) and print a ranked table.

    uv run --with typesafe-sdk python jev.py "<brief>" reelql-*.json     # needs TYPESAFE_API_KEY

Jev reads text only, so each video goes in as the ReelQL fields a judgment needs (not the whole document).
Ranked by P(on brief), then by the mean of the three scores.
"""
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor

from typesafe_sdk import Noul, Score, TypeSafeClient

LEVELS = ["Weak", "Average", "Strong"]


def state(r):
    a, v = r["analysis"], r["video"]
    return {"title": v.get("title"), "channel": v.get("channel"), "summary": a.get("summary"), "tone": (a.get("story") or {}).get("tone"),
            "advertiser": a.get("advertiser"), "products": [p["name"] for p in a.get("products", [])],
            "opening": [m["what"] for m in a.get("key_moments", []) if m["t_s"] <= 3] or [s["action"] for s in a.get("scenes", [])[:1]],
            "emotional_arc": " -> ".join(f"{e['emotion']} ({e['intensity']})" for e in a.get("emotional_arc", [])),
            "on_screen_text": [t["text"] for t in a.get("on_screen_text", [])][:10],
            "transcript": " ".join(s["text"] for s in r["speech"]["transcript"])[:4000]}


def judge(jev, brief, r):
    def ask(q):
        return {"brief": brief, "question": q}

    a = jev.system_one(state=state(r), questions={
        "on_brief": Noul(instructions=ask("Does this video match `brief`?")),
        "hook": Score(instructions=ask("How strong is the hook in `opening`?"), criteria=LEVELS),
        "product": Score(instructions=ask("How clearly does the video show `products` in use?"), criteria=LEVELS),
        "payoff": Score(instructions=ask("How strong is the emotional payoff in `emotional_arc`?"), criteria=LEVELS),
        "unsafe": Noul(instructions="Does `transcript` or `on_screen_text` contain profanity, violence, or adult content?")})
    s = {k: a.scores[k].score / (len(LEVELS) - 1) for k in ("hook", "product", "payoff")}  # 0..1
    return {"video": f"{r['video'].get('channel')}: {r['analysis'].get('advertiser') or '-'}", "on_brief": a.nouls["on_brief"].noul,
            **s, "unsafe": a.nouls["unsafe"].noul}


if __name__ == "__main__":
    if not os.environ.get("TYPESAFE_API_KEY"):
        sys.exit("TYPESAFE_API_KEY is not set. Get a Jev key at https://console.typesafe.ai, then: export TYPESAFE_API_KEY=<your key>")
    brief, files = sys.argv[1], sys.argv[2:]
    results = [d["result"] for d in (json.load(open(f)) for f in files) if d.get("status") == "done"]  # failed jobs have no result
    with TypeSafeClient() as jev, ThreadPoolExecutor(8) as pool:
        rows = list(pool.map(lambda r: judge(jev, brief, r), results))
    rows.sort(key=lambda x: (-round(x["on_brief"], 2), -(x["hook"] + x["product"] + x["payoff"])))
    print(f"Brief: {brief}\n\n| # | Video | On brief | Hook | Product | Payoff | Unsafe |\n|---|---|---|---|---|---|---|")
    for i, x in enumerate(rows, 1):
        print(f"| {i} | {x['video']} | {x['on_brief']:.0%} | {x['hook']:.2f} | {x['product']:.2f} | {x['payoff']:.2f} | {x['unsafe']:.0%} |")
