-- reloadTime is in seconds

local oneClickWepDefs = {}

local oneClickWepDefNames = {
	terraunit = {
		{ functionToCall = "Detonate", name = "Cancel", tooltip = "Cancel selected terraform units.", texture = "LuaUI/Images/Commands/Bold/cancel.png", partBuilt = true},
	},
	gunshipkrow = {
		{ functionToCall = "ClusterBomb", reloadTime = 854, name = "Carpet Bomb", tooltip = "Drop a huge number of bombs in a circle under the Krow", weaponToReload = 3, texture = "LuaUI/Images/Commands/Bold/bomb.png",},
	},
	hoverdepthcharge = {
		{ functionToCall = "ShootDepthcharge", reloadTime = 256, name = "Drop Depthcharge", tooltip = "Drops a depthchage.", weaponToReload = 1, texture = "LuaUI/Images/Commands/Bold/dgun.png",},
	},
	cloakbomb = {
		{ functionToCall = "Detonate", name = "Detonate", tooltip = "Detonate selected bomb units.",  texture = "LuaUI/Images/Commands/Bold/detonate.png",},
	},
	shieldbomb = {
		{ functionToCall = "Detonate", name = "Detonate", tooltip = "Detonate selected bomb units.", texture = "LuaUI/Images/Commands/Bold/detonate.png",},
	},
	jumpbomb = {
		{ functionToCall = "Detonate", name = "Detonate", tooltip = "Detonate selected bomb units.",  texture = "LuaUI/Images/Commands/Bold/detonate.png",},
	},
	gunshipbomb = {
		{ functionToCall = "Detonate", name = "Detonate", tooltip = "Detonate selected bomb units.", texture = "LuaUI/Images/Commands/Bold/detonate.png",},
	},
	bomberdisarm = {
		{ functionToCall = "StartRun", name = "Start Run", tooltip = "Manually activate Thunderbird run.", texture = "LuaUI/Images/Commands/Bold/bomb.png",},
	},
	--[[
	tankraid = {
		{ functionToCall = "FlameTrail", reloadTime = 850, name = "Flame Trail", tooltip = "Leave a path of flame in your wake", useSpecialReloadFrame = true, texture = "LuaUI/Images/Commands/Bold/sprint.png",},
	},
	--]]
	planefighter = {
		{ functionToCall = "Sprint", reloadTime = 850, name = "Speed Boost", tooltip = "Speed boost (5x for 1 second)", useSpecialReloadFrame = true, texture = "LuaUI/Images/Commands/Bold/sprint.png",},
	},
	--planescout = {
	--	{ functionToCall = "Cloak", reloadTime = 600, name = "Temp Cloak", tooltip = "Cloaks for 5 seconds", useSpecialReloadFrame = true},
	--},
	gunshipheavytrans = {
		{ functionToCall = "ForceDropUnit", reloadTime = 7, name = "Drop Cargo", tooltip = "Eject cargo!", useSpecialReloadFrame = true,},
	},
	gunshiptrans = {
		{ functionToCall = "ForceDropUnit", reloadTime = 7, name = "Drop Cargo", tooltip = "Eject cargo!", useSpecialReloadFrame = true,},
	},		
}


for name, data in pairs(oneClickWepDefNames) do
	if UnitDefNames[name] then 
		oneClickWepDefs[UnitDefNames[name].id] = data
	end
end

return oneClickWepDefs