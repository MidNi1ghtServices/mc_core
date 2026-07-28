Framework = {}

CreateThread(function()
    if Config.Framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()

        Framework.GetPlayer = function(src)
            return ESX.GetPlayerFromId(src)
        end

        Framework.GetPlayers = function()
            return ESX.GetExtendedPlayers()
        end

        -- CLIENT notification wrapper
        Framework.ShowNotification = function(msg)
            ESX.ShowNotification(msg)
        end

        Framework.GetMoney = function(xPlayer)
            if Config.GetMoneyMethod then
                return xPlayer.getMoney()
            else
                return xPlayer.getAccount('bank').money
            end
        end

        Framework.RemoveMoney = function(xPlayer, amount)
            if Config.GetMoneyMethod then
                xPlayer.removeMoney(amount)
            else
                xPlayer.removeAccountMoney('bank', amount)
            end
        end

    elseif Config.Framework == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()

        Framework.GetPlayer = function(src)
            return QBCore.Functions.GetPlayer(src)
        end

        Framework.GetPlayers = function()
            return QBCore.Functions.GetPlayers()
        end

        -- CLIENT notification wrapper
        Framework.ShowNotification = function(msg)
            TriggerEvent('QBCore:Notify', msg, 'primary')
        end

        Framework.GetMoney = function(xPlayer)
            return xPlayer.PlayerData.money['bank'] or Config.SalaryFallback
        end

        Framework.RemoveMoney = function(xPlayer, amount)
            xPlayer.Functions.RemoveMoney('bank', amount)
        end
    end
end)

-- SERVER ONLY: mechanic count
function Framework.GetOnlineMechanics()
    local players = Framework.GetPlayers()
    local count = 0

    for _, src in pairs(players) do
        local xPlayer = Framework.GetPlayer(src)
        if xPlayer then
            local jobName = Config.Framework == 'esx'
                and xPlayer.job.name
                or xPlayer.PlayerData.job.name

            if jobName == Config.JobName then
                count = count + 1
            end
        end
    end

    return count
end
