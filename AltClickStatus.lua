-- Alt-Click Status v0.3.0 (Classic Era + ElvUI)
local A = CreateFrame("Frame", "AltClickStatusFrame")
A.CHANNEL_MODE = "AUTO"; A.THROTTLE_SEC = 0.75
A.ENABLE_ACTIONBAR = true; A.ENABLE_UNITFRAMES = true; A.ENABLE_ELVUI_HOOKS = true
A.DEBUG = false
local function dprint(...) if A.DEBUG then print("|cff99ccff[ACS]|r", ...) end end
local lastSentAt = 0
local function pct(c, m)
    if not c or not m or m == 0 then return 0 end
    return math.floor((c / m) * 100 + 0.5)
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
    SendChatMessage(msg, chooseChannel())
end
local function getSpellNameAndRank(t)
    local n, s = GetSpellInfo(t), (GetSpellSubtext and GetSpellSubtext(t))
    if s and s ~= "" then return (n or tostring(t)) .. " (" .. s .. ")" end
    return n or tostring(t)
end
local function formatSpellStatus(t)
    local name = getSpellNameAndRank(t)
    local start, dur, en = GetSpellCooldown(t)
    local ch, maxch, chS, chD = GetSpellCharges and GetSpellCharges(t) or nil
    local gS, gD = GetSpellCooldown(61304)
    local onGCD = (gD and gD > 0 and (GetTime() < (gS + gD))) and true or false
    local inR = IsSpellInRange(t, "target")
    local rangeTxt = (inR == 1 and "In Range") or (inR == 0 and "Out of Range") or "Range N/A"
    if maxch and maxch > 1 then if ch and ch > 0 then return string.format("%s > Ready (%d/%d) · %s", name, ch, maxch,
                rangeTxt) else
            local r = chS and chD and math.max(0, (chS + chD) - GetTime()) or 0
            return string.format("%s > Recharging (%.0fs) · %s", name, r, rangeTxt)
        end end
    if en == 0 then return string.format("%s > Not Usable · %s", name, rangeTxt) end
    if start and dur and dur > 1.5 and (GetTime() < (start + dur)) then
        local r = math.max(0, (start + dur) - GetTime())
        return string.format("%s > On Cooldown (%.0fs) · %s", name, r, rangeTxt)
    end
    if onGCD then
        local r = math.max(0, (gS + gD) - GetTime())
        return string.format("%s > On GCD (%.1fs) · %s", name, r, rangeTxt)
    end
    return string.format("%s > Ready · %s", name, rangeTxt)
end
local function getSpellFromActionButton(btn)
    if not btn or not btn.action then return nil end
    local a = btn.action
    local t, id, sub = GetActionInfo(a)
    if t == "spell" and id then return id elseif t == "macro" and id then
        local n, ic, body = GetMacroInfo(id)
        if body then
            local sp = body:match("/cast%s+%b[]%s*([^%c,;]+)") or body:match("/cast%s+([^%c,;]+)") or
            body:match("cast%s+([^%c,;]+)")
            if sp then
                sp = sp:gsub("%s+$", ""):gsub("^%s+", "")
                return sp
            end
        end
    end
    return nil
end
function AltClickStatus_AltClick(btn)
    if not btn or not IsAltKeyDown() then return end
    local tok = getSpellFromActionButton(btn)
    if tok then safeSend(formatSpellStatus(tok)) else safeSend(
        "Alt-click status: unable to resolve spell on this button.") end
end

local function onAnyActionClick(self, button)
    if not A.ENABLE_ACTIONBAR then return end
    if button ~= "LeftButton" then return end
    if IsAltKeyDown() then return end
end
local function setupAltOverride(btn, name)
    if not btn or not btn.SetAttribute or not name then return false end
    if InCombatLockdown() then return false end
    if btn.__ACS_AltOverride then return true end
    local macro = ('/run AltClickStatus_AltClick(%s)'):format(name)
    btn:SetAttribute("alt-type1", "macro"); btn:SetAttribute("alt-macrotext1", macro); btn.__ACS_AltOverride = true
    return true
end
local BLIZZ_PREFIX = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton" }
local function configureBlizzardButtons()
    local conf, hook = 0, 0
    for _, p in ipairs(BLIZZ_PREFIX) do for i = 1, 24 do
            local name = p .. i
            local b = _G[name]
            if b then
                if setupAltOverride(b, name) then conf = conf + 1 end
                if b.HookScript and not b.__ACS_Hooked and not InCombatLockdown() then
                    b:HookScript("OnClick", onAnyActionClick)
                    b.__ACS_Hooked = true
                    hook = hook + 1
                end
            end
        end end
    dprint("Configured Blizzard alt overrides:", conf, "Hooked:", hook)
end
local function configureElvUIButtons()
    if not IsAddOnLoaded("ElvUI") then return end
    local conf, hook = 0, 0
    for bar = 1, 10 do for i = 1, 24 do
            local name = ("ElvUI_Bar%uButton%u"):format(bar, i)
            local b = _G[name]
            if b then
                if setupAltOverride(b, name) then conf = conf + 1 end
                if b.HookScript and not b.__ACS_Hooked and not InCombatLockdown() then
                    b:HookScript("OnClick", onAnyActionClick)
                    b.__ACS_Hooked = true
                    hook = hook + 1
                end
            end
        end end
    dprint("Configured ElvUI alt overrides:", conf, "Hooked:", hook)
    local efp = _G["ElvUF_Player"]
    if efp and not efp.__ACS_Hooked and efp.HookScript and not InCombatLockdown() then
        efp:HookScript("OnMouseUp",
            function(self, button)
                if not A.ENABLE_UNITFRAMES then return end
                if button == "LeftButton" and IsAltKeyDown() then
                    local hp, hm = UnitHealth("player"), UnitHealthMax("player")
                    local p, pm = UnitPower("player"), UnitPowerMax("player")
                    local _, tk = UnitPowerType("player")
                    local pn = _G[tk] or tk or "Power"
                    safeSend(("I have %d%% HP, %d%% %s."):format(pct(hp, hm), pct(p, pm), pn))
                end
            end)
        efp.__ACS_Hooked = true
    end
    local eft = _G["ElvUF_Target"]
    if eft and not eft.__ACS_Hooked and eft.HookScript and not InCombatLockdown() then
        eft:HookScript("OnMouseUp",
            function(self, button)
                if not A.ENABLE_UNITFRAMES then return end
                if button == "LeftButton" and IsAltKeyDown() then
                    local hp, hm = UnitHealth("target"), UnitHealthMax("target")
                    local p, pm = UnitPower("target"), UnitPowerMax("target")
                    local _, tk = UnitPowerType("target")
                    local pn = _G[tk] or tk or "Power"
                    local nm = UnitName("target") or "target"
                    safeSend(("%s: %d%% HP, %d%% %s."):format(nm, pct(hp, hm), pct(p, pm), pn))
                end
            end)
        eft.__ACS_Hooked = true
    end
end
local pending = false
local function ensureConfigured()
    if InCombatLockdown() then
        pending = true
        A:RegisterEvent("PLAYER_REGEN_ENABLED")
        dprint("In combat: deferring configuration.")
        return
    end
    configureBlizzardButtons(); configureElvUIButtons()
end
A:RegisterEvent("PLAYER_LOGIN"); A:RegisterEvent("PLAYER_ENTERING_WORLD"); A:RegisterEvent("ADDON_LOADED")
A:SetScript("OnEvent",
    function(self, event, arg1) if event == "PLAYER_LOGIN" then
            local _, _, _, iface = GetBuildInfo()
            print(("Alt-Click Status loaded (Interface %s). Use /acs for options."):format(tostring(iface or "?"))); C_Timer
                .After(0.1, ensureConfigured)
        elseif event == "PLAYER_ENTERING_WORLD" then C_Timer.After(0.5, ensureConfigured) elseif event == "ADDON_LOADED" and arg1 == "ElvUI" then
            C_Timer.After(0.2, ensureConfigured) elseif event == "PLAYER_REGEN_ENABLED" then
            A:UnregisterEvent("PLAYER_REGEN_ENABLED"); if pending then
                pending = false
                C_Timer.After(0, ensureConfigured)
            end
        end end)
SLASH_ALTCSTATUS1 = "/altclick"; SLASH_ALTCSTATUS2 = "/acs"
SlashCmdList["ALTCSTATUS"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "say" or msg == "party" or msg == "raid" then
        A.CHANNEL_MODE = msg:upper(); print("Alt-Click Status: channel set to", A.CHANNEL_MODE)
        return
    elseif msg == "auto" or msg == "default" then
        A.CHANNEL_MODE = "AUTO"; print("Alt-Click Status: channel set to AUTO")
        return
    elseif msg == "toggle bar" then
        A.ENABLE_ACTIONBAR = not A.ENABLE_ACTIONBAR; print("Alt-Click Status: action bar hooks",
            A.ENABLE_ACTIONBAR and "ON" or "OFF")
        return
    elseif msg == "toggle unit" then
        A.ENABLE_UNITFRAMES = not A.ENABLE_UNITFRAMES; print("Alt-Click Status: unit frame hooks",
            A.ENABLE_UNITFRAMES and "ON" or "OFF")
        return
    elseif msg == "toggle elv" then
        A.ENABLE_ELVUI_HOOKS = not A.ENABLE_ELVUI_HOOKS; print("Alt-Click Status: ElvUI hooks",
            A.ENABLE_ELVUI_HOOKS and "ON" or "OFF")
        return
    elseif msg == "hook elv" then
        ensureConfigured(); print("Alt-Click Status: reconfigured now.")
        return
    elseif msg == "debug on" then
        A.DEBUG = true; print("Alt-Click Status: DEBUG ON")
        return
    elseif msg == "debug off" then
        A.DEBUG = false; print("Alt-Click Status: DEBUG OFF")
        return
    end
    print("Alt-Click Status usage:"); print("  /acs auto|say|party|raid     - set output channel"); print(
    "  /acs toggle bar              - enable/disable action bar Alt+Click"); print(
    "  /acs toggle unit             - enable/disable unit frame Alt+Click"); print(
    "  /acs toggle elv              - enable/disable ElvUI-specific hooks"); print(
    "  /acs hook elv                - re-run configuration now"); print(
    "  /acs debug on|off            - toggle debug prints")
end
