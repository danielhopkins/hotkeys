-- hyper is *awesome* if you use karabiner to map fn + key to hyper + k
local hyper = {"cmd", "alt", "ctrl", "shift"}

-- Native macOS Window menu helper
local function windowMenuItem(item)
    local app = hs.application.frontmostApplication()
    if app then
        app:selectMenuItem({"Window", item})
    end
end

-- Cycling center: center → small centered → medium centered → large centered → repeat
local centerPresets = {0.7, 0.9, 1.0}  -- 70%, 90%, fullscreen
local function fuzzyEqual(a, b, tolerance)
    return math.abs(a - b) < (tolerance or 15)
end

local function getCenterPresetIndex(win)
    local f = win:frame()
    local screen = win:screen():frame()
    local widthRatio = f.w / screen.w
    local heightRatio = f.h / screen.h
    local isCenteredX = fuzzyEqual(f.x + f.w/2, screen.x + screen.w/2, 20)
    local isCenteredY = fuzzyEqual(f.y + f.h/2, screen.y + screen.h/2, 20)

    if isCenteredX and isCenteredY then
        for i, preset in ipairs(centerPresets) do
            if fuzzyEqual(widthRatio, preset, 0.05) and fuzzyEqual(heightRatio, preset, 0.05) then
                return i
            end
        end
    end
    return 0  -- not at a preset
end

-- Apps that should only be centered, not resized
local centerOnlyApps = {"iPhone Mirroring"}

local function cycleCenter()
    local win = hs.window.focusedWindow()
    if not win then return end

    local appName = win:application():name()
    local screen = win:screen():frame()
    local f = win:frame()

    -- For certain apps, just center without resizing
    if hs.fnutils.contains(centerOnlyApps, appName) then
        local newX = screen.x + (screen.w - f.w) / 2
        local newY = screen.y + (screen.h - f.h) / 2
        win:setFrame({x = newX, y = newY, w = f.w, h = f.h}, 0.2)
        return
    end

    local currentPreset = getCenterPresetIndex(win)
    local nextPreset = (currentPreset % #centerPresets) + 1
    local ratio = centerPresets[nextPreset]

    local newW = screen.w * ratio
    local newH = screen.h * ratio
    local newX = screen.x + (screen.w - newW) / 2
    local newY = screen.y + (screen.h - newH) / 2

    -- Animate like native tiling (0.2 seconds)
    win:setFrame({x = newX, y = newY, w = newW, h = newH}, 0.2)
end

-- hotkeys
-- F13-F20 are sent by Karabiner for Hyper+C/H/L/J/K (avoids ctrl conflicts in terminals)
hs.hotkey.bind({}, 'f13', function() cycleCenter() end)  -- Hyper+C: center 50% → 70% → 90% → full
hs.hotkey.bind({}, 'f17', function()  -- Hyper+H: Left half (cycles: half → top-left → bottom-left)
    cycleWindowLeft()
end)
hs.hotkey.bind({}, 'f18', function()  -- Hyper+L: Right half (cycles: half → top-right → bottom-right)
    cycleWindowRight()
end)
hs.hotkey.bind({}, 'f19', function()  -- Hyper+J: Bottom half
    local win = hs.window.focusedWindow()
    if win then win:moveToUnit({0, 0.5, 1, 0.5}) end
end)
hs.hotkey.bind({}, 'f20', function()  -- Hyper+K: Top half
    local win = hs.window.focusedWindow()
    if win then win:moveToUnit({0, 0, 1, 0.5}) end
end)
hs.hotkey.bind({"cmd", "alt"}, 'd', function()  -- Cmd+Opt+D: Toggle dock with window compensation
    -- Snapshot each window's proportional position within its screen
    local windowProps = {}
    for _, win in ipairs(hs.window.visibleWindows()) do
        if win:isStandard() then
            local sf = win:screen():frame()
            local wf = win:frame()
            table.insert(windowProps, {
                win = win,
                screenId = win:screen():id(),
                xRatio = (wf.x - sf.x) / sf.w,
                yRatio = (wf.y - sf.y) / sf.h,
                wRatio = wf.w / sf.w,
                hRatio = wf.h / sf.h,
                fixedSize = hs.fnutils.contains(centerOnlyApps, win:application():name()),
                origW = wf.w,
                origH = wf.h,
            })
        end
    end

    -- Toggle dock auto-hide
    hs.osascript.applescript('tell application "System Events" to set autohide of dock preferences to not (autohide of dock preferences)')

    -- Wait for dock animation, then reposition windows proportionally
    hs.timer.doAfter(0.8, function()
        for _, wp in ipairs(windowProps) do
            local win = wp.win
            if win:isVisible() then
                local sf = win:screen():frame()
                if wp.fixedSize then
                    -- Keep original size, re-center proportionally
                    local newX = sf.x + sf.w * wp.xRatio
                    local newY = sf.y + sf.h * wp.yRatio
                    win:setFrame({x = newX, y = newY, w = wp.origW, h = wp.origH}, 0.2)
                else
                    win:setFrame({
                        x = sf.x + sf.w * wp.xRatio,
                        y = sf.y + sf.h * wp.yRatio,
                        w = sf.w * wp.wRatio,
                        h = sf.h * wp.hRatio,
                    }, 0.2)
                end
            end
        end
    end)
end)
hs.hotkey.bind(hyper, 't', function() hs.toggleConsole() end)

-- Home automation (requires location module)
hs.hotkey.bind(hyper, 'f3', function()
    if not location.isHome() then
        hs.alert.show("Not at home")
        return
    end
    hs.shortcuts.run("Toggle heater")
    hs.alert.show("Toggling heater", 0.5)
end)

-- Window Layouts with rotation
-- hyper+1: 4 quarters - press again to rotate clockwise
-- hyper+2: Main LEFT, 2 stacked right - press again to rotate counter-clockwise
-- hyper+3: Main RIGHT, 2 stacked left - press again to rotate counter-clockwise
hs.hotkey.bind(hyper, '1', function() fourAppLayoutQuarters() end)
hs.hotkey.bind(hyper, '2', function() threeAppLayoutLeft() end)
hs.hotkey.bind(hyper, '3', function() threeAppLayoutRight() end)

-- hyper+4: Arrange two windows left/right, press again to swap
-- (getVisibleWindows is defined in window.lua)
-- Helper to check if app can't be resized
local function isFixedSizeApp(win)
    local appName = win:application():name()
    return hs.fnutils.contains(centerOnlyApps, appName)
end

-- Check which side a window is on (by center point)
local function getWindowSide(win, screen)
    local f = win:frame()
    local cx = f.x + f.w / 2
    local midX = screen.x + screen.w / 2
    return cx < midX and "left" or "right"
end

-- Check if window is approximately in the left/right half tiled position
local function isInHalfPosition(win, screen, side)
    local f = win:frame()
    local tolerance = 50  -- pixels

    local expectedX = (side == "left") and screen.x or (screen.x + screen.w / 2)
    local expectedW = screen.w / 2

    -- Check if position and size are close to expected
    local xMatch = math.abs(f.x - expectedX) < tolerance
    local wMatch = math.abs(f.w - expectedW) < tolerance
    local hMatch = math.abs(f.h - screen.h) < tolerance

    return xMatch and wMatch and hMatch
end

local function arrangeLeftRight()
    local focusedWin = hs.window.focusedWindow()
    local currentScreen

    if focusedWin then
        currentScreen = focusedWin:screen()
    else
        -- No focused window - use main screen
        currentScreen = hs.screen.mainScreen()
    end

    local screen = currentScreen:frame()

    -- Get top 2 windows on this screen (use getVisibleWindows to include console)
    local windows = {}
    for _, w in ipairs(getVisibleWindows()) do
        if w:screen():id() == currentScreen:id() then
            table.insert(windows, w)
            if #windows >= 2 then break end
        end
    end

    if #windows < 2 then
        hs.alert.show("Need 2 windows")
        return
    end

    local w1, w2 = windows[1], windows[2]
    local w1Side = getWindowSide(w1, screen)
    local w2Side = getWindowSide(w2, screen)

    -- Only consider "already arranged" if both windows are actually in tiled half positions
    local w1InPosition = isInHalfPosition(w1, screen, w1Side)
    local w2InPosition = isInHalfPosition(w2, screen, w2Side)
    local onOppositeSides = (w1Side == "left" and w2Side == "right") or (w1Side == "right" and w2Side == "left")
    local alreadyArranged = onOppositeSides and w1InPosition and w2InPosition

    -- Position each window, respecting fixed-size apps
    local function positionWindow(win, side, otherWin)
        local f = win:frame()
        local otherFixed = isFixedSizeApp(otherWin)
        local otherF = otherWin:frame()

        if isFixedSizeApp(win) then
            -- Fixed size: just move, keep dimensions, center vertically
            local newX = (side == "left") and screen.x or (screen.x + screen.w - f.w)
            local newY = screen.y + (screen.h - f.h) / 2
            win:setFrame({x = newX, y = newY, w = f.w, h = f.h}, 0.2)
        elseif otherFixed then
            -- Other is fixed: fill remaining space
            local otherWidth = otherF.w
            if side == "left" then
                win:setFrame({x = screen.x, y = screen.y, w = screen.w - otherWidth, h = screen.h}, 0.2)
            else
                win:setFrame({x = screen.x + otherWidth, y = screen.y, w = screen.w - otherWidth, h = screen.h}, 0.2)
            end
        else
            -- Both resizable: half each
            if side == "left" then
                win:setFrame({x = screen.x, y = screen.y, w = screen.w/2, h = screen.h}, 0.2)
            else
                win:setFrame({x = screen.x + screen.w/2, y = screen.y, w = screen.w/2, h = screen.h}, 0.2)
            end
        end
    end

    -- Determine target sides
    local w1Target, w2Target
    if alreadyArranged then
        -- Already in left/right layout: swap them
        w1Target = (w1Side == "left") and "right" or "left"
        w2Target = (w2Side == "left") and "right" or "left"
    else
        -- Smart assignment: each window goes to closest side
        local leftRect = {x = screen.x, y = screen.y, w = screen.w/2, h = screen.h}
        local rightRect = {x = screen.x + screen.w/2, y = screen.y, w = screen.w/2, h = screen.h}

        local w1ToLeft = windowToRectDistance(w1, leftRect)
        local w1ToRight = windowToRectDistance(w1, rightRect)
        local w2ToLeft = windowToRectDistance(w2, leftRect)
        local w2ToRight = windowToRectDistance(w2, rightRect)

        -- Check both assignment options and pick the one with less total movement
        local option1 = w1ToLeft + w2ToRight   -- w1 left, w2 right
        local option2 = w1ToRight + w2ToLeft   -- w1 right, w2 left

        if option1 <= option2 then
            w1Target = "left"
            w2Target = "right"
        else
            w1Target = "right"
            w2Target = "left"
        end
    end

    positionWindow(w1, w1Target, w2)
    positionWindow(w2, w2Target, w1)
    w1:focus()
end

hs.hotkey.bind(hyper, '4', function() arrangeLeftRight() end)

-- Hyper+Shift layer (fn + right Shift + key)
-- Karabiner detects physical right_shift alongside hyper modifiers
-- and sends shift+F-key, so we bind {"shift"}, "f<N>" here.

-- Split adjustment: moves the vertical center divider for any 2/3/4 window layout
local splitStep = 0.1  -- 10% per press

local function adjustSplit(delta)
    local focusedWin = hs.window.focusedWindow()
    if not focusedWin then return end
    local currentScreen = focusedWin:screen()
    local screen = currentScreen:frame()

    local windows = {}
    for _, w in ipairs(getVisibleWindows()) do
        if w:screen():id() == currentScreen:id() then
            table.insert(windows, w)
        end
    end

    if #windows < 2 then return end

    -- Classify windows as left or right by center x
    local midX = screen.x + screen.w / 2
    local leftWins, rightWins = {}, {}
    for _, w in ipairs(windows) do
        local f = w:frame()
        if f.x + f.w / 2 < midX then
            table.insert(leftWins, w)
        else
            table.insert(rightWins, w)
        end
    end

    if #leftWins == 0 or #rightWins == 0 then return end

    -- Current split ratio from first left window's width
    local currentRatio = leftWins[1]:frame().w / screen.w
    local newRatio = math.max(0.2, math.min(0.8, currentRatio + delta))

    local leftW = screen.w * newRatio
    local rightX = screen.x + leftW
    local rightW = screen.w - leftW

    for _, w in ipairs(leftWins) do
        local f = w:frame()
        w:setFrame({x = screen.x, y = f.y, w = leftW, h = f.h}, 0.2)
    end
    for _, w in ipairs(rightWins) do
        local f = w:frame()
        w:setFrame({x = rightX, y = f.y, w = rightW, h = f.h}, 0.2)
    end

    local display = math.floor(newRatio * 10 + 0.5) * 10
    hs.alert.show(display .. "/" .. (100 - display), 0.5)
end

-- Hyper+Shift+H (shift+F17): Move vertical split left
hs.hotkey.bind({"shift"}, 'f17', function() adjustSplit(-splitStep) end)

-- Hyper+Shift+L (shift+F18): Move vertical split right
hs.hotkey.bind({"shift"}, 'f18', function() adjustSplit(splitStep) end)

-- Horizontal split: finds non-full-height windows and adjusts the split between them.
-- In 2-window side-by-side mode, first converts to top/bottom then adjusts.
local function adjustHorizontalSplit(delta)
    local focusedWin = hs.window.focusedWindow()
    if not focusedWin then return end
    local currentScreen = focusedWin:screen()
    local screen = currentScreen:frame()

    local windows = {}
    for _, w in ipairs(getVisibleWindows()) do
        if w:screen():id() == currentScreen:id() then
            table.insert(windows, w)
        end
    end

    if #windows < 2 then return end

    -- 2 windows side-by-side: convert to top/bottom
    if #windows == 2 then
        local bothFullHeight = true
        for _, w in ipairs(windows) do
            if w:frame().h < screen.h * 0.85 then bothFullHeight = false end
        end
        if bothFullHeight then
            local w1, w2 = windows[1], windows[2]
            local halfH = screen.h / 2
            w1:setFrame({x = screen.x, y = screen.y, w = screen.w, h = halfH}, 0.2)
            w2:setFrame({x = screen.x, y = screen.y + halfH, w = screen.w, h = halfH}, 0.2)
            hs.alert.show("50/50", 0.5)
            return
        end
    end

    -- Find non-full-height windows (the stacked ones)
    local stacked = {}
    for _, w in ipairs(windows) do
        if w:frame().h < screen.h * 0.85 then
            table.insert(stacked, w)
        end
    end

    if #stacked < 2 then return end

    -- Sort by y position, take top pair
    table.sort(stacked, function(a, b) return a:frame().y < b:frame().y end)
    local topWin = stacked[1]
    local bottomWin = stacked[2]

    local columnTop = topWin:frame().y
    local columnH = (bottomWin:frame().y + bottomWin:frame().h) - columnTop
    local currentRatio = topWin:frame().h / columnH
    local newRatio = math.max(0.2, math.min(0.8, currentRatio + delta))

    local topH = columnH * newRatio
    local bottomY = columnTop + topH
    local bottomH = columnH - topH

    topWin:setFrame({x = topWin:frame().x, y = columnTop, w = topWin:frame().w, h = topH}, 0.2)
    bottomWin:setFrame({x = bottomWin:frame().x, y = bottomY, w = bottomWin:frame().w, h = bottomH}, 0.2)

    local display = math.floor(newRatio * 10 + 0.5) * 10
    hs.alert.show(display .. "/" .. (100 - display), 0.5)
end

-- Hyper+Shift+J (shift+F19): Move horizontal split down (top bigger)
hs.hotkey.bind({"shift"}, 'f19', function() adjustHorizontalSplit(splitStep) end)

-- Hyper+Shift+K (shift+F20): Move horizontal split up (bottom bigger)
hs.hotkey.bind({"shift"}, 'f20', function() adjustHorizontalSplit(-splitStep) end)

-- hyper+o: Smart tiling based on window count
-- 1 = fill, 2 = left/right, 3 = right-biased (main right, 2 stacked left), 4+ = quarters
-- Windows are assigned to positions that minimize movement (closest position wins)
-- Uses windowToRectDistance() and assignWindowsToPositions() from window.lua

local function smartTile()
    local focusedWin = hs.window.focusedWindow()
    local currentScreen

    if focusedWin then
        currentScreen = focusedWin:screen()
    else
        currentScreen = hs.screen.mainScreen()
    end

    local screen = currentScreen:frame()

    -- Get all windows on this screen
    local windows = {}
    for _, w in ipairs(getVisibleWindows()) do
        if w:screen():id() == currentScreen:id() then
            table.insert(windows, w)
        end
    end

    local count = #windows
    if count == 0 then return end

    local function placeWindow(win, rect)
        if isFixedSizeApp(win) then
            local f = win:frame()
            local newX = rect.x + (rect.w - f.w) / 2
            local newY = rect.y + (rect.h - f.h) / 2
            win:setFrame({x = newX, y = newY, w = f.w, h = f.h}, 0.2)
        else
            win:setFrame(rect, 0.2)
        end
    end

    if count == 1 then
        -- Fill screen
        local win = windows[1]
        if isFixedSizeApp(win) then
            local f = win:frame()
            local newX = screen.x + (screen.w - f.w) / 2
            local newY = screen.y + (screen.h - f.h) / 2
            win:setFrame({x = newX, y = newY, w = f.w, h = f.h}, 0.2)
        else
            win:setFrame({x = screen.x, y = screen.y, w = screen.w, h = screen.h}, 0.2)
        end

    elseif count == 2 then
        -- Reuse hyper+4 logic (handles fixed-size apps, swapping, etc.)
        arrangeLeftRight()
        return

    elseif count == 3 then
        -- Right-biased: main right, 2 stacked left
        -- Press again to rotate counter-clockwise (matches hyper+3 behavior)
        local positions = {
            {x = screen.x + screen.w/2, y = screen.y, w = screen.w/2, h = screen.h},     -- 1: right (main)
            {x = screen.x, y = screen.y, w = screen.w/2, h = screen.h/2},                -- 2: top-left
            {x = screen.x, y = screen.y + screen.h/2, w = screen.w/2, h = screen.h/2},   -- 3: bottom-left
        }

        -- Find windows in each position (uses isInRightMainLayout from window.lua)
        local rightWin, topLeftWin, bottomLeftWin = nil, nil, nil
        for _, w in ipairs(windows) do
            local pos = isInRightMainLayout(w, screen)
            if pos == "right" and not rightWin then
                rightWin = w
            elseif pos == "top-left" and not topLeftWin then
                topLeftWin = w
            elseif pos == "bottom-left" and not bottomLeftWin then
                bottomLeftWin = w
            end
        end

        -- If all 3 positions filled, rotate counter-clockwise
        if rightWin and topLeftWin and bottomLeftWin then
            -- Rotate: top-left→right, bottom-left→top-left, right→bottom-left
            topLeftWin:setFrame(positions[1], 0.2)
            bottomLeftWin:setFrame(positions[2], 0.2)
            rightWin:setFrame(positions[3], 0.2)
            topLeftWin:focus()
            return
        else
            -- Smart assignment: each window goes to closest position
            local assignments = assignWindowsToPositions(windows, positions)
            for posIdx, win in pairs(assignments) do
                placeWindow(win, positions[posIdx])
            end
            if assignments[1] then assignments[1]:focus() end
            return
        end

    else
        -- 4+ windows: assign to 4 quadrants, extras BSP into bottom-right
        -- For exactly 4 windows: press again to rotate clockwise (matches hyper+1 behavior)
        local positions = {
            {x = screen.x, y = screen.y, w = screen.w/2, h = screen.h/2},                -- 1: top-left
            {x = screen.x + screen.w/2, y = screen.y, w = screen.w/2, h = screen.h/2},   -- 2: top-right
            {x = screen.x + screen.w/2, y = screen.y + screen.h/2, w = screen.w/2, h = screen.h/2}, -- 3: bottom-right
            {x = screen.x, y = screen.y + screen.h/2, w = screen.w/2, h = screen.h/2},   -- 4: bottom-left
        }

        -- For exactly 4 windows, check if already in quarters and rotate
        if count == 4 then
            local topLeftWin, topRightWin, bottomRightWin, bottomLeftWin = nil, nil, nil, nil
            for _, w in ipairs(windows) do
                local pos = isInQuarterPosition(w, screen)
                if pos == "top-left" and not topLeftWin then
                    topLeftWin = w
                elseif pos == "top-right" and not topRightWin then
                    topRightWin = w
                elseif pos == "bottom-right" and not bottomRightWin then
                    bottomRightWin = w
                elseif pos == "bottom-left" and not bottomLeftWin then
                    bottomLeftWin = w
                end
            end

            -- If all 4 quarters filled, rotate clockwise
            if topLeftWin and topRightWin and bottomRightWin and bottomLeftWin then
                placeWindow(topLeftWin, positions[2])      -- TL → TR
                placeWindow(topRightWin, positions[3])     -- TR → BR
                placeWindow(bottomRightWin, positions[4])  -- BR → BL
                placeWindow(bottomLeftWin, positions[1])   -- BL → TL
                bottomLeftWin:focus()
                return
            end
        end

        local assignments = assignWindowsToPositions(windows, positions)

        -- Place assigned windows
        local assignedWindows = {}
        for posIdx, win in pairs(assignments) do
            placeWindow(win, positions[posIdx])
            assignedWindows[win:id()] = true
        end

        -- BSP any remaining windows into bottom-right quadrant
        local function bspTile(wins, rect, depth)
            if #wins == 0 then return end
            if #wins == 1 then
                placeWindow(wins[1], rect)
                return
            end

            local splitVertical = (depth % 2 == 0)
            local firstCount = math.ceil(#wins / 2)
            local firstWins, secondWins = {}, {}
            for i, w in ipairs(wins) do
                if i <= firstCount then
                    table.insert(firstWins, w)
                else
                    table.insert(secondWins, w)
                end
            end

            local rect1, rect2
            if splitVertical then
                rect1 = {x = rect.x, y = rect.y, w = rect.w / 2, h = rect.h}
                rect2 = {x = rect.x + rect.w / 2, y = rect.y, w = rect.w / 2, h = rect.h}
            else
                rect1 = {x = rect.x, y = rect.y, w = rect.w, h = rect.h / 2}
                rect2 = {x = rect.x, y = rect.y + rect.h / 2, w = rect.w, h = rect.h / 2}
            end

            bspTile(firstWins, rect1, depth + 1)
            bspTile(secondWins, rect2, depth + 1)
        end

        local extraWindows = {}
        for _, w in ipairs(windows) do
            if not assignedWindows[w:id()] then
                table.insert(extraWindows, w)
            end
        end

        if #extraWindows > 0 then
            local bottomRight = positions[4]
            bspTile(extraWindows, bottomRight, 0)
        end
    end

    -- Focus the originally focused window, or the first tiled window
    if focusedWin then
        focusedWin:focus()
    elseif #windows > 0 then
        windows[1]:focus()
    end
end

hs.hotkey.bind(hyper, 'o', function() smartTile() end)

-- Alt+Tab/`: Cycle through spatially overlapping windows
local function getOverlappingWindows(win)
  local frame = win:frame()
  local validWindows = {}
  local minOverlapPercent = 0.5  -- 50% of smaller window must overlap

  -- orderedWindows() returns front-to-back z-order
  for _, w in ipairs(hs.window.orderedWindows()) do
    if w:isStandard() and w:isVisible() then
      local wFrame = w:frame()

      -- Calculate intersection rectangle
      local ix = math.max(frame.x, wFrame.x)
      local iy = math.max(frame.y, wFrame.y)
      local ix2 = math.min(frame.x + frame.w, wFrame.x + wFrame.w)
      local iy2 = math.min(frame.y + frame.h, wFrame.y + wFrame.h)

      if ix < ix2 and iy < iy2 then
        local intersectArea = (ix2 - ix) * (iy2 - iy)
        local frameArea = frame.w * frame.h
        local wFrameArea = wFrame.w * wFrame.h
        local smallerArea = math.min(frameArea, wFrameArea)

        -- Require significant overlap
        if intersectArea / smallerArea >= minOverlapPercent then
          table.insert(validWindows, w)
        end
      end
    end
  end
  return validWindows
end

local function cycleOverlappingWindows(reverse)
  local win = hs.window.focusedWindow()
  if not win then return end

  local overlapping = getOverlappingWindows(win)
  if #overlapping <= 1 then return end

  local currentIdx = hs.fnutils.indexOf(overlapping, win) or 1
  local nextIdx
  if reverse then
    nextIdx = currentIdx - 1
    if nextIdx < 1 then nextIdx = #overlapping end
  else
    nextIdx = currentIdx + 1
    if nextIdx > #overlapping then nextIdx = 1 end
  end

  overlapping[nextIdx]:focus()
end

hs.hotkey.bind({"alt"}, "tab", function() cycleOverlappingWindows(false) end)
hs.hotkey.bind({"alt"}, "`", function() cycleOverlappingWindows(true) end)

-- Alt+HJKL: Directional window focus (vim-style)
-- Check if two windows overlap significantly (>30% of smaller window)
local function windowsOverlap(f1, f2)
  local ix = math.max(f1.x, f2.x)
  local iy = math.max(f1.y, f2.y)
  local ix2 = math.min(f1.x + f1.w, f2.x + f2.w)
  local iy2 = math.min(f1.y + f1.h, f2.y + f2.h)

  if ix >= ix2 or iy >= iy2 then return false end

  local intersectArea = (ix2 - ix) * (iy2 - iy)
  local smallerArea = math.min(f1.w * f1.h, f2.w * f2.h)
  return intersectArea / smallerArea >= 0.3
end

-- Custom directional focus that requires significant displacement in the target direction
-- Direction: "west", "east", "north", "south"
-- Excludes windows that overlap with the current window (use Alt+Tab for those)
-- Prefers frontmost windows when distances are similar
local function focusWindowInDirection(direction)
  local win = hs.window.focusedWindow()
  if not win then return end

  local f = win:frame()
  local cx, cy = f.x + f.w/2, f.y + f.h/2  -- center of current window

  local candidates = {}
  local visibleWindows = getVisibleWindows()  -- already in z-order (front to back)
  for zOrder, w in ipairs(visibleWindows) do
    if w:id() ~= win:id() then
      local wf = w:frame()

      -- Skip windows that overlap with current window
      if not windowsOverlap(f, wf) then
        local wcx, wcy = wf.x + wf.w/2, wf.y + wf.h/2  -- center of candidate

        local dx, dy = wcx - cx, wcy - cy
        local dominated = false  -- is the candidate primarily in the right direction?

        -- Check if candidate is in the correct direction (must be MORE in that direction than perpendicular)
        if direction == "west" and dx < 0 and math.abs(dx) > math.abs(dy) then
          dominated = true
        elseif direction == "east" and dx > 0 and math.abs(dx) > math.abs(dy) then
          dominated = true
        elseif direction == "north" and dy < 0 and math.abs(dy) > math.abs(dx) then
          dominated = true
        elseif direction == "south" and dy > 0 and math.abs(dy) > math.abs(dx) then
          dominated = true
        end

        if dominated then
          local dist = math.sqrt(dx*dx + dy*dy)
          table.insert(candidates, {window = w, distance = dist, zOrder = zOrder})
        end
      end
    end
  end

  -- Sort by distance, then by z-order (prefer frontmost when distances are similar)
  table.sort(candidates, function(a, b)
    -- If distances differ by more than 50px, sort by distance
    if math.abs(a.distance - b.distance) > 50 then
      return a.distance < b.distance
    end
    -- Otherwise prefer frontmost (lower z-order)
    return a.zOrder < b.zOrder
  end)
  if #candidates > 0 then
    candidates[1].window:focus()
  end
end

hs.hotkey.bind({"alt"}, 'h', function() focusWindowInDirection("west") end)
hs.hotkey.bind({"alt"}, 'j', function() focusWindowInDirection("south") end)
hs.hotkey.bind({"alt"}, 'k', function() focusWindowInDirection("north") end)
hs.hotkey.bind({"alt"}, 'l', function() focusWindowInDirection("east") end)

-- Obsidian: Toggle terminal with Cmd+Shift+J (only when Obsidian is focused)
-- DISABLED: blocking cmd+shift+j in other apps like iTerm2
-- hs.hotkey.bind({"cmd", "shift"}, "j", function()
--     local app = hs.application.frontmostApplication()
--     if app and app:name() == "Obsidian" then
--         local js = "const l=app.workspace.getLeavesOfType('terminal:terminal');if(l.length>0){l.forEach(x=>x.detach())}else{app.commands.executeCommandById('terminal:open-terminal.integrated.current')}"
--         hs.urlevent.openURL("obsidian://advanced-uri?vault=Work&eval=" .. hs.http.encodeForQuery(js))
--     end
-- end)

-- Hyper+P: Toggle Control Center
hs.hotkey.bind(hyper, 'm', function()  -- Hyper+M: Toggle Control Center
    local app = hs.application.get("com.apple.controlcenter")
    if not app then return end
    local axApp = hs.axuielement.applicationElement(app)
    local menuBar = axApp:attributeValue("AXExtrasMenuBar")
    if not menuBar then return end
    local children = menuBar:attributeValue("AXChildren")
    if not children then return end
    for _, item in ipairs(children) do
        if item:attributeValue("AXDescription") == "Control Center" then
            item:performAction("AXPress")
            return
        end
    end
end)

-- yeah strings
function interp(s, tab)
  return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end
getmetatable("").__mod = interp
