-- defines for window maximize toggler
local frameCache = {}

-- Global helper to get visible, standard, non-minimized windows
-- Includes Hammerspoon console which isn't in orderedWindows by default
function getVisibleWindows()
    local wins = hs.fnutils.filter(hs.window.orderedWindows(), function(w)
        return w:isStandard() and w:isVisible() and not w:isMinimized()
    end)

    -- Include Hammerspoon console if visible
    local console = hs.console.hswindow()
    if console and console:isVisible() then
        table.insert(wins, console)
    end

    return wins
end

--
-- Window position cycling (left/right sides)
-- Left: hyper+h cycles Left Half → Top-Left → Bottom-Left → Left Half
-- Right: hyper+l cycles Right Half → Top-Right → Bottom-Right → Right Half
--

local function fuzzyEqual(a, b, tolerance)
    tolerance = tolerance or 10
    return math.abs(a - b) < tolerance
end

local function getWindowPosition(win)
    local f = win:frame()
    local screen = win:screen():frame()

    local isLeft = fuzzyEqual(f.x, screen.x)
    local isRight = fuzzyEqual(f.x, screen.x + screen.w / 2)
    local isHalfWidth = fuzzyEqual(f.w, screen.w / 2)
    local isFullHeight = fuzzyEqual(f.h, screen.h)
    local isHalfHeight = fuzzyEqual(f.h, screen.h / 2)
    local isTop = fuzzyEqual(f.y, screen.y)
    local isBottom = fuzzyEqual(f.y, screen.y + screen.h / 2)

    if isHalfWidth then
        if isLeft then
            if isFullHeight then return "left-half"
            elseif isHalfHeight and isTop then return "top-left"
            elseif isHalfHeight and isBottom then return "bottom-left"
            end
        elseif isRight then
            if isFullHeight then return "right-half"
            elseif isHalfHeight and isTop then return "top-right"
            elseif isHalfHeight and isBottom then return "bottom-right"
            end
        end
    end
    return "other"
end

function cycleWindowLeft()
    local win = hs.window.focusedWindow()
    if not win then return end

    local screen = win:screen():frame()
    local pos = getWindowPosition(win)

    if pos == "left-half" then
        -- Move to top-left quarter
        win:setFrame({x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h / 2}, 0.2)
    elseif pos == "top-left" then
        -- Move to bottom-left quarter
        win:setFrame({x = screen.x, y = screen.y + screen.h / 2, w = screen.w / 2, h = screen.h / 2}, 0.2)
    else
        -- Move to left half (from bottom-left or any other position)
        win:setFrame({x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h}, 0.2)
    end
end

function cycleWindowRight()
    local win = hs.window.focusedWindow()
    if not win then return end

    local screen = win:screen():frame()
    local pos = getWindowPosition(win)

    if pos == "right-half" then
        -- Move to top-right quarter
        win:setFrame({x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h / 2}, 0.2)
    elseif pos == "top-right" then
        -- Move to bottom-right quarter
        win:setFrame({x = screen.x + screen.w / 2, y = screen.y + screen.h / 2, w = screen.w / 2, h = screen.h / 2}, 0.2)
    else
        -- Move to right half (from bottom-right or any other position)
        win:setFrame({x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h}, 0.2)
    end
end

--
-- 3-App Layout: Main app left, two apps stacked right
-- Press again to rotate windows counter-clockwise
--
-- Detect position for left-main layout (hyper+2)
local function isInLeftMainLayout(win, screen)
    local f = win:frame()
    local midX = screen.x + screen.w / 2
    local midY = screen.y + screen.h / 2

    -- Check 5 points: center + 4 corners (inset slightly)
    local inset = 20
    local points = {
        {x = f.x + f.w / 2, y = f.y + f.h / 2},
        {x = f.x + inset, y = f.y + inset},
        {x = f.x + f.w - inset, y = f.y + inset},
        {x = f.x + inset, y = f.y + f.h - inset},
        {x = f.x + f.w - inset, y = f.y + f.h - inset},
    }

    local leftCount, rightCount, topCount, bottomCount = 0, 0, 0, 0
    for _, p in ipairs(points) do
        if p.x < midX then leftCount = leftCount + 1 else rightCount = rightCount + 1 end
        if p.y < midY then topCount = topCount + 1 else bottomCount = bottomCount + 1 end
    end

    local inLeftSide = leftCount >= 3
    local inRightSide = rightCount >= 3
    local inTopSide = topCount >= 3
    local inBottomSide = bottomCount >= 3

    local isWideEnough = f.w > screen.w * 0.4
    local isFullHeight = f.h > screen.h * 0.75
    local isHalfHeight = f.h > screen.h * 0.35 and f.h < screen.h * 0.65

    if inLeftSide and isWideEnough and isFullHeight then
        return "left"
    elseif inRightSide and isWideEnough and isHalfHeight and inTopSide then
        return "top-right"
    elseif inRightSide and isWideEnough and isHalfHeight and inBottomSide then
        return "bottom-right"
    else
        return nil
    end
end

-- Detect position for right-main layout (hyper+3)
function isInRightMainLayout(win, screen)
    local f = win:frame()
    local midX = screen.x + screen.w / 2
    local midY = screen.y + screen.h / 2

    local inset = 20
    local points = {
        {x = f.x + f.w / 2, y = f.y + f.h / 2},
        {x = f.x + inset, y = f.y + inset},
        {x = f.x + f.w - inset, y = f.y + inset},
        {x = f.x + inset, y = f.y + f.h - inset},
        {x = f.x + f.w - inset, y = f.y + f.h - inset},
    }

    local leftCount, rightCount, topCount, bottomCount = 0, 0, 0, 0
    for _, p in ipairs(points) do
        if p.x < midX then leftCount = leftCount + 1 else rightCount = rightCount + 1 end
        if p.y < midY then topCount = topCount + 1 else bottomCount = bottomCount + 1 end
    end

    local inLeftSide = leftCount >= 3
    local inRightSide = rightCount >= 3
    local inTopSide = topCount >= 3
    local inBottomSide = bottomCount >= 3

    local isWideEnough = f.w > screen.w * 0.4
    local isFullHeight = f.h > screen.h * 0.75
    local isHalfHeight = f.h > screen.h * 0.35 and f.h < screen.h * 0.65

    if inRightSide and isWideEnough and isFullHeight then
        return "right"
    elseif inLeftSide and isWideEnough and isHalfHeight and inTopSide then
        return "top-left"
    elseif inLeftSide and isWideEnough and isHalfHeight and inBottomSide then
        return "bottom-left"
    else
        return nil
    end
end

-- Legacy alias for backward compatibility
local function isInThreeAppLayout(win, screen)
    local f = win:frame()

    -- Screen midpoints
    local midX = screen.x + screen.w / 2
    local midY = screen.y + screen.h / 2

    -- Check 5 points: center + 4 corners (inset slightly to avoid edge issues)
    local inset = 20
    local points = {
        {x = f.x + f.w / 2, y = f.y + f.h / 2},           -- center
        {x = f.x + inset, y = f.y + inset},               -- top-left corner
        {x = f.x + f.w - inset, y = f.y + inset},         -- top-right corner
        {x = f.x + inset, y = f.y + f.h - inset},         -- bottom-left corner
        {x = f.x + f.w - inset, y = f.y + f.h - inset},   -- bottom-right corner
    }

    -- Count how many points are in each region
    local leftCount, rightCount = 0, 0
    local topCount, bottomCount = 0, 0

    for _, p in ipairs(points) do
        if p.x < midX then leftCount = leftCount + 1 else rightCount = rightCount + 1 end
        if p.y < midY then topCount = topCount + 1 else bottomCount = bottomCount + 1 end
    end

    -- Require majority (3+ of 5 points) in a region
    local inLeftSide = leftCount >= 3
    local inRightSide = rightCount >= 3
    local inTopSide = topCount >= 3
    local inBottomSide = bottomCount >= 3

    -- Check if window roughly fills its expected area
    local isWideEnough = f.w > screen.w * 0.4
    local isFullHeight = f.h > screen.h * 0.75
    local isHalfHeight = f.h > screen.h * 0.35 and f.h < screen.h * 0.65

    if inLeftSide and isWideEnough and isFullHeight then
        return "left"
    elseif inRightSide and isWideEnough and isHalfHeight and inTopSide then
        return "top-right"
    elseif inRightSide and isWideEnough and isHalfHeight and inBottomSide then
        return "bottom-right"
    else
        return nil
    end
end

-- Smart position assignment: minimize total window movement
-- Compute distance from window center to target rect center
function windowToRectDistance(win, rect)
    local f = win:frame()
    local winCx = f.x + f.w / 2
    local winCy = f.y + f.h / 2
    local rectCx = rect.x + rect.w / 2
    local rectCy = rect.y + rect.h / 2
    return math.sqrt((winCx - rectCx)^2 + (winCy - rectCy)^2)
end

-- Greedy assignment: assign windows to positions minimizing total distance
-- Returns table mapping position index -> window
function assignWindowsToPositions(windows, positions)
    local assignments = {}
    local usedWindows = {}

    -- Build distance matrix
    local distances = {}
    for i, pos in ipairs(positions) do
        distances[i] = {}
        for j, win in ipairs(windows) do
            distances[i][j] = windowToRectDistance(win, pos)
        end
    end

    -- Greedy: repeatedly assign the closest (position, window) pair
    for _ = 1, math.min(#windows, #positions) do
        local bestDist = math.huge
        local bestPos, bestWin = nil, nil

        for posIdx, dists in pairs(distances) do
            if not assignments[posIdx] then
                for winIdx, dist in pairs(dists) do
                    if not usedWindows[winIdx] and dist < bestDist then
                        bestDist = dist
                        bestPos = posIdx
                        bestWin = winIdx
                    end
                end
            end
        end

        if bestPos and bestWin then
            assignments[bestPos] = windows[bestWin]
            usedWindows[bestWin] = true
        end
    end

    return assignments
end

-- Debug: show current window layout
function showWindowLayout()
    local wins = hs.window.orderedWindows()
    local scr = hs.screen.mainScreen():frame()
    local midX = scr.x + scr.w / 2
    local midY = scr.y + scr.h / 2
    local currentScreen = hs.screen.mainScreen()

    print("=== WINDOW LAYOUT ===")
    local count = 0
    for i, w in ipairs(wins) do
        if w:isStandard() and w:screen():id() == currentScreen:id() then
            count = count + 1
            if count > 6 then break end
            local f = w:frame()
            local cx = f.x + f.w/2
            local cy = f.y + f.h/2
            local app = w:application():name()
            local side = cx < midX and "LEFT" or "RIGHT"
            local vert = cy < midY and "TOP" or "BOT"
            local heightPct = math.floor(f.h / scr.h * 100)
            local posL = isInLeftMainLayout(w, scr) or "-"
            local posR = isInRightMainLayout(w, scr) or "-"
            print(count .. ". " .. app .. " [L:" .. posL .. " R:" .. posR .. "] " .. side .. "/" .. vert .. " " .. heightPct .. "%h")
        end
    end
    print("=====================")
end

-- hyper+2: Main app LEFT, two stacked RIGHT
function threeAppLayoutLeft()
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

    if #windows < 3 then
        hs.alert.show("Need 3 windows for this layout")
        return
    end

    -- Find windows in each position (frontmost only)
    local leftWin, topRightWin, bottomRightWin = nil, nil, nil
    for _, w in ipairs(windows) do
        local pos = isInLeftMainLayout(w, screen)
        if pos == "left" and not leftWin then
            leftWin = w
        elseif pos == "top-right" and not topRightWin then
            topRightWin = w
        elseif pos == "bottom-right" and not bottomRightWin then
            bottomRightWin = w
        end
    end

    -- Define target positions
    local positions = {
        {x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h},                          -- left (main)
        {x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h / 2},       -- top-right
        {x = screen.x + screen.w / 2, y = screen.y + screen.h / 2, w = screen.w / 2, h = screen.h / 2}, -- bottom-right
    }

    -- If all 3 positions filled, rotate counter-clockwise
    if leftWin and topRightWin and bottomRightWin then
        local oldLeft, oldTopRight, oldBottomRight = leftWin, topRightWin, bottomRightWin

        -- Rotate: top-right→left, bottom-right→top-right, left→bottom-right
        oldTopRight:setFrame(positions[1], 0.2)
        oldBottomRight:setFrame(positions[2], 0.2)
        oldLeft:setFrame(positions[3], 0.2)

        oldTopRight:focus()
    else
        -- Smart assignment: each window goes to closest position
        local layoutWindows = {windows[1], windows[2], windows[3]}
        local assignments = assignWindowsToPositions(layoutWindows, positions)

        for posIdx, win in pairs(assignments) do
            win:setFrame(positions[posIdx], 0.2)
        end

        if assignments[1] then assignments[1]:focus() end
    end
end

-- hyper+3: Main app RIGHT, two stacked LEFT
function threeAppLayoutRight()
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

    if #windows < 3 then
        hs.alert.show("Need 3 windows for this layout")
        return
    end

    -- Find windows in each position (frontmost only)
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

    -- Define target positions
    local positions = {
        {x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h},           -- right (main)
        {x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h / 2},                      -- top-left
        {x = screen.x, y = screen.y + screen.h / 2, w = screen.w / 2, h = screen.h / 2},       -- bottom-left
    }

    -- If all 3 positions filled, rotate counter-clockwise
    if rightWin and topLeftWin and bottomLeftWin then
        local oldRight, oldTopLeft, oldBottomLeft = rightWin, topLeftWin, bottomLeftWin

        -- Rotate: top-left→right, bottom-left→top-left, right→bottom-left
        oldTopLeft:setFrame(positions[1], 0.2)
        oldBottomLeft:setFrame(positions[2], 0.2)
        oldRight:setFrame(positions[3], 0.2)

        oldTopLeft:focus()
    else
        -- Smart assignment: each window goes to closest position
        local layoutWindows = {windows[1], windows[2], windows[3]}
        local assignments = assignWindowsToPositions(layoutWindows, positions)

        for posIdx, win in pairs(assignments) do
            win:setFrame(positions[posIdx], 0.2)
        end

        if assignments[1] then assignments[1]:focus() end
    end
end

-- Alias for backward compatibility
function threeAppLayout()
    threeAppLayoutLeft()
end

--
-- 4-App Quarters Layout (hyper+1)
-- Press once to arrange 4 windows in quarters, press again to rotate clockwise
-- Clockwise: top-left → top-right → bottom-right → bottom-left → top-left
--

function isInQuarterPosition(win, screen)
    local f = win:frame()
    local midX = screen.x + screen.w / 2
    local midY = screen.y + screen.h / 2

    local inset = 20
    local points = {
        {x = f.x + f.w / 2, y = f.y + f.h / 2},
        {x = f.x + inset, y = f.y + inset},
        {x = f.x + f.w - inset, y = f.y + inset},
        {x = f.x + inset, y = f.y + f.h - inset},
        {x = f.x + f.w - inset, y = f.y + f.h - inset},
    }

    local leftCount, rightCount, topCount, bottomCount = 0, 0, 0, 0
    for _, p in ipairs(points) do
        if p.x < midX then leftCount = leftCount + 1 else rightCount = rightCount + 1 end
        if p.y < midY then topCount = topCount + 1 else bottomCount = bottomCount + 1 end
    end

    local inLeftSide = leftCount >= 3
    local inRightSide = rightCount >= 3
    local inTopSide = topCount >= 3
    local inBottomSide = bottomCount >= 3

    local isHalfWidth = f.w > screen.w * 0.35 and f.w < screen.w * 0.65
    local isHalfHeight = f.h > screen.h * 0.35 and f.h < screen.h * 0.65

    if isHalfWidth and isHalfHeight then
        if inLeftSide and inTopSide then return "top-left"
        elseif inRightSide and inTopSide then return "top-right"
        elseif inRightSide and inBottomSide then return "bottom-right"
        elseif inLeftSide and inBottomSide then return "bottom-left"
        end
    end
    return nil
end

function fourAppLayoutQuarters()
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

    if #windows < 4 then
        hs.alert.show("Need 4 windows for quarters layout")
        return
    end

    -- Define quarter positions (clockwise order: TL=1, TR=2, BR=3, BL=4)
    local positions = {
        {x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h / 2},                          -- 1: top-left
        {x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h / 2},           -- 2: top-right
        {x = screen.x + screen.w / 2, y = screen.y + screen.h / 2, w = screen.w / 2, h = screen.h / 2}, -- 3: bottom-right
        {x = screen.x, y = screen.y + screen.h / 2, w = screen.w / 2, h = screen.h / 2},           -- 4: bottom-left
    }

    -- Find windows in each quarter position (frontmost only)
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
        -- Clockwise rotation: TL→TR, TR→BR, BR→BL, BL→TL
        topLeftWin:setFrame(positions[2], 0.2)      -- TL → TR
        topRightWin:setFrame(positions[3], 0.2)    -- TR → BR
        bottomRightWin:setFrame(positions[4], 0.2) -- BR → BL
        bottomLeftWin:setFrame(positions[1], 0.2)  -- BL → TL

        -- Focus the window that moved to top-left
        bottomLeftWin:focus()
    else
        -- Smart assignment: each window goes to closest position
        local layoutWindows = {windows[1], windows[2], windows[3], windows[4]}
        local assignments = assignWindowsToPositions(layoutWindows, positions)

        for posIdx, win in pairs(assignments) do
            win:setFrame(positions[posIdx], 0.2)
        end

        if assignments[1] then assignments[1]:focus() end
    end
end

function sunset()
  hs.location.start()
  local loc = hs.location.get()
  hs.location.stop()

  local sunset = hs.location.sunset(loc.latitude, loc.longitude, (os.date("%z") * 1) / 100)
  return os.date("%c", sunset)
end

function sunrise()
  hs.location.start()
  local loc = hs.location.get()
  hs.location.stop()

  local sunrise = hs.location.sunrise(loc.latitude, loc.longitude, (os.date("%z") * 1) / 100)
  return os.date("%c", sunrise)
end

-- toggle a window between centered, and being maximized
function toggleWindowMaximized()
    local win = hs.window.focusedWindow()
    if frameCache[win:id()] then
        centerWindow()
        frameCache[win:id()] = nil
    else
        frameCache[win:id()] = win:frame()
        win:maximize()
    end
end

function toggleWindowScreen()
  local currentWindow = hs.window.focusedWindow()
  currentWindow:moveToScreen(currentWindow:screen():next())
end

function centerWindow()
  local win = hs.window.focusedWindow()
  local currentWindow = win:frame()
  local currentScreen = win:screen():frame()

  local log = hs.logger.new('init','info')
  -- center to 80% of the w & h
  currentWindow.w = currentScreen.w * 0.8
  currentWindow.h = currentScreen.h * 0.8

  win:setFrame(currentWindow)
  win:centerOnScreen()
end

-- Toggle an application between being the frontmost app, and being hidden
function toggleApplication(_app)
  local log = hs.logger.new('init','info')
  local app = hs.appfinder.appFromName(_app)
  if not app then
    smartLaunchOrFocus({_app})
  else
    local mainwin = app:mainWindow()
    log.i(mainwin)
    if not mainwin then
      -- log.i("No window")
      hs.application.launchOrFocus(_app)
    elseif mainwin and mainwin ~= hs.window.focusedWindow() then
      -- log.i("Has a window but not focused")
      hs.application.launchOrFocus(_app)
    else
      app:hide()
    end
  end
end

local launchTimer = nil
function forceLaunchOrFocus(appName)
  -- first focus with hammerspoon
  hs.application.launchOrFocus(appName)

  -- clear timer if exists
  if launchTimer then launchTimer:stop() end

  -- wait 500ms for window to appear and try hard to show the window
  launchTimer = hs.timer.doAfter(0.5, function()
    local frontmostApp     = hs.application.frontmostApplication()
    local frontmostWindows = hs.fnutils.filter(frontmostApp:allWindows(), function(win) return win:isStandard() end)

    -- break if this app is not frontmost (when/why?)
    if frontmostApp:title() ~= appName then
      print('Expected app in front: ' .. appName .. ' got: ' .. frontmostApp:title())
      return
    end

    if #frontmostWindows == 0 then
      -- check if there's app name in window menu (Calendar, Messages, etc...)
      if frontmostApp:findMenuItem({ 'Window', appName }) then
        -- select it, usually moves to space with this window
        frontmostApp:selectMenuItem({ 'Window', appName })
      else
        -- otherwise send cmd-n to create new window
        hs.eventtap.keyStroke({ 'cmd' }, 'n')
      end
    end
  end)
end

-- smart app launch or focus or cycle windows
function smartLaunchOrFocus(launchApps)
  local frontmostWindow = hs.window.frontmostWindow()
  local runningApps     = hs.application.runningApplications()
  local runningWindows  = {}

  -- filter running applications by apps array
  local runningApps = hs.fnutils.map(launchApps, function(launchApp)
    return hs.application.get(launchApp)
  end)

  -- create table of sorted windows per application
  hs.fnutils.each(runningApps, function(runningApp)
    local standardWindows = hs.fnutils.filter(runningApp:allWindows(), function(win)
      return win:isStandard()
    end)

    table.sort(standardWindows, function(a, b) return a:id() < b:id() end)

    runningWindows = standardWindows
  end)

  if #runningApps == 0 then
    -- if no apps are running then launch first one in list
    forceLaunchOrFocus(launchApps[1])
  elseif #runningWindows == 0 then
    -- if some apps are running, but no windows - force create one
    forceLaunchOrFocus(runningApps[1]:title())
  else
    -- check if one of windows is already focused
    local currentIndex = hs.fnutils.indexOf(runningWindows, frontmostWindow)

    if not currentIndex then
      -- if none of them is selected focus the first one
      runningWindows[1]:focus()
    else
      -- otherwise cycle through all the windows
      local newIndex = currentIndex + 1
      if newIndex > #runningWindows then newIndex = 1 end

      runningWindows[newIndex]:focus()
    end
  end
end
