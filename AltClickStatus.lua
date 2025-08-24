-- Alt-Click Status v0.2.1 (Classic Era + ElvUI)
-- Fix: Do not hook 'ActionButton_OnClick' globally (not a function on some Classic builds).
-- Instead, explicitly HookScript() known Blizzard bar buttons + ElvUI buttons.

local A = CreateFrame("Frame", "AltClickStatusFrame")

-- -------------------------------
-- Config
-- -------------------------------
A.CHANNEL_MODE = "AUTO" -- AUTO | SAY | PARTY | RAID
A.THROTTLE_SEC = 0.75
A.ENABLE_ACTIONBAR = true
A.ENABLE_UNITFRAMES = true
A.ENABLE_ELVUI_HOOKS = true
A.DEBUG = false

local function dprint(...)
    if A.DEBUG then print("|cff99ccff[ACS]|r", ...) end
end

-- -------------------------------
-- Utils
-- -------------------------------
local lastSentAt = 0
local function pct(cur, max)
    if not cur or not max or max == 0 then return 0 end
    return math.floor((cur / max) * 100 + 0.5)
end

local function chooseChannel()
    if A.CHANNEL_MODE ~= "AUTO" then return A.CHANNEL_MODE end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return "SAY"
end

local function safeSend(msg)
    local now = GetTime()
    if (now - lastSentAt) < A.THROTTLE_SEC then return end
    lastSentAt = now
    local chan = chooseChannel()
    SendChatMessage(msg, chan)
end

-- Helpers
local function getSpellNameAndRank(spellToken)
    local name, sub = GetSpellInfo(spellToken), (GetSpellSubtext and GetSpellSubtext(spellToken))
    if sub and sub ~= "" then
        return string.format("%s (%s)", name or tostring(spellToken), sub)
    end
    return name or tostring(spellToken)
end

local function formatSpellStatus(spellToken)
    local name = getSpellNameAndRank(spellToken)
    local start, dur, enabled = GetSpellCooldown(spellToken)
    local charges, maxCharges, chStart, chDur = GetSpellCharges and GetSpellCharges(spellToken) or nil

    -- Global cooldown heuristic
    local gcdStart, gcdDur = GetSpellCooldown(61304)
    local onGCD = (gcdDur and gcdDur > 0 and (GetTime() < (gcdStart + gcdDur))) and true or false

    -- Range (may return nil if no target or not range-checked)
    local inRange = IsSpellInRange(spellToken, "target")
    local rangeTxt = (inRange == 1 and "In Range") or (inRange == 0 and "Out of Range") or "Range N/A"

    -- Charges take precedence
    if maxCharges and maxCharges > 1 then
        if charges and charges > 0 then
            return string.format("%s > Ready (%d/%d) · %s", name, charges, maxCharges, rangeTxt)
        else
            local remain = chStart and chDur and math.max(0, (chStart + chDur) - GetTime()) or 0
            return string.format("%s > Recharging (%.0fs) · %s", name, remain, rangeTxt)
        end
    end

    if enabled == 0 then
        return string.format("%s > Not Usable · %s", name, rangeTxt)
    end

    if start and dur and dur > 1.5 and (GetTime() < (start + dur)) then
        local remain = math.max(0, (start + dur) - GetTime())
        return string.format("%s > On Cooldown (%.0fs) · %s", name, remain, rangeTxt)
    end

    if onGCD then
        local remain = math.max(0, (gcdStart + gcdDur) - GetTime())
        return string.format("%s > On GCD (%.1fs) · %s", name, remain, rangeTxt)
    end

    return string.format("%s > Ready · %s", name, rangeTxt)
end

-- Given an ActionButton, figure out what it holds. Return spell token (id or name).
local function getSpellFromActionButton(btn)
    if not btn or not btn.action then return nil end
    local action = btn.action
    local t, id, subType = GetActionInfo(action)
    if t == "spell" and id then
        return id
    elseif t == "macro" and id then
        local name, icon, body = GetMacroInfo(id)
        if body then
            -- Try to parse a /cast line; handle conditionals, commas, and newlines
            local spell =
                body:match("/cast%s+%b[]%s*([^%c,;]+)") or
                body:match("/cast%s+([^%c,;]+)") or
                body:match("cast%s+([^%c,;]+)")
            if spell then
                spell = spell:gsub("%s+$", ""):gsub("^%s+", "")
                return spell -- allow using name as token for API calls
            end
        end
    elseif t == "item" then
        -- Future: items/trinkets via GetItemCooldown
    end
    return nil
end

-- -------------------------------
-- Action Button hook (read-only)
-- -------------------------------
local function onAnyActionClick(self, button)
    if not A.ENABLE_ACTIONBAR then return end
    if button ~= "LeftButton" then return end
    if not IsAltKeyDown() then return end
    local token = getSpellFromActionButton(self)
    if token then
        safeSend(formatSpellStatus(token))
    end
end

-- Robustly hook Blizzard bar buttons by known prefixes
local BLIZZ_BUTTON_PREFIXES = {
    "ActionButton",               -- main bar
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
}
local function hookBlizzardActionButtons()
    local hooked = 0
    for _, prefix in ipairs(BLIZZ_BUTTON_PREFIXES) do
        for i = 1, 24 do
            local btn = _G[prefix..i]
            if btn and not btn.__ACS_Hooked and btn.HookScript then
                btn:RegisterForClicks("AnyUp")
                btn:HookScript("OnClick", onAnyActionClick)
                btn.__ACS_Hooked = true
                hooked = hooked + 1
            end
        end
    end
    dprint("Hooked Blizzard buttons:", hooked)
end

-- -------------------------------
-- Unit frames Alt+Click
-- -------------------------------
local function announceUnitStatus(unit)
    if not UnitExists(unit) then return end
    local hp = UnitHealth(unit); local hpMax = UnitHealthMax(unit)
    local p = UnitPower(unit); local pMax = UnitPowerMax(unit)
    local _, pToken = UnitPowerType(unit)
    local pName = _G[pToken] or pToken or "Power"
    local hpPct = pct(hp, hpMax)
    local pPct = pct(p, pMax)
    if unit == "player" then
        safeSend(string.format("I have %d%% HP, %d%% %s.", hpPct, pPct, pName))
    else
        local name = UnitName(unit) or unit
        safeSend(string.format("%s: %d%% HP, %d%% %s.", name, hpPct, pPct, pName))
    end
end

local function playerFrameClick(self, button)
    if not A.ENABLE_UNITFRAMES then return end
    if button ~= "LeftButton" or not IsAltKeyDown() then return end
    announceUnitStatus("player")
end

local function targetFrameClick(self, button)
    if not A.ENABLE_UNITFRAMES then return end
    if button ~= "LeftButton" or not IsAltKeyDown() then return end
    announceUnitStatus("target")
end

if PlayerFrame then
    PlayerFrame:HookScript("OnMouseUp", playerFrameClick)
end
if TargetFrame then
    TargetFrame:HookScript("OnMouseUp", targetFrameClick)
end

-- -------------------------------
-- ElvUI hooks (Classic Era friendly)
-- -------------------------------
local function HookElvUI()
    if not A.ENABLE_ELVUI_HOOKS then return end
    if not IsAddOnLoaded("ElvUI") then return end
    local hooked = 0
    -- Hook ElvUI action buttons
    for bar = 1, 10 do
        for i = 1, 24 do
            local btn = _G[("ElvUI_Bar%uButton%u"):format(bar, i)]
            if btn and not btn.__ACS_Hooked and btn.HookScript then
                btn:RegisterForClicks("AnyUp")
                btn:HookScript("OnClick", onAnyActionClick)
                btn.__ACS_Hooked = true
                hooked = hooked + 1
            end
        end
    end
    dprint("Hooked ElvUI buttons:", hooked)
    -- Hook ElvUI unit frames
    local efp = _G["ElvUF_Player"]
    if efp and not efp.__ACS_Hooked and efp.HookScript then
        efp:HookScript("OnMouseUp", function(self, button)
            if not A.ENABLE_UNITFRAMES then return end
            if button == "LeftButton" and IsAltKeyDown() then announceUnitStatus("player") end
        end)
        efp.__ACS_Hooked = true
        dprint("Hooked ElvUF_Player")
    end
    local eft = _G["ElvUF_Target"]
    if eft and not eft.__ACS_Hooked and eft.HookScript then
        eft:HookScript("OnMouseUp", function(self, button)
            if not A.ENABLE_UNITFRAMES then return end
            if button == "LeftButton" and IsAltKeyDown() then announceUnitStatus("target") end
        end)
        eft.__ACS_Hooked = true
        dprint("Hooked ElvUF_Target")
    end
end

-- -------------------------------
-- Events
-- -------------------------------
A:RegisterEvent("PLAYER_LOGIN")
A:RegisterEvent("PLAYER_ENTERING_WORLD")
A:RegisterEvent("ADDON_LOADED")
A:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        local _, _, _, iface = GetBuildInfo()
        print(string.format("Alt-Click Status loaded (Interface %s). Use /acs for options.", tostring(iface or "?")))
        C_Timer.After(0, hookBlizzardActionButtons)
        C_Timer.After(0.3, HookElvUI)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, HookElvUI)
    elseif event == "ADDON_LOADED" and arg1 == "ElvUI" then
        C_Timer.After(0.2, HookElvUI)
    end
end)

-- -------------------------------
-- Slash commands
-- -------------------------------
SLASH_ALTCSTATUS1 = "/altclick"
SLASH_ALTCSTATUS2 = "/acs"
SlashCmdList["ALTCSTATUS"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "say" or msg == "party" or msg == "raid" then
        A.CHANNEL_MODE = msg:upper()
        print("Alt-Click Status: channel set to", A.CHANNEL_MODE)
        return
    elseif msg == "auto" or msg == "default" then
        A.CHANNEL_MODE = "AUTO"; print("Alt-Click Status: channel set to AUTO")
        return
    elseif msg == "toggle bar" then
        A.ENABLE_ACTIONBAR = not A.ENABLE_ACTIONBAR
        print("Alt-Click Status: action bar hooks", A.ENABLE_ACTIONBAR and "ON" or "OFF")
        return
    elseif msg == "toggle unit" then
        A.ENABLE_UNITFRAMES = not A.ENABLE_UNITFRAMES
        print("Alt-Click Status: unit frame hooks", A.ENABLE_UNITFRAMES and "ON" or "OFF")
        return
    elseif msg == "toggle elv" then
        A.ENABLE_ELVUI_HOOKS = not A.ENABLE_ELVUI_HOOKS
        print("Alt-Click Status: ElvUI hooks", A.ENABLE_ELVUI_HOOKS and "ON" or "OFF")
        return
    elseif msg == "hook elv" then
        HookElvUI(); print("Alt-Click Status: attempted ElvUI hook now.")
        return
    elseif msg == "debug on" then
        A.DEBUG = true; print("Alt-Click Status: DEBUG ON")
        return
    elseif msg == "debug off" then
        A.DEBUG = false; print("Alt-Click Status: DEBUG OFF")
        return
    end
    print("Alt-Click Status usage:")
    print("  /acs auto|say|party|raid     - set output channel")
    print("  /acs toggle bar              - enable/disable action bar Alt+Click")
    print("  /acs toggle unit             - enable/disable unit frame Alt+Click")
    print("  /acs toggle elv              - enable/disable ElvUI-specific hooks")
    print("  /acs hook elv                - try ElvUI hooks immediately")
    print("  /acs debug on|off            - toggle debug prints")
end
