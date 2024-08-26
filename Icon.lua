local function TogglePeggleWindow()
	local m = PeggleWindow.minimap
	m:GetScript("OnMouseUp")(m, "LeftButton")
end

local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("PeggleLDB", {
	type = "data source",
	text = "Peggle",
	icon = "Interface\\AddOns\\Peggle\\images\\minimap.tga",
	OnClick = TogglePeggleWindow,
	OnTooltipShow = function(tt)
		tt:AddLine("|cFFFFFFFFPeggle")
	end,
})

local icon = LibStub("LibDBIcon-1.0")

local function OnEvent(self, event, addon)
	if addon == "Peggle" then
		PeggleData.minimap = PeggleData.minimap or {}
		icon:Register("PeggleIcon", ldb, PeggleData.minimap)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnEvent)
