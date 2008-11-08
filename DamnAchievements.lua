local DA = {}
local blankFunc = function() end

local DEFAULT_FRAME_HEIGHT = 64
local TOTAL_MINI_ACHIEVEMENTS = 0
local achievementShown = {}
local searchName

local L = {
	["Search"] = "Search...",
}

function DA:Initialize()
	local orig_AchievementButton_Expand = AchievementButton_Expand
	AchievementButton_Expand = function(self, height, ...)
		height = height - 10
		
		-- Mini achievements aren't as high now since we use 7 per a row, not 6
		if( AchievementFrameMiniAchievement1 and AchievementFrameMiniAchievement1:IsVisible() ) then
			height = height - 10
			
			if( TOTAL_MINI_ACHIEVEMENTS >= 7 ) then
				height = height - 45
			elseif( self.reward:IsVisible() ) then
				height = height - 5
			end

		-- Progress bar achievements don't need any extra height if they are only a line of text + no reward
		elseif( AchievementFrameProgressBar1 and AchievementFrameProgressBar1:IsVisible() and math.floor(self.description:GetStringHeight()) <= 10 ) then
			height = DEFAULT_FRAME_HEIGHT
			
			if( self.reward:IsVisible() ) then
				height = height + 25
			end
		
		-- Meta achievements
		elseif( AchievementFrameMeta1 and AchievementFrameMeta1:IsVisible() ) then
			height = height - 10
			
			-- Only one line of text, reduce it a bit more
			if( math.floor(self.description:GetStringHeight()) <= 10 ) then
				height = height - 10
			end

   		-- Single line text achievements don't need as much room
   		elseif( self.reward:IsVisible() and math.floor(self.description:GetStringHeight()) <= 10 ) then
   			height = height - 15
   		end

		-- Subtract 25 so it matches our height reducations
		orig_AchievementButton_Expand(self, height, ...)

		-- Increase description size
		self.description:SetHeight(0)
	end

	orig_AchievementFrameAchievements_Update = AchievementFrameAchievements_Update
	AchievementFrameAchievements_Update = function(...)
		-- Reset the list of what we showed already
		for k in pairs(achievementShown) do achievementShown[k] = nil end
		
		orig_AchievementFrameAchievements_Update(...)
	end
	
	--[[
	-- Fix the scrolling stuff, this is a quick hack, I'll improve on it later... maybe
	orig_AchievementFrameAchievements_Update = AchievementFrameAchievements_Update
	AchievementFrameAchievements_Update = function(...)
		local category = achievementFunctions.selectedCategory
		if( category == "summary" ) then
			return
		end

		local scrollFrame = AchievementFrameAchievementsContainer		
		local offset = HybridScrollFrame_GetOffset(scrollFrame)
		local buttons = scrollFrame.buttons
		local numAchievements, numCompleted = GetCategoryNumAchievements(category)
		local extraHeight = scrollFrame.largeButtonHeight or DEFAULT_FRAME_HEIGHT

		local displayedHeight = 0
		for _, button in pairs(scrollFrame.buttons) do
			if( button:IsVisible() ) then
				displayedHeight = displayedHeight + button:GetHeight()
			end
		end

		local totalHeight = numAchievements * DEFAULT_FRAME_HEIGHT
		totalHeight = totalHeight + (extraHeight - DEFAULT_FRAME_HEIGHT)
		
		print(numAchievements, totalHeight, displayedHeight)

		-- Now call the original
		orig_AchievementFrameAchievements_Update(...)
	end
	
	-- Re-set functions so it uses the hooked one
	AchievementFrameAchievementsContainer.update = AchievementFrameAchievements_Update
	ACHIEVEMENT_FUNCTIONS.updateFunc = AchievementFrameAchievements_Update
	]]
	
	-- Restore the original height
	local orig_AchievementButton_Collapse = AchievementButton_Collapse
	AchievementButton_Collapse = function(self)
		orig_AchievementButton_Collapse(self)
		
		self.description:SetHeight(self.reward:IsVisible() and 30 or 0)
		self:SetHeight(DEFAULT_FRAME_HEIGHT)
	end
	
	-- So our global check thingy works
	local orig_AchievementButton_DisplayAchievement = AchievementButton_DisplayAchievement
	AchievementButton_DisplayAchievement = function(button, category, achievement, selectionID, ...)
		-- In order to avoid having to redo the entire display code, we hack the search in this way
		if( searchName ) then
			local id, name, points, completed, month, day, year, description, flags, icon, rewardText = GetAchievementInfo(category, achievement)
			if( achievementShown[id] or not name or not string.match(string.lower(name), searchName) ) then
				button:Hide()
				
				-- Keep going until we run out of achievements
				if( name ) then
					return AchievementButton_DisplayAchievement(button, category, achievement + 1, selectionID, ...)
				end
				return
			end
			
			-- Prevent the same achievement from showing up 5000 times
			achievementShown[id] = true
		end
		
		local result = orig_AchievementButton_DisplayAchievement(button, category, achievement, selectionID, ...)
		
		if( button.customCheck ) then
			-- Set checked if it's being tracked + hide it if it's been completed
			if( not button.completed ) then
				button.customCheck:SetChecked((button.id == GetTrackedAchievement()))
				button.customCheck:Show()
			else
				button.customCheck:Hide()
			end
		end
		
		-- Shift shield up if no reward, shift it down if there is
		button.shield:ClearAllPoints()
		button.shield:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, 2)
		
		-- Shift icon up if no reward, shift it down if there is
		button.icon:ClearAllPoints()
		button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -7)
		
		-- Moar room
		button.description:SetWidth(360)
		
		return result
	end
	
	-- More code ripped out of the achievement UI, modified to keep the objective stuff working right
	orig_AchievementButton_DisplayObjectives = AchievementButton_DisplayObjectives
	AchievementButton_DisplayObjectives = function(button, id, completed, ...)
		-- Call the original one and save the height
		local height = orig_AchievementButton_DisplayObjectives(button, id, completed, ...)
		
		-- Reset flags
		local objectives = AchievementFrameAchievementsObjectives

		-- Level 70 achievements where it has multiple for level 10/20/30/40/50/6
		if( completed and GetPreviousAchievement(id) ) then
			objectives:ClearAllPoints()
			objectives:SetPoint("TOP", (-3 * TOTAL_MINI_ACHIEVEMENTS), -30 - button.description:GetStringHeight())
		
		-- The rest, if we have a height set
		elseif( objectives:GetHeight() > 0 ) then
			-- Position progress achievements (Somebody order a knuckle sandwich)
			if( AchievementFrameProgressBar1 and AchievementFrameProgressBar1:IsVisible() ) then
				objectives:ClearAllPoints()
				objectives:SetPoint("CENTER", button, "CENTER", 0, -(button.description:GetStringHeight()))
							
			-- Position achievements for achievements (Hallowed Be Thy Name)
			elseif( AchievementFrameMeta1 and AchievementFrameMeta1:IsVisible() ) then
				objectives:ClearAllPoints()
				objectives:SetPoint("TOPLEFT", button, "TOPLEFT", 60, -25 - (button.description:GetStringHeight()))
							
			-- Position pure text achievements (The Keymaster)
			else
				objectives:ClearAllPoints()
				objectives:SetPoint("TOPLEFT", button, "TOPLEFT", 60, -35 - (button.description:GetStringHeight()))
			end

			-- For some stupid fucking reason, we have to set the width here or it bugs out
			objectives:SetWidth(1)
		end
		
		return height
	end
	
	-- Fix the cliping issue with progress bar text
	local fixedProgress = {}
	orig_AchievementButton_GetProgressBar = AchievementButton_GetProgressBar
	AchievementButton_GetProgressBar = function(index, ...)
		local frame = orig_AchievementButton_GetProgressBar(index, ...)
		if( not fixedProgress[frame] ) then
			fixedProgress[frame] = true
			getglobal(frame:GetName() .. "Text"):SetPoint("TOP", 0, -3)
		end
		
		return frame
	end
	
	-- Reset the criteria tooltips to prevent old ones from other achievements from showing
	orig_AchievementButton_GetMiniAchievement = AchievementButton_GetMiniAchievement
	AchievementButton_GetMiniAchievement = function(index, ...)
		local frame = orig_AchievementButton_GetMiniAchievement(index, ...)
		if( frame.numCriteria ) then
			for i=1, frame.numCriteria do
				frame["criteria" .. i] = nil
			end
		end
		
		return frame
	end
	
	-- Reposition the mini achievements like Level 70 so they use 7 icons per a row instead of 6 (plenty of space for this)
	orig_AchievementObjectives_DisplayProgressiveAchievement = AchievementObjectives_DisplayProgressiveAchievement
	AchievementObjectives_DisplayProgressiveAchievement = function(objectives, id)
		orig_AchievementObjectives_DisplayProgressiveAchievement(objectives, id)
		
		local id = 0
		while( true ) do
			id = id + 1
			local frame = getglobal("AchievementFrameMiniAchievement" .. id)
			if( not frame or not frame:IsVisible() ) then break end
			if( id == 1 ) then
				frame:SetPoint("TOPLEFT", objectives, "TOPLEFT", -4, -4)
			elseif( id == 8 ) then
				frame:SetPoint("TOPLEFT", AchievementFrameMiniAchievement1, "BOTTOMLEFT", 0, -8)
			else
				frame:SetPoint("TOPLEFT", "AchievementFrameMiniAchievement" .. (id - 1), "TOPRIGHT", 4, 0)
			end
		end
		
		objectives:SetHeight(math.ceil(id / 7) * ACHIEVEMENTUI_PROGRESSIVEHEIGHT)
		TOTAL_MINI_ACHIEVEMENTS = id - 1
	end
	
	-- Identify what we're showing to make this less of a horrible logic bitch
	--[[
	orig_AchievementObjectives_DisplayCriteria = orig_AchievementObjectives_DisplayCriteria or AchievementObjectives_DisplayCriteria
	AchievementObjectives_DisplayCriteria = function(objectives, id, ...)
		orig_AchievementObjectives_DisplayCriteria(objectives, id, ...)
		
		if( not id ) then
			return
		end

		for i=1, GetAchievementNumCriteria(id) do	
			local criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString = GetAchievementCriteriaInfo(id, i)
			if ( criteriaType == CRITERIA_TYPE_ACHIEVEMENT and assetID ) then
				objectives.hasMetaTypes = true
			elseif( bit.band(flags, ACHIEVEMENT_CRITERIA_PROGRESS_BAR) == ACHIEVEMENT_CRITERIA_PROGRESS_BAR ) then
				objectives.hasProgressTypes = true		
			else
				objectives.hasTextTypes = true		
			end
		end
	end
	]]
	
	-- Ripped out of the achievement UI, but modified for the smaller shield size
	local function SetText(self, text)
		getmetatable(self).__index.SetText(self, text)
		local width = self:GetStringWidth()

		-- Round the width, GetStringWidth returns a float.
		width = math.floor(width * 10 ^ 0 + 0.5) / 10 ^ 0
		if( math.fmod(width, 2) == 0 ) then
			self:SetPoint("TOPLEFT", "$parentIcon", 0, -15)
		else
			self:SetPoint("TOPLEFT", "$parentIcon", -1, -15)
		end
	end

	--[[
	frame.scrollBar.SetMinMaxValues = function(self, min, max)
		getmetatable(self).__index.SetMinMaxValues(self, min, self.setMinMaxCap or max)
	end

	frame.scrollBar.SetValue = function(self, value)
		if( self.setMinMaxCap and value > self.setMinMaxCap ) then value = self.setMinMaxCap end
		getmetatable(self).__index.SetValue(self, value)
	end
	]]
	
	-- Create two new achievement rows quickly
	local frame = AchievementFrameAchievementsContainer
	for i=1, 1 do
		local id = #(frame.buttons) + 1
		local name = "AchievementFrameAchievementsContainerButton" .. id
		local button = CreateFrame("Button", name, frame.scrollChild, "AchievementTemplate")
		button:SetPoint("TOPLEFT", frame.buttons[id - 1], "BOTTOMLEFT", 0, -2)
		table.insert(frame.buttons, button)
	end
		
	-- Update all the buttons
	local id = 1
	while( true ) do
		local name = "AchievementFrameAchievementsContainerButton" .. id
		local frame = getglobal(name)
		if( not frame ) then break end
		id = id + 1
		
		-- Re-set the API calls so it uses our new versions
		frame.Collapse = AchievementButton_Collapse
		frame.Expand = AchievementButton_Expand
		frame.shield.points.SetText = SetText

		-- Reduce shield size
		frame.shield:SetWidth(50)
		frame.shield:SetHeight(52)
		
		frame.shield.icon:SetWidth(50)
		frame.shield.icon:SetHeight(50)
		
		frame.shield.points:ClearAllPoints()
		frame.shield.points:SetFont((frame.shield.points:GetFont()), 14)
		frame.shield.points:SetText(frame.shield.points:GetText())
		
		-- Reduce icon size
		frame.icon:SetHeight(54)
		frame.icon:SetWidth(54)
		
		frame.icon.texture:SetWidth(46)
		frame.icon.texture:SetHeight(46)
		
		frame.icon.frame:SetWidth(frame.icon.texture:GetWidth() + 14)
		frame.icon.frame:SetHeight(frame.icon.texture:GetHeight() + 14)
		
		-- Shift description to match the new sizes
		frame.description:ClearAllPoints()
		frame.description:SetPoint("TOP", frame, "TOP", 0, -25)
		
		-- Reduce the background behind the achievement name
		local background = getglobal(name .. "TitleBackground")
		background:SetHeight(18)
		
		-- Shift label to fit the reduced background + reduce font size slightly
		frame.label:ClearAllPoints()
		frame.label:SetPoint("TOP", background, "TOP", 0, 2)
		frame.label:SetFont((frame.label:GetFont()), 13)
		
		-- Reduce background behind the achievement reward (if any)
		local background = getglobal(name.. "RewardBackground")
		background:SetHeight(18)

		-- Shift label to fit new size
		frame.reward:ClearAllPoints()
		frame.reward:SetPoint("TOP", background, "TOP", 0, 4)
		
		-- Stop the check icon + check box from showing
		frame.tracked.Show = blankFunc
		frame.tracked:Hide()
		
		frame.check.Show = blankFunc
		frame.check:Hide()
		
		-- Add tracking check box for them all without having to select it
		local check =  CreateFrame("CheckButton", name .. "CustomCheck", frame, "AchievementCheckButtonTemplate")
		getglobal(check:GetName() .. "Text"):Hide()

		check:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -3)
		check:SetWidth(20)
		check:SetHeight(20)
		check:SetHitRectInsets(-5, -5, -5, -5)

		frame.customCheck = check

		-- Get basics setup
		frame:Collapse()
	end
	
	--[[
	-- Setup search
	local search = self:CreateSearch()
	
	-- We can't monitor the OnShow/OnHide events because they aren't consistant (It's stupid, I know)
	orig_AchievementFrameBaseTab_OnClick = AchievementFrameBaseTab_OnClick
	AchievementFrameBaseTab_OnClick = function(id, ...)
		orig_AchievementFrameBaseTab_OnClick(id, ...)
		
		if( id == 1 ) then
			search:Show()
		else
			search:ClearFocus()
			search:Hide()
		end
	end
	]]
end

-- Search
local function searchInput(self)
	if( self.searchText or self:GetText() == "" ) then
		searchName = nil
	else
		searchName = string.lower(self:GetText())
	end
	
	AchievementFrameAchievements_Update()
end

function DA:CreateSearch()
	local search = CreateFrame("EditBox", "DASearchInput", AchievementFrameCategories, "InputBoxTemplate")
	search:SetHeight(16)
	search:SetWidth(184)
	search:SetAutoFocus(false)
	search:ClearAllPoints()
	search:SetPoint("BOTTOMLEFT", AchievementFrameCategories, "BOTTOMLEFT", 9, 4)
	search:SetFrameStrata("HIGH")
	search:Hide()
	
	search.searchText = true
	search:SetText(L["Search"])
	search:SetTextColor(0.90, 0.90, 0.90, 0.80)
	search:SetScript("OnTextChanged", searchInput)
	search:SetScript("OnEditFocusGained", function(self)
		if( self.searchText ) then
			self.searchText = nil
			self:SetText("")
			self:SetTextColor(1, 1, 1, 1)
		end
	end)
	
	search:SetScript("OnEditFocusLost", function(self)
		if( not self.searchText and string.trim(self:GetText()) == "" ) then
			self.searchText = true
			self:SetText(L["Search"])
			self:SetTextColor(0.90, 0.90, 0.90, 0.80)
		end
	end)
	
	return search
end



local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
	if( IsAddOnLoaded("Blizzard_AchievementUI") ) then
		DA:Initialize()
		self:UnregisterAllEvents()
	end
end)