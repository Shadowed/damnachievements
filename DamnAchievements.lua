local DA = {}
local blankFunc = function() end

local DEFAULT_FRAME_HEIGHT = 74

function DA:Initialize()
	local orig_AchievementButton_Expand = AchievementButton_Expand
	AchievementButton_Expand = function(self, height)
		orig_AchievementButton_Expand(self, height)

		-- Increase description size
		self.description:SetHeight(30)
	end

	local orig_AchievementButton_Collapse = AchievementButton_Collapse
	AchievementButton_Collapse = function(self)
		orig_AchievementButton_Collapse(self)
		
		-- Reset frame height
		self:SetHeight(DEFAULT_FRAME_HEIGHT)
		
		-- Decrease description size
		if( self.selected and self.reward:IsVisible()) then
			self.description:SetHeight(30)
		else
			self.description:SetHeight(0)
		end
	end
	
	-- So our global check thingy works
	local orig_AchievementButton_DisplayAchievement = AchievementButton_DisplayAchievement
	AchievementButton_DisplayAchievement = function(button, category, achievement, selectionID, ...)
		local result = orig_AchievementButton_DisplayAchievement(button, category, achievement, selectionID, ...)
		
		-- Set checked if it's being tracked + hide it if it's been completed
		if( not button.completed ) then
			button.customCheck:SetChecked((button.id == GetTrackedAchievement()))
			button.customCheck:Show()
		else
			button.customCheck:Hide()
		end
		
		return result
	end
	
	-- More code ripped out of the achievement UI, modified to keep the objective stuff working right
	orig_AchievementButton_DisplayObjectives = AchievementButton_DisplayObjectives
	AchievementButton_DisplayObjectives = function(button, ...)
		local height = orig_AchievementButton_DisplayObjectives(button, ...)
		local objectives = AchievementFrameAchievementsObjectives
		if( objectives:GetHeight() > 0 ) then
			objectives:SetPoint("TOP", "$parentDescription", "BOTTOM", 0, 8)
			objectives:SetPoint("LEFT", "$parentIcon", "RIGHT", -5, -25)
			objectives:SetPoint("RIGHT", "$parentShield", "LEFT", -10, 0)
		end
		return height
	end

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
	
	-- Reset the APIs
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
		frame.icon:SetHeight(56)
		frame.icon:SetWidth(54)
		
		frame.icon.texture:SetWidth(46)
		frame.icon.texture:SetHeight(46)
		
		frame.icon.frame:SetWidth(frame.icon.texture:GetWidth() + 14)
		frame.icon.frame:SetHeight(frame.icon.texture:GetHeight() + 14)
		
		-- Stop the check icon + check box from showing
		frame.tracked.Show = blankFunc
		frame.tracked:Hide()
		
		frame.check.Show = blankFunc
		frame.check:Hide()

		-- Add tracking check box for them all without having to select it
		local check =  CreateFrame("CheckButton", name .. "CustomCheck", frame, "AchievementCheckButtonTemplate")
		getglobal(check:GetName() .. "Text"):Hide()

		check:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -7)
		check:SetWidth(20)
		check:SetHeight(20)
		check:SetHitRectInsets(-5, -5, -5, -5)

		frame.customCheck = check

		-- Get basics setup
		frame:Collapse()
	end
end


local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
	if( IsAddOnLoaded("Blizzard_AchievementUI") ) then
		DA:Initialize()
		self:UnregisterAllEvents()
	end
end)