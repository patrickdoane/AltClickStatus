
-- Alt-Click Status (Classic Era + ElvUI)
-- Issue #12: STRICT mouse-only gate.
-- Only real Alt+Left mouse clicks announce. Alt+keybinds (Alt+1, etc.) never announce.

local A = CreateFrame("Frame", "AltClickStatusFrame")
A.CHANNEL_MODE = "AUTO"; A.THROTTLE_SEC = 0.75
A.ENABLE_ACTIONBAR = true; A.ENABLE_UNITFRAMES = true; A.ENABLE_ELVUI_HOOKS = true
A.DEBUG = false
local function dprint(...) if A.DEBUG then print("|cff99ccff[ACS]|r", ...) end end

-- -------------------------------
-- Utils
-- -------------------------------
local lastSentAt = 0
local function pct(c,m) if not c or not m or m==0 then return 0 end return math.floor((c/m)*100+0.5) end
local function chooseChannel()
    if A.CHANNEL_MODE~="AUTO" then return A.CHANNEL_MODE end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return "SAY"
end
local function safeSend(msg)
    local now=GetTime()
    if (now-lastSentAt)<A.THROTTLE_SEC then return end
    lastSentAt=now
    SendChatMessage(msg, chooseChannel())
end

-- -------------------------------
-- STRICT mouse-only gate
-- -------------------------------
local MOUSE_WINDOW = 0.50 -- seconds
local function ACS_PreClick(self, button)
    -- PreClick runs for both mouse and keybind activations.
    -- Clamp to true only when the left mouse button is actually depressed at this moment.
    self.__ACS_preWasMouse = (button == "LeftButton") and IsMouseButtonDown("LeftButton") or false
    self.__ACS_preTime = GetTime()
    self.__ACS_preAlt  = IsAltKeyDown()
end

local function ACS_OnMouseDown(self, button)
    if button ~= "LeftButton" then return end
    if not IsAltKeyDown() then return end
    -- Record a recent left mouse press on this exact frame.
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
    -- Must have been a PreClick with left mouse actually down
    if not self.__ACS_preWasMouse then return false end
    if not self.__ACS_preTime or (now - self.__ACS_preTime) > 1.0 then return false end
    -- Must ALSO have a very recent OnMouseDown on the same frame
    if not self.__ACS_lastMouseDown or (now - self.__ACS_lastMouseDown) > MOUSE_WINDOW then return false end
    -- Optional: ensure cursor is still over the frame to avoid stray marks
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

local function formatSpellStatus(token)
    local name = getSpellNameAndRank(token)
    local start, dur, enabled = GetSpellCooldown(token)
    local charges, maxCharges, chStart, chDur = GetSpellCharges and GetSpellCharges(token) or nil
    local gS, gD = GetSpellCooldown(61304)
    local onGCD = (gD and gD>0 and (GetTime() < (gS+gD))) and true or false
    local inR = IsSpellInRange(token, "target")
    local rangeTxt = (inR==1 and "In Range") or (inR==0 and "Out of Range") or "Range N/A"

    if maxCharges and maxCharges > 1 then
        if charges and charges > 0 then
            return string.format("%s > Ready (%d/%d) · %s", name, charges, maxCharges, rangeTxt)
        else
            local r = chStart and chDur and math.max(0,(chStart+chDur)-GetTime()) or 0
            return string.format("%s > Recharging (%.0fs) · %s", name, r, rangeTxt)
        end
    end
    if enabled == 0 then return string.format("%s > Not Usable · %s", name, rangeTxt) end
    if start and dur and dur > 1.5 and (GetTime() < (start + dur)) then
        local r = math.max(0,(start+dur)-GetTime())
        return string.format("%s > On Cooldown (%.0fs) · %s", name, r, rangeTxt)
    end
    if onGCD then
        local r = math.max(0,(gS+gD)-GetTime())
        return string.format("%s > On GCD (%.1fs) · %s", name, r, rangeTxt)
    end
    return string.format("%s > Ready · %s", name, rangeTxt)
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
    -- Always clear marks to avoid sticky state
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
    elseif msg=="hook elv" then
        ensureConfigured(); print("Alt-Click Status: reconfigured now."); return
    elseif msg=="debug on" then
        A.DEBUG=true; print("Alt-Click Status: DEBUG ON"); return
    elseif msg=="debug off" then
        A.DEBUG=false; print("Alt-Click Status: DEBUG OFF"); return
    end
    print("Alt-Click Status usage:")
    print("  /acs auto|say|party|raid     - set output channel")
    print("  /acs toggle bar              - enable/disable action bar Alt+Click")
    print("  /acs toggle unit             - enable/disable unit frame Alt+Click")
    print("  /acs toggle elv              - enable/disable ElvUI-specific hooks")
    print("  /acs hook elv                - re-run configuration now")
    print("  /acs debug on|off            - toggle debug prints")
end
