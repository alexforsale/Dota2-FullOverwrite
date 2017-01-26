-------------------------------------------------------------------------------
--- AUTHOR: pbenologa
--- GITHUB REPO: https://github.com/Nostrademous/Dota2-FullOverwrite
-------------------------------------------------------------------------------

require( GetScriptDirectory().."/constants" )
require( GetScriptDirectory().."/item_purchase_drow_ranger" )
require ( GetScriptDirectory().."/ability_usage_drow_ranger" )
require( GetScriptDirectory().."/jungling_generic" )

local utils = require( GetScriptDirectory().."/utility" )
local dt = require( GetScriptDirectory().."/decision_tree" )
local gHeroVar = require( GetScriptDirectory().."/global_hero_data" )

function setHeroVar(var, value)
    local bot = GetBot()
    gHeroVar.SetVar(bot:GetPlayerID(), var, value)
end

function getHeroVar(var)
    local bot = GetBot()
    return gHeroVar.GetVar(bot:GetPlayerID(), var)
end

local SKILL_Q = "drow_ranger_frost_arrows"
local SKILL_W = "drow_ranger_wave_of_silence"
local SKILL_E = "drow_ranger_trueshot"
local SKILL_R = "drow_ranger_marksmanship"

local ABILITY1 = "special_bonus_movement_speed_15"
local ABILITY2 = "special_bonus_all_stats_5"
local ABILITY3 = "special_bonus_hp_175"
local ABILITY4 = "special_bonus_attack_speed_20"
local ABILITY5 = "special_bonus_unique_drow_ranger_1"
local ABILITY6 = "special_bonus_strength_14"
local ABILITY7 = "special_bonus_unique_drow_ranger_2"
local ABILITY8 = "special_bonus_unique_drow_ranger_3"

local DrowRangerAbilityPriority = {
    SKILL_Q,    SKILL_E,    SKILL_W,    SKILL_Q,    SKILL_Q,
    SKILL_R,    SKILL_Q,    SKILL_E,    SKILL_E,    ABILITY1,
    SKILL_W,    SKILL_R,    SKILL_E,    SKILL_W,    ABILITY3,
    SKILL_W,    SKILL_R,    ABILITY5,   ABILITY8
};

local drowRangerActionStack = { [1] = constants.ACTION_NONE }

botDrow = dt:new()

function botDrow:new(o)
    o = o or dt:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

drowRangerBot = botDrow:new{actionStack = drowRangerActionStack, abilityPriority = DrowRangerAbilityPriority}
--drowRangerBot:printInfo()

drowRangerBot.Init = false

function drowRangerBot:DoHeroSpecificInit(bot)
    self:setHeroVar("HasOrbAbility", SKILL_Q)
    self:setHeroVar("OutOfRangeCasting", -1000.0)
end

function drowRangerBot:ConsiderAbilityUse()
    ability_usage_drow_ranger.AbilityUsageThink()
end

function Think()
    local bot = GetBot()

    drowRangerBot:Think(bot)

    -- if we are initialized, do the rest
    if drowRangerBot.Init then
        local timeInMinutes = math.floor(DotaTime() / 60)

        -- we should not jungle if we are mid... we can't give up a free lane to jungle
        if bot:GetLevel() >= 6  and getHeroVar("Role") ~= constants.ROLE_MID then
            if not (utils.HaveItem(bot, "item_dragon_lance")) then
                if drowRangerBot:HasAction(constants.ACTION_JUNGLING) == false then
                    drowRangerBot:AddAction(constants.ACTION_JUNGLING)
                    jungling_generic.OnStart(bot)
                end
            elseif (timeInMinutes > 18 and not utils.HaveItem(bot, "item_maelstrom")) then
                if drowRangerBot:HasAction(constants.ACTION_JUNGLING) == false then
                    drowRangerBot:AddAction(constants.ACTION_JUNGLING)
                    jungling_generic.OnStart(bot)
                end
            else
                drowRangerBot:RemoveAction(constants.ACTION_JUNGLING)
                setHeroVar("ShouldPush", true)
            end
        end

        drowRangerBot:HarassLaneEnemies(bot)
    end
end

-- We over-write DoRetreat behavior for JUNGLER Drow Ranger
function drowRangerBot:DoRetreat(bot, reason)
    -- if we got creep damage and are a JUNGLER do special stuff
    local pushing = getHeroVar("ShouldPush")
    if reason == constants.RETREAT_CREEP and (self:GetAction() ~= constants.ACTION_LANING or pushing) then
        -- if our health is lower than maximum( 15% health, 100 health )
        if bot:GetHealth() < math.max(bot:GetMaxHealth()*0.15, 100) then
            setHeroVar("RetreatReason", constants.RETREAT_FOUNTAIN)
            if ( self:HasAction(constants.ACTION_RETREAT) == false ) then
                self:AddAction(constants.ACTION_RETREAT)
                setHeroVar("IsInLane", false)
            end
        end
        -- if we are retreating - piggyback on retreat logic movement code
        if self:GetAction() == constants.ACTION_RETREAT then
            -- we use '.' instead of ':' and pass 'self' so it is the correct self
            return dt.DoRetreat(self, bot, getHeroVar("RetreatReason"))
        end

        -- we are not retreating, allow decision tree logic to fall through
        -- to the next level
        return false
    -- if we are not a jungler, invoke default DoRetreat behavior
    else
        -- we use '.' instead of ':' and pass 'self' so it is the correct self
        return dt.DoRetreat(self, bot, reason)
    end
end

function drowRangerBot:GetMaxClearableCampLevel(bot)
    if DotaTime() < 30 then
        return constants.CAMP_EASY
    end

    local marksmanship = bot:GetAbilityByName("drow_ranger_marksmanship")

    if utils.HaveItem(bot, "item_dragon_lance") and marksmanship:GetLevel() >= 1 then
        return constants.CAMP_ANCIENT
    elseif utils.HaveItem(bot, "item_power_treads") and marksmanship:GetLevel() == 1 then
        return constants.CAMP_HARD
    end

    return constants.CAMP_MEDIUM
end

-- function drowRangerBot:IsReadyToGank(bot)
    -- local frostArrow = bot:GetAbilityByName("drow_ranger_frost_arrows")

    -- if utils.HaveItem(bot, "item_dragon_lance") and frostArrow:GetLevel >= 4 then
        -- return true
    -- end
    -- return false -- that's all we need
-- end

function drowRangerBot:DoCleanCamp(bot, neutrals)
    local frostArrow = bot:GetAbilityByName("drow_ranger_frost_arrows")

    for i, neutral in ipairs(neutrals) do

        local slowed =  neutral:HasModifier("modifier_drow_ranger_frost_arrows_slow")

        if not (slowed) then
            bot:Action_UseAbilityOnEntity(frostArrow, neutral);
        end

        bot:Action_AttackUnit(neutral, true)
        break
    end
end

function drowRangerBot:HarassLaneEnemies(bot)
    local Enemies = bot:GetNearbyHeroes(bot:GetAttackRange(), true, BOT_MODE_NONE)

    table.sort(Enemies, function(n1, n2) return n1:GetHealth() < n2:GetHealth() end) -- sort by health

    local target = Enemies[#Enemies] -- get highest health enemy
    local frostArrow = bot:GetAbilityByName(SKILL_Q)

    if target ~= nil and GetUnitToUnitDistance(bot, target) < frostArrow:GetCastRange() then
        local slowed =  target:HasModifier("modifier_drow_ranger_frost_arrows_slow")

        if (not slowed) and (not target:IsRooted()) or (not target:IsStunned())
            and bot:GetMana() < math.max(bot:GetMaxMana()*0.40, 180) then
            bot:Action_UseAbilityOnEntity(frostArrow, target);
        end

        bot:Action_AttackUnit(target, false)

        --utils.AllChat("Get out of my lane "..utils.GetHeroName(target).."!")
    end
end