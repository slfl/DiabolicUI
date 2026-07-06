local _, Engine = ...
local Module = Engine:NewModule("CaptureBars")

-- Hide Blizzard's default capture bars (they otherwise float over the minimap).
-- They're created/relaid dynamically, so we re-hide them after each layout pass.
local function HideCaptureBars()
	local n = NUM_EXTENDED_UI_FRAMES or 10
	for i = 1, n do
		local bar = _G["WorldStateCaptureBar"..i]
		if bar and bar:IsShown() then
			bar:Hide()
		end
	end
end

Module.OnEnable = function(self)
	HideCaptureBars()

	if WorldStateAlwaysUpFrame_Update then
		hooksecurefunc("WorldStateAlwaysUpFrame_Update", HideCaptureBars)
	end

	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("UPDATE_WORLD_STATES")
	watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	watcher:SetScript("OnEvent", HideCaptureBars)
end
