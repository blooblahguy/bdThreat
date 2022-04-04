local addonName, addon = ...

local pixel = (PixelUtil.GetPixelToUIUnitFactor() / GetCVar("uiScale") or 1)
local border = pixel * 2
local warned = false -- warning levels for threat
local alerted = false -- warning levels for threat
local testmode = false
local total = 0
local noop = function() return false end

local media = {
	flat = "Interface\\Buttons\\WHITE8x8",
	font = "Interface\\Addons\\bdThreat\\PTSansNarrow.ttf",
	tank = "Interface\\Addons\\bdThreat\\tank.tga",
	smooth = "Interface\\Addons\\bdThreat\\smooth.tga",
}

local config = {
	window_width = 200,
	unit_limit = 8,
	bar_height = 22,
	me_bar_height = 28,
	warn = 80,
	alert = 100,
}
local window_height = ((config.bar_height + border) * config.unit_limit) + border - config.bar_height + config.me_bar_height

-- create frame
local threat = CreateFrame("frame", "bdThreat", UIParent, BackdropTemplateMixin and "BackdropTemplate")
threat:SetPoint("BOTTOMRIGHT", UIParent, -20, 20)
threat:SetMovable(true)
threat:SetUserPlaced(true)
threat:EnableMouse(true)
threat:SetResizable(true)
threat:SetSize(config.window_width, window_height)
threat:RegisterForDrag("LeftButton","RightButton")
threat:RegisterForDrag("LeftButton","RightButton")
threat:SetScript("OnDragStart", function(self) if (IsShiftKeyDown()) then self:StartMoving() end end)
threat:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
threat:SetBackdrop({bgFile = media.flat, edgeFile = media.flat, edgeSize = border})
threat:SetBackdropColor(0, 0, 0, 0.6)
threat:SetBackdropBorderColor(0, 0, 0, 1)
threat:SetScript("OnMouseWheel", function(self, delta)
	config.unit_limit = config.unit_limit - delta
	addon:kickoff()
end)

-- label text
threat.text = threat:CreateFontString(nil, "OVERLAY")
threat.text:SetFont(media.font, 14, "OUTLINE")
threat.text:SetPoint("CENTER", threat)
threat.text:SetAlpha(0.5)
threat.text:SetText("bdThreat")

-- window dragger
threat.drag = CreateFrame("Button", nil, threat)
threat.drag:EnableMouse("true")
threat.drag:SetPoint("BOTTOMRIGHT", -2, 2)
threat.drag:SetSize(12, 12)
threat.drag:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
threat.drag:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
threat.drag:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
threat.drag:SetScript("OnMouseDown", function(self)
	self:GetParent():StartSizing()
	self:SetScript("OnUpdate", function()
		addon:update_display()
	end)
end)
threat.drag:SetScript("OnMouseUp", function(self)
	self:GetParent():StopMovingOrSizing()
	self:SetScript("OnUpdate", noop)
end)

--===============================================
-- Functions
--===============================================
local function class_color(class)
	local color = RAID_CLASS_COLORS[class]
	return color.r, color.g, color.b
end

local function unit_color(unit)
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local color = RAID_CLASS_COLORS[class]
		return color.r, color.g, color.b
	end
end

local function numberize(n)
	if (n >= 10^6) then -- > 1,000,000
		return string.format("%.2fm", n / 10^6)
	elseif (n >= 10^4) then -- > 10,000
		return string.format("%.fk", n / 10^3)
	elseif (n >= 10^3) then -- > 10,000
		return string.format("%.1fk", n / 10^3)
	else
		return tostring(n)
	end
end

--===============================================
-- Bar Pool
--===============================================
local count = 0
local function create_bar(self)
	count = count + 1
	local bar = CreateFrame("statusbar", "bdThreat_Bar"..count, threat)
	bar:SetHeight(config.bar_height)
	bar:SetStatusBarTexture(media.smooth)
	bar:SetMinMaxValues(0, 1)

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(media.font, 14, "OUTLINE")

	bar.values = bar:CreateFontString(nil, "OVERLAY")
	bar.values:SetFont(media.font, 12, "OUTLINE")
	bar.values:SetPoint("RIGHT", bar, -6, 0)

	bar.icon = bar:CreateTexture(nil, "OVERLAY")
	bar.icon:SetTexture(media.tank)
	bar.icon:SetSize(14, 14)
	bar.icon:SetPoint("LEFT", bar, 4, 0)

	return bar
end

local function release_bar(self, frame)
	frame:ClearAllPoints()
	frame:SetHeight(config.bar_height)
	frame:Hide()
end

--===============================================
-- Vars
--===============================================
local player_unit = false
local forced_units = {}
local all_units = {}
local max_value = 0
local bar_pool = CreateObjectPool(create_bar, release_bar)

--===============================================
-- Main Functions
--===============================================
local function store_threat(unit, isTank)
	local isTanking, status, threatpct, rawthreatpct, threatvalue = UnitDetailedThreatSituation(unit, "target")
	-- print(unit, UnitDetailedThreatSituation(unit, "target"))
	if (status ~= nil) then -- and IsInInstance()
		local color = {unit_color(unit)}
		max_value = math.max(max_value, threatvalue)
		local name = select(1, UnitName(unit))

		-- make a priority table here
		if (UnitIsUnit(unit, "player")) then
			-- player
			player_unit = {name, color, isTanking, isTank, status, threatpct, rawthreatpct, threatvalue}
		elseif (isTank or isTanking) then
			-- tanks or current tank
			forced_units[name] = {name, color, isTanking, isTank, status, threatpct, rawthreatpct, threatvalue}
		else
			-- store rest in here
			table.insert(all_units, {name, color, isTanking, isTank, status, threatpct, rawthreatpct, threatvalue})
		end

	end
end

-- dummy data for testing
local dummy_names = {"Idontdodmg", "Medumbwarlock", "Idiot", "Farmed", "Bloo", "Padder", "Nodis", "Meofftank", "Metank", "Meextra", "Raidboss", "Over", "Lozy", "Shampy"}
local demo_names = {}
local function add_dummy_data(isTank, isTanking, isMe)
	demo_names = #demo_names > 0 and demo_names or {unpack(dummy_names)}
	local name = table.remove(demo_names, 1)
	local classes = {}
	for class, color in pairs(RAID_CLASS_COLORS) do table.insert(classes, class) end
	local color = {class_color(classes[math.random(#classes)])}
	local status = 1
	local threatvalue = math.random(0, 1203210)
	local rawthreatpct = (threatvalue / 1203210) * 130
	local threatpct = (threatvalue / 1203210) * 100

	max_value = math.max(max_value, threatvalue)

	-- add me in
	if (isMe) then
		name = select(1, UnitName("player"))
		color = {class_color(select(2, UnitClass("player")))}
	end

	if (isMe) then
		player_unit = {name, color, isTanking, isTank, status, threatpct, rawthreatpct, threatvalue}
	elseif (isTank or isTanking) then
		forced_units[name] = {name, color, isTanking, isTank, status, threatpct, rawthreatpct, threatvalue}
	else
		table.insert(all_units, {name, color, isTanking, isTank, status, threatpct, rawthreatpct, threatvalue})
	end
end

-- update unit lists
local function update_units()
	all_units = {}
	forced_units = {}
	player_unit = false
	max_value = 0

	local unit_pref
	local size

	-- check if we're using party or raid
	if (IsInRaid()) then
		unit_pref = "raid"
		size = 25
	else
		unit_pref = "party"
		size = 5
	end

	-- dummy data for testing
	if (testmode) then
		for i = 1, 10 do
			add_dummy_data(false, false, false)
		end
		
		--tanks
		for i = 1, 3 do
			local isTanking = i == 1 and true or false
			add_dummy_data(true, isTanking, false)
		end
		
		--me
		add_dummy_data(false, false, true)

		return
	end

	-- lets not run on units that aren't there
	if (not select(1, IsInInstance()) or not UnitExists("target") or not UnitCanAttack("player", "target")) then
		return
	end

	-- loop through players, getting tanks but not yourself
	for i = 0, size do
		local unit = unit_pref..i
		if (UnitExists(unit) and not UnitIsUnit(unit, "player")) then
			local isTank = UnitGroupRolesAssigned(unit) == "TANK" or GetPartyAssignment("MAINTANK", unit)
			store_threat(unit, isTank)
		end
	end

	-- now add yourself, cause sometimes we aren't in the raid roster and we need to be forced anyways
	local meTank = UnitGroupRolesAssigned("player") == "TANK" or GetPartyAssignment("MAINTANK", "player")
	store_threat("player", meTank)

	-- ok now let's alert if we're passing the tank
	if (not meTank) then
		local isTanking, status, threatpct, rawthreatpct, threatvalue = UnitDetailedThreatSituation("player", "target")

		if (status ~= nil) then
			if (rawthreatpct > 0 and rawthreatpct > config.warn) then
				if (not warned) then
					-- play warning sound
					PlaySound(846, "master")
					warned = true
				end
			else
				-- reset for next time we need to play it
				warned = false
			end
			
			if (rawthreatpct > 0 and rawthreatpct > config.alert) then
				if (not alerted) then
					-- play alerted sound
					PlaySound(17341, "master")
					alerted = true
				end
			else
				-- reset for next time we need to play it
				alerted = false
			end
		end
	end
end

-- update the threat window
function addon:update_display()
	bar_pool:ReleaseAll() -- empty item pool

	-- positioning vars
	local lastbar

	-- build a list of units to show
	local show = {}
	local used = {}

	-- add myself
	if (player_unit ~= false) then
		table.insert(show, player_unit)
	end

	-- add forced units in first
	for name, values in pairs(forced_units) do
		table.insert(show, values)
	end

	-- sort remaining units to make sure we add the top values in
	table.sort(all_units, function(a, b)
		if (a[8] ~= b[8]) then return a[8] > b[8] end
	end)

	-- and add them
	for key, values in pairs(all_units) do
		if (#show >= config.unit_limit) then break end -- we've maxed out
		table.insert(show, values)
	end

	-- now sort these fools again
	table.sort(show, function(a, b)
		if (a[8] ~= b[8]) then return a[8] > b[8] end
	end)

	-- hide threat text
	if (show[1] ~= nil) then
		threat.text:Hide()
	else
		threat.text:Show()
	end

	-- now position items inside of frame
	for k, info in pairs(show) do
		-- print(k)
		local name, color, isTanking, isTank, status, threatpct, rawthreatpct, threatvalue = unpack(info)
		local isMe = UnitIsUnit(name, "player")
		local bar = bar_pool:Acquire()

		-- rawthreatpct = (threatvalue / max_value) * 130
		-- threatpct = (threatvalue / max_value) * 100

		bar:Show()
		bar:SetStatusBarColor(unpack(color))
		bar:SetMinMaxValues(0, max_value)
		bar:SetValue(threatvalue)

		-- set current aggro target
		if (isTanking) then
			bar:SetStatusBarColor(1, 0, 0)
		end

		-- position and show icons
		if (isTank) then
			bar.icon:Show()
			bar.name:SetPoint("LEFT", bar.icon, "RIGHT", 4, 0)	
		else
			bar.icon:Hide()
			bar.name:SetPoint("LEFT", bar, 4, 0)
		end

		-- set name
		bar.name:SetText(name)

		local height = threat:GetHeight() / (config.unit_limit + 0.5) - border
		if (isMe) then
			bar:SetHeight(height * 1.5 - pixel)
		else
			bar:SetHeight(height)
		end
		
		-- make me special
		if (isMe) then
			-- bar:SetHeight(config.me_bar_height)
			bar.name:SetTextColor(1, .78, .31)
			bar.name:SetFont(media.font, bar:GetHeight() * 0.4, "OUTLINE")
			bar.values:SetTextColor(1, .78, .31)
			bar.values:SetFont(media.font, bar:GetHeight() * 0.4, "OUTLINE")
		else
			-- bar:SetHeight(config.bar_height)
			bar.name:SetTextColor(1, 1, 1)
			bar.name:SetFont(media.font, bar:GetHeight() * 0.5, "OUTLINE")
			bar.values:SetTextColor(1, 1, 1)
			bar.values:SetFont(media.font, bar:GetHeight() * 0.5, "OUTLINE")
		end

		-- set values
		
		local pct = Round(rawthreatpct)
		local amt = numberize(threatvalue)
		bar.values:SetText(amt.." : "..pct.."%")

		-- position
		if (not lastbar) then
			bar:SetPoint("TOPLEFT", threat, border, - border)
			bar:SetPoint("TOPRIGHT", threat, -border, - border)
		else
			bar:SetPoint("TOPLEFT", lastbar, "BOTTOMLEFT", 0, -border)
			bar:SetPoint("TOPRIGHT", lastbar, "BOTTOMRIGHT", 0, -border)
		end
		
		lastbar = bar
	end
end

--===============================================
-- Events
--===============================================
function addon:kickoff(self, event, arg1)
	if (not testmode and not InCombatLockdown()) then
		threat:Hide()
		return
	end
	threat:Show()

	-- update what units we are watching
	update_units()

	-- now redisplay it
	addon:update_display()
end

threat:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
threat:RegisterEvent("PLAYER_ENTERING_WORLD")
threat:RegisterEvent("PLAYER_TARGET_CHANGED")
threat:RegisterEvent("ADDON_LOADED")
threat:SetScript("OnEvent", function(self, event, arg1)
	if (event == "ADDON_LOADED" and arg1 == addonName) then
		threat:UnregisterEvent("ADDON_LOADED")

		-- Initialize Defaults
		BDTHREAT_SAVE = BDTHREAT_SAVE or config
		config = BDTHREAT_SAVE

		-- Create Window
		local window_height = ((config.bar_height + border) * config.unit_limit) + border - config.bar_height + config.me_bar_height
		-- threat:SetSize(config.window_width, window_height)

		print("bdThreat loaded. Ctrl+Shift+Click to drag. /bdt for other options")

		return
	end

	addon:kickoff()

	-- continual refresh of test data
	if (testmode) then
		threat:SetScript("OnUpdate", function(self, elapsed)
			total = total + elapsed
			if (total > 3) then
				total = 0
				addon:kickoff()
			end
		end)
	else
		threat:SetScript("OnUpdate", function() end)
	end
end)

--===============================================
-- Slash Commands
--===============================================
SLASH_BDTHREAT1, SLASH_BDTHREAT2 = "/bdthreat", '/bdt'
SlashCmdList["BDTHREAT"] = function(original_msg, editbox)
	local command, value = strsplit(" ", strtrim(original_msg), 2)

	-- basic commands
	if (command == "" or command == " ") then
		print("bdThreat Options:")
		print("   /bdthreat units [int] - Limits the number of units shown to this")
		print("   /bdthreat width [int] - Set window width")
		print("   /bdthreat barheight [int] - Set the bar height of other players")
		print("   /bdthreat playerheight [int] - Set the bar height of yourself")
		print("   /bdthreat warn [int] - Set the % of threat threshold to play warning sound")
		print("   /bdthreat alert [int] - Set the % of threat threshold to play alert sound")
		print("   /bdthreat test - Toggle test mode")
	end

	-- unit limits
	if (command == "units") then
		local value = tonumber(value)
		if (value and value > 0) then
			config.unit_limit = value
		end

		local window_height = ((config.bar_height + border) * config.unit_limit) + border - config.bar_height + config.me_bar_height
		-- threat:SetSize(config.window_width, window_height)
	end

	-- window width
	if (command == "width") then
		local value = tonumber(value)
		if (value and value > 0) then
			config.window_width = value
		end

		-- threat:SetWidth(config.window_width)
	end

	-- barheight
	if (command == "barheight") then
		local value = tonumber(value)
		if (value and value > 0) then
			config.bar_height = value
		end
	end

	-- my barheight
	if (command == "playerheight") then
		local value = tonumber(value)
		if (value and value > 0) then
			config.me_bar_height = value
		end
	end

	-- warn
	if (command == "warn") then
		local value = tonumber(value)
		if (value and value > 0) then
			config.warn = value
		end
	end

	-- alert
	if (command == "alert") then
		local value = tonumber(value)
		if (value and value > 0) then
			config.alert = value
		end
	end

	-- test
	if (command == "test") then
		testmode = not testmode
	end

	-- update everything
	addon:kickoff()
end