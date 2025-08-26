-- Alt-Click Status (Classic Era + ElvUI)
-- Feature: Alt+LeftClick on ElvUI unit frames announces unit HP/Power.
-- Keeps strict mouse-only gate for action buttons, and existing toggles.

local A = CreateFrame("Frame", "AltClickStatusFrame")
A.CHANNEL_MODE = "AUTO"; A.THROTTLE_SEC = 0.75
A.ENABLE_ACTIONBAR = true; A.ENABLE_UNITFRAMES = true; A.ENABLE_ELVUI_HOOKS = true
A.SHOW_RANGE = A and A.SHOW_RANGE or false -- may be set by DB loader elsewhere
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
-- STRICT mouse-only gate for action buttons
-- -------------------------------
local MOUSE_WINDOW = 0.50
local function ACS_PreClick(self, button)
    self.__ACS_preWasMouse = (button == "LeftButton") and IsMouseButtonDown("LeftButton") or false
    self.__ACS_preTime = GetTime()
    self.__ACS_preAlt  = IsAltKeyDown()
end
local function ACS_OnMouseDown(self, button)
    if button ~= "LeftButton" or not IsAltKeyDown() then return end
    self.__ACS_lastMouseDown = GetTime()
end
local function ACS_ClearFlags(self)
    if not self then return end
    self.__ACS_preWasMouse = nil; self.__ACS_preTime = nil; self.__ACS_preAlt  = nil; self.__ACS_lastMouseDown = nil
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
local function resourceNameAndIDs(unit)
    local id, token = UnitPowerType(unit)
    local pretty = _G[token] or token or "Power"
    return pretty, id, token
end

-- Range suffix helper only used by spell announcements; unit frames do not use range
local function maybeRangeSuffix(token, btn)
    if not A.SHOW_RANGE then return "" end
    local r = nil
    if btn and btn.action then
        local ok, val = pcall(IsActionInRange, btn.action)
        if ok then r = val end
    end
    if r == nil and token then
        local ok, val = pcall(IsSpellInRange, token, "target")
        if ok then r = val end
    end
    local txt = (r==1 and "In Range") or (r==0 and "Out of Range") or "Range N/A"
    return " · " .. txt
end

local function formatNotEnoughResource(spellToken, btn)
    local resName, powID = resourceNameAndIDs("player")
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
    return string.format("Not enough %s%s%s", resName, needTxt, maybeRangeSuffix(spellToken, btn))
end

local function formatSpellStatus(token, btn)
    local name = getSpellNameAndRank(token)
    local start, dur, enabled = GetSpellCooldown(token)
    local charges, maxCharges, chStart, chDur = GetSpellCharges and GetSpellCharges(token) or nil
    local gS, gD = GetSpellCooldown(61304)
    local onGCD = (gD and gD>0 and (GetTime() < (gS+gD))) and true or false

    if enabled == 0 then
        return string.format("%s > Not Usable%s", name, maybeRangeSuffix(token, btn))
    end
    if maxCharges and maxCharges > 1 then
        if charges and charges > 0 then
            local usable, oom = IsUsableSpell(token)
            if usable ~= true and oom == true then
                return string.format("%s > %s", name, formatNotEnoughResource(token, btn))
            end
            return string.format("%s > Ready (%d/%d)%s", name, charges, maxCharges, maybeRangeSuffix(token, btn))
        else
            local r = chStart and chDur and math.max(0,(chStart+chDur)-GetTime()) or 0
            return string.format("%s > Recharging (%.0fs)%s", name, r, maybeRangeSuffix(token, btn))
        end
    end
    if start and dur and dur > 1.5 and (GetTime() < (start + dur)) then
        local r = math.max(0,(start+dur)-GetTime())
        return string.format("%s > On Cooldown (%.0fs)%s", name, r, maybeRangeSuffix(token, btn))
    end
    if onGCD then
        local r = math.max(0,(gS+gD)-GetTime())
        return string.format("%s > On GCD (%.1fs)%s", name, r, maybeRangeSuffix(token, btn))
    end
    local usable, oom = IsUsableSpell(token)
    if usable ~= true and oom == true then
        return string.format("%s > %s", name, formatNotEnoughResource(token, btn))
    end
    return string.format("%s > Ready%s", name, maybeRangeSuffix(token, btn))
end

-- -------------------------------
-- Macro parsing
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
-- Macro entry point
-- -------------------------------
function AltClickStatus_AltClick(btn)
    if not btn then return end
    local isMouse = ACS_IsStrictMouse(btn)
    ACS_ClearFlags(btn)
    if not isMouse or not IsAltKeyDown() then return end
    local tok = getSpellFromActionButton(btn)
    if tok then
        safeSend(formatSpellStatus(tok, btn))
    else
        safeSend("Alt-click status: unable to resolve spell on this button.")
    end
end

-- -------------------------------
-- ElvUI Unit Frames (Player/Target/Focus/Pet)
-- -------------------------------
local function AnnounceUnit(unit)
    if not unit or not UnitExists(unit) then return end
    local hp, hm = UnitHealth(unit), UnitHealthMax(unit)
    local p, pm = UnitPower(unit), UnitPowerMax(unit)
    local _, tk = UnitPowerType(unit); local pn = _G[tk] or tk or "Power"
    local hpPct = pct(hp, hm)
    local pPct = pct(p, pm)
    if unit == "player" then
        safeSend(("I have %d%% HP, %d%% %s."):format(hpPct, pPct, pn))
    else
        local nm = UnitName(unit) or unit
        safeSend(("%s: %d%% HP, %d%% %s."):format(nm, hpPct, pPct, pn))
    end
end

local function hookElvUFFrame(name, unit)
    local f = _G[name]
    if not f or f.__ACS_UFHooked or not f.HookScript then return false end
    f:HookScript("OnMouseUp", function(self, btn)
        if not A.ENABLE_UNITFRAMES then return end
        if btn == "LeftButton" and IsAltKeyDown() then
            AnnounceUnit(unit)
        end
    end)
    f.__ACS_UFHooked = true
    return true
end

local function configureElvUIUnitFrames()
    if not IsAddOnLoaded("ElvUI") then return end
    local hooked = 0
    if hookElvUFFrame("ElvUF_Player", "player") then hooked = hooked + 1 end
    if hookElvUFFrame("ElvUF_Target", "target") then hooked = hooked + 1 end
    if hookElvUFFrame("ElvUF_Focus", "focus") then hooked = hooked + 1 end
    if hookElvUFFrame("ElvUF_Pet", "pet") then hooked = hooked + 1 end
    dprint("ElvUI unit frames hooked:", hooked)
end

-- -------------------------------
-- Action button hooks (Blizzard + ElvUI bars)
-- -------------------------------
local function onAnyActionClick(self, button)
    if not A.ENABLE_ACTIONBAR then return end
    if button ~= "LeftButton" then return end
    if IsAltKeyDown() then return end
end
local function setupAltOverride(btn, name)
    if not btn or not btn.SetAttribute or not name or InCombatLockdown() then return false end
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

-- -------------------------------
-- Config orchestration
-- -------------------------------
local pending=false
local function ensureConfigured()
    if InCombatLockdown() then pending=true; A:RegisterEvent("PLAYER_REGEN_ENABLED"); dprint("In combat: deferring configuration."); return end
    configureBlizzardButtons(); configureElvUIButtons(); configureElvUIUnitFrames()
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

-- Slash commands (subset)
SLASH_ALTCSTATUS1="/altclick"; SLASH_ALTCSTATUS2="/acs"
SlashCmdList["ALTCSTATUS"]=function(msg)
    msg=(msg or ""):lower()
    if msg=="toggle unit" then
        A.ENABLE_UNITFRAMES=not A.ENABLE_UNITFRAMES; print("Alt-Click Status: unit frame hooks", A.ENABLE_UNITFRAMES and "ON" or "OFF"); return
    elseif msg=="hook elv" then
        ensureConfigured(); print("Alt-Click Status: reconfigured now."); return
    else
        print("Alt-Click Status: /acs toggle unit  - enable/disable ElvUI unit-frame Alt+Click")
    end
end
