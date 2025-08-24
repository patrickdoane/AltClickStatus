local ADDON, _ = ...
not A.ENABLE_UNITFRAMES then return end
if button ~= "LeftButton" or not IsAltKeyDown() then return end
announceUnitStatus("target")
end


if TargetFrame and TargetFrame:HasScript("OnMouseUp") then
TargetFrame:HookScript("OnMouseUp", targetFrameClick)
end


-- -------------------------------
-- ElvUI hooks (Classic Era friendly)
-- -------------------------------
local function HookElvUI()
if not A.ENABLE_ELVUI_HOOKS then return end
if not IsAddOnLoaded("ElvUI") then return end
-- Hook ElvUI action buttons if present
for bar = 1, 10 do
for i = 1, 24 do
local btn = _G[("ElvUI_Bar%uButton%u"):format(bar, i)]
if btn and not btn.__ACS_Hooked then
btn:RegisterForClicks("AnyUp")
btn:HookScript("OnClick", onAnyActionClick)
btn.__ACS_Hooked = true
end
end
end
-- Hook ElvUI unit frames
local efp = _G["ElvUF_Player"]
if efp and efp:HasScript("OnMouseUp") and not efp.__ACS_Hooked then
efp:HookScript("OnMouseUp", function(self, button)
if not A.ENABLE_UNITFRAMES then return end
if button == "LeftButton" and IsAltKeyDown() then announceUnitStatus("player") end
end)
efp.__ACS_Hooked = true
end
local eft = _G["ElvUF_Target"]
if eft and eft:HasScript("OnMouseUp") and not eft.__ACS_Hooked then
eft:HookScript("OnMouseUp", function(self, button)
if not A.ENABLE_UNITFRAMES then return end
if button == "LeftButton" and IsAltKeyDown() then announceUnitStatus("target") end
end)
eft.__ACS_Hooked = true
end
end


A:RegisterEvent("PLAYER_LOGIN")
A:RegisterEvent("PLAYER_ENTERING_WORLD")
A:RegisterEvent("ADDON_LOADED")
A:SetScript("OnEvent", function(self, event, arg1)
if event == "ADDON_LOADED" then
if arg1 == "ElvUI" then C_Timer.After(0.5, HookElvUI) end
elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
C_Timer.After(1, HookElvUI)
end
end)


-- -------------------------------
-- Slash commands
-- -------------------------------
SLASH_ALTCSTATUS1 = "/altclick"
SLASH_ALTCSTATUS2 = "/acs"
SlashCmdList["ALTCSTATUS"] = function(msg)
msg = (msg or ""):lower()
if msg == "say" or msg == "party" or msg == "raid" or msg == "instance" then
A.CHANNEL_MODE = (msg == "instance" and "INSTANCE_CHAT" or msg:upper())
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
elseif msg == "hook elv" then
HookElvUI(); print("Alt-Click Status: attempted ElvUI hook now.")
return
elseif msg == "toggle elv" then
A.ENABLE_ELVUI_HOOKS = not A.ENABLE_ELVUI_HOOKS
print("Alt-Click Status: ElvUI hooks", A.ENABLE_ELVUI_HOOKS and "ON" or "OFF")
return
end
print("Alt-Click Status usage:")
print(" /acs auto|say|party|raid|instance - set output channel")
print(" /acs toggle bar - enable/disable action bar Alt+Click")
print(" /acs toggle unit - enable/disable unit frame Alt+Click")
print(" /acs toggle elv - enable/disable ElvUI-specific hooks")
print(" /acs hook elv - try ElvUI hooks immediately")
end