--
-- Auto-reload config when files change
--
local function reloadConfig(files)
    local doReload = false
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
            break
        end
    end
    if doReload then
        hs.reload()
    end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

--
-- Install IPC CLI if not already installed
--
if hs.ipc.cliStatus() == false then
	hs.ipc.cliInstall()
end

require("window")
require("hotkeys")

location = require("location")
location.startLocation()

--
-- Window animation duration (seconds)
--
hs.window.animationDuration = 0.2
