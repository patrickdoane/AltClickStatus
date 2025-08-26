-- Alt-Click Status v0.3.0j (Classic Era + ElvUI)
-- Hotfix: robust macro parser for /cast lines with chained conditionals, e.g. `/cast [@cursor][] Blizzard`.
-- Issue #12 fix: Only announce on real Alt+Left mouse clicks (ignore Alt+keybinds like Alt+1).

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
-- Mouse-origin gate (issue #12)
-- -------------------------------
-- True only if this frame saw a recent Alt+Left mouse down (keyboard hotkeys won't set this).
local function ACS_WasAltMouseClick(frame)
    if not frame or type(frame) ~= "table" then return false end
    local t = frame.__ACS_altMouseClickTime
    return t and (GetTime() - t) < 0.75 or false
end

local function ACS_MarkAltMouseDown(self, button)
    if button ~= "LeftButton" or not IsAltKeyDown() then return end
    -- Only consider action-type buttons (secure or classic)
    if self and type(self) == "table" then
        local isAction = (type(self.GetAttribute)=="function" and (self:GetAttribute("type")=="action" or self:GetAttribute("action"))) or self.action
        if isAction then
            self.__ACS_altMouseClickTime = GetTime()
            self.__ACS_altMouseClick = true
        end
    end
end

local function ACS_ClearMouseMark(self)
    if self then
        self.__ACS_altMouseClick = nil
        self.__ACS_altMouseClickTime = nil
    end
end

-- Safety net: if user Alt+Left clicks directly, capture the focused frame
if WorldFrame and WorldFrame.HookScript then
    WorldFrame:HookScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not IsAltKeyDown() then return end
        local f = GetMouseFocus()
        if f and type(f)=="table" then
            ACS_MarkAltMouseDown(f, "LeftButton")
        end
    end)
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
-- Macro parsing (hotfix)
-- -------------------------------
local function ExtractCastTokenFromMacro(body)
    if not body or body == "" then return nil end
    -- Iterate macro lines; consider the first /cast or /castsequence
    for line in body:gmatch("[^\r\n]+") do
        local cmd = line:match("^%s*/(%a+)")
        if cmd then
            cmd = cmd:lower()
            if cmd == "cast" or cmd == "castsequence" then
                -- strip the command
                local rest = line:gsub("^%s*/%a+%s*", "")
                -- repeatedly strip leading [...] blocks (handles [@cursor][] etc)
                local prev
                repeat
                    prev = rest
                    rest = rest:gsub("^%s*%b[]%s*", "")
                until rest == prev
                -- castsequence: drop reset=... options at the start if present
                if cmd == "castsequence" then
                    local before
                    repeat
                        before = rest
                        rest = rest:gsub("^%s*reset=[^,; ]+%s*,?%s*", "")
                    until rest == before
                end
                -- take the first token up to comma/semicolon/EOL (allow spaces inside spell names)
                local token = rest:match("^([^,;]+)")
                if token then
                    token = token:gsub("^%s+",""):gsub("%s+$","")
                    token = token:gsub("^!+","") -- strip leading !
                    if token ~= "" and token ~= "[]" then
                        return token
                    end
                end
            end
        end
    end
    return nil
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
            -- Use robust parser (handles `/cast [@cursor][] Blizzard`)
            local spell = ExtractCastTokenFromMacro(body)
            if spell then return spell end
        end
    end
    return nil
end

-- -------------------------------
-- Public entry for macro override (prevents casting on Alt+LeftClick)
-- -------------------------------
function AltClickStatus_AltClick(btn)
    if not btn or not IsAltKeyDown() then return end
    -- Mouse-only guard: ignore Alt+keybind activations (issue #12)
    if not ACS_WasAltMouseClick(btn) then return end

    local tok = getSpellFromActionButton(btn)
    if tok then
        safeSend(formatSpellStatus(tok))
    else
        safeSend("Alt-click status: unable to resolve spell on this button.")
    end
end

-- Avoid double-announce: placeholder (kept for future use)
local function onAnyActionClick(self, button)
    if not A.ENABLE_ACTIONBAR then return end
    if button ~= "LeftButton" then return end
    if IsAltKeyDown() then return end
end

-- -------------------------------
-- Secure override setup (no cast on Alt+LeftClick)
-- -------------------------------
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

local function hookMouseOrigin(btn)
    if not btn or not btn.HookScript or btn.__ACS_MouseHooked or InCombatLockdown() then return end
    btn:HookScript("OnMouseDown", ACS_MarkAltMouseDown)
    btn:HookScript("PostClick", ACS_ClearMouseMark)
    btn.__ACS_MouseHooked = true
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
                if b.HookScript and not b.__ACS_Hooked and not InCombatLockdown() then
                    b:HookScript("OnClick", onAnyActionClick)
                    b.__ACS_Hooked=true
                    hook=hook+1
                end
                hookMouseOrigin(b)
            end
        end
    end
    dprint("Configured Blizzard alt overrides:",conf,"Hooked:",hook)
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
                if b.HookScript and not b.__ACS_Hooked and not InCombatLockdown() then
                    b:HookScript("OnClick", onAnyActionClick)
                    b.__ACS_Hooked=true
                    hook=hook+1
                end
                hookMouseOrigin(b)
            end
        end
    end
    dprint("Configured ElvUI alt overrides:",conf,"Hooked:",hook)
    -- Unit frames (unchanged)
    local efp=_G["ElvUF_Player"]
    if efp and not efp.__ACS_Hooked and efp.HookScript and not InCombatLockdown() then
        efp:HookScript("OnMouseUp", function(self,button)
            if not A.ENABLE_UNITFRAMES then return end
            if button=="LeftButton" and IsAltKeyDown() then
                local hp,hm=UnitHealth("player"),UnitHealthMax("player")
                local p,pm=UnitPower("player"),UnitPowerMax("player")
                local _,tk=UnitPowerType("player"); local pn=_G[tk] or tk or "Power"
                safeSend(("I have %d%% HP, %d%% %s."):format(pct(hp,hm), pct(p,pm), pn))
            end
        end); efp.__ACS_Hooked=true
    end
    local eft=_G["ElvUF_Target"]
    if eft and not eft.__ACS_Hooked and eft.HookScript and not InCombatLockdown() then
        eft:HookScript("OnMouseUp", function(self,button)
            if not A.ENABLE_UNITFRAMES then return end
            if button=="LeftButton" and IsAltKeyDown() then
                local hp,hm=UnitHealth("target"),UnitHealthMax("target")
                local p,pm=UnitPower("target"),UnitPowerMax("target")
                local _,tk=UnitPowerType("target"); local pn=_G[tk] or tk or "Power"
                local nm=UnitName("target") or "target"
                safeSend(("%s: %d%% HP, %d%% %s."):format(nm, pct(hp,hm), pct(p,pm), pn))
            end
        end); eft.__ACS_Hooked=true
    end
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