-------------------------------------------------------------------------------
--- AUTHOR: Nostrademous
--- GITHUB REPO: https://github.com/Nostrademous/Dota2-FullOverwrite
-------------------------------------------------------------------------------

BotsInit = require( "game/botsinit" )
local genericAbility = BotsInit.CreateGeneric()

local utils = require( GetScriptDirectory().."/utility" )
local gHeroVar = require( GetScriptDirectory().."/global_hero_data" )

function setHeroVar(var, value)
    local bot = GetBot()
    gHeroVar.SetVar(bot:GetPlayerID(), var, value)
end

function getHeroVar(var)
    local bot = GetBot()
    return gHeroVar.GetVar(bot:GetPlayerID(), var)
end

local abilityQ = ""
local abilityW = ""
local abilityE = ""
local abilityR = ""

local castQDesire   = 0
local castWDesire   = 0
local castRDesire   = 0

local AttackRange   = 0
local ManaPerc      = 0.0
local HealthPerc    = 0.0
local modeName      = nil

function ConsiderQ()
    local bot = GetBot()
    
    if not abilityQ:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, {}
	end
	
	local CastRange = abilityQ:GetCastRange()
	local Damage    = abilityQ:GetLevel()*75
	local Radius    = abilityQ:GetAOERadius()
	
	local HeroHealth    = 10000
	local CreepHealth   = 10000
    
    
	local WeakestEnemy, HeroHealth = utils.GetWeakestHero(bot, CastRange+150)

    --------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	--try to kill enemy hero
	if modeName ~= "retreat" then
		if utils.ValidTarget(WeakestEnemy) then
			if not utils.IsTargetMagicImmune( WeakestEnemy ) then
				if HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) then
					return BOT_ACTION_DESIRE_HIGH, utils.VectorTowards(WeakestEnemy:GetLocation(), bot:GetLocation(), Radius/2)
				end
			end
		end
	end
    
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	-- fighting (team fight) and can hit 2+ enemies
	if modeName == "fight" then
		if ManaPerc > 0.4 then
			local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), CastRange, Radius, 0, 0 )
			if locationAoE.count >= 2 then
				return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc
			end
		end
	end
	
	-- If we're pushing or defending a lane and can hit 4+ creeps, go for it
	if modeName == "defendlane" or modeName == "pushlane" then
		if ManaPerc > 0.4 then
			local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), CastRange, Radius, 0, 0 )
			if locationAoE.count >= 4 then
				return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc
			end
		end
	end

	-- If we're going after someone
	if modeName == "roam" then
		local npcEnemy = getHeroVar("RoamTarget")
		if utils.ValidTarget(npcEnemy) then
			if not utils.IsTargetMagicImmune( npcEnemy ) then
				return BOT_ACTION_DESIRE_MODERATE, utils.VectorTowards(npcEnemy:GetLocation(), bot:GetLocation(), Radius/2)
			end
		end
	end
	
	-- If we're farming and can kill 3+ creeps
	if modeName == "jungling" or modeName == "laning" then
		if ManaPerc > 0.4 then
			local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), CastRange, Radius, 0, Damage )
			if ( locationAoE.count >= 3 ) then
				return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, {}
end

function ConsiderW()
    local bot = GetBot()
    
    if not abilityW:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
    
    local CastRange = abilityW:GetCastRange()
    
    --------------------------------------
	-- Global high-priorty usage
	--------------------------------------
    
    local allies = gHeroVar.GetNearbyAllies( bot, CastRange+300 )
    
	-- protect team mate, save allies from control
	for _, ally in pairs( allies ) do
		if utils.IsCrowdControlled(ally) then
			if not utils.IsTargetMagicImmune( ally ) then
				return BOT_ACTION_DESIRE_HIGH, ally
			end
		end
	end
    
    -- save allies from other disables
	if modeName == "fight" or modeName == "defendally" or ManaPerc > 0.4 then
		for _, npcTarget in pairs( allies ) do
			if (npcTarget:GetCurrentMovementSpeed() < 250 or utils.IsUnitCrowdControlled(npcTarget) or npcTarget:IsBlockDisabled())
			then
				if not utils.IsTargetMagicImmune( npcTarget ) then
					return BOT_ACTION_DESIRE_HIGH, npcTarget
				end
			end
		end
	end
    
    local enemies = gHeroVar.GetNearbyEnemies( bot, CastRange+300 )
	
    -- heal myself when retreating
	if modeName == "retreat" and HealthPerc <= 0.4+#enemies*0.05+0.2*ManaPerc then
		if #enemies >= 1 then
            if not utils.IsTargetMagicImmune(bot) then
                return BOT_ACTION_DESIRE_HIGH, bot
            end
		end
	end
    
    --------------------------------------
	-- Mode based usage
	--------------------------------------
	-- team fight usage
	if modeName == "fight" or modeName == "defendally" then
		for _, npcTarget in pairs( allies ) do
			if npcTarget:GetHealth()/npcTarget:GetMaxHealth() < (0.2+#enemies*0.05+0.2*ManaPerc) or 
                npcTarget:WasRecentlyDamagedByAnyHero(3.0) then
				if not utils.IsTargetMagicImmune( npcTarget ) then
					return BOT_ACTION_DESIRE_MODERATE, npcTarget
				end
			end
		end
	end

	-- If we're pushing a lane and attacking a tower
	if modeName == "pushlane" then
		local target = bot:GetAttackTarget()
		if utils.NotNilOrDead(target) then
			if ManaPerc > 0.4 and target:IsTower() then
                if not utils.IsTargetMagicImmune( bot ) then
                    return BOT_ACTION_DESIRE_MODERATE, bot
                end
			end
		end
	end

	-- If we're going after someone
	if modeName == "roam" then
		local npcEnemy = getHeroVar("RoamTarget")
		
		if ManaPerc > 0.4 then
			if utils.ValidTarget(npcEnemy) then
				if not utils.IsTargetMagicImmune( bot ) then
					return BOT_ACTION_DESIRE_MODERATE, bot
				end
			end
		end
	end
	
	-- If we're farming
	if modeName == "laning" or modeName == "jungling" then
        local creeps = gHeroVar.GetNearbyEnemyCreep( bot, 900 )
		if #creeps >= 2 and HealthPerc < 0.5 then
			if ManaPerc > 0.4 then
                if not utils.IsTargetMagicImmune( bot ) then
                    return BOT_ACTION_DESIRE_LOW, bot
                end
			end	
		end
	end

    return BOT_ACTION_DESIRE_NONE, nil
end

function ConsiderR()
    local bot = GetBot()
    
    if not abilityR:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end

    local CastRange = abilityR:GetCastRange()
    local Duration = abilityR:GetSpecialValueFloat("duration")
    if bot:HasScepter() then
        Duration = abilityR:GetSpecialValueFloat("duration_scepter")
    end
    
	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
    
	--try to kill enemy hero
    local WeakestEnemy, HeroHealth = utils.GetWeakestHero(bot, CastRange+300)
    
    local allies = gHeroVar.GetNearbyAllies(bot, 1200)
    local enemies = gHeroVar.GetNearbyEnemies(bot, 1200)
    
	if modeName ~= "retreat" then
		if utils.ValidTarget(WeakestEnemy) then
			if not WeakestEnemy:IsInvulnerable() then
                local extraDmg = 0.0
                if utils.IsItemAvailable("item_blade_mail") then
                    extraDmg = WeakestEnemy:GetEstimatedDamageToTarget(true, bot, Min(4.5, Duration), DAMAGE_TYPE_PHYSICAL)
                    extraDmg = WeakestEnemy:GetActualIncomingDamage(extraDmg, DAMAGE_TYPE_PHYSICAL)
                end
                
				if HeroHealth <= (bot:GetEstimatedDamageToTarget(true, WeakestEnemy, Duration, DAMAGE_TYPE_PHYSICAL) + extraDmg) and 
                    #allies >= #enemies then
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy
				end
			end
		end
	end
	
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	-- If we're going after someone
	if modeName == "roam" or modeName == "defendally" or modeName == "fight" then
		local npcEnemy = getHeroVar("RoamTarget")
        if npcEnemy == nil then npcEnemy = getHeroVar("Target") end

		if utils.ValidTarget(npcEnemy) then
            local extraDmg = 0.0
            if utils.IsItemAvailable("item_blade_mail") then
                extraDmg = npcEnemy:GetEstimatedDamageToTarget(true, bot, Min(4.5, Duration), DAMAGE_TYPE_PHYSICAL)
                extraDmg = npcEnemy:GetActualIncomingDamage(extraDmg, DAMAGE_TYPE_PHYSICAL)
            end
            
			if not npcEnemy:IsInvulnerable() and GetUnitToUnitDistance(bot, npcEnemy) < CastRange then
                if HeroHealth <= (bot:GetEstimatedDamageToTarget(true, npcEnemy, Duration, DAMAGE_TYPE_PHYSICAL) + extraDmg) and 
                    #allies >= #enemies then
                    return BOT_ACTION_DESIRE_MODERATE, npcEnemy
                end
			end
		end
	end
    
    return BOT_ACTION_DESIRE_NONE, nil
end

function genericAbility:AbilityUsageThink(bot)
    -- Check if we're already using an ability
    if utils.IsBusy(bot) then return true end
    
    -- Check to see if we are CC'ed
    if utils.IsUnableToCast(bot) then return false end

    if abilityQ == "" then abilityQ = bot:GetAbilityByName( "legion_commander_overwhelming_odds" ) end
    if abilityW == "" then abilityW = bot:GetAbilityByName( "legion_commander_press_the_attack" ) end
    if abilityE == "" then abilityE = bot:GetAbilityByName( "legion_commander_moment_of_courage" ) end
    if abilityR == "" then abilityR = bot:GetAbilityByName( "legion_commander_duel" ) end
    
    -- WRITE CODE HERE --
    AttackRange   = bot:GetAttackRange()
	ManaPerc      = bot:GetMana()/bot:GetMaxMana()
	HealthPerc    = bot:GetHealth()/bot:GetMaxHealth()
    modeName      = bot.SelfRef:getCurrentMode():GetName()
    
    local modeDesire = Max(0.01, bot.SelfRef:getCurrentModeValue())
    
    -- Consider using each ability
	local castQDesire, castQLocation  = ConsiderQ()
	local castWDesire, castWTarget    = ConsiderW()
	local castRDesire, castRTarget    = ConsiderR()
    
    if castQDesire >= modeDesire and castQDesire >= Max(castWDesire, castRDesire) then
        gHeroVar.HeroUseAbilityOnLocation(bot,  abilityQ, castQLocation )
        return true
    end
    
    if castWDesire >= modeDesire and castWDesire >= castRDesire then
        gHeroVar.HeroUseAbilityOnEntity(bot,  abilityW, castWTarget )
        return true
    end
    
    if castRDesire >= modeDesire then
        if utils.IsItemAvailable("item_blade_mail") then
            gHeroVar.HeroPushUseAbilityOnEntity(bot, abilityR, castRTarget )
            item_usage.UseBladeMail(constants.PUSH)
        else
            gHeroVar.HeroUseAbilityOnEntity(bot, abilityR, castRTarget )
        end
        return true
    end
    
    return false
end

function genericAbility:nukeDamage( bot, enemy )
    if not utils.ValidTarget(enemy) then return 0, {}, 0, 0, 0 end

    local comboQueue = {}
    local manaAvailable = bot:GetMana()
    local dmgTotal = bot:GetOffensivePower()
    local castTime = 0
    local stunTime = 0
    local slowTime = 0
    local engageDist = 500
    
    -- WRITE CODE HERE --
    
    return dmgTotal, comboQueue, castTime, stunTime, slowTime, engageDist
end

function genericAbility:queueNuke(bot, enemy, castQueue, engageDist)
    if not utils.ValidTarget(enemy) then return false end
    
    -- WRITE CODE HERE --
    
    return false
end

return genericAbility
