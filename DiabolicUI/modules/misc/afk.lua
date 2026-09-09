local ADDON, Engine = ...
local Module = Engine:NewModule("AFK")

-- "Away" screen. When the player is flagged AFK we hide the whole UI (world
-- stays visible), optionally orbit the MAIN camera around the character, and
-- show a customizable 3D model + text block. Any key returns to the game.
-- The overlay is a PARENTLESS top-level frame so UIParent:Hide() doesn't hide it.
-- Reimplemented from scratch (ElvUI-inspired idea only, none of its code).

-- WoW API
local UnitIsAFK        = UnitIsAFK
local UnitName         = UnitName
local UnitLevel        = UnitLevel
local GetGuildInfo     = GetGuildInfo
local InCombatLockdown = InCombatLockdown
local IsInInstance     = IsInInstance
local MoveViewLeftStart, MoveViewLeftStop = MoveViewLeftStart, MoveViewLeftStop
local Screenshot       = Screenshot
local SetCVar          = SetCVar
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local RAID_CLASS_COLORS   = RAID_CLASS_COLORS
local tinsert, tconcat = table.insert, table.concat
local TWO_PI           = math.pi * 2

-- default settings (stored per character under UI/character.afk)
local DEFAULTS = {
	enabled      = true,
	orbit        = true,      -- spin the main camera around the player
	cam_speed    = 0.035,     -- main camera orbit speed
	show_model   = true,      -- 3D model in the corner
	rotate_model = false,     -- spin the model itself
	model_speed  = 0.5,       -- model spin speed (rad/sec) when rotating
	model_size   = 320,
	model_facing = 5.6,       -- fixed model angle when not rotating (radians)
	show_name    = true,
	show_level   = true,
	show_guild   = true,
	show_hint    = true,
	show_whispers = true,     -- show incoming whispers on the away screen
}

local function cfg()
	local db = Engine:GetConfig("UI", "character")
	if not db.afk then db.afk = {} end
	local a = db.afk
	for k, v in pairs(DEFAULTS) do
		if a[k] == nil then a[k] = v end
	end
	return a
end

-- exposed so the options panel can read/write the same table
Module.GetSettings = function() return cfg() end

-- keys that must NOT end AFK mode on their own
local ignoreKeys = { LALT = true, RALT = true, LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true }
local printKeys  = { PRINTSCREEN = true }

-- whisper panel geometry (relative to the overlay TOPLEFT)
local CHAT_X, CHAT_Y = 40, -110
local CHAT_W, CHAT_H = 460, 420

-- class colour for a sender, looked up from the chat event's GUID (arg12).
-- Falls back to light blue when the class is unknown (e.g. Battle.net whispers,
-- or a player the client hasn't cached).
local function classColorHex(guid)
	if guid and guid ~= "" and GetPlayerInfoByGUID then
		local ok, _, class = pcall(GetPlayerInfoByGUID, guid)   -- 2nd return = english class
		if ok then
			local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
			if c then
				return ("|cff%.2x%.2x%.2x"):format(c.r * 255, c.g * 255, c.b * 255)
			end
		end
	end
	return "|cff40c0f0"
end

-- incoming-whisper handler for the scrolling message frame
local function onWhisper(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12)
	local color = classColorHex(arg12)
	self:AddMessage(("%s%s|r  %s"):format(color, arg2 or "?", arg1 or ""))
end

local function shouldShow()
	local a = cfg()
	if not a.enabled then return false end
	if not UnitIsAFK("player") then return false end
	if InCombatLockdown() then return false end
	local inInstance, instanceType = IsInInstance()
	if inInstance and (instanceType == "pvp" or instanceType == "arena") then return false end
	return true
end

local function onKeyDown(_, key)
	if ignoreKeys[key] then return end
	if printKeys[key] then Screenshot() return end
	Module.suppressed = true
	Module:Leave()
end

Module.Build = function(self)
	if self.frame then return self.frame end

	local f = CreateFrame("Frame", "DiabolicUIAFKFrame")
	f:SetFrameStrata("FULLSCREEN")
	f:SetToplevel(true)
	f:SetAllPoints(UIParent)
	f:EnableMouse(true)          -- block mouselook so the auto-orbit stays clean
	f:EnableKeyboard(false)
	f:SetScript("OnKeyDown", onKeyDown)
	f:Hide()

	local model = CreateFrame("PlayerModel", nil, f)
	model:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -60, 40)
	model:EnableMouse(false)
	model:SetScript("OnUpdate", function(m, e)
		local a = cfg()
		if a.rotate_model then
			m.facing = (m.facing or 0) + e * a.model_speed
			if m.facing > TWO_PI then m.facing = m.facing - TWO_PI end
			m:SetFacing(m.facing)
		end
	end)
	f.model = model

	local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	name:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 48, 96)
	name:SetTextColor(1, 1, 1)
	f.nameText = name

	local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -8)
	info:SetTextColor(0.8, 0.8, 0.8)
	f.infoText = info

	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -24)
	hint:SetText("Нажмите любую клавишу, чтобы вернуться")
	f.hintText = hint

	-- incoming-whisper panel (top-left): newest on top, older pushed downward
	local chat = CreateFrame("ScrollingMessageFrame", nil, f)
	chat:SetPoint("TOPLEFT", f, "TOPLEFT", CHAT_X, CHAT_Y)
	chat:SetSize(CHAT_W, CHAT_H)
	chat:SetFontObject(GameFontNormal)
	chat:SetJustifyH("LEFT")
	chat:SetFading(false)          -- keep messages on screen while away
	chat:SetMaxLines(100)
	chat:SetInsertMode("TOP")
	chat:SetScript("OnEvent", onWhisper)
	chat:Hide()
	f.chat = chat

	self.frame = f
	return f
end

Module.ApplyModel = function(self, f)
	local a = cfg()
	local m = f.model
	if not m then return end
	if a.show_model then
		m:SetSize(a.model_size, a.model_size)
		m:SetUnit("player")
		if not a.rotate_model then
			m.facing = a.model_facing
			m:SetFacing(a.model_facing)
		end
		m:Show()
	else
		m:Hide()
	end
end

Module.ApplyContent = function(self, f)
	local a = cfg()

	if a.show_name then
		f.nameText:SetText(UnitName("player") or "")
		f.nameText:Show()
	else
		f.nameText:Hide()
	end

	local parts = {}
	if a.show_level then tinsert(parts, ("Уровень %d"):format(UnitLevel("player") or 0)) end
	if a.show_guild then
		local g = GetGuildInfo("player")
		if g then tinsert(parts, "<"..g..">") end
	end
	if #parts > 0 then
		f.infoText:SetText(tconcat(parts, "  •  "))
		f.infoText:Show()
	else
		f.infoText:Hide()
	end

	if a.show_hint then f.hintText:Show() else f.hintText:Hide() end
end

Module.ApplyChat = function(self, f, clear)
	local a = cfg()
	local c = f.chat
	if not c then return end
	if a.show_whispers then
		if clear then c:Clear() end
		c:RegisterEvent("CHAT_MSG_WHISPER")
		c:RegisterEvent("CHAT_MSG_BN_WHISPER")
		c:Show()
	else
		c:UnregisterAllEvents()
		c:Hide()
	end
end

Module.Enter = function(self)
	if self.active then return end
	local f = self:Build()
	self:ApplyContent(f)
	self:ApplyModel(f)
	self:ApplyChat(f, true)

	self.active = true
	UIParent:Hide()
	f:Show()
	f:EnableKeyboard(true)
	f:SetScale(UIParent:GetScale())

	local a = cfg()
	if a.orbit then
		MoveViewLeftStart(a.cam_speed)
		self.orbiting = true
	end
end

Module.Leave = function(self)
	if not self.active then return end
	self.active = false
	if self.orbiting then MoveViewLeftStop() self.orbiting = false end
	if self.frame then
		if self.frame.chat then self.frame.chat:UnregisterAllEvents() end
		self.frame:EnableKeyboard(false)
		self.frame:Hide()
	end
	UIParent:Show()
end

-- live re-apply (only meaningful if the screen is up; harmless otherwise)
Module.Refresh = function(self)
	if not self.active or not self.frame then return end
	self:ApplyContent(self.frame)
	self:ApplyModel(self.frame)
	self:ApplyChat(self.frame, false)
	local a = cfg()
	if a.orbit and not self.orbiting then
		MoveViewLeftStart(a.cam_speed) self.orbiting = true
	elseif not a.orbit and self.orbiting then
		MoveViewLeftStop() self.orbiting = false
	end
end

Module.Update = function(self)
	if not UnitIsAFK("player") then self.suppressed = false end
	if self.active then
		if not shouldShow() then self:Leave() end
	else
		if shouldShow() and not self.suppressed then self:Enter() end
	end
end

Module.OnEnable = function(self)
	cfg()  -- ensure defaults exist
	SetCVar("autoClearAFK", "1")

	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_FLAGS_CHANGED")
	watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
	watcher:SetScript("OnEvent", function() self:Update() end)
	self.watcher = watcher
end
