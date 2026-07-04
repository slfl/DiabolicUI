local _, Engine = ...
local Module = Engine:NewModule("Options", "LOW")
local L = Engine:GetLocale()

-- WoW API
local CreateFrame = CreateFrame
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory

-- Creates a single labelled checkbox tied to a boolean setting.
--   parent   : the options panel frame
--   name     : unique global-ish frame name suffix
--   label    : text shown next to the box
--   tooltip  : hover description (optional)
--   get      : function() -> boolean   (reads current value)
--   set      : function(checked)        (writes new value + applies live)
--   anchorTo : frame to anchor below (or nil for first item)
local function CreateCheckbox(parent, name, label, tooltip, get, set, anchorTo)
	local check = CreateFrame("CheckButton", "DiabolicUIOptions"..name, parent, "InterfaceOptionsCheckButtonTemplate")

	if anchorTo then
		check:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -8)
	else
		check:SetPoint("TOPLEFT", 16, -64)
	end

	local text = _G[check:GetName().."Text"]
	text:SetText(label)

	check.tooltipText = tooltip

	check:SetScript("OnShow", function(self)
		self:SetChecked(get() and true or false)
	end)

	check:SetScript("OnClick", function(self)
		local checked = self:GetChecked() and true or false
		set(checked)
	end)

	return check
end

Module.OnEnable = function(self)
	local panel = CreateFrame("Frame", "DiabolicUIOptionsPanel", UIParent)
	panel.name = "DiabolicUI"

	-- Title
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("DiabolicUI")

	-- Subtitle
	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText(L["Additional interface options."])

	-- Checkbox: FPS / latency readout
	local perf = CreateCheckbox(
		panel,
		"Performance",
		L["Show FPS and latency"],
		L["Toggles the performance readout (frames per second and latency) on the micro menu."],
		function()
			return Engine:GetConfig("UI").show_performance
		end,
		function(checked)
			Engine:GetConfig("UI").show_performance = checked
			-- apply immediately if the action bars module is ready
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdatePerformanceVisibility then
				ActionBars:UpdatePerformanceVisibility()
			end
		end,
		nil
	)

	-- Checkbox: class-colored health orb
	local classcolor = CreateCheckbox(
		panel,
		"ClassHealthColor",
		L["Class colored health orb"],
		L["Colors the player health orb using your class color instead of the default red."],
		function()
			return Engine:GetConfig("UI").class_health_color
		end,
		function(checked)
			Engine:GetConfig("UI").class_health_color = checked
			local UnitFrames = Engine:GetModule("UnitFrames", true)
			if UnitFrames and UnitFrames.RefreshHealthColor then
				UnitFrames:RefreshHealthColor()
			end
		end,
		perf
	)

	-- Sub-option: also color the pet health orb
	local classcolorpet = CreateCheckbox(
		panel,
		"ClassHealthColorPet",
		L["Also color the pet health orb"],
		L["Also colors the pet health orb using your class color."],
		function()
			return Engine:GetConfig("UI").class_health_color_pet
		end,
		function(checked)
			Engine:GetConfig("UI").class_health_color_pet = checked
			local UnitFrames = Engine:GetModule("UnitFrames", true)
			if UnitFrames and UnitFrames.RefreshHealthColor then
				UnitFrames:RefreshHealthColor()
			end
		end,
		classcolor
	)
	-- indent the sub-option slightly to show it belongs to the one above
	classcolorpet:SetPoint("TOPLEFT", classcolor, "BOTTOMLEFT", 16, -8)

	-- Register the panel in the Interface -> AddOns list
	InterfaceOptions_AddCategory(panel)

	self.panel = panel
end
