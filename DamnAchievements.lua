local DA = {}
local blankFunc = function() end

local DEFAULT_FRAME_HEIGHT = 64
local TOTAL_MINI_ACHIEVEMENTS = 0
local lastOffset = 0
local isScrolledFull

function DA:Initialize()
	-- Removes the red border on completed achievements, it's obvious enough already they are completed
	ACHIEVEMENTUI_REDBORDER_R = 0.5
	ACHIEVEMENTUI_REDBORDER_G = 0.5
	ACHIEVEMENTUI_REDBORDER_B = 0.5
	
	ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT = 64

	local scrollOffset
	local isFixedScroll
	
	local orig_AchievementButton_Expand = AchievementButton_Expand
	AchievementButton_Expand = function(self, height, ...)
		-- Not a Blizzard button, so return it quickly
		if( not self.isBlizzardButton ) then
			return orig_AchievementButton_Expand(self, height, ...)
		end
		
		if( self.collapsed ) then
			-- Progress bar achievements don't need any extra height if they are only a line of text + no reward
			if( AchievementFrameProgressBar1 and AchievementFrameProgressBar1:IsVisible() and math.floor(self.description:GetStringHeight()) <= 10 ) then
				height = DEFAULT_FRAME_HEIGHT

				if( self.reward:IsVisible() ) then
					height = height + 25
				end

			-- Mini achievements, hit Level 80, Mini-pet achievements, etc
			elseif( AchievementFrameMiniAchievement1 and AchievementFrameMiniAchievement1:IsVisible() ) then

			-- Text achievements, Higher Learning, Well Read
			elseif( AchievementFrameCriteria1 and AchievementFrameCriteria1:IsVisible() ) then
				if( self.reward:IsVisible() ) then
					height = height + 10
				end

			-- Meta achievements, Glory of the Hero, etc
			elseif( AchievementFrameMeta1 and AchievementFrameMeta1:IsVisible() ) then
				local rows = math.ceil(AchievementFrameAchievementsObjectives:GetHeight() / ACHIEVEMENTBUTTON_CRITERIAROWHEIGHT)
				rows = rows / 2

				height = height - AchievementFrameAchievementsObjectives:GetHeight()
				height = math.floor(height + (rows * 28.5))

			-- For achievements like The Immortal with 3 lines of text, no other criteria, and a reward
			-- we only show two lines of text in this case, so we do a fake expand to make it show the rest when selected
			elseif( math.floor(self.hiddenDescription:GetHeight()) >= 25 ) then
				height = height + 14
			end
		end
		
		orig_AchievementButton_Expand(self, height, ...)

		-- If an achievement is the last one visible, set the offset to it, this fixes the issue where a quest can expand
		-- the screen and be unscrollable to view.
		if( scrollOffset ) then
			if( isScrolledFull ) then
				isScrolledFull = nil
				return
			end
		
			local lastVisible
			for _, button in pairs(AchievementFrameAchievementsContainer.buttons) do
				if( not button:IsVisible() ) then break end
				lastVisible = button
			end
			
			if( lastVisible == self ) then
				-- If we don't do this, we stack overflow
				local temp = scrollOffset
				scrollOffset = nil
				
				HybridScrollFrame_SetOffset(AchievementFrameAchievementsContainer, temp)
			end
		end

		-- Increase description size
		self.description:SetHeight(0)
	end
	
	-- To fix achievements not correctly being scrolled
	local orig_HybridScrollFrame_SetOffset = HybridScrollFrame_SetOffset
	HybridScrollFrame_SetOffset = function(self, offset, ...)
		orig_HybridScrollFrame_SetOffset(self, offset, ...)
		
		if( self == AchievementFrameAchievementsContainer ) then
			scrollOffset = offset
		end
	end
	
	-- If we scrolled all the way down, when we next call _Expand we will block the offset reset, meaning it won't mess up everything anymore
	local orig_ScrollDisable = AchievementFrameAchievementsContainer.scrollDown.Disable
	AchievementFrameAchievementsContainer.scrollDown.Disable = function(...)
		isScrolledFull = true
		return orig_ScrollDisable(...)
	end
	
	--[[
		Testing bugged scroll at bottom in dungeons/raids
		
		No bug: GetOffset, Update 17 1349 821, SetOffset 556.25, OnValueChanged 556.25, OnMouseWheel 1
		Bug: GetOffset, GetOffset, Update 17 1349 1067, SetOffset 896, Update 17 1349 821, SetOffset 556, OnValueChanged 556, OnMouseWheel 1
	
	]]
	
	-- Expand something: ExpandButton 0 84, GetOffset, Update 12 788 596
	-- Scroll down: GetOffset, Update 12 788 576, SetOffset 335, OnValueChanged 335, OnMouseWheel -1
	-- Expand something again: ExpandButton 704 84.21, GetOffset, Update 12 788 596.21
	-- Collapse: CollapseButton,  GetOffset SetOffset 315, OnValueChanged 315, Update 12 768 576, CollapseButton
	-- Expand again: ExpandButton 704 84.21, GetOffset, SetOffset, OnValueChanged 315, GetOffset, Update 12 788 616, SetOffset 335, OnValueChanged 335, Update 12 788 596


	--[[
	local orig_HybridScrollFrame_SetOffset = HybridScrollFrame_SetOffset
	HybridScrollFrame_SetOffset = function(self, offset)
		if( self == AchievementFrameAchievementsContainer ) then
			lastOffset = offset
		end
		
		orig_HybridScrollFrame_SetOffset(self, offset)
	end
	]]
	
	-- Expandy
	-- I'm not happy with this solution, but if I hook this I can only need to do an additional 4 lines of code
	-- instead of having to rewrite the AchievementFrameAchievements_Update function
	--[[
	local orig_HybridScrollFrame_ExpandButton = HybridScrollFrame_ExpandButton
	HybridScrollFrame_ExpandButton = function(self, offset, height, ...)
		if( self == AchievementFrameAchievementsContainer ) then
			height = height == DEFAULT_FRAME_HEIGHT and ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT or height
		end
		
		orig_HybridScrollFrame_ExpandButton(self, offset, height, ...)
	end
	]]
	
	-- Restore the original height
	local orig_AchievementButton_Collapse = AchievementButton_Collapse
	AchievementButton_Collapse = function(self)
		orig_AchievementButton_Collapse(self)
		
		-- Resize the container to default
		if( self.isBlizzardButton ) then
			self:SetHeight(DEFAULT_FRAME_HEIGHT)
		end
	end
	
	-- Our custom changes things
	local orig_AchievementButton_DisplayAchievement = AchievementButton_DisplayAchievement
	AchievementButton_DisplayAchievement = function(button, category, achievement, selectionID, ...)
		-- Call original + save results
		local result = orig_AchievementButton_DisplayAchievement(button, category, achievement, selectionID, ...)
		
		-- Not a Blizzard button, so return it quickly
		if( not button.isBlizzardButton ) then
			return result
		end
		
		-- Show the check button if it's not completed, or if it was tracked but it's now completed
		-- (So they can uncheck it of course)
		if( not button.completed or button.id == GetTrackedAchievement() ) then
			button.customCheck:SetChecked((button.id == GetTrackedAchievement()))
			button.customCheck:Show()
		else
			button.customCheck:Hide()
		end
		
		-- Shift shield up if no reward, shift it down if there is
		button.shield:ClearAllPoints()
		button.shield:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, 2)
		
		-- Shift icon up if no reward, shift it down if there is
		button.icon:ClearAllPoints()
		button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -7)
		
		-- Reset size if it's collapsed
		if( selectionID ~= button.id ) then
			button.description:SetWidth(360)
			button.description:SetHeight(button.reward:IsVisible() and 25 or 0)

			button.hiddenDescription:SetWidth(360)
			button.hiddenDescription:SetHeight(0)
			button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)
		else
			button:SetBackdropBorderColor(1.0, 0.15, 0.05, 1.0)
		end
				
		return result
	end
	
	-- More code ripped out of the achievement UI, modified to keep the objective stuff working right
	local orig_AchievementButton_DisplayObjectives = AchievementButton_DisplayObjectives
	AchievementButton_DisplayObjectives = function(button, id, completed, ...)
		-- Call the original one and save the height
		local height = orig_AchievementButton_DisplayObjectives(button, id, completed, ...)
		local objectives = AchievementFrameAchievementsObjectives

		-- Custom button that isn't default Blizzard, don't modify it (at all)
		if( not self.isBlizzardButton ) then
			return height
		end

		-- Level 70 achievements where it has multiple for level 10/20/30/40/50/60
		if( id and completed and GetPreviousAchievement(id) ) then
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
				--objectives:ClearAllPoints()
				--objectives:SetPoint("TOPLEFT", button, "TOPLEFT", 60, -35 - (button.description:GetStringHeight()))
			end

			-- For some odd reason, we have to set the width here or it bugs out
			objectives:SetWidth(1)
		
		-- Fakes it so it'll actually expand the frame. This is for something with a reward + to much text, like The Immortal
		elseif( button.reward:IsVisible() and math.floor(button.hiddenDescription:GetHeight()) > 20 ) then
			height = height + 1
		end

		-- Give the user a visual queue that the frame was clicked on, even if it doesn't resize
		if( height == 0 ) then
			getglobal(button:GetName() .. "Background"):SetTexCoord(0, 1, math.max(0, 1 - (button:GetHeight() / 256)), 1)
			getglobal(button:GetName() .. "Glow"):SetTexCoord(0, 1, 0, (self:GetHeight() + 5) / 128)
		end
		
		return height
	end
	
	-- Fix the cliping issue with progress bar text
	local fixedProgress = {}
	local orig_AchievementButton_GetProgressBar = AchievementButton_GetProgressBar
	AchievementButton_GetProgressBar = function(index, ...)
		local frame = orig_AchievementButton_GetProgressBar(index, ...)
		if( not fixedProgress[frame] ) then
			fixedProgress[frame] = true
			getglobal(frame:GetName() .. "Text"):SetPoint("TOP", 0, -3)
		end
		
		return frame
	end
	
	-- Reset the criteria tooltips to prevent old ones from other achievements from showing
	local orig_AchievementButton_GetMiniAchievement = AchievementButton_GetMiniAchievement
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
	local orig_AchievementObjectives_DisplayProgressiveAchievement = AchievementObjectives_DisplayProgressiveAchievement
	AchievementObjectives_DisplayProgressiveAchievement = function(objectives, id)
		orig_AchievementObjectives_DisplayProgressiveAchievement(objectives, id)
		
		-- Custom button that isn't default Blizzard, don't modify it (at all)
		if( not self.isBlizzardButton ) then
			return
		end
		
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
	
	-- Annd restore it once we leave
	local function OnLeave(self)
		if( self.isBlizzardButton and not MouseIsOver(self) ) then
			if( not self.selected ) then
				self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)
			else
				self:SetBackdropBorderColor(1.0, 0.15, 0.05, 1.0)
			end
		end
	end
	
	-- If we mouse over a selected frame, reset the border so you can see that you mouse overed it
	local function OnEnter(self)
		if( self.isBlizzardButton and self.selected ) then
			self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)
		end
	end	
	
	local orig_AchievementShield_SetPoints = AchievementShield_SetPoints
	AchievementShield_SetPoints = function(points, pointsString, normalFont, smallFont, ...)
		if( pointsString.isDAManaged ) then
			if( points == 0 ) then
				pointsString:SetText("")
				return
			end
			
			pointsString:SetText(points)

			-- Ripped out of the Blizzard achievement UI, keeps the achievement points centered on the shield
			local width = pointsString:GetStringWidth()

			-- Round the width, GetStringWidth returns a float.
			width = math.floor(width * 10 ^ 0 + 0.5) / 10 ^ 0
			if( points == 10 ) then
				pointsString:SetPoint("TOPLEFT", pointsString:GetParent().icon, 7, -15)
			elseif( math.fmod(width, 2) == 0 ) then
				pointsString:SetPoint("TOPLEFT", pointsString:GetParent().icon, 8, -15)
			else
				pointsString:SetPoint("TOPLEFT", pointsString:GetParent().icon, 8, -15)
			end
			return
		end
		
		return orig_AchievementShield_SetPoints(points, pointsString, normalFont, smallFont, ...)
	end
			
	-- Create two new achievement rows quickly so we don't have blank space due to our reduced size
	local frame = AchievementFrameAchievementsContainer
	for i=1, 2 do
		local id = #(frame.buttons) + 1
		local name = "AchievementFrameAchievementsContainerButton" .. id
		local button = CreateFrame("Button", name, frame.scrollChild, "AchievementTemplate")
		button:SetPoint("TOPLEFT", frame.buttons[id - 1], "BOTTOMLEFT", 0, -2)
		table.insert(frame.buttons, button)
	end
	
	-- Make the button all fancy
	local function updateButton(frame)
		-- Re-set the API calls so it uses our new versions
		frame.Collapse = AchievementButton_Collapse
		frame.Expand = AchievementButton_Expand
		frame.isBlizzardButton = true
		
		-- Hook OnEnter/OnLeave for our color change
		frame:HookScript("OnEnter", OnEnter)
		frame:HookScript("OnLeave", OnLeave)

		-- Reduce shield size
		frame.shield:SetWidth(50)
		frame.shield:SetHeight(52)
		
		frame.shield.icon:SetWidth(50)
		frame.shield.icon:SetHeight(50)
		
		frame.shield.points:ClearAllPoints()
		frame.shield.points:SetFont((frame.shield.points:GetFont()), 14)
		frame.shield.points:SetText(frame.shield.points:GetText())
		frame.shield.points.isDAManaged = true
		
		-- Move the plus/minus ("Is this achievement expanded") icon
		frame.plusMinus:ClearAllPoints()
		frame.plusMinus:SetPoint("TOPLEFT", 63, -7)
		frame.plusMinus:SetHeight(14)
		frame.plusMinus:SetWidth(14)
				
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
		local background = getglobal(frame:GetName() .. "TitleBackground")
		background:SetHeight(18)
		
		-- Shift label to fit the reduced background + reduce font size slightly
		frame.label:ClearAllPoints()
		frame.label:SetPoint("TOP", background, "TOP", 0, 2)
		frame.label:SetFont((frame.label:GetFont()), 13)
		
		-- Reduce background behind the achievement reward (if any)
		local background = getglobal(frame:GetName() .. "RewardBackground")
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
		local check =  CreateFrame("CheckButton", frame:GetName() .. "CustomCheck", frame, "AchievementCheckButtonTemplate")
		getglobal(check:GetName() .. "Text"):Hide()

		check:SetPoint("TOPLEFT", frame, "TOPLEFT", 75, -3)
		check:SetWidth(20)
		check:SetHeight(20)
		check:SetHitRectInsets(-5, -5, -5, -5)
		check:SetChecked(false)

		frame.customCheck = check

		-- Get basics setup
		frame:Collapse()
	end
	
	--[[
	local orig_HybridScrollFrame_CreateButtons = HybridScrollFrame_CreateButtons
	HybridScrollFrame_CreateButtons = function(self, buttonTemplate, ...)
		orig_HybridScrollFrame_CreateButtons(self, buttonTemplate, ...)

		if( buttonTemplate == "AchievementTemplate" ) then
			for _, frame in pairs(self.buttons) do
				updateButton(frame)
			end
		end
	end
	]]

	-- Update all the buttons
	for _, frame in pairs(frame.buttons) do
		updateButton(frame)
	end
	
	-- Re-set the hybrid scroll info we our new stuff
	local round = function (num) return math.floor(num + 0.5) end

	local frame = AchievementFrameAchievementsContainer
	local buttonHeight = frame.buttons[1]:GetHeight()
	
	frame.buttonHeight = round(buttonHeight)
	
	local numButtons = (frame:GetHeight() / buttonHeight) + 1
	self.overflow = math.ceil(numButtons) - numButtons
	numButtons = math.ceil(numButtons)
	
	local scrollChild = frame.scrollChild
	scrollChild:SetWidth(frame:GetWidth())
	scrollChild:SetHeight(numButtons * buttonHeight)

	frame:SetVerticalScroll(0)
	frame:UpdateScrollChildRect()
	
	local scrollBar = frame.scrollBar	
	scrollBar:SetMinMaxValues(0, numButtons * buttonHeight)
	scrollBar:SetValueStep(0.005)
	scrollBar:SetValue(0)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
	if( IsAddOnLoaded("Blizzard_AchievementUI") ) then
		self:UnregisterAllEvents()

		DA:Initialize()
	end
end)