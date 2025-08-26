
-- Alt-Click Status (Classic Era + ElvUI)
-- Hidden toggle: `/acs showrange on|off|toggle` (default OFF). No persistence yet.
-- Keeps strict mouse-only gate (#12) and insufficient resource messaging (#17).

local A = CreateFrame("Frame", "AltClickStatusFrame")
A.CHANNEL_MODE = "AUTO"; A.THROTTLE_SEC = 0.75
A.ENABLE_ACTIONBAR = true; A.ENABLE_UNITFRAMES = true; A.ENABLE_ELVUI_HOOKS = true
A.SHOW_RANGE = false -- runtime only (hidden toggle)
A.DEBUG = false
local function dprint(...) if A.DEBUG then print("|cff99ccff[ACS]|r", ...) end end

-- -------------------------------
-- Utils
-- -------------------------------
local lastSentAt = 0
local function pct(c,m) if not c or not m or m==0 then return 0 end return math.floor((c/m)*100+0.5) end
local function chooseChannel()
    if A.CHANNEL_MODE~="AUTO" then return A.CHANNEL_MODE end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return "SAY"
end
local function safeSend(msg)
    local now=GetTime()
    if (now-lastSentAt)<A.THROTTLE_SEC then return end
    lastSentAt=now
    SendChatMessage(msg, chooseChannel())
end

-- -------------------------------
-- STRICT mouse-only gate (issue #12)
-- -------------------------------
local MOUSE_WINDOW = 0.50 -- seconds
local function ACS_PreClick(self, button)
    self.__ACS_preWasMouse = (button == "LeftButton") and IsMouseButtonDown("LeftButton") or false
    self.__ACS_preTime = GetTime()
    self.__ACS_preAlt  = IsAltKeyDown()
end

local function ACS_OnMouseDown(self, button)
    if button ~= "LeftButton" then return end
    if not IsAltKeyDown() then return end
    self.__ACS_lastMouseDown = GetTime()
end

local function ACS_ClearFlags(self)
    if not self then return end
    self.__ACS_preWasMouse = nil
    self.__ACS_preTime = nil
    self.__ACS_preAlt  = nil
    self.__ACS_lastMouseDown = nil
end

local function ACS_IsStrictMouse(self)
    local now = GetTime()
    if not self then return false end
    if not self.__ACS_preWasMouse then return false end
    if not self.__ACS_preTime or (now - self.__ACS_preTime) > 1.0 then return false end
    if not self.__ACS_lastMouseDown or (now - self.__ACS_lastMouseDown) > MOUSE_WINDOW then return false end
    if self.IsMouseOver and not self:IsMouseOver() then return false end
    return true
end

-- -------------------------------
-- Spell helpers
-- -------------------------------
local function getSpellNameAndRank(token)
    local name, sub = GetSpellInfo(token), (GetSpellSubtext and GetSpellSubtext(token))
    if sub and sub ~= "" then
        return (name or tostring(token)).." ("..sub..")"
    end
    return name or tostring(token)
end

local function resourceNameAndIDs(spellToken)
    local id, token = UnitPowerType("player")
    local pretty = _G[token] or token or "Power"
    return pretty, id, token
end

local function rangeSuffix(token)
    if not A.SHOW_RANGE then return "" end
    local inR = IsSpellInRange(token, "target")
    if inR == 1 then return " · In Range" end
    if inR == 0 then return " · Out of Range" end
    return "" -- suppress "Range N/A" when toggle is on but API can't tell
end

local function formatNotEnoughResource(spellToken)
    local resName, powID = resourceNameAndIDs(spellToken)
    local have = UnitPower("player", powID) or 0
    local needTxt = ""

    local ok, getCost = pcall(function() return GetSpellPowerCost end)
    if ok and type(getCost)=="function" then
        local costs = getCost(spellToken)
        if type(costs)=="table" then
            local required = nil
            for _,ci in ipairs(costs) do
                if ci and ci.type == powID then
                    required = ci.cost or ci.minCost or required
                end
            end
            if required and required > 0 then
                needTxt = string.format(" (%d/%d)", have, required)
            end
        end
    end

    return string.format("Not enough %s%s", resName, needTxt)
end

local function formatSpellStatus(token)
    local name = getSpellNameAndRank(token)
    local start, dur, enabled = GetSpellCooldown(token)
    local charges, maxCharges, chStart, chDur = GetSpellCharges and GetSpellCharges(token) or nil
    local gS, gD = GetSpellCooldown(61304)
    local onGCD = (gD and gD>0 and (GetTime() < (gS+gD))) and true or false
    local rSfx = rangeSuffix(token)

    if enabled == 0 then
        return string.format("%s > Not Usable%s", name, rSfx)
    end

    if maxCharges and maxCharges > 1 then
        if charges and charges > 0 then
            local usable, oom = IsUsableSpell(token)
            if usable ~= true and oom == true then
                return string.format("%s > %s%s", name, formatNotEnoughResource(token), rSfx)
            end
            return string.format("%s > Ready (%d/%d)%s", name, charges, maxCharges, rSfx)
        else
            local r = chStart and chDur and math.max(0,(chStart+chDur)-GetTime()) or 0
            return string.format("%s > Recharging (%.0fs)%s", name, r, rSfx)
        end
    end

    if start and dur and dur > 1.5 and (GetTime() < (start + dur)) then
        local r = math.max(0,(start+dur)-GetTime())
        return string.format("%s > On Cooldown (%.0fs)%s", name, r, rSfx)
    end

    if onGCD then
        local r = math.max(0,(gS+gD)-GetTime())
        return string.format("%s > On GCD (%.1fs)%s", name, r, rSfx)
    end

    local usable, oom = IsUsableSpell(token)
    if usable ~= true and oom == true then
        return string.format("%s > %s%s", name, formatNotEnoughResource(token), rSfx)
    end

    return string.format("%s > Ready%s", name, rSfx)
end

-- -------------------------------
-- Macro parsing (robust for `[]`)
-- -------------------------------
local function ExtractCastTokenFromMacro(body)
    if not body or body == "" then return nil end
    for line in body:gmatch("[^\r\n]+") do
        local cmd = line:match("^%s*/(%a+)")
        if cmd then
            cmd = cmd:lower()
            if cmd == "cast" or cmd == "castsequence" then
                local rest = line:gsub("^%s*/%a+%s*", "")
                repeat
                    local prev = rest
                    rest = rest:gsub("^%s*%b[]%s*", "")
                    if rest == prev then break end
                until false
                if cmd == "castsequence" then
                    repeat
                        local before = rest
                        rest = rest:gsub("^%s*reset=[^,; ]+%s*,?%s*", "")
                        if rest == before then break end
                    until false
                end
                local token = rest:match("^([^,;]+)")
                if token then
                    token = token:gsub("^%s+",""):gsub("%s+$","")
                    token = token:gsub("^!+","")
                    if token ~= "" and token ~= "[]" then
                        return token
                    end
                end
            end
        end
    end
    return nil
end

local function getSpellFromActionButton(btn)
    if not btn or not btn.action then return nil end
    local action = btn.action
    local t, id = GetActionInfo(action)
    if t == "spell" and id then
        return id
    elseif t == "macro" and id then
        local _, _, body = GetMacroInfo(id)
        if body then
            local spell = ExtractCastTokenFromMacro(body)
            if spell then return spell end
        end
    end
    return nil
end

-- -------------------------------
-- Macro entry point (no cast on Alt+LeftClick)
-- -------------------------------
function AltClickStatus_AltClick(btn)
    if not btn then return end

    local isMouse = ACS_IsStrictMouse(btn)
    ACS_ClearFlags(btn)

    if not isMouse then return end
    if not IsAltKeyDown() then return end

    local tok = getSpellFromActionButton(btn)
    if tok then
        safeSend(formatSpellStatus(tok))
    else
        safeSend("Alt-click status: unable to resolve spell on this button.")
    end
end

-- -------------------------------
-- Secure override + hooks
-- -------------------------------
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
    btn:SetAttribute("alt-type1", "macro")
    btn:SetAttribute("alt-macrotext1", macro)
    btn.__ACS_AltOverride = true
    return true
end

local function hookButton(btn)
    if not btn or btn.__ACS_AllHooks or InCombatLockdown() then return end
    if btn.HookScript then
        btn:HookScript("PreClick", ACS_PreClick)
        btn:HookScript("OnMouseDown", ACS_OnMouseDown)
        btn:HookScript("PostClick", ACS_ClearFlags)
    end
    btn.__ACS_AllHooks = true
end

local BLIZZ_PREFIX = {"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton"}
local function configureBlizzardButtons()
    local conf,hook = 0,0
    for _,p in ipairs(BLIZZ_PREFIX) do
        for i=1,24 do
            local name=p..i
            local b=_G[name]
            if b then
                if setupAltOverride(b,name) then conf=conf+1 end
                if b.HookScript and not b.__ACS_ClickHooked and not InCombatLockdown() then
                    b:HookScript("OnClick", onAnyActionClick)
                    b.__ACS_ClickHooked=true
                end
                hookButton(b); hook=hook+1
            end
        end
    end
    dprint("Configured Blizzard buttons:",conf,"overrides; hooked:",hook)
end

local function configureElvUIButtons()
    if not IsAddOnLoaded("ElvUI") or not A.ENABLE_ELVUI_HOOKS then return end
    local conf,hook = 0,0
    for bar=1,10 do
        for i=1,24 do
            local name=("ElvUI_Bar%uButton%u"):format(bar,i)
            local b=_G[name]
            if b then
                if setupAltOverride(b,name) then conf=conf+1 end
                if b.HookScript and not b.__ACS_ClickHooked and not InCombatLockdown() then
                    b:HookScript("OnClick", onAnyActionClick)
                    b.__ACS_ClickHooked=true
                end
                hookButton(b); hook=hook+1
            end
        end
    end
    dprint("Configured ElvUI buttons:",conf,"overrides; hooked:",hook)
end

-- Deferral when in combat
local pending=false
local function ensureConfigured()
    if InCombatLockdown() then pending=true; A:RegisterEvent("PLAYER_REGEN_ENABLED"); dprint("In combat: deferring configuration."); return end
    configureBlizzardButtons(); configureElvUIButtons()
end

-- Events
A:RegisterEvent("PLAYER_LOGIN"); A:RegisterEvent("PLAYER_ENTERING_WORLD"); A:RegisterEvent("ADDON_LOADED")
A:SetScript("OnEvent", function(self,event,arg1)
    if event=="PLAYER_LOGIN" then
        local _,_,_,iface=GetBuildInfo()
        print(("Alt-Click Status loaded (Interface %s). Use /acs for options."):format(tostring(iface or "?")))
        C_Timer.After(0.1, ensureConfigured)
    elseif event=="PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, ensureConfigured)
    elseif event=="ADDON_LOADED" and arg1=="ElvUI" then
        C_Timer.After(0.2, ensureConfigured)
    elseif event=="PLAYER_REGEN_ENABLED" then
        A:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if pending then pending=false; C_Timer.After(0, ensureConfigured) end
    end
end)

-- Slash commands
SLASH_ALTCSTATUS1="/altclick"; SLASH_ALTCSTATUS2="/acs"
SlashCmdList["ALTCSTATUS"]=function(msg)
    msg=(msg or ""):lower()
    if msg=="say" or msg=="party" or msg=="raid" then
        A.CHANNEL_MODE=msg:upper(); print("Alt-Click Status: channel set to",A.CHANNEL_MODE); return
    elseif msg=="auto" or msg=="default" then
        A.CHANNEL_MODE="AUTO"; print("Alt-Click Status: channel set to AUTO"); return
    elseif msg=="toggle bar" then
        A.ENABLE_ACTIONBAR=not A.ENABLE_ACTIONBAR; print("Alt-Click Status: action bar hooks", A.ENABLE_ACTIONBAR and "ON" or "OFF"); return
    elseif msg=="toggle unit" then
        A.ENABLE_UNITFRAMES=not A.ENABLE_UNITFRAMES; print("Alt-Click Status: unit frame hooks", A.ENABLE_UNITFRAMES and "ON" or "OFF"); return
    elseif msg=="toggle elv" then
        A.ENABLE_ELVUI_HOOKS=not A.ENABLE_ELVUI_HOOKS; print("Alt-Click Status: ElvUI hooks", A.ENABLE_ELVUI_HOOKS and "ON" or "OFF"); return
    elseif msg:match("^showrange") then
        local arg = msg:match("^showrange%s+(%S+)")
        if arg == "on" then
            A.SHOW_RANGE = true; print("Alt-Click Status: range text ON")
        elseif arg == "off" then
            A.SHOW_RANGE = false; print("Alt-Click Status: range text OFF")
        elseif arg == "toggle" or arg == nil then
            A.SHOW_RANGE = not A.SHOW_RANGE; print("Alt-Click Status: range text", A.SHOW_RANGE and "ON" or "OFF")
        else
            print("Alt-Click Status: showrange expects on|off|toggle")
        end
        return
    elseif msg=="hook elv" then
        ensureConfigured(); print("Alt-Click Status: reconfigured now."); return
    elseif msg=="debug on" then
        A.DEBUG=true; print("Alt-Click Status: DEBUG ON"); return
    elseif msg=="debug off" then
        A.DEBUG=false; print("Alt-Click Status: DEBUG OFF"); return
    end
    -- Hidden toggle 'showrange' is not listed here on purpose
    print("Alt-Click Status usage:")
    print("  /acs auto|say|party|raid     - set output channel")
    print("  /acs toggle bar              - enable/disable action bar Alt+Click")
    print("  /acs toggle unit             - enable/disable unit frame Alt+Click")
    print("  /acs toggle elv              - enable/disable ElvUI-specific hooks")
    print("  /acs hook elv                - re-run configuration now")
    print("  /acs debug on|off            - toggle debug prints")
end
