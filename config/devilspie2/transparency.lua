-- Per-app transparency: backgrounds fade, content stays crisp
local app = get_application_name()
local cls = get_window_class()

-- Skip desktop
if cls == "Nemo-desktop" or cls == "nemo-desktop" or app == "Desktop" then
    return
end

-- Play window open sound (skip popups/tooltips/dialogs)
local wtype = get_window_type()
if wtype == "WINDOW_TYPE_NORMAL" then
    os.execute(os.getenv("HOME") .. '/.local/bin/47sound play ' .. os.getenv("HOME") .. '/Documents/47industries/sounds/move.mp3 &')
end

-- Skip terminals (use native opacity, text stays solid)
if cls == "Alacritty" or cls == "alacritty" then
    return
end
if cls == "Gnome-terminal" or cls == "gnome-terminal" then
    return
end

-- Check if transparency is on
local f = io.open(os.getenv("HOME") .. "/.config/47industries/transparency-state", "r")
local state = "off"
if f then
    state = f:read("*l") or "off"
    f:close()
end

if state ~= "on" then
    return
end

-- Read saved transparency level
local level = 50
local lf = io.open(os.getenv("HOME") .. "/.config/47industries/transparency-level", "r")
if lf then
    level = tonumber(lf:read("*l")) or 50
    lf:close()
end

-- Convert level to opacity: 0=solid(1.0), 100=clear(0.3)
local opacity = 1.0 - (level * 0.007)
set_window_opacity(opacity)
