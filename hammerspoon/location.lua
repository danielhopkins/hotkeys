-- Home detection via WiFi SSID or GPS location
-- Config via environment variables: HOME_SSIDS (comma-separated), HOME_LAT, HOME_LON

local M = {}

-- Read config from environment (set in fish config)
local function getEnv(name) return os.getenv(name) end

local function parseSSIDs()
    local raw = getEnv("HOME_SSIDS")
    if not raw then return {} end
    local ssids = {}
    for s in raw:gmatch("[^,]+") do
        table.insert(ssids, s:match("^%s*(.-)%s*$")) -- trim whitespace
    end
    return ssids
end

M.homeSSIDs = parseSSIDs()
M.homeLat = tonumber(getEnv("HOME_LAT")) or 0
M.homeLon = tonumber(getEnv("HOME_LON")) or 0
M.homeRadiusMeters = 200

local function haversineDistance(lat1, lon1, lat2, lon2)
    local R = 6371000 -- earth radius in meters
    local dLat = math.rad(lat2 - lat1)
    local dLon = math.rad(lon2 - lon1)
    local a = math.sin(dLat / 2) ^ 2 +
              math.cos(math.rad(lat1)) * math.cos(math.rad(lat2)) *
              math.sin(dLon / 2) ^ 2
    return R * 2 * math.atan(math.sqrt(a), math.sqrt(1 - a))
end

function M.isHomeSSID()
    local ssid = hs.wifi.currentNetwork()
    if not ssid then return false end
    for _, pattern in ipairs(M.homeSSIDs) do
        if pattern:sub(-1) == "*" then
            if ssid:sub(1, #pattern - 1) == pattern:sub(1, -2) then return true end
        else
            if ssid == pattern then return true end
        end
    end
    return false
end

function M.isHomeLocation()
    if M.homeLat == 0 and M.homeLon == 0 then return nil end
    local loc = hs.location.get()
    if not loc then return nil end -- nil = unknown (no location data)
    local dist = haversineDistance(loc.latitude, loc.longitude, M.homeLat, M.homeLon)
    return dist <= M.homeRadiusMeters
end

-- Check both: SSID first (fast/reliable), fall back to GPS
function M.isHome()
    if M.isHomeSSID() then return true end
    local locResult = M.isHomeLocation()
    if locResult ~= nil then return locResult end
    return false
end

-- Start location services (call once at startup)
function M.startLocation()
    hs.location.start()
end

return M
