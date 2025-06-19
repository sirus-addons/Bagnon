local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')
local ItemExpiration = Bagnon.Classy:New('Button')
Bagnon.ItemExpiration = ItemExpiration


local SIZE = 20
local NORMAL_TEXTURE_SIZE = 64 * (SIZE/36)

local HOOK = false

--[[ Constructor ]]--

function ItemExpiration:New(frameID, parent)
	local b = self:Bind(CreateFrame('Button', nil, parent))
	b:SetWidth(SIZE)
	b:SetHeight(SIZE)
	b:RegisterForClicks('anyUp')

	local nt = b:CreateTexture()
	nt:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	nt:SetWidth(NORMAL_TEXTURE_SIZE)
	nt:SetHeight(NORMAL_TEXTURE_SIZE)
	nt:SetPoint('CENTER', 0, -1)
	b:SetNormalTexture(nt)

	local pt = b:CreateTexture()
	pt:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	pt:SetAllPoints(b)
	b:SetPushedTexture(pt)

	local ht = b:CreateTexture()
	ht:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	ht:SetAllPoints(b)
	b:SetHighlightTexture(ht)

	local icon = b:CreateTexture()
	icon:SetAllPoints(b)
	icon:SetTexture([[Interface\Icons\Ability_BossMagistrix_Timewarp1]])

	b:SetScript('OnClick', b.OnClick)
	b:SetScript('OnEnter', b.OnEnter)
	b:SetScript('OnLeave', b.OnLeave)
	b:SetFrameID(frameID)

	self.frameAnchor = parent
	self:HookFrame()

	return b
end

function ItemExpiration:HookFrame()
	if HOOK then return end
	HOOK = true


	updatePosition = function()
		self:UpdatePosition()
	end

	ContainerItemExpirationFrame:HookScript("OnShow", updatePosition)

	if type(updateContainerFrameAnchors) == "function" then
		hooksecurefunc("updateContainerFrameAnchors", updatePosition)
	end
end

function ItemExpiration:UpdatePosition()
	ContainerItemExpirationFrame:ClearAllPoints()
	if self.frameAnchor:GetRight() > (GetScreenWidth() / 2) then
		ContainerItemExpirationFrame:SetPoint("BOTTOMRIGHT", self.frameAnchor, "BOTTOMLEFT", -10, 0)
	else
		ContainerItemExpirationFrame:SetPoint("BOTTOMLEFT", self.frameAnchor, "BOTTOMRIGHT", 10, 0)
	end
end


--[[ Frame Events ]]--

function ItemExpiration:OnClick()
	if type(ToggleContainerItemExpiration) == "function" then
		ToggleContainerItemExpiration()
		self:UpdatePosition()
	end
end

function ItemExpiration:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end
	self:UpdateTooltip()
end

function ItemExpiration:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end


--[[ Update Methods ]]--

function ItemExpiration:UpdateTooltip()
	if GameTooltip:IsOwned(self) then
		GameTooltip:SetText(ITEM_EXPIRATION_TOOLTIP, 1, 1, 1, true)
	end
end


--[[ Properties ]]--

function ItemExpiration:SetFrameID(frameID)
	if self:GetFrameID() ~= frameID then
		self.frameID = frameID
	end
end

function ItemExpiration:GetFrameID()
	return self.frameID
end