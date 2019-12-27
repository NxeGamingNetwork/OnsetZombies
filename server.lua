-- Authors: Bambo, Verideth
-- Date: 26/12/2019

ZOMBIES = {}
ZOMBIES.NPC = {}
ZOMBIES.CALLBACKS = {}
ZOMBIES.CALLBACKS.ZOMBIE_DIE = {}
ZOMBIES.CALLBACKS.ZOMBIE_SPAWN = {}

--[[
    Configurations
]]
ZOMBIES.SPAWNTIMER = {
    ACTIVE = true,
    MIN = 60000, -- ms
    MAX = 120000, -- ms
    CURRENT = 100000 -- ms
}
ZOMBIES.SPEED = {
    MIN = 100,
    MAX = 800
}
ZOMBIES.SPAWNRADIUS = {
    MIN = 1000,
    MAX = 3000
}
ZOMBIES.SPAWNCOUNT = {
    MIN = 1,
    MAX = 4
}
ZOMBIES.HEALTH = {
    MIN = 100,
    MAX = 1000
}
ZOMBIES.DISTANCE_THRESHOLD = 100  -- how close before a punch thrown
ZOMBIES.DAMAGE = {
    MIN = 1,
    MAX = 10
}
ZOMBIES.HIT_DELAY = 2 -- 2 seconds between punches
ZOMBIES.CLOTHESLIST = {
    21,
    22
}

ZOMBIES.PROCESSTIMER = 1000 -- how many MS between position updates
ZOMBIES.PROCESSTIMER_HITS = 200 -- how many MS between hit checks.


--[[
    List of commands for administrators.
]]
AddCommand("zombies_disabletimer", function(ply)
    ZOMBIES.SPAWNTIMER.ACTIVE = false
end)

AddCommand("zombies_enabletimer", function(ply)
    ZOMBIES.SPAWNTIMER.ACTIVE = false
end)

AddCommand("zombies_spawn", function(ply)
    SpawnZombie(ply)
end)

AddCommand("zombies_clear", function(ply)
    for k,npcID in pairs(GetAllNPC()) do
        if GetNPCPropertyValue(npcID, "IS_ZOMBIE") then
            DestroyNPC(npcID)
        end
    end
end)



--[[
    External API
]]
-- force spawn a few zombies
AddFunctionExport("zombies_spawn", function(ply)
    -- todo, check if admin
    SpawnZombie(ply)
end)

-- enable zombies to spawn on a timer tick.
AddFunctionExport("zombies_enabletimer", function(ply)
    ZOMBIES.SPAWNTIMER.ACTIVE = true
end)

-- disables zombies spawning on timer.
AddFunctionExport("zombies_disabletimer", function(ply)
    ZOMBIES.SPAWNTIMER.ACTIVE = false
end)

-- deletes all zombies from server.
AddFunctionExport("zombies_clear", function(ply)
    for k,npcID in pairs(GetAllNPC()) do
        if GetNPCPropertyValue(npcID, "IS_ZOMBIE") then
            DestroyNPC(npcID)
        end
    end
end)

-- takes a function
-- function onZombieDeath(ply, npcid)
AddFunctionExport("zombies_onzombiedeath", function(pFunctionID, pFunction)
    ZOMBIES.CALLBACKS.ZOMBIE_DIE[pFunctionID] = pFunction
end)

-- takes a function
-- function onZombieSpawn(npcid)
AddFunctionExport("zombies_onzombiespawn", function(pFunctionID, pFunction)
    ZOMBIES.CALLBACKS.ZOMBIE_SPAWN[pFunctionID] = pFunction
end)



AddEvent("OnPackageStart", function()
    print("[SV] Zombies initialized...")

    Delay(ZOMBIES.SPAWNTIMER.CURRENT, function()
        SpawnZombies()
    end)

    Delay(ZOMBIES.PROCESSTIMER, function()
        ProcessZombies()
    end)

    Delay(ZOMBIES.PROCESSTIMER_HITS, function()
        ZombieCheckHitPlayers()
    end)
end)

AddEvent("OnPlayerPickupHit", function(player, pickup)
	SetPlayerWeapon(player, pickup, 450, true, 1)
    DestroyPickup(pickup)
end)


function SpawnZombies()
    if ZOMBIES.SPAWNTIMER.ACTIVE then
        -- implement more sophisticated spawning.
        -- for each player in the game
        for k,ply in pairs(GetAllPlayers()) do
            -- spawn N number of zombies close by.
            local zombieCount = math.random(ZOMBIES.SPAWNCOUNT.MIN, ZOMBIES.SPAWNCOUNT.MAX)
            for i=0, zombieCount do
                SpawnZombie(ply)
            end
        end
    end

    ZOMBIES.SPAWNTIMER.CURRENT = math.random(ZOMBIES.SPAWNTIMER.MIN, ZOMBIES.SPAWNTIMER.MAX)
    Delay(ZOMBIES.SPAWNTIMER.CURRENT, function()
        SpawnZombies()
    end)
end

function SpawnZombie(ply)
    local x, y, z = GetPlayerLocation(ply)
    local h = GetPlayerHeading(ply)

    -- implement spawning distance modifies
    local magnitude = math.random(ZOMBIES.SPAWNRADIUS.MIN, ZOMBIES.SPAWNRADIUS.MAX)
    local dirX = math.random(-1000, 1000) / 1000
    local dirY = math.random(-1000, 1000) / 1000

    local positionX = x + (dirX * magnitude)
    local positionY = y + (dirY * magnitude)

    local zombieNPC = CreateNPC(positionX, positionY, z, h)

    local clothesId = ZOMBIES.CLOTHESLIST[math.random(1, #ZOMBIES.CLOTHESLIST)];
    SetNPCPropertyValue(zombieNPC, "CLOTHES_ID", clothesId)

    local hp = math.random(ZOMBIES.HEALTH.MIN, ZOMBIES.HEALTH.MAX)
    SetNPCPropertyValue(zombieNPC, "HEALTH", hp)
    SetNPCPropertyValue(zombieNPC, "IS_ZOMBIE", true, true)
    SetNPCPropertyValue(zombieNPC, "LAST_HIT", GetTimeSeconds())
    local speed = math.random(ZOMBIES.SPEED.MIN, ZOMBIES.SPEED.MAX)
    SetNPCPropertyValue(zombieNPC, "RUN_SPEED", speed)


    for k,v in pairs(ZOMBIES.CALLBACKS.ZOMBIE_SPAWN) do
        v(zombieNPC)
    end

end




function ProcessZombies()
    -- for each zombie
    for k,npcID in pairs(GetAllNPC()) do
        local npcX, npcY, npcZ = GetNPCLocation(npcID)

        if GetNPCPropertyValue(npcID, "IS_ZOMBIE") then

            local closestPlyID = 0
            local closestPlyDist = 0
            local closestPlyFound = false

            -- get the closest player
            for _,plyId in pairs(GetAllPlayers()) do
                local plyX, plyY, plyZ = GetPlayerLocation(plyId)

                local dist = math.sqrt(((plyX - npcX) ^ 2) + ((plyY - npcY) ^ 2) + ((plyZ - npcZ) ^ 2))

                if not closestPlyFound then
                    closestPlyDist = dist
                    closestPlyID = plyId
                    closestPlyFound = true
                else
                    if closestPlyDist > dist then
                        closestPlyDist = dist
                        closestPlyID = plyId
                    end
                end
                
            end
            
            -- update the zombies target
            if closestPlyFound then
                local plyX, plyY, plyZ = GetPlayerLocation(closestPlyID)
                local speed = GetNPCPropertyValue(npcID, "RUN_SPEED")

                SetNPCTargetLocation(npcID, plyX, plyY, plyZ, speed)
            end
        end
    end
    
    Delay(ZOMBIES.PROCESSTIMER, function()
        ProcessZombies()
    end)
end

AddEvent("OnNPCDamage", function(npcId, damageType, amount)
    -- add damage modifiers
    local hp = GetNPCPropertyValue(npcId, "HEALTH")
    SetNPCPropertyValue(npcId, "HEALTH", hp - amount)
    
    local newHp = GetNPCPropertyValue(npcId, "HEALTH")
    if newHp <= 0 then
        ZombieDeath(npcId)
    end
end)


function ZombieDeath(npcId)
    local npcX, npcY, npcZ = GetNPCLocation(npcId)

    -- implement pick rarity
    local chance = math.random(0, 100)
    if (chance > 80) then
        local modelId = math.random(4, 22)
        CreatePickup(modelId, npcX, npcY, npcZ)
    end

    for k,v in pairs(ZOMBIES.CALLBACKS.ZOMBIE_DIE) do
        v(npcId)
    end

    SetNPCRagdoll(npcId, true)

    Delay(10000, function()
        DestroyNPC(npcId)
    end)

end

function ZombieCheckHitPlayers()
    -- for each zombie
    for k,npcID in pairs(GetAllNPC()) do
        local npcX, npcY, npcZ = GetNPCLocation(npcID)

        if GetNPCPropertyValue(npcID, "IS_ZOMBIE") then

            local closestPlyID = 0
            local closestPlyDist = 0
            local closestPlyFound = false

            -- get the closest player
            for _,plyId in pairs(GetAllPlayers()) do
                local plyX, plyY, plyZ = GetPlayerLocation(plyId)

                local dist = math.sqrt(((plyX - npcX) ^ 2) + ((plyY - npcY) ^ 2) + ((plyZ - npcZ) ^ 2))

                if not closestPlyFound then
                    closestPlyDist = dist
                    closestPlyID = plyId
                    closestPlyFound = true
                else
                    if closestPlyDist > dist then
                        closestPlyDist = dist
                        closestPlyID = plyId
                    end
                end
                
            end
            
            -- zombie hurts player
            if closestPlyDist <= ZOMBIES.DISTANCE_THRESHOLD then
                DamagePlayer(npcID, closestPlyID)
            end

        end
    end
    
    Delay(ZOMBIES.PROCESSTIMER_HITS, function()
        ZombieCheckHitPlayers()
    end)
end

function DamagePlayer(npcId, plyId)
    if not IsValidPlayer(plyId) then return end
    
    local timeNow = GetTimeSeconds()
    local lastHit = GetNPCPropertyValue(npcId, "LAST_HIT")

    if (timeNow - lastHit) > ZOMBIES.HIT_DELAY then
        -- implement sound
        SetNPCAnimation(npcId, "THROW", false)

        -- implement damage modifier
        local damage = math.random(ZOMBIES.DAMAGE.MIN,ZOMBIES.DAMAGE.MAX)

        -- implement armor modifier
        local currHp = GetPlayerHealth(plyId)
        SetPlayerHealth(plyId, currHp - damage)

        SetNPCPropertyValue(npcId, "LAST_HIT", GetTimeSeconds())      
    end

end