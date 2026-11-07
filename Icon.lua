local AddOn, config = ...
local icon
local editMode

local function TogglePeggleWindow()
	if editMode and editMode:IsInEditMode() then return end
	local m = PeggleWindow.minimap
	m:GetScript("OnMouseUp")(m, "LeftButton")
end

config.UpdateMinimapIcon = function()
	local show = PeggleData.settings.showMinimapIcon == true
	if editMode and editMode:IsInEditMode() then show = true end
	if icon then
		PeggleWindow.minimap:Hide()
		PeggleData.minimap.hide = not show
		if show then
			icon:Show("PeggleIcon")
		else
			icon:Hide("PeggleIcon")
		end
	else
		PeggleWindow.minimap:SetShown(show)
	end
end

local function GetMinimapOffset(button)
	local angle = math.rad(PeggleData.settings.minimapAngle or 42)
	local scale = Minimap:GetEffectiveScale() / button:GetEffectiveScale()
	local padding = math.max(button:GetWidth(), button:GetHeight()) / 2 + 8
	return -(Minimap:GetWidth() * scale / 2 + padding) * math.cos(angle),
		(Minimap:GetHeight() * scale / 2 + padding) * math.sin(angle)
end

local function PositionAtMinimap(button)
	local x, y = GetMinimapOffset(button)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function RegisterHUDButton(button)
	-- LibEditMode normalizes dragged coordinates against the frame's parent.
	button:SetParent(UIParent)
	button:SetDontSavePosition(true)
	PeggleProfile.hudLayouts = PeggleProfile.hudLayouts or {}
	local layouts = PeggleProfile.hudLayouts
	local activeLayout
	local default = {point = "CENTER", x = 0, y = 0}

	local function UpdateDefaultPosition()
		local x, y = Minimap:GetCenter()
		if x and y then
			local scale = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
			local offsetX, offsetY = GetMinimapOffset(button)
			default.x = x * scale - UIParent:GetWidth() / 2 + offsetX
			default.y = y * scale - UIParent:GetHeight() / 2 + offsetY
		end
	end

	local function ApplyPosition()
		UpdateDefaultPosition()
		local position = activeLayout and layouts[activeLayout]
		if position then
			button:ClearAllPoints()
			button:SetPoint(position.point, UIParent, position.point, position.x, position.y)
		else
			PositionAtMinimap(button)
		end
	end

	editMode:RegisterCallback("layout", function(layoutName)
		activeLayout = layoutName
		ApplyPosition()
	end)
	editMode:RegisterCallback("enter", function()
		UpdateDefaultPosition()
		config.UpdateMinimapIcon()
	end)
	editMode:RegisterCallback("exit", config.UpdateMinimapIcon)
	editMode:RegisterCallback("create", function(layoutName, _, sourceLayoutName)
		local source = sourceLayoutName and layouts[sourceLayoutName]
		if source then
			layouts[layoutName] = {point = source.point, x = source.x, y = source.y}
		end
		if activeLayout == layoutName then ApplyPosition() end
	end)
	editMode:RegisterCallback("rename", function(oldName, newName)
		layouts[newName] = layouts[oldName]
		layouts[oldName] = nil
		if activeLayout == oldName then activeLayout = newName end
	end)
	editMode:RegisterCallback("delete", function(layoutName)
		layouts[layoutName] = nil
		if activeLayout == layoutName then ApplyPosition() end
	end)

	ApplyPosition()
	editMode:AddFrame(button, function(_, layoutName, point, x, y)
		if not layoutName then return end
		activeLayout = layoutName
		-- Reset Position restores the minimap anchor as well as the coordinates.
		-- LibEditMode can normalize CENTER to a corner before invoking this callback.
		local centerX, centerY = button:GetCenter()
		if centerX and centerY
			and math.abs(centerX - (UIParent:GetWidth() / 2 + default.x)) < .01
			and math.abs(centerY - (UIParent:GetHeight() / 2 + default.y)) < .01 then
			layouts[layoutName] = nil
		else
			layouts[layoutName] = {point = point, x = x, y = y}
		end
		ApplyPosition()
	end, default, "Peggle Button")
	Minimap:HookScript("OnSizeChanged", ApplyPosition)
	UIParent:HookScript("OnSizeChanged", ApplyPosition)
end

local function OnEvent(self)
	self:UnregisterEvent("VARIABLES_LOADED")
	if config.LibEditMode and config.LibEditMode.AddFrame and EditModeManagerFrame then
		editMode = config.LibEditMode
	end
	local broker = LibStub and LibStub("LibDataBroker-1.1", true)
	local dbIcon = LibStub and LibStub("LibDBIcon-1.0", true)
	if broker then
		local ldb = broker:NewDataObject("PeggleLDB", {
			type = "data source",
			text = "Peggle",
			icon = "Interface\\AddOns\\"..AddOn.."\\images\\minimap",
			OnClick = TogglePeggleWindow,
			OnTooltipShow = function(tt)
				tt:AddLine("|cFFFFFFFFPeggle")
			end,
		})
		-- LibDBIcon owns its minimap anchor; the HUD editor needs a free-moving frame.
		if dbIcon and not editMode then
			icon = dbIcon
			PeggleData.minimap = PeggleData.minimap or {}
			PeggleData.minimap.hide = PeggleData.settings.showMinimapIcon ~= true
			icon:Register("PeggleIcon", ldb, PeggleData.minimap)
		end
	end
	if not icon then
		-- Source checkouts can run without the libraries added by the release packager.
		local m = PeggleWindow.minimap
		if editMode then
			RegisterHUDButton(m)
		else
			PositionAtMinimap(m)
			Minimap:HookScript("OnSizeChanged", function() PositionAtMinimap(m) end)
		end
		m:SetScript("OnEnter", function(self)
			self.highlight:Show()
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText("Peggle")
			GameTooltip:Show()
		end)
		m:SetScript("OnLeave", function(self)
			self.highlight:Hide()
			GameTooltip:Hide()
		end)
	end
	config.UpdateMinimapIcon()
end

local f = CreateFrame("Frame")
-- The core finishes saved-variable initialization during VARIABLES_LOADED.
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", OnEvent)
