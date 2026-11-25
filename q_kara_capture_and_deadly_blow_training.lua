-- q_kara_capture_and_deadly_blow_training.lua  (v1.3: lanes and labels follow the real stick direction on either side; white note labels)
-- Q kara Capture & Deadly Blow trainer for SF3: 3rd Strike (sfiii3nr1)
-- Fightcade 2 / FBNeo. Standalone.
--
-- THE RULE (measured in Phase 0, 27/27 trials):
--   The 1 of the final 3214 must land EXACTLY 11 frames after the first 2
--   of the motion, then 4+MP, then the kick on the very next frame.
--   1 on frame 10 or earlier -> slaps. Frame 12 or later -> slaps.
--   Kick same frame as MP -> plain C&DB (no kara). Kick 2+ frames late -> b+MP only.
--
-- Q can be P1 or P2: the script finds Q automatically (menu: "Q is").
--
-- CONTROLS
--   Coin on Q's side ("insert coin") ... open / close the menu
--   In the menu: Up/Down select, Left/Right change, LP activate, Coin close
--
-- HOW TO RUN
--   Start a Q (P1) vs anyone match, then
--   Game > Lua Scripting > New Lua Script Window > Browse > Run.
--   Time and life are held full while the script runs.
--
-- Addresses from Grouflon/3rd_training_lua; move IDs measured in Phase 0.

-- =====================================================================
-- constants
-- =====================================================================

local P1_BASE     = 0x02068C6C
local P2_BASE     = 0x02069104
local FRAME_ADDR  = 0x02007F00
local TIMER_ADDR  = 0x02011377
local LIFE_OFFSET = 0x9F
local CHAR_OFFSET = 0x3C0
local Q_CHAR_ID   = 18
local MAX_LIFE    = 160

local TARGET_D    = 11     -- frames from first 2 to the HCB's 1
local MOTION_TIMEOUT = 30  -- frames before an unfinished motion is dropped
local OBSERVE_FRAMES = 25  -- frames to watch for the game's result after the 1

local BUTTONS = {
  { label = "LP", key = "Weak Punch" },
  { label = "MP", key = "Medium Punch" },
  { label = "HP", key = "Strong Punch" },
  { label = "LK", key = "Weak Kick" },
  { label = "MK", key = "Medium Kick" },
  { label = "HK", key = "Strong Kick" },
}
local IS_KICK = { LK = true, MK = true, HK = true }

local ACT = {
  SLAP_L = 0x00050024, SLAP_M = 0x00050025, SLAP_H = 0x00050026,
  CDB_L  = 0x00050028, CDB_M  = 0x00050029, CDB_H  = 0x0005002A,
  BMP    = 0x00040005,
}
local ACT_NAMES = {
  [ACT.SLAP_L] = "SLAP-L", [ACT.SLAP_M] = "SLAP-M", [ACT.SLAP_H] = "SLAP-H",
  [ACT.CDB_L]  = "CDB-L",  [ACT.CDB_M]  = "CDB-M",  [ACT.CDB_H]  = "CDB-H",
  [ACT.BMP]    = "b+MP",
  [0x00040090] = "throw", [0x00020005] = "throw-grab",
}
local function is_cdb(a) return a == ACT.CDB_L or a == ACT.CDB_M or a == ACT.CDB_H end
local function is_slap(a) return a == ACT.SLAP_L or a == ACT.SLAP_M or a == ACT.SLAP_H end

-- colors 0xRRGGBBAA
local C = {
  white = 0xFFFFFFFF, grey = 0xA0A0A0FF, dark = 0x000000C0, black = 0x000000FF,
  yellow = 0xFFE040FF, green = 0x40FF60FF, red = 0xFF5050FF, orange = 0xFFA040FF,
  cyan = 0x40E0FFFF, blue = 0x4080FFFF, purple = 0xC080FFFF, clear = 0x00000000,
}
local DIR_COLOR = {
  [1] = C.purple, [2] = C.cyan, [3] = C.purple, [4] = C.orange,
  [5] = C.grey,   [6] = C.yellow, [7] = C.grey, [8] = C.grey, [9] = C.grey,
}
local BTN_COLOR = { LP = C.blue, MP = C.blue, HP = C.blue, LK = C.red, MK = C.red, HK = C.red }

local S  -- trainer state (filled in below)

-- The game logic works in facing-relative numpad (4 = back). The display
-- uses the stick's real directions: when Q faces left (P2 side), back is
-- the stick's 6, so everything shown on screen is mirrored.
local MIRROR = { [1] = 3, [2] = 2, [3] = 1, [4] = 6, [5] = 5, [6] = 4, [7] = 9, [8] = 8, [9] = 7 }
local function facing_right_now() return S == nil or S.facing_right end
local function disp(d) if facing_right_now() then return d end return MIRROR[d] end
local function disp_str(str)
  if facing_right_now() then return str end
  return (str:gsub("%d", function(c) return tostring(MIRROR[tonumber(c)]) end))
end
local function dim(col)
  local r = math.floor(col / 0x1000000) % 0x100
  local g = math.floor(col / 0x10000) % 0x100
  local b = math.floor(col / 0x100) % 0x100
  return math.floor(r * 0.35) * 0x1000000 + math.floor(g * 0.35) * 0x10000 + math.floor(b * 0.35) * 0x100 + 0xFF
end

-- =====================================================================
-- charts  (t = frame relative to the first 2; KICK = the chosen kick)
-- =====================================================================

local CHARTS = {
  { name = "HCF > HCB", notation = "41236 3214 MP~K",
    dirs = { {4,-4,2}, {1,-2,2}, {2,0,2}, {3,2,2}, {6,4,3}, {3,7,2}, {2,9,2}, {1,11,2}, {4,13,4} },
    btns = { {"MP",13,3}, {"KICK",14,3} } },
  { name = "12321 > 4", notation = "12321 4 MP~K",
    dirs = { {1,-2,2}, {2,0,4}, {3,4,4}, {2,8,3}, {1,11,2}, {4,13,4} },
    btns = { {"MP",13,3}, {"KICK",14,3} } },
  { name = "2 3 2 1 4", notation = "23214 MP~K",
    dirs = { {2,0,5}, {3,5,3}, {2,8,3}, {1,11,2}, {4,13,4} },
    btns = { {"MP",13,3}, {"KICK",14,3} } },
}
local KICKS = { "LK", "MK", "HK" }
local MODES = { "Real-time", "Step" }
local SIDES = { "Auto", "P1", "P2" }
local SPEEDS = { 2, 3, 4 }

local cfg = { chart = 1, kick = 3, mode = 1, speed = 2, side = 1 }  -- HK C&DB by default

local function chart() return CHARTS[cfg.chart] end
local function kick_label() return KICKS[cfg.kick] end
local function btn_label(b) return b == "KICK" and kick_label() or b end

-- target direction at frame offset f (5 = neutral)
local function target_dir(f)
  for _, d in ipairs(chart().dirs) do
    if f >= d[2] and f < d[2] + d[3] then return d[1] end
  end
  return 5
end
local function target_btn_press(f)
  local out = {}
  for _, b in ipairs(chart().btns) do
    if b[2] == f then table.insert(out, btn_label(b[1])) end
  end
  return out
end

-- =====================================================================
-- log file (next to this script)
-- =====================================================================

local function script_dir()
  local info = debug and debug.getinfo and debug.getinfo(1, "S")
  if info and info.source and info.source:sub(1, 1) == "@" then
    local dir = info.source:sub(2):match("^(.*[/\\])")
    if dir then return dir end
  end
  return ""
end
local LOG_PATH = script_dir() .. "q_kara_capture_and_deadly_blow_training_log.txt"
local log_file = io.open(LOG_PATH, "a")
local function log(line)
  print(line)
  if log_file then log_file:write(line, "\n"); log_file:flush() end
end

-- =====================================================================
-- state
-- =====================================================================

S = {
  now = 0, act = 0, qx = 0, ox = 0, pfx = "P1 ", side = 1, facing_right = true,
  dir = 5, prev_dir = 5, held = {}, prev_held = {}, pressed = {},
  history = {},            -- { f, dir, pressed = {labels} }
  prev_raw = {},
  menu_open = false, menu_sel = 1,
  walking_home = false, walk_frames = 0, home = nil,
  motion = nil,            -- current attempt being tracked
  last = nil,              -- last finished attempt (for display)
  stats = { attempts = 0, karas = 0, streak = 0, best = 0, recent = {} },
  judge = {},              -- lane -> { text, color, until }
  run = nil,                -- current highway run
  step_index = 1, step_done_until = 0,
}

-- =====================================================================
-- input helpers
-- =====================================================================

local function numpad(input, facing_right)
  local up, down = input[S.pfx .. "Up"] == true, input[S.pfx .. "Down"] == true
  local left, right = input[S.pfx .. "Left"] == true, input[S.pfx .. "Right"] == true
  local fwd, back
  if facing_right then fwd, back = right, left else fwd, back = left, right end
  local v = down and 1 or (up and 3 or 2)
  local h = back and 1 or (fwd and 3 or 2)
  if fwd and back then h = 2 end
  if up and down then v = 2 end
  return (v - 1) * 3 + h
end

local function clear_p1(input)
  for _, k in ipairs({ "Up", "Down", "Left", "Right", "Start", "Coin" }) do input[S.pfx .. k] = false end
  for _, b in ipairs(BUTTONS) do input[S.pfx .. b.key] = false end
end

local function set_dir(input, d, facing_right)
  if d <= 3 then input[S.pfx .. "Down"] = true end
  if d >= 7 then input[S.pfx .. "Up"] = true end
  local col = (d - 1) % 3
  if col == 0 then input[facing_right and S.pfx .. "Left" or S.pfx .. "Right"] = true end
  if col == 2 then input[facing_right and S.pfx .. "Right" or S.pfx .. "Left"] = true end
end

local function edge(input, key) return input[key] == true and S.prev_raw[key] ~= true end

-- =====================================================================
-- menu
-- =====================================================================

local MENU = {
  { label = "Q is",   get = function()
      if cfg.side == 1 then return "Auto (" .. (S.side == 3 and "P2" or "P1") .. ")" end
      return SIDES[cfg.side] end,
    change = function(d) cfg.side = (cfg.side - 1 + d) % #SIDES + 1 end },
  { label = "Chart",  get = function() return chart().name end,
    change = function(d) cfg.chart = (cfg.chart - 1 + d) % #CHARTS + 1; S.step_index = 1 end },
  { label = "Kick",   get = function() return kick_label() end,
    change = function(d) cfg.kick = (cfg.kick - 1 + d) % #KICKS + 1 end },
  { label = "Mode",   get = function() return MODES[cfg.mode] end,
    change = function(d) cfg.mode = (cfg.mode - 1 + d) % #MODES + 1; S.step_index = 1 end },
  { label = "Scroll speed", get = function() return tostring(SPEEDS[cfg.speed]) end,
    change = function(d) cfg.speed = (cfg.speed - 1 + d) % #SPEEDS + 1 end },
  { label = "Set home distance here", action = function()
      S.home = math.abs(S.ox - S.qx); S.menu_open = false end },
  { label = "Walk Q back to home", action = function()
      S.walking_home, S.walk_frames, S.menu_open = true, 0, false end },
  { label = "Reset stats", action = function()
      S.stats = { attempts = 0, karas = 0, streak = 0, best = 0, recent = {} }; S.last = nil end },
  { label = "Close menu", action = function() S.menu_open = false end },
}

local function update_menu(input)
  if edge(input, S.pfx .. "Up") then S.menu_sel = (S.menu_sel - 2) % #MENU + 1 end
  if edge(input, S.pfx .. "Down") then S.menu_sel = S.menu_sel % #MENU + 1 end
  local item = MENU[S.menu_sel]
  if item.change then
    if edge(input, S.pfx .. "Left") then item.change(-1) end
    if edge(input, S.pfx .. "Right") then item.change(1) end
  end
  if item.action and edge(input, S.pfx .. "Weak Punch") then item.action() end
end

-- =====================================================================
-- attempt tracking (mirrors how the game arms the slaps command)
-- =====================================================================

local function start_motion()
  S.motion = { start = S.now, left2 = false, landed = false, D = nil,
               mp = nil, kick = nil, kick_label = nil, chain = {}, last_act = nil,
               observe_until = nil }
end

local function classify(m)
  local i_bmp, i_cdb, i_slap, cdb_act
  for i, c in ipairs(m.chain) do
    if c == ACT.BMP and not i_bmp then i_bmp = i end
    if is_cdb(c) and not i_cdb then i_cdb, cdb_act = i, c end
    if is_slap(c) and not i_slap then i_slap = i end
  end
  local gap = (m.mp and m.kick) and (m.kick - m.mp) or nil
  local r = { gap = gap }
  if i_bmp and i_cdb and i_bmp < i_cdb then
    r.kara, r.title, r.color = true, "KARA C&DB!", C.green
    r.detail = ACT_NAMES[cdb_act] .. " out of b+MP"
  elseif i_slap then
    r.title, r.color = "SLAPS", C.red
  elseif i_cdb then
    r.title, r.color = "C&DB (no kara)", C.orange
  elseif i_bmp then
    r.title, r.color = "b+MP only", C.orange
  else
    r.title, r.color = (#m.chain > 0) and "Other move" or "Nothing came out", C.grey
  end

  -- diagnosis, most important first
  local D = m.D
  if r.kara then
    r.tip = "Frame 11. That's it."
  elseif not D then
    r.tip = "No 3-2-1 after the 2. End the motion in 3214."
  elseif D < TARGET_D then
    r.tip = string.format("1 landed on frame %d: EARLY by %d", D, TARGET_D - D)
  elseif D > TARGET_D then
    r.tip = string.format("1 landed on frame %d: LATE by %d", D, D - TARGET_D)
  elseif i_cdb and not i_bmp then
    r.tip = "Frame 11! MP+kick together - press kick 1f AFTER MP"
  elseif not m.kick then
    r.tip = "Frame 11! No kick pressed after MP"
  elseif gap and gap >= 2 then
    r.tip = string.format("Frame 11! Kick %d frames after MP - needs exactly 1", gap)
  elseif gap and gap < 0 then
    r.tip = "Frame 11! Kick came before MP - press MP first"
  else
    r.tip = "Frame 11 - check the review strip"
  end
  return r
end

local function snapshot_history(start)
  local snap = {}
  for _, h in ipairs(S.history) do
    if h.f >= start - 4 and h.f <= start + 16 then snap[h.f - start] = h end
  end
  return snap
end

local function finish_motion()
  local m = S.motion
  S.motion = nil
  local r = classify(m)
  local st = S.stats
  st.attempts = st.attempts + 1
  if r.kara then
    st.karas = st.karas + 1; st.streak = st.streak + 1
    if st.streak > st.best then st.best = st.streak end
  else
    st.streak = 0
  end
  if m.D then
    table.insert(st.recent, m.D)
    while #st.recent > 20 do table.remove(st.recent, 1) end
  end
  S.last = { r = r, D = m.D, gap = r.gap, review = snapshot_history(m.start),
             chart = cfg.chart, until_f = S.now + 600 }

  local names = {}
  for _, c in ipairs(m.chain) do table.insert(names, ACT_NAMES[c] or string.format("%08X", c)) end
  log(string.format("f%d chart=%s kick=%s D=%s gap=%s result=%s",
    S.now, chart().name, kick_label(), tostring(m.D), tostring(r.gap),
    #names > 0 and table.concat(names, ">") or "none"))
end

local function update_motion()
  local fresh = S.dir ~= S.prev_dir
  local m = S.motion

  if not m then
    if fresh and S.dir == 2 then start_motion() end
    return
  end

  -- Before leaving 2: the game re-arms every 11 frames while 2 is held,
  -- so the clock restarts too.
  if not m.left2 then
    if S.dir ~= 2 then
      m.left2 = true
    elseif S.now - m.start >= TARGET_D then
      m.start = S.now
    end
  end

  if m.left2 and not m.landed and fresh and S.dir == 1 then
    m.landed, m.D, m.observe_until = true, S.now - m.start, S.now + OBSERVE_FRAMES
  end

  for _, lbl in ipairs(S.pressed) do
    if lbl == "MP" and not m.mp then m.mp = S.now end
    if IS_KICK[lbl] and not m.kick then m.kick, m.kick_label = S.now, lbl end
  end

  if S.act >= 0x00020000 and S.act ~= m.last_act then table.insert(m.chain, S.act) end
  m.last_act = S.act

  if m.landed then
    if S.now >= m.observe_until then
      if #m.chain > 0 or m.mp or m.kick then finish_motion() else S.motion = nil end
    end
  elseif S.now - m.start > MOTION_TIMEOUT then
    if #m.chain > 0 and (m.mp or m.kick) then finish_motion() else S.motion = nil end
  end
end

-- =====================================================================
-- highway (real-time) judging and step mode
-- =====================================================================

-- The chart sits parked with its first note on the line until you make
-- the chart's first direction input. That input starts the run: the chart
-- scrolls from there in real time, and every note is judged against it.

local HIT_WINDOW = 6     -- frames either side of a note that still count as a hit
local RUN_TAIL = 30      -- frames the run keeps going after the last note

-- every note of the current chart as { id, lane, t, len, label, color }
local LANE_OF_DIR = { [4] = "4", [1] = "1", [2] = "2", [3] = "3", [6] = "6" }

local function chart_notes()
  local notes = {}
  for i, d in ipairs(chart().dirs) do
    table.insert(notes, { id = "d" .. i, lane = LANE_OF_DIR[disp(d[1])], t = d[2], len = d[3],
      label = tostring(disp(d[1])), color = (d[2] == TARGET_D) and C.green or DIR_COLOR[d[1]] })
  end
  for i, b in ipairs(chart().btns) do
    local lbl = btn_label(b[1])
    table.insert(notes, { id = "b" .. i, lane = lbl, t = b[2], len = b[3],
      label = lbl:sub(1, 1), color = BTN_COLOR[lbl] })
  end
  return notes
end

local function chart_span()
  local first, first_dir, last = nil, nil, nil
  for _, d in ipairs(chart().dirs) do
    if not first or d[2] < first then first, first_dir = d[2], d[1] end
    if not last or d[2] + d[3] > last then last = d[2] + d[3] end
  end
  for _, b in ipairs(chart().btns) do
    if b[2] + b[3] > last then last = b[2] + b[3] end
  end
  return first, first_dir, last
end

-- chart time: frame of the chart (0 = the first 2) that is on the line now
local function chart_time()
  if S.run then return S.now - S.run.origin end
  local first = chart_span()
  return first
end

local function show_judgment(lane, text, col)
  S.judge[lane] = { text = text, color = col, until_f = S.now + 20 }
end

local function judge_input(lane)
  if not S.run then return end
  local ct = chart_time()
  local best, best_d
  for _, n in ipairs(chart_notes()) do
    if n.lane == lane and not S.run.hits[n.id] then
      local d = ct - n.t
      if math.abs(d) <= HIT_WINDOW and (not best or math.abs(d) < math.abs(best_d)) then
        best, best_d = n, d
      end
    end
  end
  if not best then return end
  local text, col
  if math.abs(best_d) <= 1 then text, col = "PERFECT", C.green
  elseif math.abs(best_d) <= 3 then text, col = (best_d < 0) and "EARLY" or "LATE", C.yellow
  else text, col = (best_d < 0) and "EARLY" or "LATE", C.orange end
  S.run.hits[best.id] = { text = text, d = best_d }
  show_judgment(lane, text, col)
end

local function update_run()
  local first, first_dir, last = chart_span()
  local fresh_dir = S.dir ~= S.prev_dir

  if not S.run then
    -- start on a fresh press of the chart's first direction
    if fresh_dir and S.dir == first_dir then
      S.run = { origin = S.now - first, hits = {}, end_f = S.now + (last - first) + RUN_TAIL }
      judge_input(LANE_OF_DIR[disp(S.dir)])
    end
    return
  end

  if fresh_dir and LANE_OF_DIR[disp(S.dir)] then judge_input(LANE_OF_DIR[disp(S.dir)]) end
  for _, lbl in ipairs(S.pressed) do judge_input(lbl) end

  -- anything that went past the line unhit is a miss
  local ct = chart_time()
  for _, n in ipairs(chart_notes()) do
    if not S.run.hits[n.id] and ct - n.t > HIT_WINDOW then
      S.run.hits[n.id] = { text = "MISS" }
      show_judgment(n.lane, "MISS", C.red)
    end
  end

  if S.now >= S.run.end_f then S.run = nil end
end

local function step_list()
  -- collapsed sequence of what to press, in order
  local seq = {}
  local items = {}
  for _, d in ipairs(chart().dirs) do table.insert(items, { t = d[2], kind = "dir", v = d[1] }) end
  for _, b in ipairs(chart().btns) do table.insert(items, { t = b[2], kind = "btn", v = btn_label(b[1]) }) end
  table.sort(items, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.kind == "dir"
  end)
  for _, it in ipairs(items) do table.insert(seq, it) end
  return seq
end

local function update_step_mode()
  local seq = step_list()
  if S.step_index > #seq then
    if S.now >= S.step_done_until then S.step_index = 1 end
    return
  end
  local want = seq[S.step_index]
  local ok = false
  if want.kind == "dir" then
    ok = (S.dir == want.v) and (S.dir ~= S.prev_dir)   -- a fresh move into that direction
  else
    for _, lbl in ipairs(S.pressed) do if lbl == want.v then ok = true end end
  end
  if ok then
    S.step_index = S.step_index + 1
    if S.step_index > #seq then S.step_done_until = S.now + 60 end
  end
end

-- =====================================================================
-- per frame
-- =====================================================================

local function before_frame()
  memory.writebyte(TIMER_ADDR, 100)
  memory.writebyte(P1_BASE + LIFE_OFFSET, MAX_LIFE)
  memory.writebyte(P2_BASE + LIFE_OFFSET, MAX_LIFE)

  S.now = memory.readdword(FRAME_ADDR)
  -- which side is Q on? (menu: Auto / P1 / P2)
  local side = cfg.side
  if side == 1 then
    if memory.readword(P1_BASE + CHAR_OFFSET) == Q_CHAR_ID then side = 2
    elseif memory.readword(P2_BASE + CHAR_OFFSET) == Q_CHAR_ID then side = 3
    else side = 2 end
  end
  local q_base, o_base = P1_BASE, P2_BASE
  if side == 3 then q_base, o_base = P2_BASE, P1_BASE end
  if S.side ~= side then S.motion, S.run, S.home = nil, nil, nil end
  S.side = side
  S.pfx = (side == 3) and "P2 " or "P1 "

  S.act = memory.readdword(q_base + 0xAC)
  S.qx = memory.readwordsigned(q_base + 0x64)
  S.ox = memory.readwordsigned(o_base + 0x64)
  S.facing_right = S.ox >= S.qx
  if not S.home then S.home = math.max(120, math.abs(S.ox - S.qx)) end

  local input = joypad.get()

  if edge(input, S.pfx .. "Coin") then
    S.menu_open = not S.menu_open
    S.walking_home = false
  end

  if S.menu_open then
    update_menu(input)
    S.prev_raw = input
    local blocked = {}
    for k, v in pairs(input) do blocked[k] = v end
    clear_p1(blocked)
    joypad.set(blocked)
    return
  end

  if S.walking_home then
    S.prev_raw = input
    local dist = math.abs(S.ox - S.qx)
    S.walk_frames = S.walk_frames + 1
    local d
    if dist < S.home - 6 then d = 4 elseif dist > S.home + 6 then d = 6 end
    if not d or S.walk_frames > 300 then S.walking_home = false; return end
    local forced = {}
    for k, v in pairs(input) do forced[k] = v end
    clear_p1(forced)
    set_dir(forced, d, S.facing_right)
    joypad.set(forced)
    return
  end

  S.prev_raw = input
  S.prev_dir = S.dir
  S.dir = numpad(input, S.facing_right)
  S.pressed = {}
  for _, b in ipairs(BUTTONS) do
    local down = input[S.pfx .. b.key] == true
    if down and not S.prev_held[b.label] then table.insert(S.pressed, b.label) end
    S.prev_held[b.label] = down
  end

  table.insert(S.history, { f = S.now, dir = S.dir, pressed = S.pressed })
  while #S.history > 90 do table.remove(S.history, 1) end

  update_motion()

  if cfg.mode == 1 then
    update_run()
  else
    update_step_mode()
  end
end

-- =====================================================================
-- drawing
-- =====================================================================

local LANES = { "4", "1", "2", "3", "6", "LP", "MP", "HP", "LK", "MK", "HK" }
local DIR_LANE_VALUE = { ["4"] = 4, ["1"] = 1, ["2"] = 2, ["3"] = 3, ["6"] = 6 }
local HW = { x = 4, y_line = 40, y_bottom = 196, lane_w = 12 }

local function text(x, y, s, col, border) gui.text(x, y, s, col or C.white, border or C.black) end
local function box(x1, y1, x2, y2, fill, line) gui.box(x1, y1, x2, y2, fill or C.clear, line or C.clear) end

local function lane_x(i) return HW.x + (i - 1) * HW.lane_w end
local function lane_index(name)
  for i, l in ipairs(LANES) do if l == name then return i end end
end
local function lane_color(l)
  if DIR_LANE_VALUE[l] then return DIR_COLOR[disp(DIR_LANE_VALUE[l])] end
  return BTN_COLOR[l]
end

local function draw_note(n, ct)
  local i = lane_index(n.lane)
  if not i then return end
  local hit = S.run and S.run.hits[n.id]
  if hit and hit.text ~= "MISS" then return end          -- hit notes disappear
  local speed = SPEEDS[cfg.speed]
  local y1 = HW.y_line + (n.t - ct) * speed
  local y2 = y1 + math.max(1, n.len) * speed - 1
  if y2 < HW.y_line - 14 or y1 > HW.y_bottom then return end
  local top = math.max(y1, HW.y_line - 14)
  local bot = math.min(y2, HW.y_bottom)
  local x = lane_x(i)
  local col = hit and 0x802020FF or n.color
  box(x + 1, top, x + HW.lane_w - 2, bot, dim(col), col)
  if y1 >= HW.y_line - 14 and y1 <= HW.y_bottom - 6 then
    text(x + 4, y1 + 1, n.label, C.white)
  end
end

local function draw_highway()
  local n = #LANES
  local right = HW.x + n * HW.lane_w
  box(HW.x - 2, HW.y_line - 24, right + 1, HW.y_bottom + 2, C.dark, C.black)
  for i, l in ipairs(LANES) do
    local x = lane_x(i)
    box(x, HW.y_line - 14, x + HW.lane_w - 1, HW.y_bottom, C.clear, 0x303030FF)
    text(x + (#l == 1 and 4 or 2), HW.y_line - 22, l, lane_color(l))
  end

  -- receptors on the line: lit while that direction / button is held
  for i, l in ipairs(LANES) do
    local x = lane_x(i)
    local lit
    if DIR_LANE_VALUE[l] then lit = (disp(S.dir) == DIR_LANE_VALUE[l]) else lit = S.prev_held[l] end
    box(x + 1, HW.y_line - 3, x + HW.lane_w - 2, HW.y_line + 3,
        lit and lane_color(l) or C.black, lit and C.white or 0x707070FF)
  end

  local ct = chart_time()
  for _, note in ipairs(chart_notes()) do draw_note(note, ct) end

  -- judgments under the line
  for i, l in ipairs(LANES) do
    local j = S.judge[l]
    if j and S.now < j.until_f then
      text(lane_x(i) - 1, HW.y_line + 6 + (i % 2) * 8, j.text:sub(1, 3), j.color)
    end
  end

  if not S.run then
    local _, first_dir = chart_span()
    text(HW.x, HW.y_bottom - 8, "Ready - start with " .. disp(first_dir), C.yellow)
  end
end

local function draw_step_mode()
  local seq = step_list()
  local y0 = 150
  box(2, y0, 380, y0 + 26, C.dark, C.black)
  text(6, y0 + 2, "STEP MODE - press each input in order (no timing)", C.grey)
  local x = 6
  for i, it in ipairs(seq) do
    local label = it.kind == "dir" and tostring(disp(it.v)) or it.v
    local w = #label * 4 + 6
    local col = (it.kind == "dir") and (DIR_COLOR[it.v] or C.white) or BTN_COLOR[it.v]
    local done = i < S.step_index
    local current = i == S.step_index
    box(x, y0 + 11, x + w, y0 + 21, done and 0x206020FF or C.black, current and C.white or col)
    text(x + 3, y0 + 13, label, done and C.green or col)
    x = x + w + 3
  end
  if S.step_index > #seq then text(6, y0 + 28, "Clean! Now go do it with timing in Real-time mode.", C.green) end
end

local function draw_status()
  local st = S.stats
  local x0 = 250
  box(x0 - 4, 26, 382, 92, C.dark, C.black)
  text(x0, 28, chart().name .. "  (" .. kick_label() .. ")", C.yellow)
  text(x0, 36, disp_str(chart().notation), C.grey)
  text(x0, 46, string.format("Kara %d / %d", st.karas, st.attempts), C.white)
  local pct = st.attempts > 0 and math.floor(st.karas * 100 / st.attempts) or 0
  text(x0 + 70, 46, pct .. "%", pct >= 50 and C.green or C.white)
  text(x0, 54, string.format("Streak %d  Best %d", st.streak, st.best), C.white)

  -- histogram of where the 1 landed (last 20)
  text(x0, 64, "1 landed on frame:", C.grey)
  local counts = {}
  for _, d in ipairs(st.recent) do
    local k = math.max(8, math.min(14, d))
    counts[k] = (counts[k] or 0) + 1
  end
  for k = 8, 14 do
    local bx = x0 + (k - 8) * 18
    local c = counts[k] or 0
    local col = (k == TARGET_D) and C.green or C.orange
    if c > 0 then box(bx, 84 - math.min(10, c * 2), bx + 12, 84, col, col) end
    local lbl = (k == 8 and "<9") or (k == 14 and "14+") or tostring(k)
    text(bx, 86, lbl, (k == TARGET_D) and C.green or C.grey)
  end
end

local function draw_live_clock()
  local m = S.motion
  local x0, y0 = 146, 26
  box(x0 - 4, y0, x0 + 98, y0 + 22, C.dark, C.black)
  text(x0, y0 + 2, "frames since first 2:", C.grey)
  local el = m and (S.now - m.start) or nil
  -- 0..16 ticks, 11 highlighted
  for k = 0, 16 do
    local bx = x0 + k * 5
    local col = (k == TARGET_D) and C.green or 0x404040FF
    if el and k <= el and not (m and m.landed and k > m.D) then
      col = (k == TARGET_D) and C.green or ((k < TARGET_D) and C.cyan or C.red)
    end
    box(bx, y0 + 11, bx + 3, y0 + 18, col, (k == TARGET_D) and C.white or C.clear)
  end
end

local function draw_result()
  local L = S.last
  if not L or S.now > L.until_f then return end
  local r = L.r
  box(142, 94, 382, 112, C.dark, C.black)
  text(146, 96, r.title, r.color)
  if r.detail then text(146 + #r.title * 4 + 6, 96, r.detail, C.grey) end
  text(146, 104, r.tip, (r.kara and C.green) or C.white)

  -- review strip: target vs you, frames -4..16 relative to the first 2
  local x0, y0, cw = 172, 196, 10
  box(x0 - 30, y0 - 2, x0 + 21 * cw + 2, y0 + 26, C.dark, C.black)
  text(x0 - 28, y0 + 1, "TARGET", C.grey)
  text(x0 - 28, y0 + 9, "YOU", C.grey)
  text(x0 - 28, y0 + 18, "frame", C.grey)
  local saved = cfg.chart
  cfg.chart = L.chart
  for f = -4, 16 do
    local cx = x0 + (f + 4) * cw
    local td = target_dir(f)
    local h = L.review[f]
    local yd = h and h.dir or nil
    local outline = (f == TARGET_D) and C.green or 0x303030FF
    box(cx, y0, cx + cw - 2, y0 + 7, C.black, outline)
    if td ~= 5 then text(cx + 3, y0 + 1, tostring(disp(td)), DIR_COLOR[td]) end
    local tb = target_btn_press(f)
    if #tb > 0 then text(cx + 7, y0 + 1, tb[#tb]:sub(1, 1), BTN_COLOR[tb[#tb]]) end
    local mismatch = yd and td ~= 5 and yd ~= td
    box(cx, y0 + 8, cx + cw - 2, y0 + 15, mismatch and 0x601010FF or C.black, outline)
    if yd then text(cx + 3, y0 + 9, tostring(disp(yd)), mismatch and C.red or (DIR_COLOR[yd] or C.white)) end
    if h and #h.pressed > 0 then
      local p = h.pressed[#h.pressed]
      text(cx + 7, y0 + 9, p:sub(1, 1), BTN_COLOR[p])
    end
    if f % 2 == 1 or f == TARGET_D then
      text(cx + 1, y0 + 18, tostring(f), (f == TARGET_D) and C.green or C.grey)
    end
  end
  cfg.chart = saved
end

local function draw_menu()
  local x0, y0 = 110, 60
  box(x0, y0, x0 + 170, y0 + 14 + #MENU * 10, 0x000000E0, C.white)
  text(x0 + 6, y0 + 4, "Q KARA TRAINER - menu (Coin closes)", C.yellow)
  for i, item in ipairs(MENU) do
    local y = y0 + 14 + (i - 1) * 10
    local sel = (i == S.menu_sel)
    local s = item.label
    if item.get then s = s .. ":  < " .. item.get() .. " >" end
    if item.action then s = s .. (sel and "   (LP)" or "") end
    text(x0 + 8, y, (sel and "> " or "  ") .. s, sel and C.white or C.grey)
  end
end

local function on_gui()
  if cfg.mode == 1 then draw_highway() else draw_step_mode() end
  draw_live_clock()
  draw_status()
  draw_result()
  if S.walking_home then text(146, 116, "Walking Q back to home distance...", C.yellow) end
  if S.menu_open then draw_menu() end
  if not S.menu_open and S.now < 600 + (S.first_frame or 0) then
    text(146, 116, "Coin = menu", C.grey)
  end
  gui.box(0, 0, 0, 0, 0, 0)
end

-- =====================================================================
-- start
-- =====================================================================

emu.registerbefore(before_frame)
gui.register(on_gui)
S.first_frame = memory.readdword(FRAME_ADDR)
log("q_kara_capture_and_deadly_blow_training v1.3 loaded. Coin opens the menu. Log: " .. LOG_PATH)
