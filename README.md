# q-kara-capture-and-deadly-blow-training-lua
 
A training Lua for **Street Fighter III: 3rd Strike** on **Fightcade 2** that teaches Q's kara Capture & Deadly Blow (b+MP kara into C&DB). Inputs scroll up a DDR-style highway with one lane for each direction and each button. After each attempt, the script reads what actually came out in the game and tells you exactly what to fix.
 
---
 
## The technique
 
Q's command grab, **Capture & Deadly Blow** (C&DB), is a half-circle back plus kick. Kara-cancelling it out of **b+MP** gives it a lot more range. The problem is that Q's **High Speed Barrage** (slaps) is quarter-circle back plus punch, so pressing MP at the end of a half-circle back normally gives you slaps.
 
The game will choose C&DB over slaps only under one exact timing:
 
> **The 1 of the final `3214` must land exactly 11 frames after the first 2 of the motion.**
> Then press **4 + MP**, and press the **kick on the very next frame**.
 
| What you did | What comes out |
|---|---|
| 1 lands on frame 10 or earlier | Slaps |
| 1 lands on frame **11** | **Kara C&DB** |
| 1 lands on frame 12 or later | Slaps |
| Frame 11, but kick on the **same** frame as MP | Plain C&DB (no kara, no extra range) |
| Frame 11, but kick **2+ frames** after MP | b+MP only |
 
Only the frame-11 timing matters. The motion can take any shape and any speed, as long as it starts on a 2, ends in `3214`, and the 1 lands on frame 11. Other notes:
- The shortest motion C&DB accepts is `3214`. The "6, down, 4" shortcut does **not** work for Q's C&DB.
- Q has **no EX C&DB**. Pressing two kicks gives the MK version.
<details>
<summary>Why this works</summary>
3rd Strike gives each step of a special-move motion a 10-frame window, and the timer is not extended if you press the same direction again. The slaps command starts counting at your first 2:
 
- If the 1 arrives within 10 frames, slaps is still live and wins.
- On frame 11, the slaps window has just expired and restarted, and there is no fresh 2 for it to start from, so only C&DB is left.
- On frame 12 or later, the second 2 of your half-circle back is still held when slaps restarts. It counts as a new 2, so slaps wins again.
The rule was measured by having a script perform the inputs itself, frame-perfectly, across about 200 variations. Every motion shape tested at 10, 11 and 12 frames followed it (27 out of 27).
</details>
---
 
## Requirements
 
- **Fightcade 2** with **Street Fighter III: 3rd Strike** (`sfiii3nr1`)
- A stick or pad mapped in Fightcade's FBNeo emulator
- Your **Coin** button mapped (it opens the trainer menu)
---
 
## Installation
 
1. Download **`q_kara_capture_and_deadly_blow_training.lua`** from this repository.
2. Save it anywhere you like. A `lua` folder inside your Fightcade folder keeps things tidy.
---
 
## Running it
 
1. Launch 3rd Strike in Fightcade (offline/test game is fine) and start a match with **Q** on either side, against any character.
2. In the emulator's menu bar, open **Game → Lua Scripting → New Lua Script Window**.
3. Click **Browse**, select `q_kara_capture_and_deadly_blow_training.lua`, then click **Run**.
While the script runs:
- The **round timer stays at 99** and **both life bars stay full**, so the round never ends.
- The script **finds Q automatically**, whether Q is P1 or P2.
To stop the script, click **Stop** in the Lua Script Window.
 
> If you also use another training Lua (such as Grouflon's 3rd Strike training mode), run only one at a time. Two scripts that both control inputs and draw overlays will interfere with each other.
 
---
 
## What's on screen
 
### Highway (left)
 
Eleven lanes:
 
```
 4   1   2   3   6  | LP  MP  HP  LK  MK  HK
```
 
- Direction lanes follow your **stick's real directions**, in left-to-right stick order. On the P2 side (Q facing left), back is the stick's 6, so the chart is mirrored and notes sweep right to left, the same way your stick moves.
- The chart sits still with its first note on the line and shows **"Ready - start with X"**. It starts scrolling the moment you press that direction, so every note is timed from **your** start.
- The **green note** is the 1 that has to land on frame 11.
- The box for each lane on the line **lights up** while you hold that direction or button.
- Notes you hit disappear and flash **PER** (perfect, within 1 frame), **EAR** (early) or **LAT** (late). Notes you miss turn red and flash **MIS**.
- Once the chart finishes, it resets and waits for your next start.
### Frame clock (top middle)
 
A row of cells that starts filling at your first 2. **Cell 11 is outlined in white**, and your 1 should land on it. Cells before 11 fill cyan and cells after 11 fill red.
 
### Stats (top right)
 
- The current chart and kick, plus its notation
- Kara successes and total attempts, with a success percentage
- Current streak and best streak
- A bar chart of **which frame your 1 landed on** over your last 20 attempts (green is frame 11)
### Verdict (middle)
 
Shows what the game actually did and one line on why:
 
| Verdict | Example message |
|---|---|
| **KARA C&DB!** | Frame 11. That's it. |
| **SLAPS** | 1 landed on frame 12: LATE by 1 |
| **SLAPS** | 1 landed on frame 9: EARLY by 2 |
| **b+MP only** | Frame 11! Kick 2 frames after MP - needs exactly 1 |
| **C&DB (no kara)** | Frame 11! MP+kick together - press kick 1f AFTER MP |
| **Nothing / other** | No 3-2-1 after the 2. End the motion in 3214. |
 
### Review strip (bottom)
 
Your last attempt next to the chart, **frame by frame from −4 to 16**, counting from your first 2:
- **TARGET** row: what the chart wanted
- **YOU** row: what you actually input. Any frame that differs from the chart is red.
- Button presses are marked with the button's first letter. Frame 11 is outlined in green.
---
 
## Menu
 
Press **Coin** (on Q's side) to open or close the menu. The game ignores your inputs while the menu is open.
 
| Control | Action |
|---|---|
| Up / Down | Select an item |
| Left / Right | Change a setting |
| LP | Run an action |
| Coin | Close the menu |
 
| Item | Options |
|---|---|
| **Q is** | Auto (default, shows which side it found), P1 or P2. Pick a side yourself for Q mirror matches. |
| **Chart** | Which motion to practice (see below) |
| **Kick** | LK, MK or **HK** (default) |
| **Mode** | **Real-time** (the scrolling highway) or **Step** |
| **Scroll speed** | 2, 3 or 4 pixels per frame |
| **Set home distance here** | Saves the current distance between Q and the dummy |
| **Walk Q back to home** | Q walks back to the saved distance by itself |
| **Reset stats** | Clears all counts, streaks and the bar chart |
| **Close menu** | Closes the menu |
 
---
 
## Charts
 
All charts teach the same frame-11 timing with a different motion. Notation is numpad, facing right; the trainer mirrors it automatically on the P2 side.
 
| Chart | Notation | Notes |
|---|---|---|
| **HCF > HCB** | `41236 3214` 4+MP~K | The standard method: a half-circle forward rolled straight into the half-circle back |
| **12321 > 4** | `12321` 4+MP~K | Stretch the middle of the motion so the final 1 lands on frame 11 |
| **2 3 2 1 4** | `23214` 4+MP~K | Start on down, roll to 3, come back through 2 and 1 |
 
`MP~K` means press MP, then the kick on the very next frame.
 
### Step mode
 
Step mode shows the chart as a row of boxes and moves on as soon as you hit the next input, with **no timing**. Use it to learn the shape of the motion, then switch to Real-time mode to learn the timing.
 
---
 
## Log file
 
Each attempt is added to **`q_kara_capture_and_deadly_blow_training_log.txt`**, in the same folder as the script:
 
```
f40512 chart=HCF > HCB kick=HK D=11 gap=1 result=b+MP>CDB-H
f40610 chart=HCF > HCB kick=HK D=12 gap=1 result=SLAP-M
```
 
- `D`: the frame your 1 landed on, counting from the first 2 (target: 11)
- `gap`: frames between MP and the kick (target: 1)
- `result`: what the game did, in order. Unrecognized moves are written as 8-digit hex IDs.
---
 
## Practice tips
 
1. **Start in Step mode** until the motion is automatic, then switch to Real-time.
2. **Watch the bar chart.** If most of your attempts land on 12, you're slightly slow, so speed up the middle of the motion. If they land on 9 or 10, add a little hold in the middle.
3. **Fix the kick separately.** If the verdict says frame 11 but "b+MP only," your motion is right and only the MP→kick gap needs work. Practice it as a fast roll from MP to the kick.
4. **Use the review strip** to find exactly which direction you held too long or too short.
5. Keep the dummy **far away** while drilling. Whiffed C&DBs recover faster, so you get more reps.
---
 
## Known limitations
 
- The trainer recognizes moves by their whiffed action IDs. A C&DB that actually **grabs** the opponent may show up as an extra hex ID in the result. The verdict still counts the kara correctly.
- Charts for hiding the motion inside normals (st.MK, cr.MK, j.MK) are planned but not included yet.
- Only tested on `sfiii3nr1` (the Fightcade 2 version). Other ROM versions may use different memory addresses.
---
 
## Credits
 
- Memory addresses (player data, character ID, timer, life) come from **Grouflon's [3rd_training_lua](https://github.com/Grouflon/3rd_training_lua)**.
- The frame rules for special-move input in 3rd Strike are based on research by the Japanese 3rd Strike data site **Game Restaurant**.
- The neutral b+MP kara C&DB was discovered by players in the UAE around 2014 and popularized by rKf and Goldriver.
 