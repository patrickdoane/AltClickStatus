-- Alt-Click Status — Items & /use support (Issue #25)
-- Classic Era + ElvUI
-- Features:
--   • Alt+LeftClick announces status for spells, items, and /use macros (incl. trinkets 13/14).
--   • Cooldowns: prefer GetActionCooldown(button.action); guard GetItemCooldown; slot cooldown for trinkets.
--   • Not-in-bags / not-equipped messaging
--   • Strict mouse-only gate (prevents Alt+keybind from triggering).

local A = CreateFrame("Frame", "AltClickStatusFrame")
A.CHANNEL_MODE = "AUTO"; A.THROTTLE_SEC = 0.75
A.ENABLE_ACTIONBAR = true; A.ENABLE_UNITFRAMES = true; A.ENABLE_ELVUI_HOOKS = true
A.SHOW_RANGE = A.SHOW_RANGE or false
A.DEBUG = false

local function dprint(...) if A.DEBUG then print("|cff99ccff[ACS]|r", ...) end end

-- Utils
local lastSentAt = 0
local function pct(c,m) if not c or not m or m==0 then return 0 end return math.floor((c/m)*100+0.5) end
local function chooseChannel()
    if A.CHANNEL_MODE~="AUTO" then return A.CHANNEL_MODE end
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return "SAY"
end
local function safeSend(msg)
    local now=GetTime()
    if (now-lastSentAt)<A.THROTTLE_SEC then return end
    lastSentAt=now
    SendChatMessage(msg, chooseChannel())
end

-- Mouse-only gate (issue #12)
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

-- Range helper (optional suffix)
local function maybeRangeSuffix(tokenOrNil, btn)
    if not A.SHOW_RANGE then return "" end
    local r = nil
    if btn and btn.action then
        local ok, val = pcall(IsActionInRange, btn.action)
        if ok then r = val end
    end
    if r == nil and tokenOrNil then
        local ok, val = pcall(IsSpellInRange, tokenOrNil, "target")
        if ok then r = val end
    end
    local txt = (r==1 and "In Range") or (r==0 and "Out of Range") or "Range N/A"
    return " · " .. txt
end

-- Spells
local function getSpellNameAndRank(token)
    local name, sub = GetSpellInfo(token), (GetSpellSubtext and GetSpellSubtext(token))
    if sub and sub ~= "" then return (name or tostring(token)).." ("..sub..")" end
    return name or tostring(token)
end
local function resourceNameAndIDs(spellToken)
    local id, token = UnitPowerType("player")
    local pretty = _G[token] or token or "Power"
    return pretty, id, token
end
local function formatNotEnoughResource(spellToken, btn)
    local resName, powID = resourceNameAndIDs(spellToken)
    local have = UnitPower("player", powID) or 0
    local needTxt = ""
    local ok, getCost = pcall(function() return GetSpellPowerCost end)
    if ok and type(getCost)=="function" then
        local costs = getCost(spellToken)
        if type(costs)=="table" then
            for _,ci in ipairs(costs) do
                if ci and ci.type == powID then
                    local required = ci.cost or ci.minCost
                    if required and required > 0 then
                        needTxt = string.format(" (%d/%d)", have, required)
                        break
                    end
                end
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

-- Items
local INV_TRINKET1, INV_TRINKET2 = 13, 14
local function itemNameByID(itemID)
    if not itemID then return nil end
    local name = GetItemInfo(itemID)
    if name then return name end
    return "item:"..tostring(itemID)
end
local function resolveItemFromSlot(slotId)
    local itemID = GetInventoryItemID("player", slotId)
    return itemID, itemNameByID(itemID)
end
local function resolveItemToken(token)
    if not token then return nil, nil, nil end
    if type(token)=="number" then
        if token==INV_TRINKET1 or token==INV_TRINKET2 then
            local iid, name = resolveItemFromSlot(token)
            return "slot", iid, name, token
        elseif token >= 20 then
            return "item", token, itemNameByID(token)
        else
            return "unknown", nil, tostring(token)
        end
    elseif type(token)=="string" then
        local id = token:match("^item:(%d+)$")
        if id then
            id = tonumber(id)
            return "item", id, itemNameByID(id)
        end
        -- Prefer resolving by bag scan to avoid cache issues / truncation
        local bagID, bagName = FindItemInBagsByExactName(token)
        if bagID then
            return "item", bagID, bagName
        end
        local name = GetItemInfo(token) or token
        return "itemname", nil, name
    end
    return "unknown", nil, tostring(token)
end

-- Safe cooldown getters
local function Cooldown_Action(btn)
    if not btn or not btn.action then return nil end
    local ok, s, d, e = pcall(GetActionCooldown, btn.action)
    if not ok then return nil end
    return s, d, e
end
local function Cooldown_Item(item)
    if type(GetItemCooldown) ~= "function" then return nil end
    local ok, s, d, e = pcall(GetItemCooldown, item)
    if not ok then return nil end
    return s, d, e
end
local function Cooldown_Inventory(slotId)
    local ok, s, d, e = pcall(GetInventoryItemCooldown, "player", slotId)
    if not ok then return nil end
    return s, d, e
end

-- Tooltip-based display name fallback for action slots (handles uncached items)
local ACS_ScanTT
local function ActionSlotDisplayName(btn)
    if not btn or not btn.action then return nil end
    -- Create a hidden GameTooltip for scanning
    if not ACS_ScanTT then
        ACS_ScanTT = CreateFrame("GameTooltip", "ACS_ScanTT", UIParent, "GameTooltipTemplate")
    end
    ACS_ScanTT:SetOwner(UIParent, "ANCHOR_NONE")
    ACS_ScanTT:ClearLines()
    if ACS_ScanTT.SetAction then
        ACS_ScanTT:SetAction(btn.action)
        local line = _G["ACS_ScanTTTextLeft1"]
        local txt = line and line:GetText() or nil
        ACS_ScanTT:Hide()
        return txt
    else
        -- Fallback to main GameTooltip if the custom one lacks SetAction
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip:ClearLines()
        if GameTooltip.SetAction then GameTooltip:SetAction(btn.action) end
        local txt = _G["GameTooltipTextLeft1"] and _G["GameTooltipTextLeft1"]:GetText() or nil
        GameTooltip:Hide()
        return txt
    end
end

-- Item name helpers (prefer real names; avoid showing raw IDs)
local function LinkName(link)
    if type(link)=="string" then
        local n = link:match("%[(.-)%]")
        if n and n ~= "" then return n end
    end
end
local function NameFromBags(itemID)
    if not itemID then return nil end
    for bag=0,4 do
        local slots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag))
        if slots then
            for slot=1,slots do
                local id = (C_Container and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)) or (GetContainerItemID and GetContainerItemID(bag, slot))
                if id == itemID then
                    local link = (C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)) or (GetContainerItemLink and GetContainerItemLink(bag, slot))
                    local n = LinkName(link)
                    if n then return n end
                end
            end
        end
    end
    return nil
end

-- Find an item ID and pretty name by exact item name in bags (case-insensitive)
local function FindItemInBagsByExactName(name)
    if not name or name == "" then return nil end
    local needle = tostring(name):lower()
    for bag=0,4 do
        local slots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag))
        if slots then
            for slot=1,slots do
                local link = (C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)) or (GetContainerItemLink and GetContainerItemLink(bag, slot))
                if link then
                    local pretty = LinkName(link)
                    if pretty and pretty:lower() == needle then
                        local id = (C_Container and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)) or (GetContainerItemID and GetContainerItemID(bag, slot))
                        return id, pretty
                    end
                end
            end
        end
    end
    return nil
end

local function PrettyItemName(itemID, providedName, slotId)
    -- Only trust providedName if it's a non-placeholder STRING
    if type(providedName) == "string" and providedName ~= tostring(itemID) and not providedName:match("^item:%d+$") then
        return providedName
    end
    if slotId then
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
        local n = LinkName(link)
        if n and n ~= "" then return n end
    end
    if itemID then
        local name = GetItemInfo and GetItemInfo(itemID)
        if type(name) == "string" and name ~= "" then return name end
        local n2 = NameFromBags(itemID)
        if type(n2) == "string" and n2 ~= "" then return n2 end
        return "Item #"..tostring(itemID)
    end
    if type(providedName) ~= "string" or providedName == "" then
        return "Item"
    end
    return providedName
end

local function formatItemStatusFromIDs(kind, itemID, name, slotId, btn)
    if kind=="slot" then
        if not itemID then
            local label = PrettyItemName(nil, name, slotId)
            if (not label) or label == "Item" or (type(label)=="string" and label:match("^Item #")) then
                label = "Trinket "..tostring(slotId)
            end
            return string.format("%s > Not Equipped", label)
        end
        local disp = PrettyItemName(itemID, name, slotId)
        local s, d, e = Cooldown_Inventory(slotId)
        if e == 0 then
            return string.format("%s > Not Usable", disp)
        end
        if s and d and d > 1.5 and (GetTime() < (s + d)) then
            local r = math.max(0,(s+d)-GetTime())
            return string.format("%s > On Cooldown (%.0fs)%s", disp, r, maybeRangeSuffix(nil, btn))
        end
        return string.format("%s > Ready%s", disp, maybeRangeSuffix(nil, btn))
    else
        local disp = PrettyItemName(itemID, name, nil)
        if type(disp) ~= "string" then disp = tostring(disp or "") end
        if disp == "" then disp = "Item" end
        -- If we still only have an ID or item:ID, try action-slot tooltip for a real name
        if (itemID and (disp == tostring(itemID) or disp == ("Item #"..tostring(itemID)))) or (type(disp)=="string" and disp:match("^item:%d+$")) then
            local tname = ActionSlotDisplayName(btn)
            if tname and tname ~= "" then disp = tname end
        end
        -- Prefer action-slot cooldown (works for items/macros placed on bars)
        local s, d, e = Cooldown_Action(btn)
        if not s then
            -- Try direct item cooldown by id or name (guarded)
            local key = itemID or name
            if key then s, d, e = Cooldown_Item(key) end
        end
        if e == 0 then
            return string.format("%s > Not Usable", disp)
        end
        if s and d and d > 1.5 and (GetTime() < (s + d)) then
            local r = math.max(0,(s+d)-GetTime())
            return string.format("%s > On Cooldown (%.0fs)%s", disp, r, maybeRangeSuffix(nil, btn))
        end
        local count = (itemID and GetItemCount and GetItemCount(itemID, false)) or (name and GetItemCount and GetItemCount(name, false)) or 0
        if (itemID or name) and count == 0 then
            return string.format("%s > Not in Bags", disp)
        end
        return string.format("%s > Ready%s", disp, maybeRangeSuffix(nil, btn))
    end
end

-- Macro parsing (spell + /use)
-- Remove bracketed conditionals anywhere in a line (e.g., [@cursor], [], [mod:shift]) and normalize spaces
local function stripBracketConds(s)
    if not s or s == "" then return s end
    local prev
    repeat
        prev = s
        s = s:gsub("%b[]", " ")
    until s == prev
    s = s:gsub("%s+", " ")
    return s
end

local function ExtractActionFromMacro(body)
    if not body or body == "" then return nil end
    for line in body:gmatch("[^\r\n]+") do
        local cmd = line:match("^%s*/(%a+)")
        if cmd then
            cmd = cmd:lower()
            if cmd == "use" then
                local rest = line:gsub("^%s*/%a+%s*", "")
                rest = stripBracketConds(rest)
                local a,b = rest:match("^%s*(%d+)%s+(%d+)%s*$") -- bag,slot (future)
                if a and b then
                    return { kind = "item-or-name", token = rest }
                end
                local tok = rest:match("^([^,;]+)")
                if tok then
                    tok = tok:gsub("^%s+", ""):gsub("%s+$", "")
                    local num = tonumber(tok)
                    if num then
                        if num == 13 or num == 14 then
                            return { kind = "slot", token = num, slotId = num }
                        elseif num >= 20 then
                            return { kind = "item", token = num }
                        else
                            return { kind = "item-or-name", token = tok }
                        end
                    else
                        local id = tok:match("^item:(%d+)$")
                        if id then
                            return { kind = "item", token = tonumber(id) }
                        else
                            return { kind = "item-or-name", token = tok }
                        end
                    end
                end
            elseif cmd == "cast" or cmd == "castsequence" then
                local rest = line:gsub("^%s*/%a+%s*", "")
                rest = stripBracketConds(rest)
                if cmd == "castsequence" then
                    repeat
                        local before = rest
                        rest = rest:gsub("^%s*reset=[^,; ]+%s*,?%s*", "")
                    until rest == before
                end
                local token = rest:match("^([^,;]+)")
                if token then
                    token = token:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^!+", "")
                    token = token:gsub("%s*%b()$", "")
                    if token ~= "" and token ~= "[]" then
                        return { kind = "spell", token = token }
                    end
                end
            end
        end
    end
    return nil
end

-- Resolve action from button (spell/item/macro) (spell/item/macro)
local function getActionFromButton(btn)
    if not btn or not btn.action then return nil end
    local t, id = GetActionInfo(btn.action)
    if t == "spell" and id then
        return { kind="spell", token=id }
    elseif t == "item" and id then
        return { kind="item", token=id }
    elseif t == "macro" and id then
        local _, _, body = GetMacroInfo(id)
        if body then
            return ExtractActionFromMacro(body) or { kind="macro", token=id }
        end
    end
    return nil
end

-- Entry point (no cast on Alt+LeftClick)
function AltClickStatus_AltClick(btn)
    if not btn then return end

    local isMouse = ACS_IsStrictMouse(btn)
    ACS_ClearFlags(btn)

    if not isMouse then return end
    if not IsAltKeyDown() then return end

    local act = getActionFromButton(btn)
    if not act then
        safeSend("Alt-click status: unable to resolve action on this button.")
        return
    end

    if act.kind == "spell" then
        safeSend(formatSpellStatus(act.token, btn))
        return
    end
    if act.kind == "item" then
        local _, name = resolveItemToken(act.token)
        safeSend(formatItemStatusFromIDs("item", act.token, name, nil, btn))
        return
    end
    if act.kind == "slot" then
        local itemID, name = resolveItemFromSlot(act.slotId or act.token)
        safeSend(formatItemStatusFromIDs("slot", itemID, name, act.slotId or act.token, btn))
        return
    end
    if act.kind == "item-or-name" then
        local kind, itemID, name = resolveItemToken(act.token)
        safeSend(formatItemStatusFromIDs(kind=="slot" and "slot" or "item", itemID, name, (kind=="slot" and act.token or nil), btn))
        return
    end
    -- Fallback for opaque macros: rely on action-slot cooldown/readiness
    local s, d = Cooldown_Action(btn)
    if s and d and d > 1.5 and (GetTime() < (s + d)) then
        local r = math.max(0,(s+d)-GetTime())
        safeSend(string.format("Action > On Cooldown (%.0fs)%s", r, maybeRangeSuffix(nil, btn)))
    else
        safeSend("Action > Ready"..maybeRangeSuffix(nil, btn))
    end
end

-- Button wiring
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
                    b:HookScript("OnClick", onAnyActionClick); b.__ACS_ClickHooked=true
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
                    b:HookScript("OnClick", onAnyActionClick); b.__ACS_ClickHooked=true
                end
                hookButton(b); hook=hook+1
            end
        end
    end
    dprint("Configured ElvUI buttons:",conf,"overrides; hooked:",hook)
end

-- ElvUI unitframes Alt+LClick -> status
local function AnnounceUnit(unit)
    if not unit or not UnitExists(unit) then return end
    local hp, hm = UnitHealth(unit), UnitHealthMax(unit)
    local p, pm = UnitPower(unit), UnitPowerMax(unit)
    local _, tk = UnitPowerType(unit); local pn = _G[tk] or tk or "Power"
    local hpPct = pct(hp, hm); local pPct = pct(p, pm)
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
        if btn == "LeftButton" and IsAltKeyDown() then AnnounceUnit(unit) end
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

-- Orchestration
local pending=false
local function ensureConfigured()
    if InCombatLockdown() then pending=true; A:RegisterEvent("PLAYER_REGEN_ENABLED"); dprint("In combat: deferring configuration."); return end
    configureBlizzardButtons(); configureElvUIButtons(); configureElvUIUnitFrames()
end
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

-- Slash (subset)
SLASH_ALTCSTATUS1="/altclick"; SLASH_ALTCSTATUS2="/acs"
SlashCmdList["ALTCSTATUS"]=function(msg)
    msg=(msg or ""):lower()
    if msg=="debug on" then A.DEBUG=true; print("Alt-Click Status: DEBUG ON"); return
    elseif msg=="debug off" then A.DEBUG=false; print("Alt-Click Status: DEBUG OFF"); return
    elseif msg=="hook elv" then ensureConfigured(); print("Alt-Click Status: reconfigured now."); return
    end
    print("Alt-Click Status usage: /acs debug on|off, /acs hook elv")
end
