ESX = exports["es_extended"]:getSharedObject()


CreateThread(function()
    MySQL.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS armor INT DEFAULT 0', {}, function()
    end)
end)


RegisterNetEvent('hud:server:UpdateArmor')
AddEventHandler('hud:server:UpdateArmor', function(newArmor)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        MySQL.update('UPDATE users SET armor = ? WHERE identifier = ?', {
            newArmor,
            xPlayer.identifier
        }, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent('hud:client:ArmorUpdated', src, newArmor)
            end
        end)
    end
end)

RegisterNetEvent('hud:server:LoadArmor')
AddEventHandler('hud:server:LoadArmor', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        MySQL.query('SHOW COLUMNS FROM users LIKE "armor"', {}, function(result)
            print('DEBUG: Column check result: ' .. tostring(result and #result or 'nil'))
            if result and #result > 0 then
                MySQL.single('SELECT armor FROM users WHERE identifier = ?', {
                    xPlayer.identifier
                }, function(armorResult)
                    if armorResult and armorResult.armor then
                        TriggerClientEvent('hud:client:UpdateArmor', src, armorResult.armor)
                    end
                end)
            else
                MySQL.query('ALTER TABLE users ADD COLUMN armor INT DEFAULT 0', {}, function()
                    MySQL.update('UPDATE users SET armor = ? WHERE identifier = ?', {
                        0,
                        xPlayer.identifier
                    }, function(affectedRows)
                        if affectedRows > 0 then
                            TriggerClientEvent('hud:client:UpdateArmor', src, 0)
                        end
                    end)
                end)
            end
        end)
    else
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        local armor = GetPedArmour(GetPlayerPed(src))
        MySQL.update('UPDATE users SET armor = ? WHERE identifier = ?', {
            armor,
            xPlayer.identifier
        }, function(affectedRows)
            if affectedRows > 0 then
            end
        end)
    end
end)



print('===========================================================')
print('===========================================================')
print('Script: PITRS_HUD')
print('Version: 1.0.0')
print('Author: Pitrs')
print('Description: Custom ESX HUD')
print('===========================================================')
print('Checking dependencies...')
if GetResourceState('ox_lib') == 'started' then
    print('✓ ox_lib loaded')
else
    print('✗ ox_lib not loaded')
end
if GetResourceState('oxmysql') == 'started' then
    print('✓ oxmysql loaded')
else
    print('✗ oxmysql not loaded')
end
if GetResourceState('es_extended') == 'started' then
    print('✓ es_extended loaded')
else
    print('✗ es_extended not loaded')
end
if GetResourceState('esx_status') == 'started' then
    print('✓ esx_status loaded')
else
    print('✗ esx_status not loaded')
end
if GetResourceState('esx_basicneeds') == 'started' then
    print('✓ esx_basicneeds loaded')
else
    print('✗ esx_basicneeds not loaded')
end
print('Script successfully started!')
print('===========================================================')