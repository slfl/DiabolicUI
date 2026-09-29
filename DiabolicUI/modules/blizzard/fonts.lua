local ADDON, Engine = ...
local Module = Engine:NewModule("Fonts")

local gameLocale = GetLocale()
local isLatin = ({ enUS  = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true, ptPT = true })[gameLocale]

-- Combat text font choice ------------------------------------------------------
-- Original client values, captured before this file changes anything. They are
-- already localized by the client (e.g. *_CYR font files on ruRU), so turning the
-- feature off restores exactly what the game would use on its own.
local ORIG_DAMAGE_TEXT_FONT   = DAMAGE_TEXT_FONT
local ORIG_STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local ORIG_COMBAT = {}
if CombatTextFont then
	ORIG_COMBAT.font, ORIG_COMBAT.size, ORIG_COMBAT.style = CombatTextFont:GetFont()
	ORIG_COMBAT.sx, ORIG_COMBAT.sy = CombatTextFont:GetShadowOffset()
	ORIG_COMBAT.sr, ORIG_COMBAT.sg, ORIG_COMBAT.sb, ORIG_COMBAT.sa = CombatTextFont:GetShadowColor()
end

-- The four stock game faces. Localized clients ship *_CYR variants, so the
-- candidate order depends on the locale; only files that actually load are listed.
local isCyrillic = (gameLocale == "ruRU")
local function pick(cyr, base)
	if isCyrillic then return { cyr, base } else return { base, cyr } end
end
local GAME_FONTS = {
	{ key = "frizqt",   text = "Friz Quadrata", paths = { ORIG_STANDARD_TEXT_FONT, [[Fonts\FRIZQT___CYR.TTF]], [[Fonts\FRIZQT__.TTF]] } },
	{ key = "arialn",   text = "Arial Narrow",  paths = { [[Fonts\ARIALN.TTF]] } },
	{ key = "skurri",   text = "Skurri",        paths = pick([[Fonts\SKURRI_CYR.TTF]], [[Fonts\skurri.ttf]]) },
	{ key = "morpheus", text = "Morpheus",      paths = pick([[Fonts\MORPHEUS_CYR.TTF]], [[Fonts\MORPHEUS.ttf]]) },
}

-- a font file "exists" if a probe FontString actually switches to it
local probe
local function fontLoads(path)
	if not path or path == "" then return false end
	if not probe then probe = UIParent:CreateFontString(nil, "BACKGROUND") end
	probe:SetFont(ORIG_STANDARD_TEXT_FONT, 12)
	probe:SetFont(path, 12)
	local got = probe:GetFont()
	return (got and got:lower() == path:lower()) and true or false
end

Module.SetUp = function(self)
	-- shortcuts to the fonts
	local config = self:GetStaticConfig("Fonts")

	self.fonts = {
		text_normal = config.fonts.text_normal.path,
		text_narrow = config.fonts.text_narrow.path,
		text_serif = config.fonts.text_serif.path,
		text_serif_italic = config.fonts.text_serif_italic.path,
		header_normal = config.fonts.header_normal.path,
		header_light = config.fonts.header_light.path,
		number = config.fonts.number.path,
		damage = config.fonts.damage.path
	}

	-- hash table to quickly tell us if font face supports the current locale
	local fonts = self.fonts
	self.canIUse = {
		[fonts.text_normal] = config.fonts.text_normal.locales[gameLocale], 
		[fonts.text_narrow] = config.fonts.text_narrow.locales[gameLocale],
		[fonts.text_serif] = config.fonts.text_serif.locales[gameLocale], 
		[fonts.text_serif_italic] = config.fonts.text_serif_italic.locales[gameLocale], 
		[fonts.header_normal] = config.fonts.header_normal.locales[gameLocale], 
		[fonts.header_light] = config.fonts.header_light.locales[gameLocale], 
		[fonts.number] = config.fonts.number.locales[gameLocale], 
		[fonts.damage] = config.fonts.damage.locales[gameLocale]
	}

end

Module.SetGameEngineFonts = function(self)
	local canIUse = self.canIUse
	local fonts = self.fonts

	-- game engine fonts
	-- *These will only be updated when the user
	-- relogs into the game from the character selection screen, 
	-- not when simply reloading the user interface!
	if canIUse[fonts.header_light] then 
		UNIT_NAME_FONT = fonts.header_light 

		-- the following need the string to be the global name of a fontobject. weird. 
		NAMEPLATE_FONT = fonts.header_light
	end
	
	if canIUse[fonts.damage] then 
		DAMAGE_TEXT_FONT = fonts.damage 
	end
	
	if canIUse[fonts.text_normal] then 
		STANDARD_TEXT_FONT = fonts.text_normal 
	end
	
	-- default values
	UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT = 14
	CHAT_FONT_HEIGHTS = { 12, 13, 14, 15, 16, 18, 20, 22 }
end

Module.SetFontObjects = function(self)
	local fonts = self.fonts
	
	self:SetFont(NumberFontNormal, fonts.number)

	self:SetFont(FriendsFont_Large, fonts.header_light)
	self:SetFont(GameFont_Gigantic, fonts.header_light) -- not present in WotLK
	self:SetFont(ChatBubbleFont, fonts.text_normal) -- not present in WotLK...?
	self:SetFont(FriendsFont_UserText, fonts.header_light)
	self:SetFont(QuestFont_Large, fonts.header_normal, 14, "", 0, 0, 0) -- 15
	self:SetFont(QuestFont_Shadow_Huge, fonts.header_normal, 16, "", 0, 0, 0) -- 18
	self:SetFont(QuestFont_Super_Huge, fonts.header_light, 18, "", 0, 0, 0) -- 24 garrison mission list -- not present in WotLK
	self:SetFont(DestinyFontLarge, fonts.header_normal) -- 18 -- not present in WotLK
	self:SetFont(DestinyFontHuge, fonts.header_light) -- 32 -- not present in WotLK
	self:SetFont(CoreAbilityFont, fonts.header_light) -- 32 -- not present in WotLK
	self:SetFont(QuestFont_Shadow_Small, fonts.header_normal, nil, "", 0, 0, 0) -- 14 -- not present in WotLK
	self:SetFont(MailFont_Large, fonts.header_normal, nil, "", 0, 0, 0) -- 15
	
	-- floating combat text
	self:SetFont(CombatTextFont, self.fonts.damage, 100, "", -2.5, -2.5, .35) 
	
	-- chat font
	self:SetFont(ChatFontNormal, nil, nil, "", -.75, -.75, 1)
	
end

Module.SetFont = function(self, fontObject, font, size, style, shadowX, shadowY, shadowA, r, g, b, shadowR, shadowG, shadowB)
	-- simple copout for non-existing fontobjects
	if not fontObject then
		return
	end
	local oldFont, oldSize, oldStyle  = fontObject:GetFont()

	if not font then
		font = oldFont
	end

	if not size then
		size = oldSize
	end

	-- forcefully keep the outlines thin
	if not style then
		style = (oldStyle == "OUTLINE") and "THINOUTLINE" or oldStyle 
	end
	
	-- don't change the font face if it doesn't support the current locale
	fontObject:SetFont(self.canIUse[font] and font or oldFont, size, style) 
	if shadowX and shadowY then
		fontObject:SetShadowOffset(shadowX, shadowY)
		fontObject:SetShadowColor(shadowR or 0, shadowG or 0, shadowB or 0, shadowA or 1)
	end
	
	if r and g and b then
		fontObject:SetTextColor(r, g, b)
	end
	
	return fontObject	
end

Module.HookCombatText = function(self)
	-- combat text
--	COMBAT_TEXT_HEIGHT = 16
--	COMBAT_TEXT_CRIT_MAXHEIGHT = 16
--	COMBAT_TEXT_CRIT_MINHEIGHT = 16
--	COMBAT_TEXT_SCROLLSPEED = 3

	COMBAT_TEXT_HEIGHT = 16
	COMBAT_TEXT_CRIT_MAXHEIGHT = 16
	COMBAT_TEXT_CRIT_MINHEIGHT = 16
	COMBAT_TEXT_SCROLLSPEED = 3

	hooksecurefunc("CombatText_UpdateDisplayedMessages", function() 
--		if COMBAT_TEXT_FLOAT_MODE == "1" then
--			COMBAT_TEXT_LOCATIONS.startY = 484
--			COMBAT_TEXT_LOCATIONS.endY = 709
--		end
		COMBAT_TEXT_LOCATIONS.startY = 220
		COMBAT_TEXT_LOCATIONS.endY = 440
	end)
end

-- Settings live in their own top-level table of the saved variables. The engine
-- only rebuilds its registered config keys, so this table survives untouched,
-- and it can be read raw at our ADDON_LOADED — the earliest point where saved
-- variables exist, and early enough for DAMAGE_TEXT_FONT (PLAYER_LOGIN is not).
Module.GetCombatFontSettings = function(self)
	if type(DiabolicUI_DB) ~= "table" then DiabolicUI_DB = {} end
	local s = DiabolicUI_DB.CombatFont
	if type(s) ~= "table" then
		s = {}
		DiabolicUI_DB.CombatFont = s
	end
	if s.enabled == nil then s.enabled = true end
	if s.font == nil then s.font = "addon" end
	return s
end

-- { value, text, path } for every usable font: ours first, then the game's
Module.GetCombatFontList = function(self)
	if self.combatFontList then return self.combatFontList end
	local list = {
		{ value = "addon", text = "DiabolicUI (Coalition)", path = self.fonts.damage },
	}
	for _, f in ipairs(GAME_FONTS) do
		for _, path in ipairs(f.paths) do
			if fontLoads(path) then
				list[#list + 1] = { value = f.key, text = f.text, path = path }
				break
			end
		end
	end
	self.combatFontList = list
	return list
end

Module.GetCombatFontPath = function(self, key)
	for _, f in ipairs(self:GetCombatFontList()) do
		if f.value == key then return f.path end
	end
end

-- DAMAGE_TEXT_FONT (numbers over targets) is only picked up by the engine on a
-- full relog; CombatTextFont (Blizzard's scrolling combat text) updates live.
Module.ApplyCombatFont = function(self)
	local s = self:GetCombatFontSettings()
	if s.enabled then
		local path = self:GetCombatFontPath(s.font) or self.fonts.damage
		DAMAGE_TEXT_FONT = path
		if CombatTextFont then
			CombatTextFont:SetFont(path, 100, "")
			CombatTextFont:SetShadowOffset(-2.5, -2.5)
			CombatTextFont:SetShadowColor(0, 0, 0, .35)
		end
	else
		DAMAGE_TEXT_FONT = ORIG_DAMAGE_TEXT_FONT
		if CombatTextFont and ORIG_COMBAT.font then
			CombatTextFont:SetFont(ORIG_COMBAT.font, ORIG_COMBAT.size, ORIG_COMBAT.style)
			CombatTextFont:SetShadowOffset(ORIG_COMBAT.sx or 0, ORIG_COMBAT.sy or 0)
			CombatTextFont:SetShadowColor(ORIG_COMBAT.sr or 0, ORIG_COMBAT.sg or 0, ORIG_COMBAT.sb or 0, ORIG_COMBAT.sa or 0)
		end
	end
end

-- Fonts (especially game engine fonts) need to be set very early in the loading process, 
-- so for this specific module we'll bypass the normal loading order, and just fire away!
Module:SetUp()
Module:SetGameEngineFonts()
Module:SetFontObjects()

if IsAddOnLoaded("Blizzard_CombatText") then
	Module:HookCombatText()
	Module.hookedCombatText = true
end

Module.ADDON_LOADED = function(self, event, addon, ...)
	if addon == ADDON then
		-- saved variables are available now: apply the user's combat font choice
		self:ApplyCombatFont()
		self.appliedCombatFont = true
	elseif addon == "Blizzard_CombatText" and not self.hookedCombatText then
		self:HookCombatText()
		self.hookedCombatText = true
	end
	if self.appliedCombatFont and self.hookedCombatText then
		self:UnregisterEvent("ADDON_LOADED")
	end
end
Module:RegisterEvent("ADDON_LOADED")
