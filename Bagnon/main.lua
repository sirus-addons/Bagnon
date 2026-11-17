--[[
	main.lua
		The bagnon driver thingy
--]]

Bagnon = LibStub('AceAddon-3.0'):NewAddon('Bagnon', 'AceEvent-3.0', 'AceConsole-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')


--[[
	Binding Setup
--]]

BINDING_HEADER_BAGNON = 'Bagnon'
BINDING_NAME_BAGNON_TOGGLE = L.ToggleBags
BINDING_NAME_BANKNON_TOGGLE = L.ToggleBank
BINDING_NAME_BAGNON_KEYS_TOGGLE = L.ToggleKeys


--[[
	Startup
--]]

function Bagnon:OnInitialize()
	self.frames = {}

	self:HookBagClickEvents()
	self:RegisterAutoDisplayEvents()
	self:AddSlashCommands()
	self:CreateOptionsLoader()
	self:CreateLDBLauncher()
	self:CreateGuildBankLoader()
end

--create a loader for the options menu
function Bagnon:CreateOptionsLoader()
	local f = CreateFrame('Frame', nil, InterfaceOptionsFrame)
	f:SetScript('OnShow', function(self)
		self:SetScript('OnShow', nil)
		LoadAddOn('Bagnon_Config')
	end)
end

function Bagnon:CreateGuildBankLoader()
	local name, title, notes, enabled, loadable = GetAddOnInfo('Bagnon_GuildBank')
	if enabled and loadable then
		GuildBankFrame_LoadUI = function()
			LoadAddOn('Bagnon_GuildBank') 
		end
	end
end

function Bagnon:CreateLDBLauncher()
	local LDB = LibStub:GetLibrary('LibDataBroker-1.1', true)
	if not LDB then return end

	LDB:NewDataObject('BagnonLauncher', {
		type = 'launcher',

		icon = [[Interface\Icons\INV_Misc_Bag_07]],

		OnClick = function(_, button)
			if button == 'LeftButton' then
				if IsShiftKeyDown() then
					Bagnon:ToggleFrame('bank')
				elseif IsAltKeyDown() then
					Bagnon:ToggleFrame('keys')
				else
					Bagnon:ToggleFrame('inventory')
				end
			elseif button == 'RightButton' then
				Bagnon:ShowOptions()
			end
		end,

		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then return end

			tooltip:AddLine('Bagnon')
			tooltip:AddLine(L.TipShowInventory, 1, 1, 1)
			tooltip:AddLine(L.TipShowBank, 1, 1, 1)
			tooltip:AddLine(L.TipShowKeyring, 1, 1, 1)
			tooltip:AddLine(L.TipShowOptions, 1, 1, 1)
		end,
	})
end


--[[
	Frame Display
--]]

function Bagnon:GetFrame(frameID)
	for i, frame in pairs(self.frames) do
		if frame:GetFrameID() == frameID then
			return frame
		end
	end
end

function Bagnon:CreateFrame(frameID)
	table.insert(self.frames, self.Frame:New(frameID))
end

function Bagnon:ShowFrame(frameID)
	if self:IsFrameEnabled(frameID) then
		if not self:GetFrame(frameID) then
			self:CreateFrame(frameID)
		end

		self.FrameSettings:Get(frameID):Show()
		return true
	end
	return false
end

function Bagnon:HideFrame(frameID)
	if self:IsFrameEnabled(frameID) then
		self.FrameSettings:Get(frameID):Hide()
		return true
	end
	return false
end

function Bagnon:ToggleFrame(frameID)
	if self:IsFrameEnabled(frameID) then
		if not self:GetFrame(frameID) then
			self:CreateFrame(frameID)
		end

		self.FrameSettings:Get(frameID):Toggle()
		return true
	end
	return false
end

function Bagnon:IsFrameEnabled(frameID)
	return self.Settings:IsFrameEnabled(frameID)
end

function Bagnon:FrameControlsBag(frameID, bagSlot)
	return self.FrameSettings:Get(frameID):IsBagSlotShown(bagSlot) or (not self:IsBlizzardBagPassThroughEnabled())
end

function Bagnon:IsBlizzardBagPassThroughEnabled()
	return self.Settings:IsBlizzardBagPassThroughEnabled()
end


--[[
	Bag Click Events
--]]

function Bagnon:HookBagClickEvents()
	self:HideBlizzardBagFrames()

	local pending
	local updater = CreateFrame('Frame')
	updater:Hide()
	updater:SetScript('OnUpdate', function(f)
		f:Hide()
		local action = pending
		pending = nil
		action()
	end)

	local function hook(name, action)
		hooksecurefunc(name, function(arg1, arg2)
			pending = function() action(arg1, arg2) end
			updater:Show()
		end)
	end

	--backpack
	hook('CloseBackpack', function()
		self:HideFrame('inventory')
	end)

	hook('OpenBackpack', function()
		if self:FrameControlsBag('inventory', BACKPACK_CONTAINER) then
			self:ShowFrame('inventory')
		end
	end)

	hook('ToggleBackpack', function()
		if self:FrameControlsBag('inventory', BACKPACK_CONTAINER) then
			self:ToggleFrame('inventory')
		end
	end)

	--single bag
	hook('ToggleBag', function(bagSlot)
		local frameID = self:GetBagFrameID(bagSlot)
		if frameID then
			self:ToggleFrame(frameID)
		end
	end)

	hook('OpenBag', function(bagSlot)
		local frameID = self:GetBagFrameID(bagSlot)
		if frameID then
			self:ShowFrame(frameID)
		end
	end)

	--keyring
	hook('ToggleKeyRing', function()
		local toggled = self:FrameControlsBag('keys', KEYRING_CONTAINER) and self:ToggleFrame('keys')

		if not toggled and self:FrameControlsBag('inventory', KEYRING_CONTAINER) then
			self:ToggleFrame('inventory')
		end
	end)

	--all bags
	--closing the game menu triggers this function, and can be done in combat
	hook('CloseAllBags', function()
		self:HideFrame('inventory')
	end)

	hook('OpenAllBags', function(frame, force)
		if self:FrameControlsBag('inventory', BACKPACK_CONTAINER) then
			if frame or force then
				self:ShowFrame('inventory')
			else
				self:ToggleFrame('inventory')
			end
		end
	end)

	hooksecurefunc('BackpackButton_UpdateChecked', function() self:UpdateBlizzardBagButtons() end)
	hooksecurefunc('BagSlotButton_UpdateChecked', function() self:UpdateBlizzardBagButtons() end)
end

function Bagnon:HideBlizzardBagFrames()
	local hiddenParent = CreateFrame('Frame', nil, UIParent)
	hiddenParent:SetAllPoints()
	hiddenParent:Hide()

	local parents = {}
	local function hide(frame)
		if frame then
			parents[frame] = frame:GetParent()
			frame:SetParent(hiddenParent)
			frame:HookScript('OnHide', function() frame:SetParent(hiddenParent) end)
		end
	end

	for i = 1, NUM_CONTAINER_FRAMES do
		hide(_G['ContainerFrame' .. i])
	end
	hide(ContainerFrameCombinedBags)
	hide(ContainerFrameCombinedBank)

	hooksecurefunc('ContainerFrame_GenerateFrame', function(frame, size, bagSlot)
		if frame == ContainerFrameCombinedBank then
			bagSlot = BANK_CONTAINER
		end
		if parents[frame] and not self:GetBagFrameID(bagSlot) then
			frame:SetParent(parents[frame])
		end
	end)

	self.hiddenBlizzardBagFrames = hiddenParent
end

function Bagnon:CloseBlizzardBagFrames(frameID)
	for _, frame in pairs({self.hiddenBlizzardBagFrames:GetChildren()}) do
		local bagSlot = frame == ContainerFrameCombinedBank and BANK_CONTAINER or frame:GetID()
		if frame:IsShown() and self:GetBagFrameID(bagSlot) == frameID then
			frame:Hide()
		end
	end
end

function Bagnon:UpdateBlizzardBagButtons()
	local frame = self:GetFrame('inventory')
	local shown = frame and frame:IsVisible()

	for bagSlot = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		if self:GetBagFrameID(bagSlot) == 'inventory' then
			local button = bagSlot == BACKPACK_CONTAINER and MainMenuBarBackpackButton or _G['CharacterBag' .. (bagSlot - 1) .. 'Slot']
			button:SetChecked(shown)
		end
	end
end

function Bagnon:GetBagFrameID(bagSlot)
	if bagSlot == KEYRING_CONTAINER then
		if self:IsFrameEnabled('keys') and self:FrameControlsBag('keys', bagSlot) then
			return 'keys'
		end
	end

	local frameID = (self.BagSlotInfo:IsBank(bagSlot) or self.BagSlotInfo:IsBankBag(bagSlot)) and 'bank' or 'inventory'
	if self:IsFrameEnabled(frameID) and self:FrameControlsBag(frameID, bagSlot) then
		return frameID
	end
end


--[[
	Automatic Display
--]]

function Bagnon:RegisterAutoDisplayEvents()
	self.BagEvents:Listen(self, 'BANK_OPENED')
	self.BagEvents:Listen(self, 'BANK_CLOSED')
	self:RegisterEvent('MAIL_CLOSED')
	self:RegisterEvent('AUCTION_HOUSE_SHOW')
	self:RegisterEvent('AUCTION_HOUSE_CLOSED')
	self:RegisterEvent('MERCHANT_SHOW')
	self:RegisterEvent('MERCHANT_CLOSED')
	self:RegisterEvent('TRADE_SHOW')
	self:RegisterEvent('TRADE_CLOSED')
	self:RegisterEvent('TRADE_SKILL_SHOW')
	self:RegisterEvent('TRADE_SKILL_CLOSE')
	self:RegisterEvent('GUILDBANKFRAME_OPENED')
	self:RegisterEvent('GUILDBANKFRAME_CLOSED')

	--override normal bank display
	if self:IsFrameEnabled('bank') then
		BankFrame:UnregisterEvent('BANKFRAME_OPENED')
		BankFrame:UnregisterEvent('BANKFRAME_CLOSED')
	end
	
	local f = CreateFrame('Frame', nil, CharacterFrame)
	f:SetScript('OnShow', function() Bagnon:PLAYER_FRAME_SHOW() end)
	f:SetScript('OnHide', function() Bagnon:PLAYER_FRAME_HIDE() end)
end

function Bagnon:ShowFrameAtEvent(frameID, event)
	if self:AutoDisplayingFrameOnEvent(frameID, event) then
		self:ShowFrame(frameID)
	end
end

function Bagnon:HideFrameAtEvent(frameID, event)
	if self:AutoDisplayingFrameOnEvent(frameID, event) then
		self:HideFrame(frameID)
	end
end

function Bagnon:AutoDisplayingFrameOnEvent(frameID, event)
	return self.Settings:IsFrameShownAtEvent(frameID, event)
end


--[[ Display Events ]]--

--visiting the bank
function Bagnon:BANK_OPENED()
	self:ShowFrame('bank')
	self:ShowFrameAtEvent('inventory', 'bank')
end

function Bagnon:BANK_CLOSED()
	self:HideFrame('bank')
	self:HideFrameAtEvent('inventory', 'bank')
end

--visiting the mailbox
--mail frame is a special case, since its automatically handled by the stock interface
function Bagnon:MAIL_CLOSED()
	self:HideFrame('inventory')
end

--visiting the auction house
function Bagnon:AUCTION_HOUSE_SHOW()
	self:ShowFrameAtEvent('inventory', 'ah')
end

function Bagnon:AUCTION_HOUSE_CLOSED()
	self:HideFrameAtEvent('inventory', 'ah')
end

--visitng a vendor
function Bagnon:MERCHANT_SHOW()
	self:ShowFrameAtEvent('inventory', 'vendor')
end

function Bagnon:MERCHANT_CLOSED()
	self:HideFrameAtEvent('inventory', 'vendor')
end

--trading
function Bagnon:TRADE_SHOW()
	self:ShowFrameAtEvent('inventory', 'trade')
end

function Bagnon:TRADE_CLOSED()
	self:HideFrameAtEvent('inventory', 'trade')
end

--visiting the guild bank
function Bagnon:GUILDBANKFRAME_OPENED()
	self:ShowFrameAtEvent('inventory', 'guildbank')
end

function Bagnon:GUILDBANKFRAME_CLOSED()
	self:HideFrameAtEvent('inventory', 'guildbank')
end

--crafting
function Bagnon:TRADE_SKILL_SHOW()
	self:ShowFrameAtEvent('inventory', 'craft')
end

function Bagnon:TRADE_SKILL_CLOSE()
	self:HideFrameAtEvent('inventory', 'craft')
end

--player frame
function Bagnon:PLAYER_FRAME_SHOW()
	self:ShowFrameAtEvent('inventory', 'player')
end

function Bagnon:PLAYER_FRAME_HIDE()
	self:HideFrameAtEvent('inventory', 'player')
end


--[[
	Slash Commands
--]]

function Bagnon:AddSlashCommands()
	self:RegisterChatCommand('bagnon', 'HandleSlashCommand')
	self:RegisterChatCommand('bgn', 'HandleSlashCommand')
end

function Bagnon:HandleSlashCommand(cmd)
	cmd = cmd and cmd:lower() or ''
	if cmd == 'bank' then
		self:ToggleFrame('bank')
	elseif cmd == 'bags' then
		self:ToggleFrame('inventory')
	elseif cmd == 'keys' then
		self:ToggleFrame('keys')
	elseif cmd == 'version' then
		self:PrintVersion()
	elseif cmd == 'config' then
		self:ShowOptions()
	elseif cmd == '?' or cmd == 'help' then
		self:PrintHelp()
	else
		if not self:ShowOptions() then
			self:PrintHelp()
		end
	end
end

function Bagnon:PrintVersion()
	self:Print(self.SavedSettings:GetDBVersion())
end

function Bagnon:PrintHelp()
	local function PrintCmd(cmd, desc)
		print(string.format(' - |cFF33FF99%s|r: %s', cmd, desc))
	end

	self:Print(L.Commands)
	PrintCmd('bags', L.CmdShowInventory)
	PrintCmd('bank', L.CmdShowBank)
	PrintCmd('keys', L.CmdShowKeyring)
	PrintCmd('version', L.CmdShowVersion)
end

function Bagnon:ShowOptions()
	if LoadAddOn('Bagnon_Config') then
		InterfaceOptionsFrame_OpenToCategory(self.GeneralOptions)
		return true
	end
	return false
end