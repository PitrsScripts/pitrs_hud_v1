local configCode = LoadResourceFile(GetCurrentResourceName(), 'config.lua')
if configCode then
    load(configCode)()
end

local micModes = {"whisper", "normal", "shouting"}
local currentMicModeIndex = 2

local speedMultiplier = 3.6
local speedUnit = "KM/H"
if Config and Config.SpeedUnit == "mph" then
    speedMultiplier = 2.236936
    speedUnit = "MPH"
end

local cachedHealth = 100
local cachedArmor = 0
local cachedHunger = 100
local cachedThirst = 100
local cachedStamina = 100
local cachedOxygen = 100
local cachedIsUnderwater = false
local cachedStreetName = ""
local cachedZoneName = ""
local cachedDirection = ""
local cachedCompass = ""
local cachedIsMicActive = false
local cachedMicMode = "normal"
local cachedIsInVehicle = false
local cachedIsPauseMenuActive = false

-- Car HUD variables
local cachedSpeed = 0
local cachedGear = "N"
local cachedFuel = 0
local cachedEngine = 100
local cachedCruiseSpeed = 0
local cachedLimiterSpeed = 0
local cruiseControlActive = false
local cruiseControlSpeed = 0
local speedLimiterActive = false
local speedLimiterSpeed = 0
local lastCruiseActivate = 0
local lastVehicleHealth = {}
local hudVisible = true
local currentVehicle = nil

local prevHealth = 100
local prevArmor = 0
local prevHunger = 100
local prevThirst = 100
local prevStamina = 100
local prevOxygen = 100
local prevIsUnderwater = false
local prevIsMicActive = false
local prevMicMode = "normal"
local prevIsInVehicle = false
local prevStreetName = ""
local prevZoneName = ""
local prevDirection = ""
local prevCompass = ""
local prevIsPauseMenuActive = false

local lastArmorUpdate = 0
local lastArmorValue = 0
local updateInterval = 1000
local isCharacterChosen = false 
local hudScale = 1.0


-- ====== MINIMAP ======
function LoadRectMinimap()
    local defaultAspectRatio = 1920/1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX/resolutionY
    local minimapOffset = 0
    if aspectRatio > defaultAspectRatio then
        minimapOffset = ((defaultAspectRatio-aspectRatio)/3.6)-0.008
    end
    RequestStreamedTextureDict("squaremap", false)
    while not HasStreamedTextureDictLoaded("squaremap") do
        Wait(150)
    end

    SetMinimapClipType(0)
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
    AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "squaremap", "radarmasksm")
    
    SetMinimapComponentPosition("minimap", "L", "B", -0.015 + minimapOffset, -0.025, 0.1638, 0.183)
    SetMinimapComponentPosition("minimap_mask", "L", "B", -0.015 + minimapOffset, 0.015, 0.128, 0.20)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.02 + minimapOffset, 0.04, 0.262, 0.300)

    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetRadarBigmapEnabled(true, false)
    SetMinimapClipType(0)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
end

Citizen.CreateThread(function()
    Wait(2000)
    LoadRectMinimap()
end)

CreateThread(function()
    while true do
        Wait(300)
        local playerPed = PlayerPedId()
        DisplayRadar(IsPedInAnyVehicle(playerPed) and hudVisible)
    end
end)

-- ========== DISPLAY HUD AFTER CHARACTER SELECTION==========

RegisterNetEvent('esx:playerLoaded') 
AddEventHandler('esx:playerLoaded', function()
    isCharacterChosen = true
    Wait(1000)
    SendNUIMessage({type = "toggleHUDIcons", visible = true}) 
end)

RegisterNetEvent('esx_multicharacter:characterChosen')
AddEventHandler('esx_multicharacter:characterChosen', function()
    isCharacterChosen = true
    Wait(1000)
    LoadRectMinimap()
    SendNUIMessage({type = "toggleHUDIcons", visible = true})
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    Wait(2000)
    LoadRectMinimap()
    TriggerServerEvent('hud:server:LoadArmor')
    SendNUIMessage({type = "toggleHUDIcons", visible = false}) 
end)

-- ====== ARMOR SAVE DATABASE  ======
AddEventHandler('playerSpawned', function()
    Wait(1000)
    TriggerServerEvent('hud:server:LoadArmor')
    LoadRectMinimap()
end)

CreateThread(function()
    while true do
        local currentTime = GetGameTimer()
        if currentTime - lastArmorUpdate >= updateInterval then
            local playerPed = PlayerPedId()
            local currentArmor = GetPedArmour(playerPed)
            if currentArmor ~= lastArmorValue then
                TriggerServerEvent('hud:server:UpdateArmor', currentArmor)
                lastArmorValue = currentArmor
            end
            lastArmorUpdate = currentTime
        end
        Wait(500) 
    end
end)

RegisterNetEvent('hud:client:ArmorUpdated')
AddEventHandler('hud:client:ArmorUpdated', function(newArmor) end)

RegisterNetEvent('hud:client:UpdateArmor')
AddEventHandler('hud:client:UpdateArmor', function(armorValue)
    local playerPed = PlayerPedId()
    SetPedArmour(playerPed, armorValue)
    cachedArmor = armorValue
end)

-- ====== GET DIRECTION ======
local function getDirection()
    local angle = GetEntityHeading(PlayerPedId())
    local direction = ''

    if angle >= 0 and angle < 22.5 then
        direction = 'North'
    elseif angle >= 22.5 and angle < 67.5 then
        direction = 'Northeast'
    elseif angle >= 67.5 and angle < 112.5 then
        direction = 'East'
    elseif angle >= 112.5 and angle < 157.5 then
        direction = 'Southeast'
    elseif angle >= 157.5 and angle < 202.5 then
        direction = 'South'
    elseif angle >= 202.5 and angle < 247.5 then
        direction = 'Southwest'
    elseif angle >= 247.5 and angle < 292.5 then
        direction = 'West'
    elseif angle >= 292.5 and angle < 337.5 then
        direction = 'Northwest'
    else
        direction = 'North'
    end

    return direction
end

-- ====== COMPASS  ======
local function getCompassDirection()
    local angle = GetEntityHeading(PlayerPedId())
    local compass = ''

    if angle >= 315 or angle < 45 then
        compass = 'N'
    elseif angle >= 45 and angle < 135 then
        compass = 'E'
    elseif angle >= 135 and angle < 225 then
        compass = 'S'
    elseif angle >= 225 and angle < 315 then
        compass = 'W'
    end

    return compass
end

-- ====== SEPARATE THREADS FOR CACHING ======

-- Hunger/Thirst update every 3 seconds
CreateThread(function()
    while true do
        if isCharacterChosen then
            TriggerEvent('esx_status:getStatus', 'hunger', function(status)
                cachedHunger = math.floor((status.val / 1000000) * 100)
            end)
            TriggerEvent('esx_status:getStatus', 'thirst', function(status)
                cachedThirst = math.floor((status.val / 1000000) * 100)
            end)
        end
        Wait(3000)
    end
end)

-- Health/Armor/Stamina update every 600ms
local wasHoldingShiftWhileStill = false
local safeStamina = 100
CreateThread(function()
    while true do
        if isCharacterChosen then
            local playerPed = PlayerPedId()
            local playerId = PlayerId()
            cachedHealth = GetEntityHealth(playerPed) - 100
            cachedArmor = GetPedArmour(playerPed)

            -- STAMINA LOGIKA
            local isShiftHeld = IsControlPressed(0, 21)
            local speed = GetEntitySpeed(playerPed)
            local isSprinting = isShiftHeld and speed > 1.5
            local isStandingStill = isShiftHeld and speed < 0.1
            local currentStamina = GetPlayerStamina(playerId)

            if isSprinting then
                wasHoldingShiftWhileStill = false
                safeStamina = currentStamina - 1.0
                safeStamina = math.max(0, safeStamina)
                SetPlayerStamina(playerId, safeStamina)
            elseif isStandingStill then
                if not wasHoldingShiftWhileStill then
                    safeStamina = currentStamina
                    wasHoldingShiftWhileStill = true
                end
                SetPlayerStamina(playerId, safeStamina)
            else
                wasHoldingShiftWhileStill = false
                safeStamina = currentStamina
            end

            cachedStamina = math.floor(safeStamina)
            SetPlayerMaxStamina(playerId, 100.0)
        end
        Wait(100) -- More frequent for stamina
    end
end)

-- Underwater check every 300ms
CreateThread(function()
    while true do
        if isCharacterChosen then
            local playerPed = PlayerPedId()
            local isInVehicle = IsPedInAnyVehicle(playerPed, false)
            if not isInVehicle then
                local playerCoords = GetEntityCoords(playerPed)
                local waterLevel = GetWaterHeight(playerCoords.x, playerCoords.y, playerCoords.z)
                cachedIsUnderwater = waterLevel and playerCoords.z < (waterLevel - 2.0)
            else
                cachedIsUnderwater = false
            end
        end
        Wait(300)
    end
end)

-- Oxygen update based on underwater
CreateThread(function()
    while true do
        if isCharacterChosen then
            if cachedIsUnderwater then
                if cachedOxygen > 0 then
                    cachedOxygen = math.max(0, cachedOxygen - 1.0)
                end
            else
                if cachedOxygen < 100 then
                    cachedOxygen = math.min(100, cachedOxygen + 0.6)
                end
            end
        end
        Wait(1000) -- Update oxygen every second
    end
end)

-- Location update every 500ms
CreateThread(function()
    while true do
        if isCharacterChosen then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local streetHash = GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
            local streetName = GetStreetNameFromHashKey(streetHash)
            if streetName then
                streetName = string.gsub(streetName, "<[^>]*>", "")
                cachedStreetName = streetName
            end
            local zoneHash = GetNameOfZone(playerCoords.x, playerCoords.y, playerCoords.z)
            local zoneName = GetLabelText(zoneHash)
            if zoneName then
                zoneName = string.gsub(zoneName, "<[^>]*>", "")
            end
            if zoneName == "NULL" or zoneName == "" then
                zoneName = "Neznámá oblast"
            end
            cachedZoneName = zoneName
            cachedDirection = getDirection()
            cachedCompass = getCompassDirection()
        end
        Wait(500)
    end
end)

-- Mic and vehicle status update
CreateThread(function()
    while true do
        if isCharacterChosen then
            cachedIsMicActive = NetworkIsPlayerTalking(PlayerId())
            cachedMicMode = micModes[currentMicModeIndex]
            cachedIsInVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
            cachedIsPauseMenuActive = IsPauseMenuActive()
            DisplayRadar(cachedIsInVehicle and hudVisible)

            -- Car HUD update
            if cachedIsInVehicle then
                local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    local speed = GetEntitySpeed(vehicle) * 3.6
                    cachedSpeed = math.floor(speed + 0.5)
                    
                    local gear = GetVehicleCurrentGear(vehicle)
                    cachedGear = gear == 0 and "R" or tostring(gear)
                    
                    local success, petrolTank = pcall(function() return GetVehiclePetrolTankVolume(vehicle) end)
                    local isElectric = success and petrolTank == 0.0
                    
                    local successFuel, fuelLevel = pcall(function() return GetVehicleFuelLevel(vehicle) end)
                    cachedFuel = successFuel and math.floor(fuelLevel) or 0
                    
                    local rawEngine = GetVehicleEngineHealth(vehicle)
                    cachedEngine = math.max(0, math.min(100, math.floor(rawEngine / 10)))
                    
                    if cruiseControlActive then
                        cachedCruiseSpeed = math.floor(cruiseControlSpeed * 3.6 + 0.5)
                    else
                        cachedCruiseSpeed = 0
                    end
                    
                    if speedLimiterActive then
                        cachedLimiterSpeed = math.floor(speedLimiterSpeed * 3.6 + 0.5)
                    else
                        cachedLimiterSpeed = 0
                    end
                    
                    -- Send car data
                    SendNUIMessage({
                        type = "updateVehicleData",
                        speed = cachedSpeed,
                        fuel = cachedFuel,
                        gear = cachedGear,
                        engine = cachedEngine,
                        cruiseSpeed = cachedCruiseSpeed,
                        limiterSpeed = cachedLimiterSpeed,
                        cruiseActive = cruiseControlActive,
                        limiterActive = speedLimiterActive,
                        isElectric = isElectric
                    })
                    
                    if Config.EnableCarHUD and hudVisible then
                        SendNUIMessage({
                            type = "showHUD"
                        })
                    end
                    
                    -- Cruise control logic
                    if cruiseControlActive then
                        local shouldTurnOff = GetControlNormal(0, 72) > 0 or GetControlNormal(0, 76) > 0 or HasEntityCollidedWithAnything(vehicle)
                        if GetGameTimer() - lastCruiseActivate > 1000 then
                            shouldTurnOff = shouldTurnOff or GetControlNormal(0, 71) > 0
                        end
                        if shouldTurnOff then
                            cruiseControlActive = false
                        else
                            local currentSpeed = GetEntitySpeed(vehicle)
                            if currentSpeed < cruiseControlSpeed - 5 then
                                cruiseControlActive = false
                            elseif currentSpeed < cruiseControlSpeed - 0.5 then
                                SetVehicleForwardSpeed(vehicle, cruiseControlSpeed)
                            end
                        end
                    end
                    
                    -- Speed limiter logic
                    if speedLimiterActive then
                        SetVehicleMaxSpeed(vehicle, speedLimiterSpeed)
                    else
                        SetVehicleMaxSpeed(vehicle, 999.0)
                    end
                    
                    -- Engine health logic
                    if cachedEngine <= 0 then
                        SetVehicleEngineOn(vehicle, false, true, true)
                        SetVehicleUndriveable(vehicle, true)
                    else
                        local engineMultiplier = cachedEngine / 100.0
                        SetVehicleEnginePowerMultiplier(vehicle, engineMultiplier)
                        SetVehicleEngineTorqueMultiplier(vehicle, engineMultiplier)
                    end
                end
            else
                cachedSpeed = 0
                cachedFuel = 0
                cachedGear = "N"
                cachedEngine = 100
                cachedCruiseSpeed = 0
                cachedLimiterSpeed = 0
                cruiseControlActive = false
                speedLimiterActive = false
                SendNUIMessage({
                    type = "hideHUD"
                })
            end
        end
        Wait(200)
    end
end)

-- Vehicle damage thread
CreateThread(function()
    while true do
        if isCharacterChosen and cachedIsInVehicle then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle and vehicle ~= 0 then
                Wait(1000)
                local vehId = vehicle
                if DoesEntityExist(vehId) then
                    local bodyHealth = GetVehicleBodyHealth(vehId)
                    if not lastVehicleHealth[vehId] then
                        lastVehicleHealth[vehId] = bodyHealth
                    end
                    local lastHealth = lastVehicleHealth[vehId]
                    if lastHealth then
                        local healthDiff = lastHealth - bodyHealth
                        if healthDiff > 1 then
                            local currentEngine = GetVehicleEngineHealth(vehId)
                            local newEngine = math.max(0, currentEngine - (healthDiff * 1.5))
                            SetVehicleEngineHealth(vehId, newEngine)
                            lastVehicleHealth[vehId] = bodyHealth
                        end
                    end
                end
            end
        else
            Wait(5000)
        end
    end
end)

-- ====== MAIN LOOP FOR SENDING NUI ======
CreateThread(function()
    while true do
        if isCharacterChosen then
            local healthRounded = math.floor(cachedHealth)
            local armorRounded = math.floor(cachedArmor)
            local staminaRounded = math.floor(cachedStamina)
            local oxygenRounded = math.floor(cachedOxygen)

            if healthRounded ~= prevHealth or
               armorRounded ~= prevArmor or
               cachedHunger ~= prevHunger or
               cachedThirst ~= prevThirst or
               staminaRounded ~= prevStamina or
               oxygenRounded ~= prevOxygen or
               cachedIsUnderwater ~= prevIsUnderwater or
               cachedIsMicActive ~= prevIsMicActive or
               cachedMicMode ~= prevMicMode or
               cachedIsInVehicle ~= prevIsInVehicle or
               cachedStreetName ~= prevStreetName or
               cachedZoneName ~= prevZoneName or
               cachedDirection ~= prevDirection or
               cachedCompass ~= prevCompass or
               cachedIsPauseMenuActive ~= prevIsPauseMenuActive then

                SendNUIMessage({
                    type = "toggleHUDIcons",
                    visible = not cachedIsPauseMenuActive and hudVisible
                })

                SendNUIMessage({
                    type = "updateHUD",
                    health = healthRounded,
                    armor = armorRounded,
                    hunger = cachedHunger,
                    thirst = cachedThirst,
                    stamina = staminaRounded,
                    oxygen = oxygenRounded,
                    isUnderwater = cachedIsUnderwater,
                    isMicActive = cachedIsMicActive,
                    micMode = cachedMicMode,
                    isInVehicle = cachedIsInVehicle,
                    street = cachedStreetName,
                    direction = cachedDirection,
                    compass = cachedCompass,
                    location = cachedZoneName,
                    area = cachedZoneName
                })

                prevHealth = healthRounded
                prevArmor = armorRounded
                prevHunger = cachedHunger
                prevThirst = cachedThirst
                prevStamina = staminaRounded
                prevOxygen = oxygenRounded
                prevIsUnderwater = cachedIsUnderwater
                prevIsMicActive = cachedIsMicActive
                prevMicMode = cachedMicMode
                prevIsInVehicle = cachedIsInVehicle
                prevStreetName = cachedStreetName
                prevZoneName = cachedZoneName
                prevDirection = cachedDirection
                prevCompass = cachedCompass
                prevIsPauseMenuActive = cachedIsPauseMenuActive
            end
        end
        Wait(500)
    end
end)


-- ====== PMA VOICE  ======
local function changeMicMode()
    currentMicModeIndex = currentMicModeIndex + 1
    if currentMicModeIndex > #micModes then
        currentMicModeIndex = 1
    end

    local newMicMode = micModes[currentMicModeIndex]

    if Config.enableVoiceNotifications then
        lib.notify({
            title = 'Změna režimu mikrofonu',
            description = 'Režim mikrofonu byl nastaven na ' .. newMicMode,
            type = 'success'
        })
    end

    SendNUIMessage({
        type = "updateMicMode",
        micMode = newMicMode,
    })
end

RegisterCommand("cruise_control", function()
    if cachedIsInVehicle then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        local speed = GetEntitySpeed(vehicle)
        if speed > 1.0 then
            cruiseControlActive = not cruiseControlActive
            if cruiseControlActive then
                cruiseControlSpeed = speed
                lastCruiseActivate = GetGameTimer()
            end
        end
    end
end)

RegisterCommand("speed_limiter", function()
    if cachedIsInVehicle then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        local speed = GetEntitySpeed(vehicle)
        if speed > 1.0 then
            speedLimiterActive = not speedLimiterActive
            if speedLimiterActive then
                speedLimiterSpeed = speed
            end
        end
    end
end)

if Config.EnableHUDToggle then
    RegisterCommand(Config.HUDToggleCommand, function()
        hudVisible = not hudVisible
        SendNUIMessage({
            type = "toggleHUDIcons",
            visible = not cachedIsPauseMenuActive and hudVisible
        })
        if not hudVisible and cachedIsInVehicle then
            SendNUIMessage({type = "hideHUD"})
        elseif hudVisible and cachedIsInVehicle and Config.EnableCarHUD then
            SendNUIMessage({type = "showHUD"})
        end
        if Config.enableVoiceNotifications then
            -- Notification here if needed
        end
    end, false)
end

RegisterKeyMapping("cruise_control", "Toggle Cruise Control", "keyboard", "N")
RegisterKeyMapping("speed_limiter", "Toggle Speed Limiter", "keyboard", "J")

RegisterCommand('toggleMicMode', function()
    changeMicMode()
end, false)

RegisterKeyMapping('toggleMicMode', 'Toggle Microphone Mode', 'keyboard', 'f11')
