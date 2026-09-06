-- ══════════════════════════════════════════════════════════════
-- UI LIBRARY LOADER — in jedes Script einfügen, das die Lib nutzt
-- 1. LIB_URL  → Codeberg-URL deines lib.enc-Blobs
-- 2. LIB_KEY  → MUSS exakt dem KEY aus encrypt.js entsprechen
-- 3. LIB_AUTH → MUSS exakt dem AUTH aus encrypt.js entsprechen
-- ══════════════════════════════════════════════════════════════

local LIB_URL  = "https://codeberg.org/leon232hie/OxideUiLibary/raw/branch/main/lib.enc"  -- ← eintragen
local LIB_KEY  = "Buffy-Lib-2026-XyZ!"   -- ← KEY aus encrypt.js
local LIB_AUTH = "UltraGeheim42"         -- ← AUTH aus encrypt.js

-- Base64 Decode (pure Lua)
local function b64decode(s)
    local map, alphabet = {}, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #alphabet do map[alphabet:sub(i, i)] = i - 1 end
    local out, n = {}, 0
    for i = 1, #s, 4 do
        local a, b = map[s:sub(i, i)], map[s:sub(i + 1, i + 1)]
        local c, d = map[s:sub(i + 2, i + 2)], map[s:sub(i + 3, i + 3)]
        if a and b then
            n = n + 1; out[n] = string.char(a * 4 + math.floor(b / 16))
            if c then
                n = n + 1; out[n] = string.char((b % 16) * 16 + math.floor(c / 4))
                if d then
                    n = n + 1; out[n] = string.char((c % 4) * 64 + d)
                end
            end
        end
    end
    return table.concat(out)
end

-- XOR entschlüsseln (exakt wie encrypt.js)
local function xorDecrypt(b64, key)
    local data = b64decode(b64)
    local out, kl = {}, #key
    for i = 1, #data do
        out[i] = string.char(bit32.bxor(data:byte(i), key:byte(((i - 1) % kl) + 1)))
    end
    return table.concat(out)
end

-- Blob holen + entschlüsseln + ausführen
local ok, source = pcall(function()
    local http = game:GetService("HttpService")
    return xorDecrypt(http:GetAsync(LIB_URL, true, { ["X-Auth"] = LIB_AUTH }), LIB_KEY)
end)
if not ok then
    ok, source = pcall(function()
        return xorDecrypt(game:HttpGet(LIB_URL, { Headers = { ["X-Auth"] = LIB_AUTH } }), LIB_KEY)
    end)
end
assert(ok and source, "UI Library konnte nicht geladen werden: " .. tostring(ok))

local chunk, compileErr = loadstring(source)
assert(chunk, "UI Library failed to compile: " .. tostring(compileErr))

local Library = chunk()
