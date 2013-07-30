------------------- ABOUT ----------------------
--
-- In this cold planet hero seeks for a part of the
-- antigravity device. He has to capture Icy Pit who
-- knows where the device is hidden. Hero will be
-- able to use only the ice gun for this mission.

-- TODO
-- maybe use rope challenge to go there
-- add checkpoints
-- fix the stats
-- manually set the frozen hogs to last frozen for fixed number of turns
-- SetState(bandit1.gear,bor(GetState(bandit1.gear),gstFrozen))
-- SetEffect(bandit1.gear,heFrozen,9999999)

HedgewarsScriptLoad("/Scripts/Locale.lua")
HedgewarsScriptLoad("/Scripts/Animate.lua")

----------------- VARIABLES --------------------
-- globals
local campaignName = loc("A Space Adventure")
local missionName = loc("Ice planet, a frozen adventure!")
local heroAtAntiFlyArea = false
local heroVisitedAntiFlyArea = false
local heroAtFinalStep = false
local iceGunTaken = false
local checkPointReached = 1 -- 1 is normal spawn
-- dialogs
local dialog01 = {}
-- mission objectives
local goals = {
	[dialog01] = {missionName, loc("Getting ready"), loc("Collect the icegun and get the device part from Thanta"), 1, 4500},
}
-- crates
local icegunY = 1950
local icegunX = 260
-- hogs
local hero = {}
local ally = {}
local bandit1 = {}
local bandit2 = {}
local bandit3 = {}
local bandit4 = {}
local bandit5 = {}
-- teams
local teamA = {}
local teamB = {}
local teamC = {}
local teamD = {}
-- hedgehogs values
hero.name = "Hog Solo"
hero.x = 340
hero.y = 1840
hero.dead = false
ally.name = "Paul McHoggy"
ally.x = 300
ally.y = 1840
bandit1.name = "Thanta"
bandit1.x = 3240
bandit1.y = 1280
bandit1.dead = false
bandit1.frozen = false
bandit1.roundsToUnfreeze = 0
bandit2.name = "Billy Frost"
bandit2.x = 1480
bandit2.y = 1990
bandit3.name = "Ice Jake"
bandit3.x = 1860
bandit3.y = 1150
bandit4.name = "John Snow"
bandit4.x = 3200
bandit4.y = 970
bandit4.frozen = false
bandit4.roundsToUnfreeze = 0
bandit5.name = "White Tee"
bandit5.x = 3280
bandit5.y = 600
bandit5.frozen = false
bandit5.roundsToUnfreeze = 0
teamA.name = loc("Allies")
teamA.color = tonumber("FF0000",16) -- red
teamB.name = loc("Frozen Bandits")
teamB.color = tonumber("0033FF",16) -- blues
teamC.name = loc("Hog Solo")
teamC.color = tonumber("38D61C",16) -- green

-------------- LuaAPI EVENT HANDLERS ------------------

function onGameInit()
	Seed = 1
	--GameFlags = gfDisableWind
	TurnTime = 25000
	CaseFreq = 0
	MinesNum = 0
	MinesTime = 1
	Explosives = 0
	Delay = 3
	Map = "ice01_map"
	Theme = "Snow"
	
	-- Hog Solo
	AddTeam(teamC.name, teamC.color, "Bone", "Island", "HillBilly", "cm_birdy")
	hero.gear = AddHog(hero.name, 0, 100, "war_desertgrenadier1")
	AnimSetGearPosition(hero.gear, hero.x, hero.y)
	HogTurnLeft(hero.gear, true)
	-- Ally
	AddTeam(teamA.name, teamA.color, "Bone", "Island", "HillBilly", "cm_birdy")
	ally.gear = AddHog(ally.name, 0, 100, "tophats")
	AnimSetGearPosition(ally.gear, ally.x, ally.y)
	-- Frozen Bandits
	AddTeam(teamB.name, teamB.color, "Bone", "Island", "HillBilly", "cm_birdy")
	bandit1.gear = AddHog(bandit1.name, 1, 120, "tophats")
	AnimSetGearPosition(bandit1.gear, bandit1.x, bandit1.y)	
	HogTurnLeft(bandit1.gear, true)
	bandit2.gear = AddHog(bandit2.name, 1, 100, "tophats")
	AnimSetGearPosition(bandit2.gear, bandit2.x, bandit2.y)
	bandit3.gear = AddHog(bandit3.name, 1, 100, "tophats")
	AnimSetGearPosition(bandit3.gear, bandit3.x, bandit3.y)
	bandit4.gear = AddHog(bandit4.name, 1, 40, "tophats")
	AnimSetGearPosition(bandit4.gear, bandit4.x, bandit4.y)
	HogTurnLeft(bandit4.gear, true)
	bandit5.gear = AddHog(bandit5.name, 1, 40, "tophats")
	AnimSetGearPosition(bandit5.gear, bandit5.x, bandit5.y)
	HogTurnLeft(bandit5.gear, true)
	
	-- get the check point
	if tonumber(GetCampaignVar("Ice01CheckPoint")) then
		checkPointReached = tonumber(GetCampaignVar("Ice01CheckPoint"))
	end
	
	if checkPointReached == 1 then
		-- Start of the game
	elseif checkPointReached == 2 then
		iceGunTaken = true
		AnimSetGearPosition(hero.gear, 840, 1650)
	elseif checkPointReached == 3 then		
		iceGunTaken = true
		heroAtFinalStep = true
		heroVisitedAntiFlyArea = true
		AnimSetGearPosition(hero.gear, 1450, 910)
	end
	
	AnimInit()
	AnimationSetup()	
end

function onGameStart()
	AnimWait(hero.gear, 3000)
	FollowGear(hero.gear)
	
	-- Add mines
	AddGear(1612, 940, gtMine, 0, 0, 0, 0)
	AddGear(1622, 945, gtMine, 0, 0, 0, 0)
	AddGear(1645, 950, gtMine, 0, 0, 0, 0)
	AddGear(1655, 960, gtMine, 0, 0, 0, 0)
	AddGear(1665, 965, gtMine, 0, 0, 0, 0)
	
	AddGear(1800, 1000, gtMine, 0, 0, 0, 0)
	AddGear(1810, 1005, gtMine, 0, 0, 0, 0)
	AddGear(1820, 1010, gtMine, 0, 0, 0, 0)
	AddGear(1830, 1015, gtMine, 0, 0, 0, 0)
	AddGear(1840, 1020, gtMine, 0, 0, 0, 0)
	
	AddGear(1900, 1020, gtMine, 0, 0, 0, 0)
	AddGear(1910, 1020, gtMine, 0, 0, 0, 0)
	AddGear(1920, 1020, gtMine, 0, 0, 0, 0)
	AddGear(1930, 1030, gtMine, 0, 0, 0, 0)
	AddGear(1940, 1040, gtMine, 0, 0, 0, 0)
	
	AddGear(2130, 1110, gtMine, 0, 0, 0, 0)
	AddGear(2140, 1120, gtMine, 0, 0, 0, 0)
	AddGear(2180, 1120, gtMine, 0, 0, 0, 0)
	AddGear(2200, 1130, gtMine, 0, 0, 0, 0)
	AddGear(2210, 1130, gtMine, 0, 0, 0, 0)
	
	local x=2300
	local step=0
	while x<3100 do
		AddGear(x, 1150, gtMine, 0, 0, 0, 0)
		step = step + 1
		if step == 5 then
			step = 0
			x = x + math.random(100,300)
		else
			x = x + math.random(10,30)
		end
	end
	
	AddEvent(onHeroDeath, {hero.gear}, heroDeath, {hero.gear}, 1)
	AddEvent(onHeroFinalStep, {hero.gear}, heroFinalStep, {hero.gear}, 0)
	AddEvent(onAntiFlyArea, {hero.gear}, antiFlyArea, {hero.gear}, 1)
	AddEvent(onNonAntiFlyArea, {hero.gear}, nonAntiFlyArea, {hero.gear}, 1)
	AddEvent(onThantaDeath, {bandit1.gear}, thantaDeath, {bandit1.gear}, 1)
	
	AddAmmo(hero.gear, amJetpack, 99)
	AddAmmo(bandit1.gear, amBazooka, 5)
	AddAmmo(bandit2.gear, amBazooka, 4)
	AddAmmo(bandit3.gear, amMine, 2)
	AddAmmo(bandit3.gear, amGrenade, 3)
	AddAmmo(bandit4.gear, amBazooka, 5)
	AddAmmo(bandit5.gear, amBazooka, 5)
	
	if checkPointReached == 1 then
		AddAmmo(hero.gear, amBazooka, 1)
		SpawnAmmoCrate(icegunX, icegunY, amIceGun)
		AddEvent(onColumnCheckPoint, {hero.gear}, columnCheckPoint, {hero.gear}, 0)
		AddEvent(onHeroAtIceGun, {hero.gear}, heroAtIceGun, {hero.gear}, 0)
		AddAnim(dialog01)
	elseif checkPointReached == 2 then
		AddAmmo(hero.gear, amIceGun, 8)
		AnimCaption(hero.gear, loc("Go to Thanta and get the device part!"), 5000)
	elseif checkPointReached == 3 then
		AddAmmo(hero.gear, amIceGun, 6)
		AnimCaption(hero.gear, loc("Go to Thanta and get the device part!"), 5000)
	end
	
end

function onNewTurn()		
	-- round has to start if hero goes near the column
	if not heroVisitedAntiFlyArea and CurrentHedgehog ~= hero.gear then
		TurnTimeLeft = 0
	elseif not heroVisitedAntiFlyArea and CurrentHedgehog == hero.gear then
		TurnTimeLeft = -1
	elseif not heroAtFinalStep and (CurrentHedgehog == bandit1.gear or CurrentHedgehog == bandit4.gear or CurrentHedgehog == bandit5.gear) then		
		AnimSwitchHog(hero.gear)
		TurnTimeLeft = 0
	elseif heroAtFinalStep and (CurrentHedgehog == bandit2.gear or CurrentHedgehog == bandit3.gear) then
		if (GetHealth(bandit1.gear) and GetEffect(bandit1.gear,heFrozen) > 256) and
			((GetHealth(bandit4.gear) and GetEffect(bandit4.gear,heFrozen) > 256) or not GetHealth(bandit4.gear)) and
			((GetHealth(bandit5.gear) and GetEffect(bandit5.gear,heFrozen) > 256) or not GetHealth(bandit5.gear)) then
			AnimSwitchHog(hero.gear)
		else
			AnimSwitchHog(hero.gear)
			TurnTimeLeft = 0
		end
	elseif CurrentHedgehog == ally.gear then
		TurnTimeLeft = 0
	end
	-- frozen hogs accounting
	if CurrentHedgehog == hero.gear and heroAtFinalStep and TurnTimeLeft > 0 then
		if bandit1.frozen then
			if bandit1.roundsToUnfreeze == 0 then
				SetEffect(bandit1.gear, heFrozen, 255)
				bandit1.frozen = false
			else
				bandit1.roundsToUnfreeze = bandit1.roundsToUnfreeze - 1
			end
		end
		if bandit4.frozen then
			if bandit4.roundsToUnfreeze == 0 then
				SetEffect(bandit4.gear, heFrozen, 255)
				bandit4.frozen = false
			else
				bandit4.roundsToUnfreeze = bandit4.roundsToUnfreeze - 1
			end
		end
		if bandit5.frozen then
			if bandit5.roundsToUnfreeze == 0 then
				SetEffect(bandit5.gear, heFrozen, 255)
				bandit5.frozen = false
			else
				bandit5.roundsToUnfreeze = bandit5.roundsToUnfreeze - 1
			end
		end
	else
		if bandit1.frozen then
			SetEffect(bandit1.gear, heFrozen, 9999999999)
		end
		if bandit4.frozen then
			SetEffect(bandit4.gear, heFrozen, 9999999999)
		end
		if bandit5.frozen then
			SetEffect(bandit5.gear, heFrozen, 9999999999)
		end
	end
end

function onGameTick()
	AnimUnWait()
	if ShowAnimation() == false then
		return
	end
	ExecuteAfterAnimations()
	CheckEvents()
	
	if GetEffect(bandit1.gear, heFrozen) > 256 and not bandit1.frozen then
		bandit1.frozen = true
		SetEffect(bandit1.gear, heFrozen, 9999999999)
		bandit1.roundsToUnfreeze = 1
	end
	if GetEffect(bandit4.gear, heFrozen) > 256 and not bandit4.frozen then
		bandit4.frozen = true
		SetEffect(bandit4.gear, heFrozen, 9999999999)
		bandit4.roundsToUnfreeze = 2
	end
	if GetEffect(bandit5.gear, heFrozen) > 256 and not bandit5.frozen then
		bandit5.frozen = true
		SetEffect(bandit5.gear, heFrozen, 9999999999)
		bandit5.roundsToUnfreeze = 2
	end
end

function onAmmoStoreInit()
	SetAmmo(amIceGun, 0, 0, 0, 8)
end

function onGearDelete(gear)
	if gear == hero.gear then
		hero.dead = true
	elseif gear == bandit1.gear then
		bandit1.dead = true
	end
end

function onPrecise()
	if GameTime > 3000 then
		SetAnimSkip(true)   
	end
end

-------------- EVENTS ------------------

function onAntiFlyArea(gear)
	if not hero.dead and (GetX(gear) > 860 or GetY(gear) < 1400) and not heroAtAntiFlyArea then
		return true
	end
	return false
end

function onNonAntiFlyArea(gear)
	if not hero.dead and (GetX(gear) < 860 and GetY(gear) > 1400) and heroAtAntiFlyArea then
		return true
	end
	return false
end

function onHeroDeath(gear)
	if hero.dead then
		return true
	end
	return false
end

function onHeroFinalStep(gear)
	if not hero.dead and GetY(gear) < 960 and GetX(gear) > 1400 then
		return true
	end
	return false
end

function onColumnCheckPoint(gear)
	if not hero.dead and iceGunTaken and GetX(gear) < 870 and GetX(gear) > 850 and GetY(gear) > 1500 and StoppedGear(gear) then
		return true
	end
	return false
end

function onHeroAtIceGun(gear)
	if not hero.dead and GetX(gear) < icegunX+15 and GetX(gear) > icegunX-15 and GetY(gear) > icegunY-15 and GetY(gear) < icegunY+15 then
		return true
	end
	return false
end

function onThantaDeath(gear)
	if bandit1.dead then
		return true
	end
	return false
end

-------------- OUTCOMES ------------------

function antiFlyArea(gear)
	heroAtAntiFlyArea = true
	if TurnTimeLeft < -1 then
		heroVisitedAntiFlyArea = true
		TurnTimeLeft = 0	
		FollowGear(hero.gear)
		AddAmmo(hero.gear, amJetpack, 0)
		AnimSwitchHog(bandit1.gear)	
		FollowGear(hero.gear)
		TurnTimeLeft = 0
	else
		AddAmmo(hero.gear, amJetpack, 0)	
	end
end

function nonAntiFlyArea(gear)
	heroAtAntiFlyArea = false
	AddAmmo(hero.gear, amJetpack, 99)
end

function heroDeath(gear)
	SendStat('siGameResult', loc("Hog Solo lost, try again!")) --1
	-- more custom stats
	EndGame()
end

function heroFinalStep(gear)
	heroAtFinalStep = true
	SaveCampaignVar("Ice01CheckPoint", "3")
	SaveCampaignVar("HeroHealth", GetHealth(hero.gear))	
	WriteLnToConsole("Final Step")
end

function columnCheckPoint(gear)
	SaveCampaignVar("Ice01CheckPoint", "2")	
	SaveCampaignVar("HeroHealth", GetHealth(hero.gear))
	AnimCaption(hero.gear, loc("Checkpoint reached!"), 5000)
end

function heroAtIceGun(gear)
	iceGunTaken=true
end

function thantaDeath(gear)
	SendStat('siGameResult', loc("Hog Solo lost, try again!")) --1
	-- more custom stats
	EndGame()
end

-------------- ANIMATIONS ------------------

function Skipanim(anim)
	if goals[anim] ~= nil then
		ShowMission(unpack(goals[anim]))
    end
end

function AnimationSetup()
	-- DIALOG 01 - Start, welcome to moon
	AddSkipFunction(dialog01, Skipanim, {dialog01})
	table.insert(dialog01, {func = AnimWait, args = {hero.gear, 3000}})
	table.insert(dialog01, {func = AnimCaption, args = {hero.gear, loc("In the ice planet, where ice rules..."), 5000}})
	table.insert(dialog01, {func = AnimSay, args = {ally.gear, loc("Finaly you are here..."), SAY_SAY, 2000}})
	table.insert(dialog01, {func = AnimWait, args = {hero.gear, 2000}})
	table.insert(dialog01, {func = AnimSay, args = {hero.gear, loc("Hi! Nice to meet you"), SAY_SAY, 3000}})
	table.insert(dialog01, {func = AnimWait, args = {ally.gear, 2000}})
	table.insert(dialog01, {func = AnimSay, args = {ally.gear, loc("Listen carefuly! The bandit leader, Thanta has recently found a very strange device"), SAY_SAY, 4000}})
	table.insert(dialog01, {func = AnimSay, args = {ally.gear, loc("He doesn't know it but this device is a part of the antigravity device"), SAY_SAY, 2500}})
	table.insert(dialog01, {func = AnimWait, args = {hero.gear, 8000}})
	table.insert(dialog01, {func = AnimSay, args = {hero.gear, loc("Nice, then I should get the part as soon as possible!"), SAY_SAY, 4000}})
	table.insert(dialog01, {func = AnimWait, args = {ally.gear, 4000}})
	table.insert(dialog01, {func = AnimSay, args = {ally.gear, loc("Be careful, your gadgets won't work in the bandit area. You should get an ice gun"), SAY_SAY, 7000}})
	table.insert(dialog01, {func = AnimSay, args = {ally.gear, loc("There is one below us!"), SAY_SAY, 4000}})
	table.insert(dialog01, {func = AnimWait, args = {hero.gear, 500}})
	table.insert(dialog01, {func = AnimSwitchHog, args = {hero.gear}})
end
