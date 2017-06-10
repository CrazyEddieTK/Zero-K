--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Chili SpecPanel - Next Gen",
    desc      = "Displays team information while spectating.",
    author    = "GoogleFrog, KingRaptor, CrazyEddie",
    date      = "3 June 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- TODO:
--
--	- Tweak everything, esp. anything that has asymmetry
--		- Decide where I want mirroring and where I want asymmetry
--	- Rearrange bounds in this order: x,r,w,y,b,h
--	- Rewrite the bounds to be the simplest possible
--		- ... and make sure that there's explicitly exactly two in each dimension
--	- Make the unitpic frames and labels children of the pic, to make it simpler
--		- Look for other objects that can be nested that way that aren't already
--	- Rearrange all other object parameters into a consistent and pleasing order
--	- Consistentize capitalization of parameters
--	- Parameterize the colors
--		- Balance Bar colors, including writing a function to attenuate them
--	- Deal with padding in all the objects (??)
--	- Look for any other text that needs autosize = false (all of it?)
--
--	- Revise the balance bars:
--		- Make them multibars, stacked on top of each other
--		- Set the leader to 100%
--		- Set the lagger whatever percentage they are of the leader
--
--	- Logic to enable/disable when appropriate (speccing and not FFA)
--	- Hotkeyable option to enable and disable
--	- Handle widget:PlayerChanged
--	- Colourblind option
--	- Fancy skinning option? Learn about skins and fancyskins
--	- Reskin the panels so they look more like Evolved panels (but transparent) and less like buttons
--	- Handle interactions with (hiding) the standard econ bars
--	- Stop collecting stats at game over, prior to the losing side self-destroying,
--		so you can see what the stats were just before they resigned.
--
--	- Hook up to actual data
--		- This will be a good time to revise the panelData data structure
--		- It has a lot of redundancy that was there for mocking up the layout
--	- Wait, I can specify the buildpic filename as "#" .. udid ??? - Go change the others, too.
--	- Figure out how to deal with attrition
--	- Get team names and other team data
--	- Add wins data
--	- Revise wins logic to update at end of game instead of all throughout the game
--	- Rip out the mock data and add in initialization data
--	- Add an iteration on initialization to get current unit data, even if
--		the widget was restarted midway through a game
--	- Hook up the bg screenshots to live data
--		- For 1v1, I'll need a way to detect and track the facplop
--		- For teams, I'll need a count of the playerteams on each side
--		- That probably SHOULD include AI players, which means I'll need to
--			modify GetOpposingAllyTeams()
--	- Come up with all the unit category exceptions and edge cases and add them
--	- Make more bg screenshots
--	- Add flashing to resbars, including:
--		- Grey on metal excess - see #1960
--			- Fast if excessing, slow if close to excessing
--			- Match implementation in gui_chili_economy_panel2.lua
--			- ... and also if wasting E? (but not if close to wasting)
--		- Red on energy stalling
--		- ... and some kind of indication for zero storage (but what?)
--	- Add tooltips to everything.
--		"What do you mean, everything?"
--		"EEEEEVVVERYTHIIIING!!!!!!"
--	- Add context menu / ShowOptions on meta-click
--	- Consider making small / medium / large versions
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("colors.h.lua")
VFS.Include("LuaRules/Configs/constants.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local echo = Spring.Echo
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamRulesParam = Spring.GetTeamRulesParam

local Chili
local screen0

local specPanel
local panelParams
local panelData
local mockData
local allyTeams
local panel_is_on
local teamSides = {}
local timer_updateclock = 0
local timer_updatestats = 0
local smoothTables = {}
local smoothedTables = {
	resources_left = {0,0,0,0,0,0,0,0,0,0,0,0,},
	resources_right = {0,0,0,0,0,0,0,0,0,0,0,0,},
}

local SpecWindowStartStop
local didonce

-- This is probably getting refactored away
local unitStats = {
	{
		total = 0,
		offense = 0,
		defense = 0,
		eco = 0,
		units = {},
		cons = {
			count = 0,
			udids = {},
		},
		comms = {},
	},
	{
		total = 0,
		offense = 0,
		defense = 0,
		eco = 0,
		units = {},
		cons = {
			count = 0,
			udids = {},
		},
		comms = {},
	},
}

local unitCategoryExceptions = {
	offense = {
	},
	defense = {
	},
	eco = {
	},
	other = {
	},
}

local col_metal = {136/255,214/255,251/255,1}
local col_energy = {.93,.93,0,1}
local default_playercolors = { left = {0.5,0.5,1,1}, right = {1,0.2,0.2,1}, }
local smooth_count = 3
local unitpic_slots = 5
local compic_slots = 3

-- hardcoding these for now, will add colourblind options later
local positiveColourStr = GreenStr
local negativeColourStr = RedStr


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options Functions


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options

options_path = 'Settings/HUD Panels/Spectator Panel NG'

options_order = {
	'enableSpecNG',
}
 
options = {
	enableSpecNG = {
		name  = "Enable as Spec NG",
		type  = "bool",
		value = true,
		OnChange = function(self)
			SpecWindowStartStop()
		end,
		desc = "Enables the spectator resource bars when spectating a game with two teams."
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities

local function pack(...)
	return { n = select("#", ...), ... }
end

local function Smooth(tablename, data)
	local output_table = {}
	smoothTables[tablename] = smoothTables[tablename] or {}
	for i,v in ipairs(data) do
		smoothTables[tablename][i] = smoothTables[tablename][i] or {}
		table.insert(smoothTables[tablename][i], v)
		if #smoothTables[tablename][i] > smooth_count then
			table.remove(smoothTables[tablename][i], 1)
		end
		local sum = 0
		for j,w in ipairs(smoothTables[tablename][i]) do
			sum = sum + w
		end
		output_table[i] = sum / #smoothTables[tablename][i]
	end
	return unpack(output_table)
end

local function Format(input, override)

	-- Leaving out the sign to save space.
	-- For this panel, the direction is always implied
	-- and will still be colorcoded when needed.
	--
	-- local leadingString = positiveColourStr .. "+"
	local leadingString = positiveColourStr
	if input < 0 then
		-- leadingString = negativeColourStr .. "-"
		leadingString = negativeColourStr
	end
	leadingString = override or leadingString
	input = math.abs(input)
	
	if input < 0.05 then
		if override then
			-- Nope. Don't want a decimal point.
			-- return override .. "0.0"
			return override .. "0"
		end
		return WhiteStr .. "0"
	elseif input < 10 - 0.05 then
		-- Nope. Don't want a decimal point.
		-- return leadingString .. ("%.1f"):format(input) .. WhiteStr
		return leadingString .. ("%.0f"):format(input) .. WhiteStr
	elseif input < 10^3 - 0.5 then
		return leadingString .. ("%.0f"):format(input) .. WhiteStr
	elseif input < 10^4 then
		return leadingString .. ("%.1f"):format(input/1000) .. "k" .. WhiteStr
	elseif input < 10^5 then
		return leadingString .. ("%.0f"):format(input/1000) .. "k" .. WhiteStr
	else
		return leadingString .. ("%.0f"):format(input/1000) .. "k" .. WhiteStr
	end
end

local function GetTimeString()
  local secs = math.floor(Spring.GetGameSeconds())
  if (timeSecs ~= secs) then
    timeSecs = secs
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    if (h > 0) then
      timeString = string.format('%02i:%02i:%02i', h, m, s)
    else
      timeString = string.format('%02i:%02i', m, s)
    end
  end
  return timeString
end

function GetWinString(name) -- forward-declared
	local winTable = WG.WinCounter_currentWinTable
	if winTable and winTable[name] and winTable[name].wins then
		-- TODO - Do something else to mark the winner of the previous game, not this
		-- return (winTable[name].wonLastGame and "*" or "") .. winTable[name].wins
		return winTable[name].wins
	end
	return
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Update Panel Data

local function UpdateClock(t)
	t.clocklabel:SetCaption(GetTimeString())
end

local function UpdateWins(t)
	for i,side in ipairs({'left', 'right'}) do
		local wins = GetWinString(allyTeams[i].name) or 0
		t[side].winslabel_bottom:SetCaption(wins)
	end
end

local function FetchUpdatedResources()
	-- The energy stats seem wrong.
	-- They were taken from the current spec panels. I've probably translated them
	-- incorrectly, but what I have here gives results that seem very wrong.
	--
	-- For example: Generation 62, Reclaim 0, OD 9 => Income 71.
	-- 	Surely in this case Income should be 53, yes? Showing that
	--	9 of the 62 energy generated was used to produce metal and
	--	therefore was not available to use as energy.
	--
	-- This warrants further investigation.
	
	for i,side in ipairs({'left', 'right'}) do
		local smCurr, smStor, smInco, smOvdr, smRecl, smBase, seCurr, seStor, seInco, seOvdr, seRecl, seBase = 0,0,0,0,0,0,0,0,0,0,0,0
		local allyTeamID = allyTeams[i].allyTeamID
		local teams = Spring.GetTeamList(allyTeamID)
	
		for j = 1, #teams do
			local mCurr, mStor, _, mInco = spGetTeamResources(teams[j], "metal")
			local eCurr, eStor, _, eInco = spGetTeamResources(teams[j], "energy")
		
			smInco = smInco + (mInco or 0)
			smBase = smBase + (spGetTeamRulesParam(teams[j], "OD_metalBase") or 0)
		
			-- Strange magic
			smCurr = smCurr + (mCurr or 0)
			smStor = smStor + (mStor or 0) - HIDDEN_STORAGE
			seCurr = seCurr + math.min((eCurr or 0), (eStor or 0) - HIDDEN_STORAGE)
			seStor = seStor + (eStor or 0) - HIDDEN_STORAGE 
		
			-- WITCHCRAFT!!
			local energyChange = spGetTeamRulesParam(teams[j], "OD_energyChange") or 0
			seRecl = seRecl + (eInco or 0) - math.max(0, energyChange)
			seBase = seBase + (eInco or 0)
		end

		smOvdr = spGetTeamRulesParam(teams[1], "OD_team_metalOverdrive") or 0
		seOvdr = spGetTeamRulesParam(teams[1], "OD_team_energyOverdrive") or 0

		local smRecl = smInco
				- (spGetTeamRulesParam(teams[1], "OD_team_metalOverdrive") or 0)
				- (spGetTeamRulesParam(teams[1], "OD_team_metalBase") or 0) 
				- (spGetTeamRulesParam(teams[1], "OD_team_metalMisc") or 0)
	
		-- The other half of the incantation
		seRecl = math.max(0, seRecl)
		seInco = (spGetTeamRulesParam(teams[1], "OD_team_energyIncome") or 0) + seRecl
		
		smoothedTables['resources_'..side] = pack(
			Smooth(
				'resources_'..side,
				pack(smCurr, smStor, smInco, smOvdr, smRecl, smBase, seCurr, seStor, seInco, seOvdr, seRecl, seBase)
			)
		)
	end
end

local function DisplayUpdatedResources(t)
	local mInco_bb = {}
	local mBase_bb = {}
	for i,side in ipairs({'left', 'right'}) do
		local smCurr, smStor, smInco, smOvdr, smRecl, smBase, seCurr, seStor, seInco, seOvdr, seRecl, seBase = unpack(smoothedTables['resources_'..side])
		t[side].resource_stats.metal.total:SetCaption(Format(smInco, ""))
		t[side].resource_stats.metal.labels[1]:SetCaption("E:" .. Format(smBase, ""))
		t[side].resource_stats.metal.labels[2]:SetCaption("R:" .. Format(smRecl, ""))
		t[side].resource_stats.metal.labels[3]:SetCaption("O:" .. Format(smOvdr, ""))
		t[side].resource_stats.metal.bar:SetValue(100 * smCurr / smStor)
		t[side].resource_stats.energy.total:SetCaption(Format(seInco, ""))
		t[side].resource_stats.energy.labels[1]:SetCaption("G:" .. Format(seBase, ""))
		t[side].resource_stats.energy.labels[2]:SetCaption("R:" .. Format(seRecl, ""))
		t[side].resource_stats.energy.labels[3]:SetCaption("O:" .. Format(seOvdr, ""))
		t[side].resource_stats.energy.bar:SetValue(100 * seCurr / seStor)
		-- TODO - Deal with the case of zero storage
		mInco_bb[side] = smInco
		mBase_bb[side] = smBase
	end
	t.balancebars[1].bar:SetValue(100 * mInco_bb.left / (mInco_bb.left + mInco_bb.right))
	t.balancebars[2].bar:SetValue(100 * mBase_bb.left / (mBase_bb.left + mBase_bb.right))
end

local function DisplayUpdatedUnitStats(t)
	local military_bb = {}
	for i,side in ipairs({'left', 'right'}) do
		t[side].unit_stats.total:SetCaption("Unit Value: " .. Format(unitStats[i].total, ""))
		t[side].unit_stats[1].label:SetCaption(Format(unitStats[i].offense, ""))
		t[side].unit_stats[2].label:SetCaption(Format(unitStats[i].defense, ""))
		t[side].unit_stats[3].label:SetCaption(Format(unitStats[i].eco, ""))
		military_bb[side] = unitStats[i].offense + unitStats[i].defense
		
		-- These two are parallel enough that I might want to refactor them,
		--	possibly using a generic iterator function that takes sort functions
		--
		local sorted_udids = {}
		for n in pairs(unitStats[i].units) do table.insert(sorted_udids, n) end
		if #sorted_udids > 0 then
			table.sort(sorted_udids, function (a,b) return unitStats[i].units[a].metal > unitStats[i].units[b].metal end)
			for pic = 1, unitpic_slots - 1 do
				local text = sorted_udids[pic] and unitStats[i].units[sorted_udids[pic]].count or ''
				local filename = sorted_udids[pic] and UnitDefs[sorted_udids[pic]].name or 'fakeunit'
				t[side].unitpics[unitpic_slots - pic + 1].text:SetCaption(text)
				t[side].unitpics[unitpic_slots - pic + 1].unitpic.file = 'unitpics/' .. filename .. '.png'
				t[side].unitpics[unitpic_slots - pic + 1].unitpic:Invalidate()
			end
		end
		
		-- Nearly the same as the one above
		--
		local sorted_con_udids = {}
		for n in pairs(unitStats[i].cons.udids) do table.insert(sorted_con_udids, n) end
		if #sorted_con_udids > 0 then
			table.sort(sorted_con_udids, function (a,b) return unitStats[i].cons.udids[a].metal > unitStats[i].cons.udids[b].metal end)
			for pic = 1,1 do
				local text = unitStats[i].cons.count or ''
				local filename = sorted_con_udids[pic] and UnitDefs[sorted_con_udids[pic]].name or 'fakeunit'
				t[side].unitpics[pic].text:SetCaption(text)
				t[side].unitpics[pic].unitpic.file = 'unitpics/' .. filename .. '.png'
				t[side].unitpics[pic].unitpic:Invalidate()
			end
		end

		-- Ditto?
		--
		local sorted_comm_ids = {}
		for n in pairs(unitStats[i].comms) do table.insert(sorted_comm_ids, n) end
		if #sorted_comm_ids > 0 then
			table.sort(sorted_comm_ids, function (a,b) return unitStats[i].comms[a].level > unitStats[i].comms[b].level end)
			for pic = 1,compic_slots do
				
				if pic == 1 then
					if #sorted_comm_ids > compic_slots then
						local text = ("Lvl " .. unitStats[i].comms[sorted_comm_ids[compic_slots]].level) or ''
						local filename = ("#" .. unitStats[i].comms[sorted_comm_ids[compic_slots]].udid) or 'unitpics/fakeunit.png'
						local moretext = (#sorted_comm_ids - compic_slots) .. " more"
						t[side].compics[pic].unitpicframe:Show()
						t[side].compics[pic].unitpicframe:BringToFront()
						t[side].compics[pic].unitpic.file = filename
						t[side].compics[pic].unitpic:Show()
						t[side].compics[pic].unitpic:BringToFront()
						t[side].compics[pic].unitpic:Invalidate()
						t[side].compics[pic].text:SetCaption(text)
						t[side].compics[pic].text:Show()
						t[side].compics[pic].text:BringToFront()
						t[side].compics[pic].moretext:SetCaption(moretext)
						t[side].compics[pic].moretext:Show()
						t[side].compics[pic].moretext:BringToFront()
					else
						local text = ("Lvl " .. unitStats[i].comms[sorted_comm_ids[#sorted_comm_ids]].level) or ''
						local filename = ("#" .. unitStats[i].comms[sorted_comm_ids[#sorted_comm_ids]].udid) or 'unitpics/fakeunit.png'
						t[side].compics[pic].unitpicframe:Show()
						t[side].compics[pic].unitpicframe:BringToFront()
						t[side].compics[pic].unitpic.file = filename
						t[side].compics[pic].unitpic:Show()
						t[side].compics[pic].unitpic:BringToFront()
						t[side].compics[pic].unitpic:Invalidate()
						t[side].compics[pic].text:SetCaption(text)
						t[side].compics[pic].text:Show()
						t[side].compics[pic].text:BringToFront()
					end
				else
					if pic <= #sorted_comm_ids then
						local text = ("Lvl " .. unitStats[i].comms[sorted_comm_ids[math.min(compic_slots, #sorted_comm_ids) - pic + 1]].level) or ''
						local filename = ("#" .. unitStats[i].comms[sorted_comm_ids[math.min(compic_slots, #sorted_comm_ids) - pic + 1]].udid) or 'unitpics/fakeunit.png'
						t[side].compics[pic].unitpicframe:Show()
						t[side].compics[pic].unitpicframe:BringToFront()
						t[side].compics[pic].unitpic.file = filename
						t[side].compics[pic].unitpic:Show()
						t[side].compics[pic].unitpic:BringToFront()
						t[side].compics[pic].unitpic:Invalidate()
						t[side].compics[pic].text:SetCaption(text)
						t[side].compics[pic].text:Show()
						t[side].compics[pic].text:BringToFront()
					else
						local text = ''
						local filename = 'unitpics/fakeunit.png'
						t[side].compics[pic].unitpicframe:Hide()
						t[side].compics[pic].unitpic.file = filename
						t[side].compics[pic].unitpic:Invalidate()
						t[side].compics[pic].unitpic:Hide()
						t[side].compics[pic].text:SetCaption(text)
						t[side].compics[pic].text:Hide()
					end
				end
			end
		end
	end
	t.balancebars[3].bar:SetValue(100 * military_bb.left / (military_bb.left + military_bb.right))
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Unit Stats Call-ins and Processor

local function ProcessUnit(unitID, unitDefID, unitTeam, remove)
	if not panel_is_on then return end
	
	local side = teamSides[unitTeam]
	local id = unitID
	local udid = unitDefID
	local ud = UnitDefs[unitDefID]
	local cp = ud.customParams
	local e = unitCategoryExceptions

	if ud and not (cp.dontcount or cp.is_drone) then
		-- TODO - Not certain these are the right ways to get this information
		--
		local metal = Spring.Utilities.GetUnitCost(unitID, unitDefID)
		local level = (Spring.GetUnitRulesParam(unitID, "comm_level") or 0) + 1
		local mobile = ud.speed and ud.speed ~= 0
		local armed = not ud.springCategories.unarmed
		local generator = cp.income_energy or cp.ismex or cp.windgen
		local con = ud.isMobileBuilder and not ud.customParams.commtype
		local comm = ud.customParams.commtype

		local offense
		local defense
		local eco
		local other
		
		local inc = 1
		if remove then
			metal = -metal
			inc = -inc
		end
		
		unitStats[side].total = unitStats[side].total + metal
		if e.offense[udid] or (armed and mobile and not e.defense[udid] and not e.eco[udid] and not e.other[udid]) then
			offense = true
			unitStats[side].offense = unitStats[side].offense + metal
		elseif e.defense[udid] or (armed and not mobile and not e.eco[udid] and not e.other[udid]) then
			defense = true
			unitStats[side].defense = unitStats[side].defense + metal
		elseif e.eco[udid] or (not mobile and generator and not e.other[udid]) then
			eco = true
			unitStats[side].eco = unitStats[side].eco + metal
		else
			other = true
		end
		
		if offense and not (con or comm) then
			unitStats[side].units[udid] = unitStats[side].units[udid] or {}
			unitStats[side].units[udid].count = (unitStats[side].units[udid].count or 0) + inc
			unitStats[side].units[udid].metal = (unitStats[side].units[udid].metal or 0) + metal
			if unitStats[side].units[udid].count == 0 then
				unitStats[side].units[udid] = nil
			end
		end
		
		if con then
			unitStats[side].cons.count = unitStats[side].cons.count + inc
			unitStats[side].cons.udids[udid] = unitStats[side].cons.udids[udid] or {}
			unitStats[side].cons.udids[udid].count = (unitStats[side].cons.udids[udid].count or 0) + inc
			unitStats[side].cons.udids[udid].metal = (unitStats[side].cons.udids[udid].metal or 0) + metal
			if unitStats[side].cons.udids[udid].count == 0 then
				unitStats[side].cons.udids[udid] = nil
			end
		end
		
		if comm then
			if remove then
				unitStats[side].comms[id] = nil
			else
				unitStats[side].comms[id] = unitStats[side].comms[id] or {}
				unitStats[side].comms[id].udid = udid or 0
				unitStats[side].comms[id].level = level or 0
			end
		end
	end
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	--
	-- TODO - Put the initial factory detection and bg picture updating code here
	--		(but first read through the facplop code to be sure I know how it works)
	--

	ProcessUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitReverseBuilt(unitID)
      ProcessUnit(unitID, unitDefID, unitTeam, true)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
      ProcessUnit(unitID, unitDefID, unitTeam, true)
end

function widget:UnitGiven(unitID, unitDefID, newTeamID, teamID)
	ProcessUnit(unitID, unitDefID, teamID, true)
	ProcessUnit(unitID, unitDefID, newTeamID)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Setup Data

local function GetOpposingAllyTeams()
	-- TODO - Consider whether this should set up the file-scoped allyTeams directly
	--        rather than returning the data it as a value to be stored by the caller

	local allyteams = {}
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
	local allyTeamList = Spring.GetAllyTeamList()

	for i = 1, #allyTeamList do
		local allyTeamID = allyTeamList[i]
		local teamList = Spring.GetTeamList(allyTeamID)
		if allyTeamID ~= gaiaAllyTeamID and #teamList > 0 then

			local winString
			local playerName
			for j = 1, #teamList do
				local _, playerID, _, isAI = Spring.GetTeamInfo(teamList[j])
				if not isAI then
					playerName = Spring.GetPlayerInfo(playerID)
					winString = GetWinString(playerName)
					break
				end
			end
			
			-- TODO - This is not a good way to do this
			--        Merge this with the loop immediately above, and handle them both better
			for j = 1, #teamList do
				teamSides[teamList[j]] = i
			end

			local name = Spring.GetGameRulesParam("allyteam_long_name_" .. allyTeamID) or "Unknown"
			-- Hardcode the long_name length limit, don't make it an option
			-- TODO - Figure out what the limit should be
			-- if name and string.len(name) > options.clanNameLengthCutoff.value then
			-- 	name = Spring.GetGameRulesParam("allyteam_short_name_" .. allyTeamID) or name
			-- end

			allyteams[#allyteams + 1] = {
				allyTeamID = allyTeamID, -- allyTeamID for the team
				name = name, -- Large display name of the team
				color = {Spring.GetTeamColor(teamList[1])} or {1,1,1,1}, -- color of the teams text (color of first player)
				playerName = playerName or "AI", -- representitive player name (for win counter)
				winString = winString or "0", -- Win string from win counter
				playercount = #teamList,
			}
		end
	end

	if #allyteams ~= 2 then
		return
	end
	
	if allyteams[1].allyTeamID > allyteams[2].allyTeamID then
		allyteams[1], allyteams[2] = allyteams[2], allyteams[1]
		for i = 1, #teamSides do
			teamSides[i] = 3 - teamSides[i]
		end
	end
	
	if allyteams[1].playercount > 1 or allyteams[2].playercount > 1 then
		allyteams[1].color = default_playercolors.left
		allyteams[2].color = default_playercolors.right
	end
	
	return allyteams
end

local function SetupMockData()
	local mock = {}
	
	mock.playernames	= { left = "GoogleFrog", right = "Anarchid", }
	mock.playercolors	= { left = {0.5,0.5,1,1}, right = {1,0.2,0.2,1}, }
	mock.playerwins		= { left = math.random(0,4), right = math.random(0,4), }
	mock.bgfac		= { left = "cloakies", right = "hovers", }

	mock.resource_stats = {
		left = {
			{
				type = 'metal',
				total = 156,
				bar = 25,
				icon = 'LuaUI/Images/ibeam.png',
				color = col_metal,
				{ name = "Extraction", value = 100, label = "E", label_x = 65, },
				{ name = "Reclaim", value = 15, label = "R", label_x = 110, },
				{ name = "Overdrive", value = 20, label = "O", label_x = 150, },
			},
			{
				type = 'energy',
				total = 1955,
				bar = 66,
				icon = 'LuaUI/Images/energy.png',
				color = col_energy,
				{ name = "Generation", value = 1234, label = "G", label_x = 65, },
				{ name = "Reclaim", value = 133, label = "R", label_x = 110, },
				{ name = "Overdrive", value = 543, label = "O", label_x = 150, },
			},
		},
		right = {
			{
				type = 'metal',
				total = 156,
				bar = 25,
				icon = 'LuaUI/Images/ibeam.png',
				color = col_metal,
				{ name = "Extraction", value = 100, label = "E", label_x = 65, },
				{ name = "Reclaim", value = 15, label = "R", label_x = 110, },
				{ name = "Overdrive", value = 20, label = "O", label_x = 150, },
			},
			{
				type = 'energy',
				total = 1955,
				bar = 66,
				icon = 'LuaUI/Images/energy.png',
				color = col_energy,
				{ name = "Generation", value = 1234, label = "G", label_x = 65, },
				{ name = "Reclaim", value = 133, label = "R", label_x = 110, },
				{ name = "Overdrive", value = 543, label = "O", label_x = 150, },
			},
		},
	}
	
	mock.unit_stats = {
		left = {
			total = 5447 + 1521 + 12550,
			{ name = "Offense", value = 5447, icon = 'LuaUI/Images/commands/Bold/attack.png', icon_x = 0, },
			{ name = "Defense", value = 1521, icon = 'LuaUI/Images/commands/Bold/guard.png', icon_x = 50, },
			{ name = "Economy", value = 12550, icon = 'LuaUI/Images/energy.png', icon_x = 100, },
		},
		right = {
			total = 3386 + 872 + 10995,
			{ name = "Offense", value = 3386, icon = 'LuaUI/Images/commands/Bold/attack.png', icon_x = 0, },
			{ name = "Defense", value = 872, icon = 'LuaUI/Images/commands/Bold/guard.png', icon_x = 50, },
			{ name = "Economy", value = 10995, icon = 'LuaUI/Images/energy.png', icon_x = 100, },
		},
	}
	
	mock.balancebars = {
		{ name = "Income", value = 100 * mock.resource_stats.left[1].total / (mock.resource_stats.left[1].total + mock.resource_stats.right[1].total) },
		{ name = "Extraction", value = 100 * mock.resource_stats.left[1][1].value / (mock.resource_stats.left[1][1].value + mock.resource_stats.right[1][1].value) },
		{ name = "Military", value = 100 *
			(mock.unit_stats.left[1].value + mock.unit_stats.left[2].value) /
			(mock.unit_stats.left[1].value + mock.unit_stats.left[2].value + mock.unit_stats.right[1].value + mock.unit_stats.right[2].value)
		},
		{ name = "Attrition", value = 50 },
	}
	
	mock.unitpics = {
		left = {
		},
		right = {
		},
	}
	mock.compics = {
		left = {
--[[
			{ name = "commrecon", value = "2 more" },
			{ name = "commstrike", value = "Lvl 4" },
			{ name = "commassault", value = "Lvl 6" },
--]]
		},
		right = {
--[[
			{ name = "commrecon", value = "2 more" },
			{ name = "commstrike", value = "Lvl 4" },
			{ name = "commassault", value = "Lvl 6" },
--]]
		},
	}
	
	return mock
end

local function SetupLayoutParams()
	local p = {}

	p.topcenterwidth = 200
	p.balancepanelwidth = 80
	
	p.balancelabelheight = 20
	p.balancebarheight = 10
	p.balanceheight = p.balancelabelheight + p.balancebarheight
	p.balancepanelheight = p.balanceheight * 4 + 5
	
	p.rowheight = 30
	p.topheight = p.rowheight * 1.5
	p.picsize = p.rowheight * 1.8
	
	p.unitpanelwidth = 150
	p.resourcebarwidth = 100
	p.resourcestatpanelwidth = 200
	p.resourcepanelwidth = p.resourcestatpanelwidth + p.resourcebarwidth
	
	p.screenWidth,p.screenHeight = Spring.GetWindowGeometry()
	p.screenHorizCentre = p.screenWidth / 2
	p.windowWidth = (p.resourcepanelwidth + p.unitpanelwidth) * 2 + p.balancepanelwidth + 24
	p.windowheight = p.topheight + p.balancepanelheight
	p.playerlabelwidth = (p.windowWidth - p.topcenterwidth) / 2
	
	return p
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Create Panels

local function AddCenterPanels(t, p, d)
	-- 	t == table of panels; new panels will be added
	-- 	p == parameters to build layout
	-- 	d == data to populate panels
	
	t.window = Chili.Panel:New{
		classname = 'main_window',
		name = "SpecPanel",
		padding = {0,0,0,0},
		x = p.screenHorizCentre - p.windowWidth/2,
		y = 0,
		clientWidth  = p.windowWidth,
		clientHeight = p.windowheight,
	}

	t.topcenterpanel = Chili.Panel:New{
		parent = t.window,
		classname = 'main_window_small',
		padding = {5,5,5,5},
		x = (p.windowWidth - p.topcenterwidth)/2,
		width = p.topcenterwidth,
		height = p.topheight,
		dockable = false;
		draggable = false,
		resizable = false,
	}
	t.clocklabel = Chili.Label:New{
		parent = t.topcenterpanel,
		padding = {0,0,0,0},
		width = '100%',
		height = '100%',
		align = 'center',
		valign = 'center',
		autosize = false,
		fontsize = 24,
		textColor = {0.95, 1.0, 1.0, 1},
		caption = GetTimeString(),
	}
	
	t.balancepanel = Chili.Panel:New{
		parent = t.window,
		classname = 'main_window_small',
		padding = {0,0,0,0},
		x = (p.windowWidth - p.balancepanelwidth)/2,
		y = p.topheight,
		width = p.balancepanelwidth,
		height = p.balancepanelheight,
	}
	t.balancebars = {}
	for i,bar in ipairs(d.balancebars) do
		t.balancebars[i] = {}
		t.balancebars[i].label = Chili.Label:New{
			parent = t.balancepanel,
			y = p.balanceheight * (i-1) + 4,
			width = '100%',
			height = 15,
			autosize = false,
			caption = bar.name,
			align = 'center',
		}
		t.balancebars[i].bar = Chili.Progressbar:New{
			parent = t.balancepanel,
			orientation = 'horizontal',
			value = bar.value,
			x = '15%',
			y = p.balanceheight * (i-1) + p.balancelabelheight,
			width = '70%',
			height = p.balancebarheight,
			color = d.playercolors['left'],
			backgroundColor = {1,0,0,0},
		}
		t.balancebars[i].bar_bg = Chili.Progressbar:New{
			parent = t.balancepanel,
			orientation = 'horizontal',
			value = 100,
			x = '15%',
			y = p.balanceheight * (i-1) + p.balancelabelheight,
			width = '70%',
			height = p.balancebarheight,
			color = d.playercolors['right'],
		}
	end
	
end

local function AddSidePanels(t, p, d, side)
	-- 	t == table of panels; new panels will be added
	-- 	p == parameters to build layout
	-- 	d == data to populate panels

	local x, right
	if side == 'left' then
		x = "x"
		right = "right"
	elseif side == 'right' then
		x = "right"
		right = "x"
	else
		return
	end
	
	t[side] = t[side] or {}
	local ts = t[side]
	
	ts.winslabel_top = Chili.Label:New{
		parent = t.topcenterpanel,
		padding = {0,0,0,0},
		[x] = 0,
		y = '5%',
		width = 50,
		height = '30%',
		autosize = false,
		align = 'center',
		valign = 'center',
		textColor = d.playercolors[side],
		caption = "Wins:",
	}
	ts.winslabel_bottom = Chili.Label:New{
		parent = t.topcenterpanel,
		padding = {0,0,0,0},
		[x] = 0,
		y = '30%',
		width = 50,
		height = '70%',
		autosize = false,
		align = 'center',
		valign = 'center',
		fontsize = 20,
		textColor = d.playercolors[side],
		caption = d.playerwins[side],
	}

	ts.playerlabel = Chili.Label:New{
		parent = t.window,
		padding = {0,0,0,0},
		[right] = (p.windowWidth + p.topcenterwidth)/2,
		width = p.playerlabelwidth,
		height = p.topheight,
		align = 'center',
		valign = 'center',
		autosize = false,
		textColor = d.playercolors[side],
		fontsize = 28,
		fontShadow = true,
		fontOutline = false,
		caption = d.playernames[side],
	}
	
	ts.resource_stats = {}
	for i,resource in ipairs(d.resource_stats[side]) do
		local restype = d.resource_stats[side][i].type
		ts.resource_stats[restype] = {}
		local r = ts.resource_stats[restype]
		r.panel = Chili.Panel:New{
			parent = t.window,
			y = p.topheight + p.rowheight * (i-1),
			[right] = (p.windowWidth + p.balancepanelwidth)/2 + p.unitpanelwidth,
			width = p.resourcepanelwidth,
			height = p.rowheight,
			skin = nil,
			skinName = 'default',
			backgroundColor = {0,0,0,0},
			borderColor = {1,1,1,1},
			borderThickness = 1,
		}
		r.barpanel = Chili.Control:New{
			parent = r.panel,
			padding = {0,0,0,0},
			y = 0,
			right = 0,
			width = p.resourcebarwidth,
			height = '100%',
		}
		r.bar = Chili.Progressbar:New{
			parent = r.barpanel,
			padding = {0,0,0,0},
			x = '5%',
			y = '10%',
			height = '80%',
			right = '0%',
			color = resource.color,
			value = resource.bar,
		}
		r.statpanel = Chili.Control:New{
			parent = r.panel,
			padding = {0,0,0,0},
			x = 0,
			y = 0,
			width = p.resourcestatpanelwidth,
			height = '100%',
		}
		r.total = Chili.Label:New{
			parent = r.statpanel,
			x = 18,
			height = '100%',
			width = 25,
			autosize = false,
			valign = 'center',
			fontsize = 20,
			textColor = resource.color,
			caption = Format(resource.total, ""),
		}
		r.icon = Chili.Image:New{
			parent = r.statpanel,
			x = 0,
			height = 18,
			width = 18,
			file = resource.icon,
		}
		r.labels = {}
		for j,stat in ipairs(resource) do
			local color, shadow, outline
			if i == 2 and j == 3 then
				color = {1,0.3,0.3,1}
				shadow = false
				outline = true
			else
				color = resource.color
				shadow = true
				outline = false
			end
			r.labels[j] = Chili.Label:New{
				parent = r.statpanel,
				x = stat.label_x,
				height = '100%',
				width = 50,
				valign = 'center',
				autosize = false,
				textColor = color,
				fontShadow = shadow,
				fontOutline = outline,
				caption = stat.label .. ":" .. Format(stat.value, ""),
			}
		end
	end
	
	ts.unitpanel = Chili.Panel:New{
		parent = t.window,
		y = p.topheight,
		[right] = (p.windowWidth + p.balancepanelwidth)/2,
		height = p.rowheight * 2,
		width = p.unitpanelwidth,
		skin = nil,
		skinName = 'default',
		backgroundColor = {0,0,0,0},
		borderColor = {1,1,1,1},
		borderThickness = 1,
	}
	ts.unit_stats = {}
	ts.unit_stats.total = Chili.Label:New{
		parent = ts.unitpanel,
		[x] = 0,
		height = '50%',
		width = '100%',
		align = 'center',
		valign = 'center',
		autosize = false,
		fontsize = 16,
		textColor = { 0.85, 0.85, 0.85, 1.0 },
		caption = "Unit Value: " .. Format(d.unit_stats[side].total, ""),
	}
	for i,stat in ipairs(d.unit_stats[side]) do
		ts.unit_stats[i] = {}
		ts.unit_stats[i].icon = Chili.Image:New{
			parent = ts.unitpanel,
			x = stat.icon_x,
			y = '60%',
			height = 18,
			width = 18,
			file = stat.icon,
		}
		ts.unit_stats[i].label = Chili.Label:New{
			parent = ts.unitpanel,
			x = stat.icon_x + 18,
			y = '50%',
			height = '50%',
			width = 20,
			valign = 'center',
			textColor = { 0.7, 0.7, 0.7, 1.0 },
			caption = Format(stat.value, ""),
		}
	end
	
	ts.unitpics = {}
	for i = 1,unitpic_slots do
		ts.unitpics[i] = {}
		ts.unitpics[i].text = Chili.Label:New{
			parent = t.window,
			y = p.topheight + p.rowheight * 2 + 5,
			[right] = (p.windowWidth + p.balancepanelwidth)/2 + p.picsize * (i-1) + 5,
			height = p.picsize - 10,
			width = p.picsize - 10,
			autosize = false,
			align = 'right',
			valign = 'bottom',
			fontsize = 16,
			caption = '',
		}
		ts.unitpics[i].unitpic = Chili.Image:New{
			parent = t.window,
			y = p.topheight + p.rowheight * 2,
			[right] = (p.windowWidth + p.balancepanelwidth)/2 + p.picsize * (i-1),
			height = p.picsize,
			width = p.picsize,
			file = 'unitpics/fakeunit.png',
		}
		local framepic
		if i == 1 then
			framepic = 'bitmaps/icons/frame_cons.png'
		else
			framepic = 'bitmaps/icons/frame_unit.png'
		end
		ts.unitpics[i].unitpicframe = Chili.Image:New{
			parent = t.window,
			y = p.topheight + p.rowheight * 2,
			[right] = (p.windowWidth + p.balancepanelwidth)/2 + p.picsize * (i-1),
			height = p.picsize,
			width = p.picsize,
			keepAspect = false,
			file = framepic,
		}
	end
	
	ts.compics = {}
	for i = 1,compic_slots do
		ts.compics[i] = {}
		if i == 1 then
			ts.compics[i].moretext = Chili.Label:New{
				parent = t.window,
				y = p.topheight + p.rowheight * 2 + 5,
				[right] = (p.windowWidth + p.balancepanelwidth)/2 + p.picsize * (i-1) + p.picsize * unitpic_slots,
				height = p.picsize - 10,
				width = p.picsize - 10,
				autosize = false,
				align = 'center',
				valign = 'center',
				textColor = col_energy,
				caption = '',
			}
			ts.compics[i].moretext:Hide()
		end
		ts.compics[i].text = Chili.Label:New{
			parent = t.window,
			y = p.topheight + p.rowheight * 2 + 5,
			[right] = (p.windowWidth + p.balancepanelwidth)/2 + p.picsize * (i-1) + p.picsize * unitpic_slots,
			height = p.picsize - 10,
			width = p.picsize - 10,
			autosize = false,
			align = 'right',
			valign = 'bottom',
			caption = '',
		}
		ts.compics[i].unitpic = Chili.Image:New{
			parent = t.window,
			y = p.topheight + p.rowheight * 2,
			[right] = (p.windowWidth + p.balancepanelwidth)/2 + p.picsize * (i-1) + p.picsize * unitpic_slots,
			height = p.picsize,
			width = p.picsize,
			file = 'unitpics/fakeunit.png',
		}
		local framepic = 'bitmaps/icons/frame_unit.png'
		ts.compics[i].unitpicframe = Chili.Image:New{
			parent = t.window,
			y = p.topheight + p.rowheight * 2,
			[right] = (p.windowWidth + p.balancepanelwidth)/2 + p.picsize * (i-1) + p.picsize * unitpic_slots,
			height = p.picsize,
			width = p.picsize,
			keepAspect = false,
			file = framepic,
		}
		ts.compics[i].text:Hide()
		ts.compics[i].unitpic:Hide()
		ts.compics[i].unitpicframe:Hide()
	end
	
	ts.bg_top = Chili.Panel:New{
		parent = t.window,
		[x] = 12,
		y = 0,
		width  = (p.windowWidth - 24) / 2,
		height = p.topheight,
		skin = nil,
		skinName = 'default',
		backgroundColor = {0,0,0,0.2},
		borderColor = {0,0,0,0},
	}
	ts.bg_bottom = Chili.Panel:New{
		parent = t.window,
		[x] = 12,
		y = p.topheight,
		width  = (p.windowWidth - 24) / 2,
		height = p.windowheight - p.topheight,
		skin = nil,
		skinName = 'default',
		backgroundColor = {0,0,0,0.6},
		borderColor = {0,0,0,0},
	}
	ts.bg_image = Chili.Image:New{
		parent = t.window,
		[x] = 12,
		y = 7,
		width  = (p.windowWidth - 24) / 2,
		height = p.windowheight - 14,
		keepAspect = false,
		file = 'LuaUI/Images/specpanel_ng/' .. d.bgfac[side] .. '_' .. side .. '.png',
	}
	
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Startup and Shutdown

function SpecWindowStartStop(force)
	-- TODO - Consider whether it would be better instead to unregister
	--	the call-ins when the panel is turned off and re-register them
	--	when turned back on than to use the flag to short-circuit the
	--	call-ins and in ProcessUnit()
	
	-- TODO - Consider whether it would be better to have the option setting
	--	here to enable/disable the widget's functionality, or just have
	--	a menu button to enable/disable (i.e. load/unload) the widget
	--	entirely.
	--
	--	Also - is what's desired just a visibility toggle while the stats
	--	collection continues, or a halt to the stats collection while
	--	the panel is disabled?
	
	local spectating = select(1, Spring.GetSpectatingState())
	
	if force == 'start' or (force ~= 'stop' and (options.enableSpecNG.value and spectating)) then
		if not panel_is_on then
			-- TODO - Don't forget to re-initialize things like smoothedTables and unitStats
			-- while bearing in mind that we could be re-initializing in the middle of the game
			specPanel = {}
			allyTeams = GetOpposingAllyTeams()
			panelParams = SetupLayoutParams()
			mockData = SetupMockData()
			panelData = mockData
			panelData.playernames = { left = allyTeams[1].name, right = allyTeams[2].name, }
			panelData.playerwins = { left = allyTeams[1].winString, right = allyTeams[2].winString, }
			AddCenterPanels(specPanel, panelParams, panelData)
			AddSidePanels(specPanel, panelParams, panelData, 'left')
			AddSidePanels(specPanel, panelParams, panelData, 'right')
			if specPanel and specPanel.window then
				screen0:AddChild(specPanel.window)
			end
	
			DisplayUpdatedResources(specPanel)
			DisplayUpdatedUnitStats(specPanel)
			panel_is_on = true
		end
	elseif force == 'stop' or (force ~= 'start' and not (options.enableSpecNG.value and spectating)) then
		if panel_is_on then
			specPanel.window:Dispose()
			specPanel = nil
			panel_is_on = false
		end
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- General Call-ins

function widget:Shutdown()
end

function widget:PlayerChanged(pID)
	if pID == Spring.GetMyPlayerID() then
		SpecWindowStartStop()
	end
end

function widget:Initialize()
	Chili = WG.Chili
	if (not Chili) then
		widgetHandler:RemoveWidget()
		return
	end
	screen0 = Chili.Screen0
end

function widget:Update(dt)
	if not didonce then
		SpecWindowStartStop()
		didonce = true
	end
	if panel_is_on then
		timer_updateclock = timer_updateclock + dt
		timer_updatestats = timer_updatestats + dt
		-- Update the resource bar flashing status and graphics
		--	- TBD
		if timer_updateclock >= 1 then
			UpdateClock(specPanel)
			-- TBD: revise Wins logic so it only updates at game end, not every userframe during play
			UpdateWins(specPanel)
			_,timer_updateclock = math.modf(Spring.GetGameSeconds())
		end
		if timer_updatestats >= 2 then
			DisplayUpdatedResources(specPanel)
			DisplayUpdatedUnitStats(specPanel)
			_,timer_updatestats = math.modf(Spring.GetGameSeconds())
		end
	end
end

function widget:GameFrame(n)
	if panel_is_on then
		if n%TEAM_SLOWUPDATE_RATE == 0 then
			FetchUpdatedResources()
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

