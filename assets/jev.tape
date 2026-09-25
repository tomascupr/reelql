# Records assets/demo.gif: vhs assets/demo.tape (needs REELQL_API_KEY, TYPESAFE_API_KEY and a logged-in Claude Code), then trim the idle tail:
# ffmpeg -t 40 -i assets/demo.gif -vf "split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none" t.gif && gifsicle -O3 t.gif -o assets/demo.gif (jev.gif: trim to where the answer ends)
Output assets/jev.gif
Set Shell zsh
Set FontSize 18
Set Width 1300
Set Height 980
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms
Set PlaybackSpeed 2.5

Hide
Type "mkdir -p ~/reelql-demo; cd ~/reelql-demo; clear; claude --setting-sources project --strict-mcp-config --plugin-dir ~/Repos/reelql --allowedTools Bash --model sonnet" Enter
Wait+Screen@30s /for agents/
Sleep 1s
Show

Sleep 1s
Type "rank these ads for a family-friendly brief that shows the product in use: https://www.tiktok.com/@starbucks/video/7685379388979875085 https://www.tiktok.com/@samsung/video/7683468749499911431 https://www.tiktok.com/@psg/video/7687260979759058178 https://www.tiktok.com/@fifaworldcup/video/7664663334871944470 https://www.tiktok.com/@natgeo/video/7686521463628664095"
Sleep 500ms
Enter
Wait+Screen@20s /esc to interrupt/
Sleep 140s
Hide
Ctrl+C
Ctrl+C
