---
name: reelql
description: Analyze any video link (YouTube, TikTok, Vimeo, media file): story, brands, products, emotional arc, key moments, transcript. Use whenever the user shares a video URL.
---

# ReelQL

ReelQL turns a video URL into one JSON document. It needs the environment variable `REELQL_API_KEY`, a personal key (testers get one by DMing @tomcupr on X). The scripts check their own keys; when one is missing they print how to get it. Pass that on to the user as it is and wait for the key. Never inspect `REELQL_API_KEY` or `TYPESAFE_API_KEY` yourself (no `echo`, `printenv`, `env`, `cat .env`, not even to test that one is set), and never write a key into a file or command line.

## Run videos

Run the script in this skill's directory, in the foreground (it finishes in a minute or two), from a scratch directory:

```sh
bash <this skill's directory>/scripts/reelql.sh "<url>" ["<url>" ...]
```

It saves each result as `reelql-1.json`, `reelql-2.json`, ... in URL order, two videos at a time, and prints `done` or `failed` with the reason for each one. A 4-minute video takes about 25 s, a 15-minute one about a minute. It needs `curl` and `jq`.

A result is large: the transcript alone can be tens of kB. Read only the parts you need with `jq`, for example:

```sh
jq '.result.analysis | {summary, advertiser, brands, products, emotional_arc, key_moments, on_screen_text}' reelql-1.json
jq '.result.video | {title, channel, platform, duration_s, stats}' reelql-1.json
jq -r '.result.speech.transcript[] | "[\(.start)] \(.speaker): \(.text)"' reelql-1.json
```

## What to tell the user

If the user asked something specific ("who is the advertiser?", "when does the logo appear?"), answer just that from the fields that hold it, with timestamps.

If they only shared a link or said "analyze this", give this brief, in this order, and skip any part the video has nothing for:

1. **What it is**: one sentence, with the platform, channel and length.
2. **Who's selling what**: the advertiser, and each product with the time it first appears.
3. **The story**: the premise and how it unfolds, in 2-3 sentences.
4. **How it should feel**: the emotional arc as a chain (curiosity → anticipation → excitement), with the moment behind each shift.
5. **Key moments**: at most 5 lines, formatted as `m:ss` then what happens.
6. **On-screen text** worth knowing (dates, prices, calls to action), and the views and likes if the platform reports them.

Keep it under about 20 lines, then offer one or two follow-ups the data can answer (the full transcript, scene by scene, the cast).

## Judge or rank videos with Jev (optional)

If the user wants a judgment rather than a description, and `TYPESAFE_API_KEY` is set, use Jev (TypeSafe's judgment model). Judgments include "is this on brief?", "rank these ads", "which is safest?" and "which one should we run?".

1. Run all the videos through `scripts/reelql.sh` in one call.
2. Pass the result files to the `scripts/jev.py` script in this skill's directory:

```sh
uv run --with typesafe-sdk python <this skill's directory>/scripts/jev.py "<the brief, in the user's words>" reelql-*.json
```

It prints a table ranked by the probability that each video is on brief, with hook, product and payoff scores (0 to 1) and the probability that the content is unsafe. Show the table, then say in one or two sentences why the top video wins and what holds back the rest, using the ReelQL fields. Jev's numbers are judgments, not measurements: say so if the user is about to act on a close call. Without `TYPESAFE_API_KEY`, judge from the ReelQL fields yourself and say that Jev would give calibrated scores.

## What the result holds

`.result` has `schema_version`, then:

- `video`: title, channel, duration_s, platform, url, upload_date, description (the caption), tags, music (TikTok sound), stats (views, likes, comments, as reported at fetch time; `null` where the platform does not give one).
- `speech.transcript[]`: `{start, end, speaker, text}`, speakers labelled `SPEAKER_00`...
- `analysis`:
  - `summary`
  - `story`: premise, tone, themes, arc
  - `characters[]`: `name_or_label`, appearance, role, first_seen_s
  - `audio`: music, sound effects, voiceover, tone
  - `advertiser`, `brands[]`, `products[]` (with each appearance's time and prominence)
  - `chapters[]`: one per 30 s, `{start_s, end_s, title, summary}`
  - `scenes[]`, `key_moments[]`
  - `emotional_arc[]`: what the viewer is meant to feel, `{t_s, emotion, intensity 1-5, cue}`
  - `on_screen_text[]`

All times are seconds from the start of the video. A person's name appears only when the title, channel, on-screen text or transcript contains it; otherwise `name_or_label` is a short description ("young girl"). `advertiser`, `brand` and `mood` are `null` when nothing in the video supports them. Report these as the video's own evidence, not as verified facts.

## Errors

- `400`: the URL was refused (private address, not http(s), a live stream, longer than 30 minutes, over 4 GB, or not a video). The reason is in `.detail`.
- `401`: missing or wrong key.
- `429`: the key already has 2 jobs queued or running, for example from another session. Wait and run again.
- `404` on a job: wrong id, older than a day, or the service restarted (jobs are kept in memory). Submit again.
- A `failed` job: `.error` says why (for example a deleted or region-blocked post).
