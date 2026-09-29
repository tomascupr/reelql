# ReelQL: give your agent eyes

Agents can read, but they can't watch. Give ReelQL a public video link and get back one typed JSON document: scenes, speech, on-screen text, products and the emotional arc, each with its timestamp. It is an HTTP API with a Claude skill. Every key starts with 10 free minutes, then video costs $0.05 a minute.

- In: a public video link (YouTube, TikTok, Vimeo and anything else yt-dlp can fetch) or a direct media file
- Out: one JSON document, every field timestamped
- Length: up to 30 minutes and 4 GB a video
- Speed: about 25 seconds for a 4-minute video
- Runs on: open models on our own GPUs, with no third-party AI APIs

## A real run

Blender Studio's short Wing It! (3:58, CC BY 4.0) took 22 seconds. The unedited result is at https://reelql.com/wingit.json. An excerpt:

```json
{
  "schema_version": "1.2",
  "video": {"title": "WING IT! - Blender Open Movie", "channel": "Blender Studio", "duration_s": 238.0},
  "analysis": {
    "characters": [{"id": "c1", "name_or_label": "Grey Cat", "first_seen_s": 0}],
    "products": [{"name": "Spacesuit", "brand": null, "category": "Costume/Equipment",
                  "appearances": [{"t_s": 22.6, "how_shown": "Worn by Cat Engineer during exit scene.", "prominence": "medium"}]}],
    "emotional_arc": [{"t_s": 87.0, "emotion": "excitement", "intensity": 5, "cue": "The dramatic launch of the rocket and the subsequent freefall."}],
    "on_screen_text": [{"t_s": 232.0, "text": "Licensed as Creative Commons Attribution 4.0 © Blender Foundation - studio.blender.org/wing-it"}]
  }
}
```

- Every time is in seconds from the start of the video.
- A character gets a name only when the title, channel, on-screen text or transcript gives one; otherwise ReelQL writes a label such as "Grey Cat".
- `brand` and `advertiser` are `null` when nothing in the video supports them.
- Emotions come from a fixed list of 21, with intensity from 1 to 5, so arcs compare across videos.
- The full document also has `summary`, `story`, `audio`, `chapters` (one per 30 seconds), `scenes`, `key_moments`, a speaker-labelled `transcript` and per-step `timing`.

## What it's for

ReelQL reads what's on screen: products, logos, text and what people do.

- Brand scouting: a grocery buyer runs tens of thousands of TikToks through ReelQL to find brands worth stocking. Count the brands in each week's results; the names that keep climbing are the shortlist. A 30-second TikTok costs 2.5 cents.
- Ad review: check a cut against its brief. ReelQL turns the video into fields and Jev, TypeSafe's judgment model, answers typed questions about them with probabilities.
- Creator vetting: before sponsoring a creator, run their recent posts and read the transcript, the text on screen and what happens in each scene.
- Skip it when everything is said out loud. Lectures, podcasts and most tutorials live in their audio, and their subtitles are free.

## Get started

Get a key (10 free minutes, no account):

```sh
curl -s -X POST https://reelql.tail6c0e2d.ts.net/keys
```

Run a video and poll for the result:

```sh
API=https://reelql.tail6c0e2d.ts.net; H="X-API-Key: $REELQL_API_KEY"
curl -s -H "$H" -H 'Content-Type: application/json' $API/jobs -d '{"url": "https://www.youtube.com/watch?v=..."}'
curl -s -H "$H" $API/jobs/<id>   # queued, running, then done (with "result") or failed (with "error")
```

In Claude Code:

```sh
claude plugin marketplace add tomascupr/reelql
claude plugin install reelql@reelql
export REELQL_API_KEY=<your key>
```

On claude.ai (Team and Enterprise), upload https://github.com/tomascupr/reelql/releases/latest/download/reelql.zip under Settings → Capabilities → Skills.

## Pricing

- $0.05 per minute of video, charged by the video's length rounded up to the second, from prepaid credit. A job that fails costs nothing.
- Every new key starts with 10 free minutes. Top up $5 to $500 in whole dollars; $5 buys 100 minutes.
- People pay on a Stripe page (`POST /credits/checkout`), where Stripe adds VAT or sales tax where it applies. Agents can pay over MPP, the Machine Payments Protocol (`POST /credits`).
- `GET /balance` shows the minutes left.

## Limits

- Public videos only: nothing behind a login, and no live streams.
- Five jobs queued or running per key. Results are kept for a day.
- When many jobs are waiting, a new one gets `503` with `Retry-After`.
- ReelQL runs on a single GPU server, with no uptime promise. Jobs survive a restart of the service.
- ReelQL keeps the fetched video and the result on its server. Don't send anything you aren't allowed to share.

## Links

- Agent guide: https://reelql.com/llms.txt
- Source, skill and examples: https://github.com/tomascupr/reelql
- API description: https://reelql.tail6c0e2d.ts.net/openapi.json
- Built by Tomas Cupr: https://x.com/tomcupr
