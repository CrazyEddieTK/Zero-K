--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Chili EndGame Window",
    desc      = "v0.005 Chili EndGame Window. Creates award control and receives stats control from another widget.",
    author    = "CarRepairer",
    date      = "2013-09-05",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local spSendCommands			= Spring.SendCommands

local echo = Spring.Echo
local spec

local Chili
local Image
local Button
local Checkbox
local Window
local Panel
local ScrollPanel
local StackPanel
local Label
local Line
local screen0
local color2incolor
local incolor2color

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local showEndgameWindowTimer
local window_endgame
local awardPanel
local awardSubPanel
local statsPanel
local statsSubPanel
local addedStatsSubPanel = false
local awardButton = false
local statsButton = false
local showingTab = 'awards'
local teamNames = {}
local teamColors = {}

local awardPanelHeight = 50
local awardPanelWidth = 230
local awardPanelLabelHeight = 40
local awardPad = 10

local SELECT_BUTTON_COLOR = {0.98, 0.48, 0.26, 0.85}
local SELECT_BUTTON_FOCUS_COLOR = {0.98, 0.48, 0.26, 0.85}
local BUTTON_COLOR
local BUTTON_FOCUS_COLOR

local awardDescs = VFS.Include("LuaRules/Configs/award_names.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--functions

local function SetTeamNamesAndColors()
  for _,teamID in ipairs(Spring.GetTeamList()) do
	local _,leader,isDead,isAI,_,allyTeamID = Spring.GetTeamInfo(teamID)
	if isAI then
		local skirmishAIID, name, hostingPlayerID, shortName, version, options = Spring.GetAIInfo(teamID)
		teamNames[teamID] = name
	else
		local name = Spring.GetPlayerInfo(leader)
		teamNames[teamID] = name
	end
    local r,g,b = Spring.GetTeamColor(teamID)
    teamColors[teamID] = {r,g,b,1}
  end
end

local function MakeAwardPanel(awardType, record)
	local desc = awardDescs[awardType]
	local fontsize = desc:len() > 25 and 12 or 16
	return Panel:New{
		width=awardPanelWidth,
		height=awardPanelHeight,
		children = {
			Image:New{ file='LuaRules/Images/awards/trophy_'.. awardType ..'.png'; 		x=0;y=0; width=30; height=40; };
			Label:New{ caption = desc; 		autosize=true, x=35; y=0;	textColor={1,1,0,1}; fontsize=fontsize; };
			Label:New{ caption = record, 	autosize=true, x=35; y=20 };
		}
	}
end

-- returns true if tab is already showing, shows tab
local function ShowTab(tabName)
	if showingTab == tabName then
		return true
	end
	showingTab = tabName
	return false
end


local function AddStatsSubPanel()
	if addedStatsSubPanel then
		return
	end
	addedStatsSubPanel = true
	statsPanel:AddChild(statsSubPanel)
end

local function SetButtonSelected(button, isSelected)
	if isSelected then
		button.backgroundColor = SELECT_BUTTON_COLOR
		button.focusColor = SELECT_BUTTON_FOCUS_COLOR
	else
		button.backgroundColor = BUTTON_COLOR
		button.focusColor = BUTTON_FOCUS_COLOR
	end
	button:Invalidate()
end

local function ShowAwards()
	if ShowTab('awards') then return end
	
	window_endgame:RemoveChild(statsPanel)
	window_endgame:AddChild(awardPanel)
	
	SetButtonSelected(awardButton, true)
	SetButtonSelected(statsButton, false)
end
local function ShowStats()
	statsSubPanel = WG.statsPanel
	if not statsSubPanel then
		echo 'Stats Panel not ready yet.'
		return
	end
	
	if ShowTab('stats') then return end
	
	AddStatsSubPanel()
	
	window_endgame:RemoveChild(awardPanel)
	window_endgame:AddChild(statsPanel)
	
	SetButtonSelected(statsButton, true)
	SetButtonSelected(awardButton, false)
end


-- TESTING MOCK
local mock_awards = {
---[[
	{
		pwn     = 'Damaged value: 1',
		navy    = 'Damaged value: 1',
		air     = 'Damaged value: 1',
		nux     = 'Damaged value: 1',
		friend  = 'Damage inflicted on allies: 1',
		shell   = 'Damaged value: 1',
		fire    = 'Burnt value: 1',
		emp     = 'Stunned value: 1',
		slow    = 'Slowed value: 1',
		t3      = 'Experimental Engineer',
		cap     = 'Captured value: 1',
		share   = 'Shared value: 1',
		terra   = 'Terraform: 1',
		reclaim = 'Reclaimed value: 1',
		rezz    = 'Resurrected value: 1',
		vet     = 'Flea: 1000% cost made',
		ouch    = 'Damage received: 1',
		kam     = 'Damaged value: 1',
		comm    = 'Damaged value: 1',
		mex     = 'Mexes built: 1',
		mexkill = 'Mexes destroyed: 1',
		rage    = 'Damaged value: 1',
		head    = '1 Commanders eliminated',
		dragon  = '1 White Dragons annihilated',
		heart   = 'Damage: 1',
		sweeper = '1 Nests wiped out',
	},
--]]
	{
		pwn     = 'Damaged value: 1',
		navy    = 'Damaged value: 1',
		air     = 'Damaged value: 1',
		vet     = 'Flea: 1000% cost made',
	},
	{
		slow    = 'Slowed value: 1',
		t3      = 'Experimental Engineer',
		cap     = 'Captured value: 1',
		share   = 'Shared value: 1',
		terra   = 'Terraform: 1',
		reclaim = 'Reclaimed value: 1',
		rezz    = 'Resurrected value: 1',
		vet     = 'Flea: 1000% cost made',
	},
	{
		navy    = 'Damaged value: 1',
		air     = 'Damaged value: 1',
		vet     = 'Flea: 1000% cost made',
	},
	{
		pwn     = 'Damaged value: 1',
		vet     = 'Flea: 1000% cost made',
	},
	{
		nux     = 'Damaged value: 1',
	},
	{
		pwn     = 'Damaged value: 1',
		navy    = 'Damaged value: 1',
		air     = 'Damaged value: 1',
		nux     = 'Damaged value: 1',
		friend  = 'Damage inflicted on allies: 1',
		shell   = 'Damaged value: 1',
		vet     = 'Flea: 1000% cost made',
	},
	{
		pwn     = 'Damaged value: 1',
		air     = 'Damaged value: 1',
		nux     = 'Damaged value: 1',
		friend  = 'Damage inflicted on allies: 1',
		shell   = 'Damaged value: 1',
		vet     = 'Flea: 1000% cost made',
	},
	{
		pwn     = 'Damaged value: 1',
		nux     = 'Damaged value: 1',
		friend  = 'Damage inflicted on allies: 1',
		shell   = 'Damaged value: 1',
		vet     = 'Flea: 1000% cost made',
	},
	{
		navy    = 'Damaged value: 1',
		nux     = 'Damaged value: 1',
		friend  = 'Damage inflicted on allies: 1',
		shell   = 'Damaged value: 1',
		vet     = 'Flea: 1000% cost made',
	},
}

local function SetupAwardsPanel()
	awardSubPanel:ClearChildren()
--	for teamID,awards in pairs(WG.awardList) do
	for teamID,awards in pairs(mock_awards) do 		-- TESTING MOCK

-- TODO: Sort by number of awards; it will make the display look nicer
--	because the larger boxes will be at the end instead of breaking up
--	the 2x2 boxes, which will be most of them
--
--	Or maybe better to do largest first? So that the biggest winner has
--	the more prominent position? It might still look okay that way.

		local awardCount = 0
		for awardType, record in pairs(awards) do
			awardCount = awardCount + 1
		end

		if awardCount > 0 then
			local rows, cols = 0, 0
			local boxheight, boxwidth = 0, 0

			if awardCount <= 4 then
				rows, cols = 2, 2
			elseif awardCount <= 6 then
				rows, cols = 3, 2
			else
				rows, cols = math.ceil(awardCount / 3), 3
			end
			
			boxwidth = (awardPanelWidth + awardPad) * cols
			boxheight = (awardPanelHeight + awardPad) * rows + awardPanelLabelHeight

			local playerBox = Panel:New {
				parent = awardSubPanel,
				width = boxwidth,
				height = boxheight,
			}
			local playerLabel = Label:New {
				parent = playerBox,
				align = 'center',
				x=0, y=0,
				width = boxwidth,
				autosize = true,
				caption = teamNames[teamID],
				fontSize = 24,
				fontShadow = true,
				textColor = teamColors[teamID],
			}
			local playerLine = Line:New {
				parent = playerBox,
				y = 25,
				width = '70%',
				x = boxwidth * .15,
			}

			local award_i = 0
			for awardType, record in pairs(awards) do
				local award = MakeAwardPanel(awardType, record)
				local award_x = (award_i % cols) * (awardPanelWidth + awardPad)
				local award_y = math.floor(award_i / cols) * (awardPanelHeight + awardPad) + awardPanelLabelHeight
				if math.ceil((award_i + 1)/cols) == math.ceil(awardCount/cols) then
					award_x = award_x + ( (cols - ((awardCount - 1) % cols) - 1) * ((awardPanelWidth + awardPad)/2) )
				end
				award.x = award_x
				award.y = award_y
				playerBox:AddChild(award)
				award_i = award_i + 1
			end
		end
	end
end


function SetAwardList(awardList)
	WG.awardList = awardList
	SetupAwardsPanel()
	ShowAwards()
end

local function ShowEndGameWindow()
--	if WG.awardList then
	if true then 			-- TESTING MOCK
		ShowAwards()
	else
		ShowStats()
	end
	
	screen0:AddChild(window_endgame)
end

local function SetupControls()
	window_endgame = Window:New{  
		name = "GameOver",
		caption = "Game aborted",
		textColor = {0.5,0.5,0.5,1}, 
		fontSize = 50,
		x = '20%',
		y = '20%',
		width  = '60%',
		height = '60%',
		classname = "main_window",
		--autosize   = true;
		--parent = screen0,
		draggable = true,
		resizable = true,
		minWidth=500;
		minHeight=400;
	}
	
	awardPanel = ScrollPanel:New{
		parent = window_endgame,
		x=10;y=50;
		bottom=10;right=10;
		autosize = true,
		scrollbarSize = 6,
		horizontalScrollbar = false,
		hitTestAllowEmpty = true;
		tooltip = "",
	}
	statsPanel = ScrollPanel:New{
		x=10;y=50;
		bottom=10;right=10;
		backgroundColor  = {1,1,1,1},
		borderColor = {1,1,1,1},
	}
	
	awardSubPanel = StackPanel:New{
		parent = awardPanel,
		x=0;y=0;
		bottom=10;right=10;
		backgroundColor  = {1,1,1,1},
		borderColor = {1,1,1,1},
		padding = {10, 10, 10, 10},
		tooltip = "",
		autosize = true,
		
		resizeItems = false,
		centerItems = false,
		orientation = 'horizontal';

		itemPadding = {0, 0, 0, 0},
		itemMargin  = {10, 25, 10, 25},
	}
	
	local B_HEIGHT = 40
	awardButton = Button:New{
		x=9, y=7,
		height=B_HEIGHT;
		caption="Awards",
		OnClick = {
			ShowAwards
		};
		parent = window_endgame;
	}
	BUTTON_COLOR = awardButton.backgroundColor
	BUTTON_FOCUS_COLOR = awardButton.focusColor
	SetButtonSelected(awardButton, true)
	
	statsButton = Button:New{
		x=85, y=7,
		height=B_HEIGHT;
		caption="Statistics",
		OnClick = {
			ShowStats
		};
		parent = window_endgame;
	}
	
	Button:New{
		y=7;
		width=80;
		right=9;
		height=B_HEIGHT;
		caption="Exit",
		OnClick = {
			function() 
				if Spring.GetMenuName and Spring.GetMenuName() ~= "" then
					Spring.Reload("")
				else
					Spring.SendCommands("quit","quitforce")
				end
			 end
		};
		parent = window_endgame;
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--callins
function widget:Initialize()
	if (not WG.Chili) then
		widgetHandler:RemoveWidget()
		return
	end

	spec = Spring.GetSpectatingState()

	Chili = WG.Chili
	Image = Chili.Image
	Button = Chili.Button
	Checkbox = Chili.Checkbox
	Window = Chili.Window
	Panel = Chili.Panel
	ScrollPanel = Chili.ScrollPanel
	StackPanel = Chili.StackPanel
	Label = Chili.Label
	Line = Chili.Line
	screen0 = Chili.Screen0
	color2incolor = Chili.color2incolor
	incolor2color = Chili.incolor2color
	
	SetupControls()

	Spring.SendCommands("endgraph 0")
	
	widgetHandler:RegisterGlobal("SetAwardList", SetAwardList)
	
	SetTeamNamesAndColors()
	
	if Spring.IsGameOver() then
		showEndgameWindowTimer = 1
	end
end

function widget:GameOver (winners)
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
	if #winners > 1 then
		if spec then
			window_endgame.caption = "Game over!"
			window_endgame.font.color = {1,1,1,1}
		else
			local i_win = false
			for i = 1, #winners do
				if (winners[i] == Spring.GetMyAllyTeamID()) then
					i_win = true
				end
			end

			if i_win then
				window_endgame.caption = "Victory!"
				window_endgame.font.color = {0,1,0,1}
			else
				window_endgame.caption = "Defeat!"
				window_endgame.font.color = {1,0,0,1}
			end
		end
	elseif #winners == 1 then
		local winnerTeamName = Spring.GetGameRulesParam("allyteam_long_name_"  .. winners[1]) or "Team " .. winners[1]
		if string.len(winnerTeamName) > 10 then
			winnerTeamName = Spring.GetGameRulesParam("allyteam_short_name_" .. winners[1]) or "Team " .. winners[1]
		end
		if spec then
			if (winners[1] == gaiaAllyTeamID) then
				window_endgame.caption = "Draw!"
				window_endgame.font.color = {1,1,1,1}
			else
				window_endgame.caption = (winnerTeamName .. " wins!")
				window_endgame.font.color = {1,1,1,1}
			end
		elseif (winners[1] == Spring.GetMyAllyTeamID()) then
			window_endgame.caption = "Victory!"
			window_endgame.font.color = {0,1,0,1}
		elseif (winners[1] == gaiaAllyTeamID) then
			window_endgame.caption = "Draw!"
			window_endgame.font.color = {1,1,0,1}
		else
			window_endgame.caption = "Defeat!" -- could somehow add info on who won (eg. for FFA) but as-is it won't fit
			window_endgame.font.color = {1,0,0,1}
		end
	end
	window_endgame.tooltip = ""
	window_endgame:Invalidate()
	showEndgameWindowTimer = 2
end

function widget:Update(dt)
	if not showEndgameWindowTimer then
		return
	end
	showEndgameWindowTimer = showEndgameWindowTimer - dt
	if showEndgameWindowTimer > 0 then
		return
	end
	
	SetupAwardsPanel() 		-- TESTING MOCK
	ShowEndGameWindow()
	showEndgameWindowTimer = nil
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("SetAwardList")
end


