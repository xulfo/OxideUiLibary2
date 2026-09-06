-- ══════════════════════════════════════════════════════════════════════════════
-- OXIDE HUB — Premium Gate (paid loadstring entry)
-- Premium key validation is served by the Deno Deploy API.
-- 1. Reads the key (embedded via _G.OxidePremiumKey, or typed).
-- 2. Fetches the device HWID automatically (never typed by the user).
-- 3. Activates via the backend key API (/redeem). 1 key = 1 HWID.
--    - First device to redeem locks the key.
--    - A different device gets KICKED from the game and blacklisted.
-- 4. On success, pulls the PREMIUM script from the gated /content endpoint
--    (the script is NOT publicly downloadable), loads the UI library, and runs it.
--
-- Personal loadstring (issued by the Discord bot):
--   _G.OxidePremiumKey = "OXIDE-XXXX-XXXX-XXXX" loadstring(game:HttpGet("https://codeberg.org/leon232hie/oxide-premium/raw/branch/main/PremiumGate.lua"))()
-- ══════════════════════════════════════════════════════════════════════════════

local CFG = {
    KEY_API      = "https://oxide-premium-api.xulfo.deno.net",
    LIB_URL      = "https://raw.githubusercontent.com/xulfo/OxideUiLibary2/main/UiLibary/Libary.lua",
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer

local function log(...)
    print("[OxidePremiumGate]", ...)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- STATUS OVERLAY — always visible (embedded-key mode included), so a failure
-- is never silent. Shows "activating…", then success/error, then disappears.
-- ══════════════════════════════════════════════════════════════════════════════
local statusGui, statusLabel
local function ensureStatusGui()
    if statusGui and statusGui.Parent then return end
    local playerGui = lp and lp:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        playerGui = lp and lp:WaitForChild("PlayerGui")
    end
    if not playerGui then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "OxidePremiumStatus"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    sg.Parent = playerGui
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 320, 0, 26)
    lbl.Position = UDim2.new(1, -330, 0, 12)
    lbl.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
    lbl.BackgroundTransparency = 0.2
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(220, 224, 230)
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Text = "OXIDE Premium — connecting…"
    lbl.Parent = sg
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
    statusGui = sg
    statusLabel = lbl
end

local function setStatusText(msg, good)
    ensureStatusGui()
    if statusLabel then
        statusLabel.Text = msg
        statusLabel.TextColor3 = good and Color3.fromRGB(120, 200, 120) or Color3.fromRGB(255, 120, 120)
    end
    log(msg)
end

local function clearStatusGui()
    if statusGui then
        pcall(function() statusGui:Destroy() end)
        statusGui, statusLabel = nil, nil
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- HWID — fetched automatically
-- ══════════════════════════════════════════════════════════════════════════════
local function djb2(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 4294967296
    end
    return string.format("%08x", h)
end

local function getHWID()
    local ok, cid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and type(cid) == "string" and #cid > 0 then
        return djb2("rbx:" .. cid)
    end
    local ok2, ex = pcall(function() return identifyexecutor() end)
    if ok2 and type(ex) == "string" and #ex > 0 then
        return djb2("exec:" .. ex)
    end
    return djb2("uid:" .. tostring(lp and lp.UserId or 0))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- HTTP — tries the common executor request globals, then GET fallbacks.
-- ══════════════════════════════════════════════════════════════════════════════
local function httpRequest(opts)
    -- build the candidate list safely: `syn` may not exist on most executors
    local candidates = { request, http_request }
    if type(syn) == "table" and type(syn.request) == "function" then
        candidates[#candidates + 1] = syn.request
    end
    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then
            local ok, res = pcall(fn, opts)
            if ok and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
                return res
            end
        end
    end
    return nil
end

local function callAPI(path, params)
    -- POST via executor request() (the API accepts POST for every route)
    local res = httpRequest({
        Url = CFG.KEY_API .. path,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(params),
    })
    if res then
        local okj, parsed = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if okj and type(parsed) == "table" then return parsed end
    end

    -- GET fallback (the API accepts GET for /redeem, /check, /content)
    local q = {}
    for k, v in pairs(params) do
        table.insert(q, k .. "=" .. HttpService:UrlEncode(tostring(v)))
    end
    local url = CFG.KEY_API .. path .. "?" .. table.concat(q, "&")
    local okg, body = pcall(game.HttpGet, game, url)
    if okg and type(body) == "string" then
        local okj, parsed = pcall(HttpService.JSONDecode, HttpService, body)
        if okj and type(parsed) == "table" then return parsed end
    end
    return nil
end

local function kickFromGame(msg)
    pcall(function() lp:Kick(msg) end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LIBRARY LOADER (download raw source → loadstring → execute)
-- Fully open source: the library is served as plain Lua, no encryption.
-- ══════════════════════════════════════════════════════════════════════════════
local function FetchText(url)
    local res = httpRequest({ Url = url, Method = "GET" })
    if res and res.StatusCode == 200 and type(res.Body) == "string" and #res.Body >= 100 then
        return true, res.Body
    end
    local ok, src = pcall(game.HttpGet, game, url)
    if ok and type(src) == "string" and #src >= 100 then
        return true, src
    end
    return false, nil
end

local function LoadLibrary()
    local libUrl = CFG.LIB_URL
    local ok, source = FetchText(libUrl)
    if not ok then
        return nil, "Failed to download library source."
    end
    local chunk, compileErr = loadstring(source)
    if not chunk then
        return nil, "Library compile error: " .. tostring(compileErr)
    end
    local ok2, lib = pcall(chunk)
    if not ok2 then
        return nil, "Library execution error: " .. tostring(lib)
    end
    if type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        return nil, "Library has no CreateWindow."
    end
    return lib, nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- BASIC UI (standalone — no library dependency before the key is verified)
-- ══════════════════════════════════════════════════════════════════════════════
local gateStatusLabel
local function buildUI(hwid, onSubmit, autoKey)
    local sg = Instance.new("ScreenGui")
    sg.Name = "OxidePremiumGate"
    sg.ResetOnSpawn = false
    sg.Parent = lp:FindFirstChildOfClass("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 190)
    frame.Position = UDim2.new(0.5, -160, 0.5, -95)
    frame.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 28)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(129, 163, 214)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "OXIDE — Premium Access"
    title.Parent = frame

    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, -32, 0, 34)
    keyBox.Position = UDim2.new(0, 16, 0, 52)
    keyBox.BackgroundColor3 = Color3.fromRGB(34, 36, 42)
    keyBox.BorderSizePixel = 0
    keyBox.Font = Enum.Font.Code
    keyBox.TextSize = 14
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.PlaceholderText = "OXIDE-XXXX-XXXX-XXXX"
    keyBox.PlaceholderColor3 = Color3.fromRGB(120, 124, 132)
    keyBox.Text = ""
    keyBox.Parent = frame
    Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 6)

    local hwidLabel = Instance.new("TextLabel")
    hwidLabel.Size = UDim2.new(1, -32, 0, 20)
    hwidLabel.Position = UDim2.new(0, 16, 0, 92)
    hwidLabel.BackgroundTransparency = 1
    hwidLabel.Font = Enum.Font.Gotham
    hwidLabel.TextSize = 11
    hwidLabel.TextColor3 = Color3.fromRGB(140, 144, 152)
    hwidLabel.TextXAlignment = Enum.TextXAlignment.Left
    hwidLabel.Text = "HWID: " .. hwid
    hwidLabel.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -32, 0, 18)
    status.Position = UDim2.new(0, 16, 0, 130)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextColor3 = Color3.fromRGB(255, 120, 120)
    status.Text = ""
    status.Parent = frame
    gateStatusLabel = status

    local activate = Instance.new("TextButton")
    activate.Size = UDim2.new(1, -32, 0, 36)
    activate.Position = UDim2.new(0, 16, 0, 146)
    activate.BackgroundColor3 = Color3.fromRGB(129, 163, 214)
    activate.BorderSizePixel = 0
    activate.Font = Enum.Font.GothamBold
    activate.TextSize = 15
    activate.TextColor3 = Color3.fromRGB(20, 22, 26)
    activate.Text = "Activate"
    activate.Parent = frame
    Instance.new("UICorner", activate).CornerRadius = UDim.new(0, 6)

    local function setStatus(msg, good)
        status.Text = msg
        status.TextColor3 = good and Color3.fromRGB(120, 200, 120) or Color3.fromRGB(255, 120, 120)
    end

    local function submit()
        local key = keyBox.Text:gsub("%s+", ""):upper()
        if key == "" then
            setStatus("Enter your key first.", false)
            return
        end
        activate.Text = "Checking…"
        activate.AutoButtonColor = false
        onSubmit(key, setStatus)
    end

    activate.MouseButton1Click:Connect(submit)

    -- draggable
    local dragging, startPos, startMouse
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startMouse = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - startMouse
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- key embedded in the loadstring -> auto-submit, no manual typing
    if autoKey and autoKey ~= "" then
        keyBox.Text = autoKey
        task.spawn(submit)
    end
end

-- reports to the gate UI label (if present) AND the always-visible overlay
local function report(msg, good)
    if gateStatusLabel then
        gateStatusLabel.Text = msg
        gateStatusLabel.TextColor3 = good and Color3.fromRGB(120, 200, 120) or Color3.fromRGB(255, 120, 120)
    end
    setStatusText(msg, good)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- MAIN
-- ══════════════════════════════════════════════════════════════════════════════
local hwid = getHWID()

local function runPremium(content, setStatus)
    local lib, err = LoadLibrary()
    if not lib then
        if setStatus then setStatus("Key OK, but the UI library failed to load.", false) end
        return
    end
    _G.OxideLib = lib

    local fullSource = "Library = _G.OxideLib;\n" .. content
    local chunk, compileErr = loadstring(fullSource)
    if not chunk then
        if setStatus then setStatus("Premium script compile error: " .. tostring(compileErr), false) end
        return
    end
    local ok, runErr = pcall(chunk)
    if not ok then
        if setStatus then setStatus("Premium script runtime error: " .. tostring(runErr), false) end
    else
        clearStatusGui()
    end
end

local function activate(key, setStatus)
    setStatus("Activating…", true)
    local res = callAPI("/redeem", { key = key, hwid = hwid })
    if not res then
        -- one retry: some executors' HTTP proxy needs a moment after join
        task.wait(1)
        res = callAPI("/redeem", { key = key, hwid = hwid })
    end
    if not res then
        setStatus("Could not reach the key server. Retry.", false)
        return
    end

    if res.ok then
        setStatus("Activated! Loading…", true)
        -- fetch the premium script (gated, not publicly downloadable)
        local contentRes = callAPI("/content", { key = key, hwid = hwid, place = tostring(game.PlaceId) })
        if contentRes and contentRes.ok and type(contentRes.content) == "string" then
            runPremium(contentRes.content, setStatus)
        else
            local err = contentRes and contentRes.error or "Could not load premium content."
            setStatus(err, false)
        end
    elseif res.status == "blacklisted" then
        kickFromGame("OXIDE: This key is locked to another device. You have been blacklisted.")
    else
        setStatus(res.error or "Invalid key.", false)
    end
end

local embedded = _G.OxidePremiumKey
if embedded and embedded ~= "" then
    -- Key came from the loadstring → activate silently in the background;
    -- the status overlay shows progress, the hub window is the only UI on success.
    task.spawn(function()
        local ok, err = pcall(function() activate(embedded, report) end)
        if not ok then
            report("Error: " .. tostring(err), false)
        end
    end)
else
    buildUI(hwid, activate, nil)
end
