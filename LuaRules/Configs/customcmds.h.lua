--------------------------------------------------------------------------------
--
--  Proposed Command ID Ranges:
--
--    all negative:  Engine (build commands)
--       0 -   999:  Engine
--    1000 -  9999:  Group AI
--   10000 - 19999:  LuaUI
--   20000 - 29999:  LuaCob
--   30000 - 39999:  LuaRules
--

CMD_RETREAT =	10000
CMD_RETREAT_ZONE = 10001
CMD_SETHAVEN = CMD_RETREAT_ZONE

CMD_FACTORY_GUARD = 13921

CMD_BUILD = 10010
CMD_AREA_MEX = 10100

CMD_MORPH = 31210
CMD_EMBARK = 31800
CMD_DISEMBARK = 31801
CMD_STEALTH = 32100
CMD_CLOAK_SHIELD = 32101
CMD_MINE = 32105	-- easymetal2
CMD_REARM = 32768	-- bomber control
CMD_FIND_PAD = 32769	-- bomber control
CMD_PRIORITY= 34220
CMD_AP_FLY_STATE = 34569	-- unit_air_plants
CMD_AP_AUTOREPAIRLEVEL = 34570	-- unit_air_plants
CMD_ANTINUKEZONE = 35130	-- ceasefire
CMD_UNIT_AI = 36214
CMD_UNIT_KILL_SUBORDINATES = 35821	-- unit_capture
CMD_UNIT_BOMBER_DIVE_STATE = 34281  -- bomber dive
CMD_JUMP = 38521
CMD_TIMEWARP = 32523

-- terraform
CMD_RAMP = 39734
CMD_LEVEL = 39736
CMD_RAISE = 39737
CMD_SMOOTH = 39738
CMD_RESTORE = 39739
CMD_TERRAFORM_INTERNAL = 39801

-- not included here, just listed
--[[
CMD_PURCHASE = 32601	-- planetwars, range up to 32601 + #purchases
CMD_MORPH_STOP = 32210	-- range up to 32210 + #morphs
CMD_MORPH = 31210		-- ditto
]]--

-- deprecated
--[[
CMD_PLANTBOMB =     	32523
CMD_AUTOREPAIR =    	33250 	-- up to 33250 + 3
CMD_AUTORECLAIM =   	33251
CMD_AUTOASSIST  =   	33252
CMD_AUTOATTACK  =   	33253
CMD_PRIORITY=			34220
CobButton =         	34520 	-- up to 32520 + different cob buttons
CMD_SCRAMBLE =      	35128
CMD_WRECK =         	36734
CMD_RESTOREBOMB = 		39735
]]--