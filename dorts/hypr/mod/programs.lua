---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "Thunar"
local menu        = "hyprlauncher"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
 hl.on("hyprland.start", function () 
hl.exec_cmd("kitty")
hl.exec_cmd("qs")
hl.exec_cmd("swaync")
hl.exec_cmd("hyprpaper")
 end)
