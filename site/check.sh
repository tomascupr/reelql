#!/usr/bin/env bash
# What reelql.com serves to agents, checked over HTTP: bash site/check.sh [base URL]   (default https://reelql.com)
# vercel.json uses legacy `routes` on purpose: `rewrites` run after the filesystem, so / would never reach /index.md,
# and they can't answer 404. ponytail: the Accept match is a substring, so q-values are ignored (`text/markdown;q=0`
# still gets Markdown); Routing Middleware could parse them if that ever matters.
set -u
B=${1:-https://reelql.com}; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT; fails=0
ok() { if [ $? = 0 ]; then echo "ok    $1"; else echo "FAIL  $1"; fails=$((fails + 1)); fi; }  # reports the check just run
get() { IFS=$'\t' read -r s ct vary link < <(curl -sSL --max-time 10 -o "$T/body" -H "Accept: $1" \
  -w '%{http_code}\t%{content_type}\t%header{vary}\t%header{link}\n' "$B$2"); }  # $1 Accept, $2 path
py() { python3 - "$T/body"; }  # a check in Python (from a heredoc) on the last body
MD=text/markdown; BROWSER='text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'

get $MD /
[ "$s" = 200 ]; ok "/ as Markdown: 200"
[[ $ct == text/markdown* ]]; ok "/ as Markdown: text/markdown"
[[ $vary == *Accept* ]]; ok "/ as Markdown: Vary: Accept"
[[ $link == *'</llms.txt>; rel="describedby"'* ]]; ok "/ as Markdown: Link to llms.txt"
head -1 "$T/body" | grep -q '^# ReelQL'; ok "/ as Markdown: body is Markdown"

get "$BROWSER" /
[ "$s" = 200 ] && [[ $ct == text/html* ]] && grep -qi '<!doctype html>' "$T/body"; ok "/ for a browser: HTML"
[[ $vary == *Accept* ]]; ok "/ for a browser: Vary: Accept"
py <<'PY'; ok "/ HTML has SoftwareApplication JSON-LD"
import json, re, sys
d = json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>', open(sys.argv[1]).read(), re.S).group(1))
assert d["@type"] == "SoftwareApplication" and all(d.get(k) for k in ("name", "url", "description", "offers"))
PY
py > "$T/links" <<'PY'
import sys
from html.parser import HTMLParser
class Links(HTMLParser):
    def handle_starttag(self, tag, a):
        a = dict(a)
        if tag == "link" and (a.get("rel"), a.get("type")) in (("alternate", "text/markdown"), ("describedby", None)):
            print(a["rel"], a["href"])
Links().feed(open(sys.argv[1]).read())
PY
alt=$(awk '$1 == "alternate" {print $2}' "$T/links"); desc=$(awk '$1 == "describedby" {print $2}' "$T/links")
get '*/*' "${alt:-/none}"; [ "$s" = 200 ] && [[ $ct == text/markdown* ]]; ok "/ HTML links its Markdown version (${alt:-none})"
get '*/*' "${desc:-/none}"; [ "$s" = 200 ]; ok "/ HTML links its llms.txt (${desc:-none})"

get $MD /no-such-page-for-check
[ "$s" = 404 ]; ok "404 as Markdown: 404"
[[ $ct == text/markdown* ]]; ok "404 as Markdown: text/markdown"
grep -q 'llms.txt' "$T/body"; ok "404 as Markdown: explains and links"
get "$BROWSER" /no-such-page-for-check
[ "$s" = 404 ]; ok "404 for a browser: 404"

get '*/*' /llms.txt
[ "$s" = 200 ]; ok "llms.txt: 200"
py <<'PY'; ok "llms.txt: an H1, a blockquote, then only H2 sections"
import sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if l.strip()]
assert lines[0].startswith("# ") and lines[1].startswith("> ")
assert next(l for l in lines[1:] if l.startswith("#")).startswith("## ")
PY
grep -qi 'when to use' "$T/body"; ok "llms.txt: says when to use it"
! awk '/^## /{f=1; next} f && /^- / && !/^- \[[^]]+\]\([^)]+\)/' "$T/body" | grep -q .; ok "llms.txt: file lists are links"
for u in $(awk '/^## /{f=1} f' "$T/body" | grep -o '](https://[^)]*)' | tr -d '()]'); do
  [ "$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "$u")" = 200 ]; ok "llms.txt link answers 200: $u"
done

get '*/*' /sitemap.xml
[ "$s" = 200 ] && py <<'PY'; ok "sitemap.xml: valid, lists / with lastmod"
import sys, xml.etree.ElementTree as E
n = "{http://www.sitemaps.org/schemas/sitemap/0.9}"; r = E.parse(sys.argv[1]).getroot()
assert r.tag == n + "urlset" and ["https://reelql.com/"] == [u.findtext(n + "loc") for u in r] and all(u.findtext(n + "lastmod") for u in r)
PY
get '*/*' /robots.txt
grep -q '^Sitemap: https://reelql.com/sitemap.xml' "$T/body"; ok "robots.txt: points at the sitemap"

# The price and limits are written by hand in each of these; they have to agree
for u in "$B/" "$B/index.md" "$B/llms.txt" https://raw.githubusercontent.com/tomascupr/reelql/main/{README.md,skills/reelql/SKILL.md}; do
  curl -sSL --max-time 10 -o "$T/doc" "$u"
  miss=$(for f in '\$0\.05' '(five|5) (jobs|videos)' '30 minutes' '4 GB'; do grep -qiE "$f" "$T/doc" || printf '%s ' "$f"; done)
  [ -z "$miss" ]; ok "price and limits stated in $u${miss:+ (missing: $miss)}"
done

[ $fails = 0 ] && echo "all checks passed" || { echo "$fails failed"; exit 1; }
