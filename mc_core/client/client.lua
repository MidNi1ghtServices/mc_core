-- ============================================================
--  MC CORE - COMBINED CLIENT.LUA
-- ============================================================

-- ============================================================
-- GLOBAL: Zentrales Notify-System (konfigurierbar über NotifyConfig)
-- ============================================================
-- Wird von ALLEN Modulen außer Sperrzone genutzt (kleine Toast-Notification).
-- Sperrzone nutzt bewusst weiterhin hex_future_hud:announce (großes Banner).
--
-- In deiner config.lua einstellbar, z.B.:
--
-- NotifyConfig = {
--     system = "auto",  -- "auto" | "hex_future_hud" | "ox_lib" | "esx" | "qbcore" | "custom"
--     customEvent = "mc_core:notify", -- nur bei system = "custom"
--     defaultDuration = 5000
-- }
--
function MC_Notify(title, msg, ntype, duration)
    ntype = ntype or "info"
    duration = duration or (NotifyConfig and NotifyConfig.defaultDuration) or 5000
    local system = (NotifyConfig and NotifyConfig.system) or "auto"

    local function tryHexHud()
        if GetResourceState('hex_future_hud') == 'started' then
            TriggerEvent('hex_future_hud:notify', title, msg, ntype, duration)
            return true
        end
        return false
    end

    local function tryOxLib()
        if GetResourceState('ox_lib') == 'started' then
            exports.ox_lib:notify({ title = title, description = msg, type = ntype, duration = duration })
            return true
        end
        return false
    end

    local function tryEsx()
        if GetResourceState('es_extended') == 'started' then
            local ESX = exports["es_extended"]:getSharedObject()
            ESX.ShowNotification(("%s: %s"):format(title, msg))
            return true
        end
        return false
    end

    local function tryQbCore()
        if GetResourceState('qb-core') == 'started' then
            local QBCore = exports['qb-core']:GetCoreObject()
            QBCore.Functions.Notify(msg, ntype, duration)
            return true
        end
        return false
    end

    local function tryCustom()
        if NotifyConfig and NotifyConfig.customEvent then
            TriggerEvent(NotifyConfig.customEvent, title, msg, ntype, duration)
            return true
        end
        return false
    end

    local function fallback()
        SetTextComponentFormat("STRING")
        AddTextComponentString(("%s: %s"):format(title, msg))
        DisplayHelpTextFromStringLabel(0, false, true, -1)
    end

    -- Fest eingestelltes System (überspringt Auto-Detect)
    if system == "hex_future_hud" then if tryHexHud() then return end
    elseif system == "ox_lib" then if tryOxLib() then return end
    elseif system == "esx" then if tryEsx() then return end
    elseif system == "qbcore" then if tryQbCore() then return end
    elseif system == "custom" then if tryCustom() then return end
    end

    -- Auto-Detect (system == "auto" oder obiges Fixed-System nicht verfügbar)
    if tryCustom() then return end
    if tryHexHud() then return end
    if tryOxLib() then return end
    if tryEsx() then return end
    if tryQbCore() then return end

    fallback()
end

-- Hilfsfunktion speziell für "Help"-Notifies (3D/HUD Hinweis à la "Drücke E")
function MC_NotifyHelp(msg)
    if NotifyConfig and NotifyConfig.customHelpEvent then
        TriggerEvent(NotifyConfig.customHelpEvent, msg)
        return
    end

    if GetResourceState('hex_future_hud') == 'started' then
        TriggerEvent('hex_future_hud:notify', msg)
        return
    end

    SetTextComponentFormat("STRING")
    AddTextComponentString(msg)
    DisplayHelpTextFromStringLabel(0, false, true, -1)
end


-- ============================================================
-- SECTION: antiafk.lua (CLIENT)
-- ============================================================
do
    local lastActivity = GetGameTimer()
    local lastPos = nil
    local warned = false

    local function updateActivity()
        lastActivity = GetGameTimer()
        warned = false
        TriggerServerEvent('mc_core:updateActivity')
    end

    -- CamRotThreshold: ab wie viel Grad Blickrichtungsänderung pro Check als "aktiv" zählt.
    -- (ersetzt den alten, kaputten Raycast-Check, der fast immer "true" ergeben hat,
    --  weil ein Raycast von der Kamera aus so gut wie immer innerhalb von 5m etwas trifft
    --  -> Spieler galt dadurch praktisch NIE als AFK)
    local lastCamRot = nil
    Config.AntiAFK.CamRotThreshold = Config.AntiAFK.CamRotThreshold or 1.5

    local function playerMoved()
        local cfg = Config.AntiAFK
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        if lastPos == nil then
            lastPos = pos
            lastCamRot = GetGameplayCamRot()
            return true
        end

        local dist = #(pos - lastPos)
        if dist > cfg.MoveThreshold then
            lastPos = pos
            lastCamRot = GetGameplayCamRot()
            return true
        end

        local vel = GetEntityVelocity(ped)
        if #(vel) > cfg.VelocityThreshold then
            lastPos = pos
            lastCamRot = GetGameplayCamRot()
            return true
        end

        local camRot = GetGameplayCamRot()
        if lastCamRot ~= nil then
            local rotDelta = #(camRot - lastCamRot) -- Delta der Kamera-Rotation in Grad
            if rotDelta > cfg.CamRotThreshold then
                lastCamRot = camRot
                lastPos = pos
                return true
            end
        end
        lastCamRot = camRot

        return false
    end

    CreateThread(function()
        while true do
            local cfg = Config.AntiAFK
            Wait(cfg.CheckIntervalMs)

            if not cfg.Enabled then
                goto continue
            end

            if playerMoved() then
                updateActivity()
                goto continue
            end

            local elapsedMs = GetGameTimer() - lastActivity
            local elapsedMin = elapsedMs / 60000.0
            local remainingSec = math.floor((cfg.KickAfterMinutes * 60) - (elapsedMs / 1000))

            if cfg.WarnBeforeKick and (not warned) and remainingSec <= cfg.WarnSecondsBefore and remainingSec > 0 then
                warned = true
                BeginTextCommandThefeedPost("STRING")
                AddTextComponentSubstringPlayerName(string.format(cfg.WarnMessage, remainingSec))
                EndTextCommandThefeedPostTicker(true, true)
            end

            if elapsedMin >= cfg.KickAfterMinutes then
                TriggerServerEvent('mc_core:afkKickCheck')
            end

            ::continue::
        end
    end)

    -- Debug: /afkstatus zeigt dir Restzeit bis zum Kick in der Konsole (F8)
    RegisterCommand('afkstatus', function()
        local elapsedMs = GetGameTimer() - lastActivity
        local remainingSec = math.floor((Config.AntiAFK.KickAfterMinutes * 60) - (elapsedMs / 1000))
        print(string.format("[AntiAFK] Letzte Aktivität vor %.1f Sekunden. Restzeit bis Kick: %d Sekunden.", elapsedMs / 1000, remainingSec))
    end, false)
end


-- ============================================================
-- SECTION: crafter.lua
-- ============================================================
do
    local ESX = exports["es_extended"]:getSharedObject()

    local CraftBlips = {}
    local craftBlipsVisible = GetResourceKvpString("crafter_blips_visible") ~= "0"

    function SetCraftBlipsVisible(state)
        craftBlipsVisible = state

        for _, blip in pairs(CraftBlips) do
            SetBlipDisplay(blip, state and 2 or 0)
        end

        SetResourceKvp("crafter_blips_visible", state and "1" or "0")
    end

    CreateThread(function()
        if not Config.CraftZones then return end

        for _, blip in pairs(CraftBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        CraftBlips = {}

        for _, zone in pairs(Config.CraftZones) do
            if zone.blip and zone.blip.enabled ~= false then

                local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)

                SetBlipSprite(blip, zone.blip.sprite or 566)
                SetBlipColour(blip, zone.blip.color or 46)
                SetBlipScale(blip, zone.blip.scale or 0.8)
                SetBlipAsShortRange(blip, true)

                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(zone.label or "Crafter")
                EndTextCommandSetBlipName(blip)

                CraftBlips[#CraftBlips + 1] = blip
            end
        end

        SetCraftBlipsVisible(craftBlipsVisible)
    end)

    RegisterCommand("craftblips", function()
        SetCraftBlipsVisible(not craftBlipsVisible)
        MC_Notify("Crafter", craftBlipsVisible and "Crafter-Blips aktiviert" or "Crafter-Blips deaktiviert", craftBlipsVisible and "success" or "error")
    end)

    CreateThread(function()
        if not Config.UseOxTarget then return end

        for _, zone in pairs(Config.CraftZones) do
            exports.ox_target:addSphereZone({
                coords = zone.coords,
                radius = zone.radius or 2.0,
                debug = false,
                options = {
                    {
                        name = "crafter_" .. zone.name,
                        icon = "fa-solid fa-hammer",
                        label = zone.label,
                        onSelect = function()
                            SendNUIMessage({
                                action = "openCrafter",
                                zone = zone.name,
                                crafts = zone.crafts
                            })
                            SetNuiFocus(true, true)
                            TriggerServerEvent("mc_core:requestCraftQueue")
                        end
                    }
                }
            })
        end
    end)

    CreateThread(function()
        while true do
            local sleep = 1000

            if not Config.UseOxTarget then
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)

                for _, zone in pairs(Config.CraftZones) do
                    local dist = #(pos - zone.coords)

                    if dist < 20.0 then
                        sleep = 0

                        if zone.marker and zone.marker.enabled then
                            DrawMarker(
                                zone.marker.type or 1,
                                zone.coords.x,
                                zone.coords.y,
                                zone.coords.z + (zone.marker.z_offset or -1.0),
                                0.0,0.0,0.0,
                                0.0,0.0,0.0,
                                zone.marker.size.x or 1.5,
                                zone.marker.size.y or 1.5,
                                zone.marker.size.z or 0.5,
                                zone.marker.color.r or zone.marker.r or 255,
                                zone.marker.color.g or zone.marker.g or 255,
                                zone.marker.color.b or zone.marker.b or 0,
                                zone.marker.color.a or zone.marker.alpha or 150,
                                false,true,2,false
                            )
                        end

                        if dist < (zone.radius or 2.0) then
                            MC_NotifyHelp("Drücke ~INPUT_CONTEXT~, um den Crafter zu öffnen.")

                            if IsControlJustPressed(0, 38) then
                                SendNUIMessage({
                                    action = "openCrafter",
                                    zone = zone.name,
                                    crafts = zone.crafts
                                })
                                SetNuiFocus(true, true)
                                TriggerServerEvent("mc_core:requestCraftQueue")
                            end
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)

    RegisterNUICallback("craft", function(data, cb)
        TriggerServerEvent("mc_core:craftItem", data)
        cb("ok")
    end)

    RegisterNUICallback("closeCrafter", function(_, cb)
        SetNuiFocus(false, false)
        cb("ok")
    end)

    RegisterNUICallback("collectCraft", function(data, cb)
        TriggerServerEvent("mc_core:collectCraftItem", data.id)
        cb("ok")
    end)

    RegisterNetEvent("mc_core:craftQueueUpdate")
    AddEventHandler("mc_core:craftQueueUpdate", function(queue)
        SendNUIMessage({
            action = "updateQueue",
            queue = queue
        })
    end)
end


-- ============================================================
-- SECTION: discord.lua
-- ============================================================
do
    CreateThread(function()
        while true do
            SetDiscordAppId(Config.DiscordAppId)

            SetDiscordRichPresenceAsset(Config.DiscordLogo)
            SetDiscordRichPresenceAssetText(Config.DiscordLogoText)

            SetDiscordRichPresenceAssetSmall(Config.DiscordSmallLogo)
            SetDiscordRichPresenceAssetSmallText(Config.DiscordSmallLogoText)

            SetRichPresence(Config.DiscordStatusFormat:format(
                #GetActivePlayers(),
                GetPlayerServerId(PlayerId())
            ))

            SetDiscordRichPresenceAction(0, Config.DiscordButton1Label, Config.DiscordButton1Url)
            SetDiscordRichPresenceAction(1, Config.DiscordButton2Label, Config.DiscordButton2Url)

            Wait(Config.DiscordUpdateInterval)
        end
    end)
end


-- ============================================================
-- SECTION: elevator.lua
-- ============================================================
do
    local function CoreOpenMenu(title, options)
        if TriggerEvent("mc_core:menu:open", title, options) then return end
        if TriggerEvent("hex_hud:menu:open", title, options) then return end

        print("Kein Menüsystem gefunden – Fallback aktiv")
        for i,v in ipairs(options) do
            print(i .. ": " .. v.title)
        end
    end

    local function FadeTeleport(coords)
        DoScreenFadeOut(500)
        Wait(600)
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
        Wait(500)
        DoScreenFadeIn(500)
    end

    local function OpenElevatorMenu(elevator)
        local opts = {}

        for _, floor in ipairs(elevator.floors) do
            opts[#opts+1] = {
                title = floor.label,
                action = function()
                    MC_Notify("Fahrstuhl", "Fahre zu: "..floor.label, "info", 3000)
                    FadeTeleport(floor.coords)
                end
            }
        end

        CoreOpenMenu(elevator.name, opts)
    end

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for _, elevator in ipairs(ElevatorConfig.Elevators) do
                local dist = #(coords - elevator.pos)

                if dist < 10.0 then
                    sleep = 0

                    DrawMarker(1, elevator.pos.x, elevator.pos.y, elevator.pos.z,
                        0,0,0, 0,0,0, 0.25,0.25,0.25, 0,120,255,180, false,true,2,false)

                    if dist < 1.4 then
                        MC_NotifyHelp("Drücke ~INPUT_CONTEXT~ für Fahrstuhl")

                        if IsControlJustPressed(0, ElevatorConfig.Key) then
                            OpenElevatorMenu(elevator)
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)
end


-- ============================================================
-- SECTION: combatlog.lua
-- ============================================================
do
    RegisterNetEvent('mc_core:combatlog:showMarker')
    AddEventHandler('mc_core:combatlog:showMarker', function(coords, text)
        if not Config.CombatLog.Enabled then return end

        CreateThread(function()
            local endTime = GetGameTimer() + Config.CombatLog.MarkerTime
            local mc = Config.CombatLog.MarkerColor
            local tc = Config.CombatLog.TextColor

            while GetGameTimer() < endTime do
                DrawMarker(1, coords.x, coords.y, coords.z + 1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, 1.0,1.0,1.0,
                    mc.r, mc.g, mc.b, 150, false, true, 2, false, nil, nil, false)

                SetDrawOrigin(coords.x, coords.y, coords.z + 1.2, 0)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(text)
                SetTextFont(4)
                SetTextScale(0.35, 0.35)
                SetTextColour(tc.r, tc.g, tc.b, 255)
                SetTextCentre(true)
                EndTextCommandDisplayText(0.0, 0.0)
                ClearDrawOrigin()

                Wait(0)
            end
        end)
    end)
end


-- ============================================================
-- SECTION: event.lua
-- ============================================================
do
    RegisterNetEvent('mc_event:announce')
    AddEventHandler('mc_event:announce', function(title, msg, timeout)
        MC_Notify(title, msg, "info", timeout)
    end)
end


-- ============================================================
-- SECTION: farming.lua
-- ============================================================
do
    local isFarming = false
    local currentFarm = nil
    local farmingThread = nil

    CreateThread(function()
        for name, farm in pairs(Config.Farming) do
            if farm.blip and farm.blip.enabled then
                local blip = AddBlipForCoord(farm.coords.x, farm.coords.y, farm.coords.z)
                SetBlipSprite(blip, farm.blip.id)
                SetBlipColour(blip, farm.blip.color)
                SetBlipScale(blip, farm.blip.scale)
                SetBlipAsShortRange(blip, farm.blip.shortrange)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(farm.blip.name)
                EndTextCommandSetBlipName(blip)
            end
        end
    end)

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for farmName, farm in pairs(Config.Farming) do
                local dist = #(coords - farm.coords)

                if dist <= farm.zonesize then
                    sleep = 0

                    DrawMarker(
                        farm.marker.typ,
                        farm.coords.x, farm.coords.y, farm.coords.z + farm.marker.z_offset,
                        0.0,0.0,0.0,
                        0.0,0.0,0.0,
                        farm.marker.size.x, farm.marker.size.y, farm.marker.size.z,
                        farm.marker.color.r, farm.marker.color.g, farm.marker.color.b, farm.marker.color.t,
                        farm.marker.move, farm.marker.rotate,
                        2, false, false, false
                    )

                    currentFarm = farmName
                end
            end

            Wait(sleep)
        end
    end)

    function FarmingProgress(seconds)
        local start = GetGameTimer()
        local finish = start + (seconds * 1000)

        while GetGameTimer() < finish do
            Wait(0)

            local now = GetGameTimer()
            local progress = (now - start) / (seconds * 1000)
            if progress < 0 then progress = 0 end
            if progress > 1 then progress = 1 end

            DrawRect(0.50, 0.92, 0.22, 0.030, 10, 10, 14, 180)

            DrawRect(
                0.39 + (progress * 0.11),
                0.92,
                progress * 0.22,
                0.022,
                74, 163, 255, 255
            )

            DrawRect(
                0.39 + (progress * 0.11),
                0.92,
                progress * 0.22,
                0.022,
                74, 163, 255, 120
            )

            SetTextFont(4)
            SetTextScale(0.40, 0.40)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextOutline()

            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("Sammeln...")
            EndTextCommandDisplayText(0.50, 0.885)
        end
    end

    function StartFarming(farmName)
        if isFarming then return end

        local farm = Config.Farming[farmName]
        if not farm then return end

        isFarming = true
        currentFarm = farmName

        MC_Notify("Farming", "Auto-Farming gestartet.", "success")

        farmingThread = CreateThread(function()
            while isFarming do

                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)

                if #(coords - farm.coords) > farm.zonesize then
                    MC_Notify("Farming", "Zone verlassen – Auto-Farming gestoppt.", "error")
                    StopFarming()
                    break
                end

                if farm.animation then
                    RequestAnimDict(farm.animation.animDictionary)
                    while not HasAnimDictLoaded(farm.animation.animDictionary) do
                        Wait(10)
                    end

                    TaskPlayAnim(
                        ped,
                        farm.animation.animDictionary,
                        farm.animation.animationName,
                        8.0, -8.0,
                        farm.time * 1000,
                        1, 0, false, false, false
                    )
                end

                FarmingProgress(farm.time)

                TriggerServerEvent("mc_core:farming:collect", farmName)

                Wait(250)
                ClearPedTasks(ped)
            end
        end)
    end

    function StopFarming()
        isFarming = false
        currentFarm = nil
        ClearPedTasks(PlayerPedId())
    end

    CreateThread(function()
        while true do
            Wait(0)

            if currentFarm then
                MC_NotifyHelp("~INPUT_CONTEXT~ Auto-Farming starten/stoppen")

                if IsControlJustPressed(0, 38) then
                    if not isFarming then
                        StartFarming(currentFarm)
                    else
                        StopFarming()
                        MC_Notify("Farming", "Auto-Farming beendet.", "error")
                    end
                end
            end
        end
    end)

    CreateThread(function()
        while true do
            Wait(0)

            if isFarming and IsControlJustPressed(0, 73) then
                StopFarming()
                MC_Notify("Farming", "Auto-Farming beendet.", "error")
            end
        end
    end)

    local lastPosition = vector3(0.0,0.0,0.0)
    local afkCounter = 0

    CreateThread(function()
        while true do
            Wait(5000)

            if isFarming then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)

                if #(coords - lastPosition) < 0.5 then
                    afkCounter = afkCounter + 1
                else
                    afkCounter = 0
                end

                lastPosition = coords

                if afkCounter >= 12 then
                    StopFarming()
                    MC_Notify("Farming", "Auto-Farming wegen Inaktivität beendet.", "error")
                end
            end
        end
    end)
end


-- ============================================================
-- SECTION: Fraktionssperre.lua
-- ============================================================
do
    RegisterNetEvent(FraksperreConfig.Notify.helpEvent)
    AddEventHandler(FraksperreConfig.Notify.helpEvent, function(message)
        BeginTextCommandDisplayHelp("STRING")
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandDisplayHelp(0, false, true, -1)
    end)

    CreateThread(function()
        local C = FraksperreConfig.Commands

        TriggerEvent('chat:addSuggestion', ('/%s'):format(C.setblock), 'Setzt eine Fraktionssperre für einen Spieler', {
            { name = 'id',      help = 'Server-ID des Spielers' },
            { name = 'stunden', help = 'Dauer der Sperre in Stunden (optional, Standard: FraksperreConfig.Hours)' },
        })

        TriggerEvent('chat:addSuggestion', ('/%s'):format(C.removeblock), 'Entfernt die Fraktionssperre eines Spielers', {
            { name = 'id', help = 'Server-ID des Spielers' },
        })

        TriggerEvent('chat:addSuggestion', ('/%s'):format(C.getblocktime), 'Zeigt die verbleibende Sperrzeit eines Spielers an', {
            { name = 'id', help = 'Server-ID des Spielers' },
        })
    end)
end


-- ============================================================
-- SECTION: givecar.lua
-- ============================================================
do
    RegisterNetEvent("givecar:spawn")
    AddEventHandler("givecar:spawn", function(model, plate)
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local heading = GetEntityHeading(playerPed)
        local ESX = exports["es_extended"]:getSharedObject()

        ESX.Game.SpawnVehicle(model, coords, heading, function(vehicle)
            SetVehicleNumberPlateText(vehicle, plate)
            SetPedIntoVehicle(playerPed, vehicle, -1)

            SetVehicleOnGroundProperly(vehicle)
            SetVehicleHasBeenOwnedByPlayer(vehicle, true)
            SetEntityAsMissionEntity(vehicle, true, true)
        end)
    end)

    RegisterCommand(ConfigGiveCar.Commands.setCar, function(_, args)
        local ESX = exports["es_extended"]:getSharedObject()

        local targetId = tonumber(args[1])

        if not targetId then
            ESX.ShowNotification(ConfigGiveCar.Messages.setCarUsage)
            return
        end

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle == 0 or not DoesEntityExist(vehicle) then
            ESX.ShowNotification(ConfigGiveCar.Messages.noVehicle)
            return
        end

        local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
        local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))

        TriggerServerEvent("mc_core:setcar", targetId, vehicleProps, displayName)
    end, false)
end


-- ============================================================
-- SECTION: klingel.lua
-- ============================================================
do
    local lastPress = 0

    function DrawText3D(x, y, z, text)
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        SetDrawOrigin(x, y, z, 0)
        DrawText(0.0, 0.0)
        ClearDrawOrigin()
    end

    CreateThread(function()
        while true do
            Wait(0)

            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for job, data in pairs(Config.Klingel.Jobs) do
                local dist = #(coords - data.coords)

                if dist < 2.0 then
                    DrawText3D(data.coords.x, data.coords.y, data.coords.z + 0.2, "~g~E~w~ drücken um zu klingeln")

                    if IsControlJustPressed(0, 38) then
                        if (GetGameTimer() - lastPress) < Config.Klingel.Cooldown then
                            MC_Notify("Klingel", "Bitte warte kurz…", "warning")
                        else
                            lastPress = GetGameTimer()
                            TriggerServerEvent("mc_core:klingel:trigger", job)
                        end
                    end
                end
            end
        end
    end)
end


-- ============================================================
-- SECTION: labor.lua
-- ============================================================
do
    if not Config then
        print("^1[mc_core] Config konnte nicht geladen werden!^7")
        return
    end

    local LaborBlips = {}

    CreateThread(function()

        for _,lab in pairs(Config.Labors) do

            if lab.blip and lab.blip.enabled then

                local blip = AddBlipForCoord(lab.coords)

                SetBlipSprite(blip, lab.blip.sprite)
                SetBlipColour(blip, lab.blip.color)
                SetBlipScale(blip, lab.blip.scale)

                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(lab.label)
                EndTextCommandSetBlipName(blip)

                table.insert(LaborBlips, blip)

            end

        end

    end)

    CreateThread(function()

        if not Config.UseOxTarget then return end

        for _,lab in pairs(Config.Labors) do

            exports.ox_target:addSphereZone({

                coords = lab.coords,

                radius = lab.radius,

                debug = false,

                options = {

                    {

                        name = "labor_"..lab.id,

                        icon = "fa-solid fa-flask",

                        label = lab.label,

                        onSelect = function()

                            SetNuiFocus(true,true)

                            SendNUIMessage({

                                action="openLabor",

                                labor=lab.id,

                                label=lab.label

                            })

                            TriggerServerEvent("mc_core:getLaborStatus",lab.id)

                        end

                    }

                }

            })

        end

    end)

    CreateThread(function()

        while true do

            local sleep = 1000

            if not Config.UseOxTarget then

                local ped = PlayerPedId()

                local coords = GetEntityCoords(ped)

                for _,lab in pairs(Config.Labors) do

                    local dist = #(coords-lab.coords)

                    if dist < 20.0 then

                        sleep = 0

                        DrawMarker(

                            1,

                            lab.coords.x,
                            lab.coords.y,
                            lab.coords.z-1,

                            0.0,0.0,0.0,

                            0.0,0.0,0.0,

                            1.5,
                            1.5,
                            0.5,

                            lab.marker.r,
                            lab.marker.g,
                            lab.marker.b,
                            lab.marker.alpha,

                            false,
                            true,
                            2,
                            false,
                            nil,
                            nil,
                            false
                        )

                        if dist < lab.radius then

                            MC_NotifyHelp("Drücke ~INPUT_CONTEXT~ um das Labor zu öffnen")

                            if IsControlJustPressed(0,38) then

                                SetNuiFocus(true,true)

                                SendNUIMessage({

                                    action="openLabor",

                                    labor=lab.id,

                                    label=lab.label

                                })

                                TriggerServerEvent("mc_core:getLaborStatus",lab.id)

                            end

                        end

                    end

                end

            end

            Wait(sleep)

        end

    end)

    RegisterNetEvent("mc_core:sendLaborStatus",function(data)

        SendNUIMessage({

            action="updateLabor",

            items=data.items,

            money=data.money,

            finish=data.finish

        })

    end)

    RegisterNUICallback("deposit",function(data,cb)

        TriggerServerEvent("mc_core:depositLabor",data)

        cb("ok")

    end)

    RegisterNUICallback("collect",function(data,cb)

        TriggerServerEvent("mc_core:collectLabor",data)

        cb("ok")

    end)

    RegisterNUICallback("closeLabor",function(_,cb)

        SetNuiFocus(false,false)

        cb("ok")

    end)
end


-- ============================================================
-- SECTION: maut.lua 
-- ============================================================
do
    local insideToll = {}
    local processingToll = {}
    local EXIT_BUFFER = 15.0 -- größerer Puffer gegen Zittern am Zonenrand

    CreateThread(function()
        while true do
            local sleep = 500
            local ped = PlayerPedId()

            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                local isDriver = (GetPedInVehicleSeat(veh, -1) == ped)

                if isDriver then
                    sleep = 0

                    local coords = GetEntityCoords(veh)
                    local speed = GetEntitySpeed(veh) * 3.6

                    for _, toll in ipairs(MautConfig.Tolls) do
                        local dist = #(coords - toll.coords)

                        if dist <= toll.radius then

                            -- Eintritt: nur EINMAL pro Aufenthalt in der Zone
                            if not insideToll[toll.name] and not processingToll[toll.name] then
                                processingToll[toll.name] = true
                                insideToll[toll.name] = true

                                local dynamicPrice = MautConfig.Price

                                if speed >= 350 then
                                    dynamicPrice = math.floor(
                                        MautConfig.HighSpeedBase + ((speed - 350) * MautConfig.SpeedFactor)
                                    )
                                elseif speed > 50 then
                                    dynamicPrice = math.floor(
                                        MautConfig.Price + ((speed - 50) * MautConfig.SpeedFactor)
                                    )
                                end

                                TriggerServerEvent("mc_core:maut:pay", toll.name, dynamicPrice, speed)

                                if speed >= 200 then
                                    TriggerServerEvent("mc_core:maut:policeAlert", toll.name, dynamicPrice, speed)
                                end

                                processingToll[toll.name] = false
                            end

                        elseif dist > toll.radius + EXIT_BUFFER then
                            -- Austritt: dem Server explizit melden, damit die Sperre aufgehoben wird
                            if insideToll[toll.name] then
                                insideToll[toll.name] = false
                                processingToll[toll.name] = false
                                TriggerServerEvent("mc_core:maut:exit", toll.name)
                            end
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

-- ============================================================
-- SECTION: mechanic_client.lua
-- ============================================================
do
    local currentInsuranceTier = "basic"
    local insuranceCache = {}
    local insuranceNPC = nil
    local lastDrivenVeh = 0
    local lastDrivenPlate = nil

    local function getTierDurations(tier)
        if tier == 'basic' then
            return Config.MechanicDurationBasic, Config.RepairDurationBasic, Config.RequiredMechanicBasic
        elseif tier == 'default' then
            return Config.MechanicDurationDefault, Config.RepairDurationDefault, Config.RequiredMechanicDefault
        elseif tier == 'premium' then
            return Config.MechanicDurationPremium, Config.RepairDurationPremium, Config.RequiredMechanicPremium
        end

        return Config.MechanicDurationBasic, Config.RepairDurationBasic, Config.RequiredMechanicBasic
    end

    CreateThread(function()
        if not Config or not Config.MechanicInsuranceNPC or not Config.MechanicInsuranceLocation then
            print("^1[mc_vsMechanic] Config missing or incomplete^7")
            return
        end

        RequestModel(GetHashKey(Config.MechanicInsuranceNPC))
        while not HasModelLoaded(GetHashKey(Config.MechanicInsuranceNPC)) do
            Wait(10)
        end

        local loc = Config.MechanicInsuranceLocation
        insuranceNPC = CreatePed(4, GetHashKey(Config.MechanicInsuranceNPC), loc.x, loc.y, loc.z - 1.0, loc.w, false, true)
        SetEntityInvincible(insuranceNPC, true)
        FreezeEntityPosition(insuranceNPC, true)
        SetBlockingOfNonTemporaryEvents(insuranceNPC, true)

        if Config.EnableBlip and Config.BlipCoords then
            local blip = AddBlipForCoord(Config.BlipCoords.x, Config.BlipCoords.y, Config.BlipCoords.z)
            SetBlipSprite(blip, Config.BlipSprite or 1)
            SetBlipScale(blip, Config.BlipSize or 0.8)
            SetBlipColour(blip, Config.BlipColour or 1)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.BlipName or "Mechaniker Versicherung")
            EndTextCommandSetBlipName(blip)
        end
    end)

    CreateThread(function()
        while true do
            Wait(0)
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local loc = vector3(Config.MechanicInsuranceLocation.x, Config.MechanicInsuranceLocation.y, Config.MechanicInsuranceLocation.z)

            local dist = #(pCoords - loc)

            if dist < 5.0 then
                if Config.EnableDraw then
                    SetTextFont(0)
                    SetTextProportional(1)
                    SetTextScale(Config.DrawSize or 0.3, Config.DrawSize or 0.3)
                    local c = Config.DrawColor or { r = 255, g = 255, b = 255, a = 255 }
                    SetTextColour(c.r, c.g, c.b, c.a)
                    SetTextCentre(1)
                    SetTextEntry("STRING")
                    AddTextComponentString("Drücke [E], um deine Versicherung zu verwalten")
                    DrawText(Config.DrawX or 0.4, Config.DrawY or 0.005)
                end

                if IsControlJustPressed(0, Config.Key or 38) then
                    OpenInsuranceMenu()
                end
            end
        end
    end)

    function OpenInsuranceMenu()
        local playerPed = PlayerPedId()
        local veh = GetVehiclePedIsIn(playerPed, false)
        local plate = nil

        if veh ~= 0 then
            plate = GetVehicleNumberPlateText(veh)
        end

        local tiers = {
            basic = { price = Config.MechanicInsuranceBasicCost or 100 },
            default = { price = Config.MechanicInsuranceDefaultCost or 250 },
            premium = { price = Config.MechanicInsurancePremiumCost or 500 }
        }

        SendNUIMessage({ action = "resetInsuranceUI" })

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openInsurance",
            plate = plate,
            zone = "npc",
            tiers = tiers
        })
    end

    function OpenInsuranceMenuWithPremiumPreselect()
        local playerPed = PlayerPedId()
        local veh = GetVehiclePedIsIn(playerPed, false)
        local plate = nil
        if veh ~= 0 then
            plate = GetVehicleNumberPlateText(veh)
        end

        local tiers = {
            basic = { price = Config.MechanicInsuranceBasicCost or 100 },
            default = { price = Config.MechanicInsuranceDefaultCost or 250 },
            premium = { price = Config.MechanicInsurancePremiumCost or 500 }
        }

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openInsurance",
            plate = plate,
            zone = "npc",
            tiers = tiers,
            preselect = "premium"
        })
    end

    RegisterNUICallback("selectInsurance", function(data, cb)
        if not data or not data.tier or not data.plate then
            cb("error")
            return
        end

        insuranceCache[data.plate] = data.tier
        currentInsuranceTier = data.tier

        TriggerServerEvent("mc_insurance:buy", data.tier, data.plate)

        MC_Notify("Versicherung", ("Versicherung abgeschlossen: %s für %s"):format(tostring(data.tier), tostring(data.plate)), "success")

        cb("ok")
    end)

    RegisterNUICallback("closeInsurance", function(_, cb)
        SetNuiFocus(false, false)
        cb("ok")
    end)

    RegisterNetEvent("mc_insurance:setTier")
    AddEventHandler("mc_insurance:setTier", function(plate, tier)
        if not plate or not tier then return end
        insuranceCache[plate] = tier

        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then
            local myPlate = GetVehicleNumberPlateText(veh)
            if myPlate == plate then
                currentInsuranceTier = tier
            end
        end
    end)

    RegisterNetEvent("mc_vsMechanic:requestWithInsurance")
    AddEventHandler("mc_vsMechanic:requestWithInsurance", function(onlineMechs)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local plate = nil
        if veh ~= 0 then
            plate = GetVehicleNumberPlateText(veh)
        end

        local tier = "basic"
        if plate and insuranceCache[plate] then
            tier = insuranceCache[plate]
        else
            tier = currentInsuranceTier or "basic"
        end

        local mechDuration, repairDuration, requiredMechs = getTierDurations(tier)

        if onlineMechs >= requiredMechs then
            MC_Notify("Mechaniker", "Es sind genug Mechaniker online für deine Versicherungsstufe.", "info")
            return
        end

        TriggerEvent('mc_vsMechanic:spawnNPCMechanic', mechDuration, repairDuration, 0)
    end)

    RegisterNetEvent('mc_vsMechanic:spawnNPCMechanic')
    AddEventHandler('mc_vsMechanic:spawnNPCMechanic', function(mechDuration, repairDuration, cost)
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)

        local spawnPos = pCoords + vector3(
            math.random(-Config.SpawnRadius, Config.SpawnRadius),
            math.random(-Config.SpawnRadius, Config.SpawnRadius),
            0.0
        )

        RequestModel(GetHashKey(Config.MechanicModel))
        RequestModel(GetHashKey(Config.MechanicVehicle))

        while not HasModelLoaded(GetHashKey(Config.MechanicModel)) or not HasModelLoaded(GetHashKey(Config.MechanicVehicle)) do
            Wait(10)
        end

        local veh = CreateVehicle(GetHashKey(Config.MechanicVehicle), spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
        local npc = CreatePedInsideVehicle(veh, 4, GetHashKey(Config.MechanicModel), -1, true, false)

        TaskVehicleDriveToCoord(npc, veh, pCoords.x, pCoords.y, pCoords.z, 20.0, 1.0, GetHashKey(Config.MechanicVehicle), 786603, 1.0)

        MC_Notify("Mechaniker", "Mechaniker ist unterwegs...", "info")

        Wait(mechDuration * 1000)

        TaskLeaveVehicle(npc, veh, 0)
        Wait(2000)

        MC_Notify("Mechaniker", "Reparatur gestartet...", "info")

        Wait(repairDuration * 1000)

        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            SetVehicleFixed(vehicle)
            SetVehicleEngineHealth(vehicle, 1000.0)
        end

        MC_Notify("Mechaniker", "Fahrzeug repariert!", "success")

        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
        if DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
    end)

    function RequestInsuranceForCurrentVehicle()
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            MC_Notify("Versicherung", "Du sitzt in keinem Fahrzeug.", "error")
            return
        end

        local plate = GetVehicleNumberPlateText(veh)
        if not plate or plate == "" then
            MC_Notify("Versicherung", "Kein Kennzeichen gefunden.", "error")
            return
        end

        TriggerServerEvent("mc_insurance:getForPlate", plate)
    end

    CreateThread(function()
        while true do
            Wait(1000)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, true)
            if veh ~= 0 and veh ~= lastDrivenVeh then
                lastDrivenVeh = veh
                local plate = GetVehicleNumberPlateText(veh)
                if plate and plate ~= "" then
                    lastDrivenPlate = plate
                end
            end
        end
    end)

    function BuyPremiumForLastDrivenVehicle()
        if not lastDrivenPlate or lastDrivenPlate == "" then
            MC_Notify("Versicherung", "Kein zuletzt gefahrenes Fahrzeug gefunden.", "error")
            return
        end

        insuranceCache[lastDrivenPlate] = "premium"
        currentInsuranceTier = "premium"

        TriggerServerEvent("mc_insurance:buy", "premium", lastDrivenPlate)

        MC_Notify("Versicherung", "Premium‑Versicherung abgeschlossen für " .. lastDrivenPlate, "success")
    end

    RegisterCommand("buyPremiumLast", function()
        BuyPremiumForLastDrivenVehicle()
    end, false)

    CreateThread(function()
        local lastVeh = 0
        while true do
            Wait(1000)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= lastVeh then
                lastVeh = veh
                if veh ~= 0 then
                    local plate = GetVehicleNumberPlateText(veh)
                    if plate and insuranceCache[plate] then
                        currentInsuranceTier = insuranceCache[plate]
                    else
                        TriggerServerEvent("mc_insurance:getForPlate", plate)
                    end
                end
            end
        end
    end)

    exports('GetInsuranceTierForPlate', function(plate)
        return insuranceCache[plate] or "basic"
    end)

    exports('IsPlateInsured', function(plate)
        return insuranceCache[plate] ~= nil
    end)
end


-- ============================================================
-- SECTION: moneywash.lua
-- ============================================================
do
    if not Config or not Config.Moneywash then
        print("^1[mc_core] Moneywash-Konfiguration konnte nicht geladen werden!^7")
        return
    end

    local MW = Config.Moneywash
    local moneywashBlips = {}
    local moneywashOpen = false

    CreateThread(function()
        for _, loc in ipairs(MW.locations) do
            if loc.blip and loc.blip.enabled then
                local blip = AddBlipForCoord(loc.coords)

                SetBlipSprite(blip, loc.blip.sprite)
                SetBlipColour(blip, loc.blip.color)
                SetBlipScale(blip, loc.blip.scale)

                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(loc.label)
                EndTextCommandSetBlipName(blip)

                table.insert(moneywashBlips, blip)
            end
        end
    end)

    local function OpenMoneywashMenu()
        moneywashOpen = true

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openMoneywash",
            config = {
                packages = MW.packages,
                custom   = MW.custom,
                minFee   = MW.minFee,
                maxFee   = MW.maxFee,
            },
        })

        TriggerServerEvent("mc_core:getMoneywashStatus")
    end

    CreateThread(function()
        if not MW.useOxTarget then return end

        for _, loc in ipairs(MW.locations) do
            exports.ox_target:addSphereZone({

                coords = loc.coords,
                radius = loc.radius,
                debug = false,

                options = {
                    {
                        name = "moneywash_" .. loc.id,
                        icon = "fa-solid fa-money-bill-transfer",
                        label = "Geld waschen",
                        onSelect = function()
                            OpenMoneywashMenu()
                        end,
                    },
                },

            })
        end
    end)

    CreateThread(function()
        while true do

            local sleep = 1000

            if not MW.useOxTarget then

                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)

                for _, loc in ipairs(MW.locations) do

                    local dist = #(coords - loc.coords)

                    if dist < 20.0 then

                        sleep = 0

                        DrawMarker(
                            1,
                            loc.coords.x, loc.coords.y, loc.coords.z - 1,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            1.5, 1.5, 0.5,
                            loc.marker.r, loc.marker.g, loc.marker.b, loc.marker.alpha,
                            false, true, 2, false, nil, nil, false
                        )

                        if dist < loc.radius then

                            MC_NotifyHelp("Drücke ~INPUT_CONTEXT~ um Geld zu waschen")

                            if IsControlJustPressed(0, 38) and not moneywashOpen then
                                OpenMoneywashMenu()
                            end

                        end

                    end

                end

            end

            Wait(sleep)

        end
    end)

    RegisterNetEvent("mc_core:sendMoneywashStatus")
    AddEventHandler("mc_core:sendMoneywashStatus", function(data)
        SendNUIMessage({
            action = "updateMoneywash",
            blackMoney = data.blackMoney,
            cleanMoney = data.cleanMoney,
            jobs = data.jobs,
            now = data.now,
        })
    end)

    RegisterNetEvent("mc_core:moneywashPoliceAlert")
    AddEventHandler("mc_core:moneywashPoliceAlert", function(coords, blipMinutes)
        MC_Notify("Geldwäsche", "Ein Passant meldet verdächtige Aktivitäten! Position auf der Karte markiert.", "warning")

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, MW.policeNotify.blipSprite)
        SetBlipColour(blip, MW.policeNotify.blipColor)
        SetBlipScale(blip, 1.0)
        SetBlipFlashes(blip, true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(MW.policeNotify.blipLabel)
        EndTextCommandSetBlipName(blip)

        SetTimeout(blipMinutes * 60 * 1000, function()
            RemoveBlip(blip)
        end)
    end)

    RegisterNUICallback("startMoneywash", function(data, cb)
        TriggerServerEvent("mc_core:startMoneywash", data)
        cb("ok")
    end)

    RegisterNUICallback("collectMoneywash", function(data, cb)
        TriggerServerEvent("mc_core:collectMoneywash", data)
        cb("ok")
    end)

    RegisterNUICallback("closeMoneywash", function(_, cb)
        SetNuiFocus(false, false)
        moneywashOpen = false
        cb("ok")
    end)
end


-- ============================================================
-- SECTION: npc_blocker.lua
-- ============================================================
do
    local ESX = exports["es_extended"]:getSharedObject()

    local PlayerVehicles = {}

    local function InRadius(coords)
        return #(coords - ZoneCenter) <= ZoneRadius
    end

    CreateThread(function()
        while true do
            Wait(500)

            if not EnableNPCBlocker then
                goto continue_outer
            end

            local vehicles = GetGamePool("CVehicle")

            for _, veh in ipairs(vehicles) do
                if DoesEntityExist(veh) then

                    local coords = GetEntityCoords(veh)

                    if InRadius(coords) then

                        local netId = VehToNet(veh)

                        local playerInside = false

                        for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                            local ped = GetPedInVehicleSeat(veh, seat)

                            if ped ~= 0 and IsPedAPlayer(ped) then
                                playerInside = true
                                PlayerVehicles[netId] = true
                                break
                            end
                        end

                        if playerInside then
                            goto continue
                        end

                        if PlayerVehicles[netId] then
                            goto continue
                        end

                        local plate = ESX.Math.Trim(GetVehicleNumberPlateText(veh))
                        local owned = lib.callback.await("npc_blocker:isOwnedVehicle", false, plate)

                        if owned then
                            goto continue
                        end

                        local driver = GetPedInVehicleSeat(veh, -1)

                        if driver ~= 0 and not IsPedAPlayer(driver) then
                            SetEntityAsMissionEntity(driver, true, true)
                            SetEntityAsMissionEntity(veh, true, true)

                            DeletePed(driver)
                            DeleteVehicle(veh)

                        elseif driver == 0 then
                            SetEntityAsMissionEntity(veh, true, true)
                            DeleteVehicle(veh)
                        end
                    end
                end

                ::continue::
            end

            ::continue_outer::
        end
    end)

    CreateThread(function()
        while EnableNPCBlocker and DebugNPCBlocker do
            Wait(0)

            DrawMarker(
                1,
                ZoneCenter.x, ZoneCenter.y, ZoneCenter.z - 1.0,
                0.0,0.0,0.0,
                0.0,0.0,0.0,
                ZoneRadius * 2.0,
                ZoneRadius * 2.0,
                1.0,
                255,0,0,120,
                false,false,2,false
            )
        end
    end)
end


-- ============================================================
-- SECTION: purge.lua
-- ============================================================
do
    local purge = false
    local purgeEnd = 0
    local lastNotify = 0

    RegisterNetEvent("mc_core:purgeStart")
    AddEventHandler("mc_core:purgeStart", function(duration)
        purge = true
        purgeEnd = GetGameTimer() + (duration * 1000)

        MC_Notify("🔥 PURGE AKTIV", "Alle Gesetze sind außer Kraft!", "warning", 8000)

        if Config.Purge.GiveWeapons then
            for _,weapon in ipairs(Config.Purge.Weapons) do
                GiveWeaponToPed(PlayerPedId(), GetHashKey(weapon), 250, false, true)
            end
        end

        if Config.Purge.ScreenEffect then
            StartScreenEffect("DrugsTrevorClownsFight", 0, true)
        end
    end)

    RegisterNetEvent("mc_core:purgeStop")
    AddEventHandler("mc_core:purgeStop", function()
        purge = false
        StopScreenEffect("DrugsTrevorClownsFight")

        MC_Notify("🧊 PURGE ENDE", "Die Stadt kehrt zur Normalität zurück.", "info", 8000)
    end)

    CreateThread(function()
        while true do
            Wait(200)

            if purge then
                local remaining = math.floor((purgeEnd - GetGameTimer()) / 1000)

                if remaining <= 5 and remaining > 0 then
                    if remaining ~= lastNotify then
                        lastNotify = remaining
                        MC_Notify("Purge endet", remaining .. " Sekunden", "warning", 1200)
                    end
                end
            end
        end
    end)
end


-- ============================================================
-- SECTION: revive.lua
-- ============================================================
do
    local reviveUiOpen = false

    function OpenReviveUI()
        reviveUiOpen = true
        SetNuiFocus(true, true)

        SendNUIMessage({
            action = "openRevive",
            price = Config.Revive.Price
        })
    end

    function CloseReviveUI()
        reviveUiOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "closeRevive" })
    end

    RegisterNUICallback("closeRevive", function(_, cb)
        CloseReviveUI()
        cb('ok')
    end)

    RegisterNUICallback("startRevive", function(_, cb)
        TriggerServerEvent("revive:requestRevive")
        cb('ok')
    end)

    RegisterNetEvent("revive:verifyDead", function()
        local ped = PlayerPedId()

        if not IsEntityDead(ped) then
            MC_Notify("Revive", "Du bist nicht bewusstlos.", "error")
            CloseReviveUI()
            return
        end

        TriggerServerEvent("revive:doPaymentAndRevive")
    end)

    RegisterNetEvent("revive:doRevive", function()
        TriggerEvent("esx_ambulancejob:revive")
        CloseReviveUI()
    end)

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for _, station in ipairs(Config.Revive.Stations) do
                if #(coords - station.coords) < 2.0 then
                    sleep = 0

                    if IsEntityDead(ped) then
                        MC_NotifyHelp("Drücke ~INPUT_CONTEXT~, um die Revive-Station zu öffnen")

                        if IsControlJustReleased(0, 38) and not reviveUiOpen then
                            OpenReviveUI()
                        end
                    else
                        MC_NotifyHelp("Nur für bewusstlose Personen verfügbar")
                    end
                end
            end

            if reviveUiOpen and sleep == 1000 then
                CloseReviveUI()
            end

            Wait(sleep)
        end
    end)

    CreateThread(function()
        if not Config.Revive.Blips.enabled then return end

        for _, station in ipairs(Config.Revive.Stations) do
            local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)

            SetBlipSprite(blip, Config.Revive.Blips.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Revive.Blips.scale)
            SetBlipColour(blip, Config.Revive.Blips.color)

            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.Revive.Blips.name)
            EndTextCommandSetBlipName(blip)
        end
    end)

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            if Config.Revive.Marker.enabled then
                for _, station in ipairs(Config.Revive.Stations) do
                    local dist = #(coords - station.coords)

                    if dist < 20.0 then
                        sleep = 0

                        DrawMarker(
                            Config.Revive.Marker.type,
                            station.coords.x, station.coords.y, station.coords.z - 0.95,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            Config.Revive.Marker.size.x,
                            Config.Revive.Marker.size.y,
                            Config.Revive.Marker.size.z,
                            Config.Revive.Marker.color.r,
                            Config.Revive.Marker.color.g,
                            Config.Revive.Marker.color.b,
                            Config.Revive.Marker.color.a,
                            Config.Revive.Marker.rotate,
                            false,
                            2,
                            false,
                            nil,
                            nil,
                            false
                        )
                    end
                end
            end

            Wait(sleep)
        end
    end)
end


-- ============================================================
-- SECTION: kampfunfaehig.lua
-- ============================================================
do
    local isDown = false
    local remaining = 0
    local totalDuration = 0
    local canSelfRespawn = false

    -- Hotbar-Tasten (1-9, INPUT_SELECT_WEAPON_*) waehrend der
    -- Kampfunfaehigkeit blocken. Das eigentliche Inventar (TAB/I)
    -- bleibt unberuehrt.
    local hotbarControls = { 157, 158, 159, 160, 161, 162, 163, 164, 165 }

    local function RunControlBlocker()
        CreateThread(function()
            while isDown do
                local ped = PlayerPedId()

                if Config.Kampfunfaehig.DisableHotbar then
                    for _, control in ipairs(hotbarControls) do
                        DisableControlAction(0, control, true)
                    end
                end

                if type(Config.Kampfunfaehig.BlockedActions) == "function" then
                    Config.Kampfunfaehig.BlockedActions(ped)
                end

                Wait(0)
            end
        end)
    end

    local function ShowHud(seconds)
        SendNUIMessage({ action = "mc_core:kampfunfaehig:show" })
        SendNUIMessage({ action = "mc_core:kampfunfaehig:update", seconds = seconds, total = totalDuration })
    end

    local function HideHud()
        SendNUIMessage({ action = "mc_core:kampfunfaehig:hide" })
    end

    local function RunCountdown()
        CreateThread(function()
            while isDown and remaining > 0 do
                Wait(1000)
                remaining = remaining - 1
                if isDown then ShowHud(remaining) end
            end

            if not isDown or remaining > 0 then return end

            if Config.Kampfunfaehig.OnTimeoutAction == "auto_respawn" then
                TriggerServerEvent('mc_core:kampfunfaehig:autoRespawn')
            else
                canSelfRespawn = true
                MC_Notify("Kampfunfähig", Config.Kampfunfaehig.HudLocale.timeoutNotify, "info", 8000)
            end
        end)
    end

    local function EnterKampfunfaehig()
        if isDown or not Config.Kampfunfaehig.Enabled then return end

        local ped = PlayerPedId()
        if type(Config.Kampfunfaehig.CanStart) == "function" and not Config.Kampfunfaehig.CanStart(ped) then
            return
        end

        isDown = true
        canSelfRespawn = false
        remaining = Config.Kampfunfaehig.Duration
        totalDuration = Config.Kampfunfaehig.Duration

        TriggerServerEvent('mc_core:kampfunfaehig:start')
        TriggerEvent(Config.Kampfunfaehig.DeathEvent)
        RunControlBlocker()
        ShowHud(remaining)
        RunCountdown()
    end

    local function ExitKampfunfaehig()
        if not isDown then return end

        isDown = false
        canSelfRespawn = false
        HideHud()
        TriggerServerEvent('mc_core:kampfunfaehig:stop')
    end

    -- Whitelisted Gruppen/Jobs (Admin/Sanitaeter): Server sagt "skip",
    -- HUD/Sperren sofort wieder aufheben
    RegisterNetEvent('mc_core:kampfunfaehig:skip', function()
        ExitKampfunfaehig()
    end)

    -- Von einem Admin per /dtstart ausgeloest
    RegisterNetEvent('mc_core:kampfunfaehig:forceStart', function(seconds)
        if isDown then return end

        local ped = PlayerPedId()
        isDown = true
        canSelfRespawn = false
        remaining = seconds
        totalDuration = seconds

        MC_Notify("Kampfunfähig", Config.Kampfunfaehig.L("gotStartedDt"), "error")
        RunControlBlocker()
        ShowHud(remaining)
        RunCountdown()
    end)

    -- Von einem Admin per /dtclear oder /dtclearradius ausgeloest
    RegisterNetEvent('mc_core:kampfunfaehig:forceClear', function()
        if not isDown then return end
        MC_Notify("Kampfunfähig", Config.Kampfunfaehig.L("gotRemovedDt"), "success")
        ExitKampfunfaehig()
    end)

    -- Nach Server-Neustart / Reconnect: Timer mit verbleibender Zeit fortsetzen
    RegisterNetEvent('mc_core:kampfunfaehig:resume', function(secondsLeft)
        isDown = true
        canSelfRespawn = false
        remaining = secondsLeft
        totalDuration = Config.Kampfunfaehig.Duration

        RunControlBlocker()
        ShowHud(remaining)
        RunCountdown()
    end)

    RegisterNetEvent('mc_core:kampfunfaehig:autoRespawnClient', function(coords)
        DoScreenFadeOut(500)
        Wait(500)

        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
        TriggerEvent(Config.Kampfunfaehig.ReviveEvent)

        Wait(300)
        DoScreenFadeIn(500)

        ExitKampfunfaehig()
    end)

    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            local dead = IsEntityDead(ped)

            if dead and not isDown then
                EnterKampfunfaehig()
            elseif not dead and isDown then
                ExitKampfunfaehig()
            end

            if isDown and canSelfRespawn and Config.Kampfunfaehig.OnTimeoutAction == "allow_self_respawn" then
                MC_NotifyHelp("Drücke ~INPUT_CONTEXT~, um dich selbst wiederzubeleben")

                if IsControlJustReleased(0, Config.Kampfunfaehig.SelfRespawnKey) then
                    TriggerServerEvent('mc_core:kampfunfaehig:autoRespawn')
                end
            end

            Wait(500)
        end
    end)
end


-- ============================================================
-- SECTION: sperrezone.lua
-- ============================================================
-- Sperrzone nutzt bewusst NICHT MC_Notify, sondern direkt
-- hex_future_hud:announce (großes Banner statt kleiner Toast).
-- ============================================================
do
    ESX = exports['es_extended']:getSharedObject()

    local Zones = {}
    local PlayerData = {}

    -- Sperrzone-spezifischer Announce-Helper
    local function SperrzoneAnnounce(title, msg, timeout)
        TriggerEvent('hex_future_hud:announce', title, msg, timeout or 10000)
    end

    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
        TriggerServerEvent('mc_sperrzone:requestSync')
    end)

    RegisterNetEvent('esx:setJob', function(job)
        PlayerData.job = job
    end)

    CreateThread(function()
        while ESX.GetPlayerData().job == nil do Wait(200) end
        PlayerData = ESX.GetPlayerData()
        TriggerServerEvent('mc_sperrzone:requestSync')
    end)

    RegisterNetEvent('mc_sperrzone:syncAll', function(serverZones)
        for _, z in pairs(Zones) do
            if z.blip and DoesBlipExist(z.blip) then
                RemoveBlip(z.blip)
            end
            if z.radiusBlip and DoesBlipExist(z.radiusBlip) then
                RemoveBlip(z.radiusBlip)
            end
        end

        Zones = {}

        for _, z in ipairs(serverZones) do
            local jobCfg = Config.Jobs[z.job] or { label = z.jobLabel, blipColor = 1 }

            local blip = AddBlipForCoord(z.coords.x, z.coords.y, z.coords.z)
            SetBlipSprite(blip, Config.BlipSprite)
            SetBlipScale(blip, Config.BlipScale)
            SetBlipColour(blip, jobCfg.blipColor)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(_L('blip_name', jobCfg.label))
            EndTextCommandSetBlipName(blip)

            local radiusBlip = nil
            if Config.ShowRadiusBlip then
                radiusBlip = AddBlipForRadius(z.coords.x, z.coords.y, z.coords.z, z.radius + 0.0)
                if radiusBlip and radiusBlip ~= 0 then
                    SetBlipRotation(radiusBlip, 0)
                    SetBlipAsShortRange(radiusBlip, false)
                    SetBlipColour(radiusBlip, jobCfg.blipColor or 1)
                    SetBlipAlpha(radiusBlip, Config.RadiusBlipAlpha or 150)
                    SetBlipPriority(radiusBlip, 0)
                end
            end

            z.blip = blip
            z.radiusBlip = radiusBlip
            z.markerColor = jobCfg.markerColor or { r = 255, g = 0, b = 0, a = 100 }

            Zones[z.id] = z
        end
    end)

    RegisterNetEvent('mc_sperrzone:notify', function(msg, type)
        local title = "Sperrzone"

        if type == "success" then
            title = "✅ Sperrzone"
        elseif type == "error" then
            title = "❌ Sperrzone"
        elseif type == "warning" then
            title = "⚠️ Sperrzone"
        elseif type == "info" then
            title = "ℹ️ Sperrzone"
        end

        SperrzoneAnnounce(title, msg, 10000)
    end)

    CreateThread(function()
        while true do
            local sleep = 500
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for _, z in pairs(Zones) do
                local dist = #(coords - vector3(z.coords.x, z.coords.y, z.coords.z))
                if dist < Config.DrawDistance then
                    sleep = 0
                    local c = z.markerColor
                    DrawMarker(
                        Config.MarkerType,
                        z.coords.x, z.coords.y, z.coords.z + Config.MarkerZOffset,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        z.radius * 2.0, z.radius * 2.0, 1.0,
                        c.r, c.g, c.b, c.a,
                        false, false, 2, true, nil, nil, false
                    )
                end
            end

            Wait(sleep)
        end
    end)

    local function hasZonePermission()
        return PlayerData.job and Config.Jobs[PlayerData.job.name] ~= nil
    end

    local function findZoneImIn()
        local coords = GetEntityCoords(PlayerPedId())
        for id, z in pairs(Zones) do
            local dist = #(coords - vector3(z.coords.x, z.coords.y, z.coords.z))
            if dist <= z.radius then
                return id, z
            end
        end
        return nil
    end

    RegisterCommand(Config.Commands.create, function(source, args)
        if not hasZonePermission() then
            SperrzoneAnnounce("❌ Sperrzone", _L('no_permission'))
            return
        end

        local radius = tonumber(args[1]) or Config.DefaultRadius
        local coords = GetEntityCoords(PlayerPedId())

        TriggerServerEvent('mc_sperrzone:create', radius, { x = coords.x, y = coords.y, z = coords.z })
    end, false)

    RegisterCommand(Config.Commands.remove, function(source, args)
        local id, zone = findZoneImIn()
        if not id then
            SperrzoneAnnounce("❌ Sperrzone", _L('not_in_own_zone'))
            return
        end

        local coords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('mc_sperrzone:remove', id, { x = coords.x, y = coords.y, z = coords.z })
    end, false)

    AddEventHandler('onResourceStop', function(resourceName)
        if GetCurrentResourceName() ~= resourceName then return end
        for _, z in pairs(Zones) do
            if z.blip and DoesBlipExist(z.blip) then RemoveBlip(z.blip) end
            if z.radiusBlip and DoesBlipExist(z.radiusBlip) then RemoveBlip(z.radiusBlip) end
        end
    end)
end


-- ============================================================
-- SECTION: tow.lua
-- ============================================================
do
    local whitelist = {
        'dlbrickade',
        'TOW',
        'BENSON',
        'WASTLNDR',
        'MULE',
        'MULE2',
        'MULE3',
        'MULE4',
        'TRAILER',
        'ARMYTRAILER',
        'Fontaine 51',
        'semihauler',
        'Eguinchoevo',
        'BOATTRAILER'
    }

    local offsets = {
        {model = 'dlbrickade', offset = {x = 0.0, y = -9.3, z = -1.6}},
        {model = 'TOW', offset = {x = 0.0, y = -8.4, z = -1.25}},
        {model = 'BENSON', offset = {x = 0.0, y = 0.0, z = -1.25}},
        {model = 'WASTLNDR', offset = {x = 0.0, y = -7.2, z = -0.9}},
        {model = 'MULE', offset = {x = 0.0, y = -7.0, z = -1.75}},
        {model = 'MULE2', offset = {x = 0.0, y = -7.0, z = -1.75}},
        {model = 'MULE3', offset = {x = 0.0, y = -7.0, z = -1.75}},
        {model = 'MULE4', offset = {x = 0.0, y = -7.0, z = -1.75}},
        {model = 'TRAILER', offset = {x = 0.0, y = -9.0, z = -1.25}},
        {model = 'Fontaine 51', offset = {x = 0.0, y = -9.5, z = -3.0}},
        {model = 'semihauler', offset = {x = 0.0, y = -9.5, z = -3.0}},
        {model = 'ARMYTRAILER', offset = {x = 0.0, y = -9.5, z = -3.0}},
    }

    local rampHash = 'imp_prop_flatbed_ramp'

    function GetVehicleBelowMe(cFrom, cTo)
        local rayHandle = CastRayPointToPoint(cFrom.x, cFrom.y, cFrom.z, cTo.x, cTo.y, cTo.z, 10, PlayerPedId(), 0)
        local _, _, _, _, vehicle = GetRaycastResult(rayHandle)
        return vehicle
    end

    function contains(item, list)
        for _, value in ipairs(list) do
            if value == item then return true end
        end
        return false
    end

    function drawNotification(text)
        MC_Notify("Abschleppen", text, "info")
    end

    RegisterCommand('rampe', function ()
        local player = PlayerPedId()
        local playerCoords = GetEntityCoords(player)
        local radius = 7.0

        local vehicle = nil

        if IsAnyVehicleNearPoint(playerCoords, radius) then
            vehicle = GetClosestVehicle(playerCoords, radius, 0, 70)
            local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))

            drawNotification("Versuche Rampe anzubauen für: " .. vehicleName)

            if contains(vehicleName, whitelist) then
                local vehicleCoords = GetEntityCoords(vehicle)

                local ramp = CreateObject(rampHash, vector3(vehicleCoords), true, false, false)
                for _, value in pairs(offsets) do
                    if vehicleName == value.model then
                        AttachEntityToEntity(ramp, vehicle, GetEntityBoneIndexByName(vehicle, 'chassis'), value.offset.x, value.offset.y, value.offset.z , 180.0, 180.0, 0.0, 0, 0, 1, 0, 0, 1)
                    end
                end

                drawNotification("Rampe wurde angebaut.")
                return
            end
            drawNotification("Du kannst keine Rampe an dieses Fahrzeug bauen.")
            return
        end
    end)

    RegisterCommand('rampedv', function()
        local player = PlayerPedId()
        local playerCoords = GetEntityCoords(player)

        local object = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 7.0, rampHash, false, 0, 0)

        if not IsPedInAnyVehicle(player, false) then
            if GetHashKey(rampHash) == GetEntityModel(object) then
                DeleteObject(object)
                drawNotification("Rampe entfernt.")
                return
            end
        end

        drawNotification("Steige aus deinem Fahrzeug aus, um die Rampe zu entfernen.")
    end)

    RegisterCommand('anbniden', function()
        local player = PlayerPedId()
        local vehicle = nil

        if IsPedInAnyVehicle(player, false) then
            vehicle = GetVehiclePedIsIn(player, false)
            if GetPedInVehicleSeat(vehicle, -1) == player then
                local vehicleCoords = GetEntityCoords(vehicle)
                local vehicleOffset = GetOffsetFromEntityInWorldCoords(vehicle, 1.0, 0.0, -1.0)
                local belowEntity = GetVehicleBelowMe(vehicleCoords, vehicleOffset)
                local vehicleBelowName = GetDisplayNameFromVehicleModel(GetEntityModel(belowEntity))

                local vehiclesOffset = GetOffsetFromEntityGivenWorldCoords(belowEntity, vehicleCoords)

                if contains(vehicleBelowName, whitelist) then
                    if not IsEntityAttached(vehicle) then
                        AttachEntityToEntity(vehicle, belowEntity, GetEntityBoneIndexByName(belowEntity, 'chassis'), vehiclesOffset, 0.0, 0.0, 0.0, false, false, true, false, 0, true)
                        return drawNotification('Fahrzeug wurde angebunden.')
                    end
                    return drawNotification('Das Fahrzeug ist schon angebunden.')
                end
                return drawNotification('Du kannst dieses Fahrzeug nicht festmachen: ' .. vehicleBelowName)
            end
            return drawNotification('Du musst im Fahrersitz sein.')
        end
        drawNotification('Du bist in keinem Fahrzeug.')
    end)

    RegisterCommand('abbinden', function()
        local player = PlayerPedId()
        local vehicle = nil

        if IsPedInAnyVehicle(player, false) then
            vehicle = GetVehiclePedIsIn(player, false)
            if GetPedInVehicleSeat(vehicle, -1) == player then
                DetachEntity(vehicle, false, true)
            end
        end
    end)
end


-- ============================================================
-- SECTION: verkauf.lua
-- ============================================================
do
    CreateThread(function()
        for name, data in pairs(Config.Verkauf) do
            local coords = data.coords

            if data.blip and data.blip.enabled then
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                SetBlipSprite(blip, data.blip.id)
                SetBlipColour(blip, data.blip.color)
                SetBlipScale(blip, data.blip.scale)
                SetBlipAsShortRange(blip, data.blip.shortrange)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(data.blip.name)
                EndTextCommandSetBlipName(blip)
            end

            CreateThread(function()
                while true do
                    local sleep = 1000
                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)
                    local dist = #(playerCoords - coords)

                    if dist <= data.zonesize then
                        sleep = 0

                        if data.marker then
                            DrawMarker(
                                data.marker.typ,
                                coords.x, coords.y, coords.z + data.marker.z_offset,
                                0.0, 0.0, 0.0,
                                0.0, 0.0, 0.0,
                                data.marker.size.x, data.marker.size.y, data.marker.size.z,
                                data.marker.color.r, data.marker.color.g, data.marker.color.b, data.marker.color.t,
                                data.marker.move, data.marker.rotate, 2, false, nil, nil, false
                            )
                        end

                        MC_NotifyHelp(data.helpmsg)

                        if IsControlJustPressed(0, 38) then
                            TriggerServerEvent("mc_core:verkauf:sell", name)
                        end
                    end

                    Wait(sleep)
                end
            end)
        end
    end)
end

-- ============================================================
-- MODUL: CarryPeople - CLIENT
-- ============================================================
-- Ersetzt das vorherige selbstgebaute Carry-System. Übernommen aus
-- dem eigenständigen "CarryPeople"-Script von Robbster. Über
-- Config.CarryPeople.enabled an/aus schaltbar. Helper-Funktionen
-- mit "CP_" Präfix, da PiggyBack/TakeHostage (weiter unten) mit
-- identisch benannten lokalen Helpern arbeiten.
-- ============================================================

local carryPeopleState = {
    InProgress = false,
    targetSrc = -1,
    type = "",
    personCarrying = {
        animDict = "missfinale_c2mcs_1",
        anim = "fin_c2_mcs_1_camman",
        flag = 49,
    },
    personCarried = {
        animDict = "nm",
        anim = "firemans_carry",
        attachX = 0.27,
        attachY = 0.15,
        attachZ = 0.63,
        flag = 33,
    }
}

local function CP_Notify(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

local function CP_GetClosestPlayer(radius)
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(targetCoords - playerCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    if closestDistance ~= -1 and closestDistance <= radius then
        return closestPlayer
    else
        return nil
    end
end

local function CP_EnsureAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end
    end
    return animDict
end

RegisterCommand(Config.CarryPeople.command, function(source, args)
    if not Config.CarryPeople.enabled then return end

    if not carryPeopleState.InProgress then
        local closestPlayer = CP_GetClosestPlayer(Config.CarryPeople.maxDistance)
        if closestPlayer then
            local targetSrc = GetPlayerServerId(closestPlayer)
            if targetSrc ~= -1 then
                carryPeopleState.InProgress = true
                carryPeopleState.targetSrc = targetSrc
                TriggerServerEvent("CarryPeople:sync", targetSrc)
                CP_EnsureAnimDict(carryPeopleState.personCarrying.animDict)
                carryPeopleState.type = "carrying"
            else
                CP_Notify("~r~Niemand in der Nähe zum Tragen!")
            end
        else
            CP_Notify("~r~Niemand in der Nähe zum Tragen!")
        end
    else
        carryPeopleState.InProgress = false
        ClearPedSecondaryTask(PlayerPedId())
        DetachEntity(PlayerPedId(), true, false)
        TriggerServerEvent("CarryPeople:stop", carryPeopleState.targetSrc)
        carryPeopleState.targetSrc = 0
    end
end, false)

RegisterNetEvent("CarryPeople:syncTarget")
AddEventHandler("CarryPeople:syncTarget", function(targetSrc)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
    carryPeopleState.InProgress = true
    CP_EnsureAnimDict(carryPeopleState.personCarried.animDict)
    AttachEntityToEntity(PlayerPedId(), targetPed, 0, carryPeopleState.personCarried.attachX, carryPeopleState.personCarried.attachY, carryPeopleState.personCarried.attachZ, 0.5, 0.5, 180, false, false, false, false, 2, false)
    carryPeopleState.type = "beingcarried"
end)

RegisterNetEvent("CarryPeople:cl_stop")
AddEventHandler("CarryPeople:cl_stop", function()
    carryPeopleState.InProgress = false
    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
end)

CreateThread(function()
    while true do
        if carryPeopleState.InProgress then
            if carryPeopleState.type == "beingcarried" then
                if not IsEntityPlayingAnim(PlayerPedId(), carryPeopleState.personCarried.animDict, carryPeopleState.personCarried.anim, 3) then
                    TaskPlayAnim(PlayerPedId(), carryPeopleState.personCarried.animDict, carryPeopleState.personCarried.anim, 8.0, -8.0, 100000, carryPeopleState.personCarried.flag, 0, false, false, false)
                end
            elseif carryPeopleState.type == "carrying" then
                if not IsEntityPlayingAnim(PlayerPedId(), carryPeopleState.personCarrying.animDict, carryPeopleState.personCarrying.anim, 3) then
                    TaskPlayAnim(PlayerPedId(), carryPeopleState.personCarrying.animDict, carryPeopleState.personCarrying.anim, 8.0, -8.0, 100000, carryPeopleState.personCarrying.flag, 0, false, false, false)
                end
            end
        end
        Wait(0)
    end
end)

-- ============================================================
-- MODUL: Jail (esx_jail) - CLIENT
-- ============================================================
-- Übernommen aus dem eigenständigen "esx_jail"-Script.
-- Config.Locale wurde zu Config.JailLocale umbenannt (Konflikt mit
-- mc_core's Config.Locale = 'de', siehe config.lua).
-- ============================================================

ESX = ESX or exports['es_extended']:getSharedObject() -- geteiltes ESX-Objekt (siehe server.lua-Muster), keine erneute Belegung nötig

local isJailed = false
local currentJailId = nil
local remainingTime = 0
local currentReason = nil
local escapeThreadActive = false

-- ####################################################
-- ##                   HELPERS                       ##
-- ####################################################

local function Notify(msg, type)
    lib.notify({ description = msg, type = type or 'inform' })
end

local function GetJobName()
    local xPlayer = ESX.GetPlayerData()
    return xPlayer.job and xPlayer.job.name or nil
end

RegisterNetEvent('esx_jail:notify', function(msg, type)
    Notify(msg, type)
end)

-- ####################################################
-- ##          BEIM SPAWNEN PRÜFEN OB INHAFTIERT      ##
-- ####################################################

AddEventHandler('esx:playerLoaded', function()
    ESX.TriggerServerCallback('esx_jail:checkOnLoad', function(data)
        if data then
            if data.type == 'admin' then
                SendToAdminJail(data.time, data.reason)
            else
                SendToJail(data.jailId, data.time, data.reason)
            end
        end
    end)
end)

-- ####################################################
-- ##                 INS GEFÄNGNIS                   ##
-- ####################################################

RegisterNetEvent('esx_jail:sendToJail', function(jailId, minutes, reason, location)
    SendToJail(jailId, minutes, reason, location)
end)

function SendToJail(jailId, minutes, reason, location)
    local jail = Config.Jails[jailId]
    if not jail then return end

    isJailed = true
    currentJailId = jailId
    remainingTime = minutes
    currentReason = reason or 'Kein Grund angegeben'

    -- location = 'yard' -> im Hof spawnen (falls konfiguriert), sonst normale Zelle
    local spawnPool = jail.cellSpawns
    if location == 'yard' and jail.yardSpawns and #jail.yardSpawns > 0 then
        spawnPool = jail.yardSpawns
    end
    local spawn = spawnPool[math.random(#spawnPool)]
    local ped = PlayerPedId()

    DoScreenFadeOut(500)
    Wait(600)
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z)
    SetEntityHeading(ped, spawn.w)
    DoScreenFadeIn(500)

    ApplyPrisonClothes()

    Notify(Config.JailLocale.arrested:format(minutes, jail.label), 'error')
    StartEscapeWatch()
end

-- ####################################################
-- ##          ADMIN-JAIL (fixer Ort, kein jailId)     ##
-- ####################################################
-- Eigenständige Variante für /adminjail und /putinjail: kein Gefängnis aus
-- Config.Jails, sondern immer Config.AdminJail.Position. Escape-Alarm/Arbeiten/
-- Gym/Essen greifen hier bewusst nicht, da currentJailId dabei nil bleibt.

RegisterNetEvent('esx_jail:sendToAdminJail', function(minutes, reason)
    SendToAdminJail(minutes, reason)
end)

function SendToAdminJail(minutes, reason)
    isJailed = true
    currentJailId = nil
    remainingTime = minutes
    currentReason = reason or 'Kein Grund angegeben'

    local pos = Config.AdminJail.Position
    local ped = PlayerPedId()

    DoScreenFadeOut(500)
    Wait(600)
    SetEntityCoords(ped, pos.x, pos.y, pos.z)
    DoScreenFadeIn(500)

    ApplyPrisonClothes()

    Notify(Config.JailLocale.arrested:format(minutes, 'Admin-Jail'), 'error')
end

RegisterNetEvent('esx_jail:releaseFromAdminJail', function(returnCoords)
    isJailed = false
    currentJailId = nil
    remainingTime = 0
    currentReason = nil
    lib.hideTextUI()

    if returnCoords and returnCoords.x then
        local ped = PlayerPedId()
        DoScreenFadeOut(500)
        Wait(600)
        SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z)
        if returnCoords.h then
            SetEntityHeading(ped, returnCoords.h)
        end
        DoScreenFadeIn(500)
    end

    RestorePlayerClothes(nil)
    Notify(Config.JailLocale.released, 'success')
end)

RegisterNetEvent('esx_jail:updateAdminTimeDisplay', function(minutes)
    remainingTime = minutes
end)

-- ####################################################
-- ##                  ENTLASSEN                      ##
-- ####################################################

RegisterNetEvent('esx_jail:releaseFromJail', function(jailId, originalSkin)
    local jail = Config.Jails[jailId]
    isJailed = false
    currentJailId = nil
    remainingTime = 0
    currentReason = nil
    lib.hideTextUI() -- sofort ausblenden, nicht erst auf den nächsten Thread-Tick warten

    if jail then
        local ped = PlayerPedId()
        DoScreenFadeOut(500)
        Wait(600)
        SetEntityCoords(ped, jail.releaseCoords.x, jail.releaseCoords.y, jail.releaseCoords.z)
        SetEntityHeading(ped, jail.releaseCoords.w)
        DoScreenFadeIn(500)
    end

    RestorePlayerClothes(originalSkin)
    Notify(Config.JailLocale.released, 'success')
end)

RegisterNetEvent('esx_jail:updateTimeDisplay', function(minutes)
    remainingTime = minutes
end)

-- ####################################################
-- ##              STRÄFLINGS-KLEIDUNG                ##
-- ####################################################
-- Wichtig: die Original-Kleidung wird VOR dem Umziehen gesichert und an den
-- Server geschickt (jail_storage), damit sie auch nach Reconnect/Serverrestart
-- korrekt wiederhergestellt werden kann. Vorher wurde beim "Wiederherstellen"
-- versehentlich nur die aktuelle (=Gefängnis-)Kleidung erneut geladen.

function ApplyPrisonClothes()
    if not Config.PrisonClothes.enabled then return end
    local xPlayer = ESX.GetPlayerData()
    local skinSet = xPlayer.sex == 0 and Config.PrisonClothes.male or Config.PrisonClothes.female

    TriggerEvent('skinchanger:getSkin', function(currentSkin)
        -- Original-Skin sichern, BEVOR er überschrieben wird
        TriggerServerEvent('esx_jail:saveOriginalSkin', currentSkin)

        local prisonSkin = {}
        for k, v in pairs(currentSkin) do prisonSkin[k] = v end
        for k, v in pairs(skinSet) do prisonSkin[k] = v end

        -- Nur visuell laden, NICHT registrieren/speichern, damit die
        -- Gefängniskleidung nie in der echten Skin-Datenbank landet
        TriggerEvent('skinchanger:loadSkin', prisonSkin)
    end)
end

function RestorePlayerClothes(originalSkin)
    if not Config.PrisonClothes.enabled then return end

    if originalSkin then
        TriggerEvent('skinchanger:loadSkin', originalSkin)
        TriggerEvent('esx_skin:playerRegisterSkin', originalSkin)
    else
        -- Fallback falls kein Original-Skin übermittelt wurde: aus der
        -- persistierten Skin-Datenbank neu laden (nicht die aktuelle Optik nehmen!)
        TriggerEvent('esx_skin:setDefaultModel')
        TriggerEvent('skinchanger:getSkin', function(savedSkin)
            TriggerEvent('skinchanger:loadSkin', savedSkin)
        end)
    end
end

-- ####################################################
-- ##               HUD - RESTSTRAFE                  ##
-- ####################################################

CreateThread(function()
    local lastText = nil
    while true do
        Wait(0)
        if isJailed then
            local text = ('Inhaftiert - Reststrafe: %s Minute(n)\nGrund: %s'):format(remainingTime, currentReason or '-')
            if text ~= lastText then
                lib.showTextUI(text, {
                    position = 'top-center',
                    icon = 'handcuffs'
                })
                lastText = text
            end
        else
            if lastText ~= nil then
                lib.hideTextUI()
                lastText = nil
            end
            Wait(500)
        end
    end
end)

-- ####################################################
-- ##                FLUCHT-ERKENNUNG                 ##
-- ####################################################

function StartEscapeWatch()
    if escapeThreadActive or not Config.Escape.enabled then return end
    escapeThreadActive = true

    CreateThread(function()
        while isJailed do
            Wait(2000)
            local jail = Config.Jails[currentJailId]
            if jail then
                local coords = GetEntityCoords(PlayerPedId())
                local dist = #(coords - jail.zone.center)
                if dist > jail.zone.radius then
                    if Config.Escape.preventEscape then
                        local spawn = jail.cellSpawns[1]
                        SetEntityCoords(PlayerPedId(), spawn.x, spawn.y, spawn.z)
                        Notify('Du kannst nicht fliehen!', 'error')
                    else
                        TriggerServerEvent('esx_jail:escapeAttempt', currentJailId)
                        TriggerServerEvent('esx_jail:escapeCoords', currentJailId, coords)
                    end
                end
            end
        end
        escapeThreadActive = false
    end)
end

RegisterNetEvent('esx_jail:escapeAlert', function(jailLabel, inmateName)
    Notify(Config.JailLocale.escape_alert:format(jailLabel), 'error')
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', true)
end)

-- ####################################################
-- ##       AUSBRUCH PER MINISPIEL (/ausbrechen)      ##
-- ####################################################
-- Gilt bewusst NUR fürs normale Jail (currentJailId muss gesetzt sein) -
-- bei /adminjail bleibt currentJailId nil, der Befehl greift dort also
-- gar nicht erst (AdminJail soll unverändert bleiben).
local lastEscapeMinigameAttempt = 0

RegisterCommand(Config.Escape.minigame.command, function()
    if not Config.Escape.enabled or not Config.Escape.minigame.enabled then return end

    if not isJailed or not currentJailId then
        Notify('Du kannst hier nicht so ausbrechen.', 'error')
        return
    end

    local now = GetGameTimer()
    local cooldownMs = (Config.Escape.minigame.cooldown or 120) * 1000
    if now - lastEscapeMinigameAttempt < cooldownMs then
        local waitLeft = math.ceil((cooldownMs - (now - lastEscapeMinigameAttempt)) / 1000)
        Notify(('Warte noch %d Sekunden, bevor du es erneut versuchst.'):format(waitLeft), 'error')
        return
    end
    lastEscapeMinigameAttempt = now

    local success = lib.skillCheck(Config.Escape.minigame.difficulty)

    if success then
        TriggerServerEvent('esx_jail:escapeMinigameSuccess', currentJailId)
    else
        Notify('Ausbruch fehlgeschlagen!', 'error')
        TriggerServerEvent('esx_jail:escapeMinigameFail', currentJailId)
    end
end, false)

RegisterNetEvent('esx_jail:escapeBlip', function(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.Escape.blipSprite)
    SetBlipColour(blip, Config.Escape.blipColor)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Flüchtiger Insasse')
    EndTextCommandSetBlipName(blip)
    SetTimeout(60000, function()
        RemoveBlip(blip)
    end)
end)

-- ####################################################
-- ##                    ARBEITEN                     ##
-- ####################################################

CreateThread(function()
    for jailId, jail in pairs(Config.Jails) do
        for i, work in ipairs(jail.workPoints) do
            lib.zones.sphere({
                coords = work.coords,
                radius = 1.5,
                debug = false,
                onEnter = function()
                    if isJailed and currentJailId == jailId then
                        lib.showTextUI('[E] ' .. work.label)
                    end
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    if isJailed and currentJailId == jailId and IsControlJustReleased(0, 38) then -- E
                        lib.hideTextUI()
                        if lib.progressCircle({
                            duration = work.duration,
                            label = work.label,
                            useWhileDead = false,
                            canCancel = true,
                            disable = { move = true, car = true, combat = true },
                            anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                        }) then
                            TriggerServerEvent('esx_jail:workComplete', i, jailId)
                        end
                    end
                end
            })
        end
    end
end)

-- ####################################################
-- ##                     GYM                         ##
-- ####################################################

local gymCooldown = 0

CreateThread(function()
    if not Config.Gym.enabled then return end
    for jailId, jail in pairs(Config.Jails) do
        for _, coords in ipairs(jail.gymPoints) do
            lib.zones.sphere({
                coords = coords,
                radius = 1.5,
                onEnter = function()
                    if isJailed and currentJailId == jailId then
                        lib.showTextUI('[E] Trainieren')
                    end
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    if isJailed and currentJailId == jailId and IsControlJustReleased(0, 38) then
                        if GetGameTimer() < gymCooldown then
                            Notify('Du bist noch erschöpft.', 'error')
                            return
                        end
                        lib.hideTextUI()
                        local ped = PlayerPedId()
                        RequestAnimDict(Config.Gym.animDict)
                        while not HasAnimDictLoaded(Config.Gym.animDict) do Wait(10) end
                        TaskPlayAnim(ped, Config.Gym.animDict, Config.Gym.anim, 8.0, -8.0, Config.Gym.duration, 1, 0, false, false, false)
                        lib.progressBar({
                            duration = Config.Gym.duration,
                            label = 'Training...',
                            canCancel = false,
                        })
                        ClearPedTasks(ped)
                        gymCooldown = GetGameTimer() + (Config.Gym.cooldown * 1000)
                        Notify('Du fühlst dich fitter.', 'success')
                    end
                end
            })
        end
    end
end)

-- ####################################################
-- ##               ESSEN / TRINKEN                   ##
-- ####################################################

RegisterCommand('givefood', function()
    if not Config.Food.enabled then return end
    local jobName = GetJobName()
    if not jobName then return end

    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > Config.Food.interactDistance then
        Notify(Config.JailLocale.player_not_found, 'error')
        return
    end

    local targetServerId = GetPlayerServerId(closestPlayer)

    local options = {}
    for _, itemCfg in ipairs(Config.Food.items) do
        options[#options + 1] = {
            title = itemCfg.label,
            onSelect = function()
                TriggerServerEvent('esx_jail:giveFood', targetServerId, itemCfg)
            end
        }
    end

    lib.registerContext({ id = 'jail_food_menu', title = 'Insassen versorgen', options = options })
    lib.showContext('jail_food_menu')
end)

RegisterNetEvent('esx_jail:consumeFood', function(itemConfig)
    if itemConfig.hunger then
        TriggerEvent('esx_status:add', 'hunger', itemConfig.hunger)
    end
    if itemConfig.thirst then
        TriggerEvent('esx_status:add', 'thirst', itemConfig.thirst)
    end
    Notify('Du hast etwas bekommen.', 'success')
end)

-- ####################################################
-- ##                  BESTECHUNG                     ##
-- ####################################################

RegisterCommand('bribe', function()
    if not isJailed or not Config.Bribe.enabled then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local nearbyGuards = {}

    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= ped then
            local dist = #(coords - GetEntityCoords(targetPed))
            if dist <= Config.Bribe.guardDistance then
                nearbyGuards[#nearbyGuards + 1] = GetPlayerServerId(playerId)
            end
        end
    end

    local confirmed = lib.alertDialog({
        header = 'Bestechung',
        content = ('Möchtest du versuchen den Wächter für $%s zu bestechen?'):format(Config.Bribe.cost),
        centered = true,
        cancel = true
    })

    if confirmed == 'confirm' then
        TriggerServerEvent('esx_jail:bribeAttempt', nearbyGuards)
    end
end)

-- ####################################################
-- ##            VERHAFTEN (POLIZEI-SEITE)            ##
-- ####################################################

RegisterCommand('arrest', function()
    local jobName = GetJobName()
    if not jobName then return end

    local isAllowed = false
    for _, job in ipairs(Config.ArrestJobs) do
        if jobName == job then isAllowed = true end
    end
    if not isAllowed then
        Notify(Config.JailLocale.not_allowed_job, 'error')
        return
    end

    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > Config.ArrestDistance then
        Notify(Config.JailLocale.player_not_found, 'error')
        return
    end

    local targetServerId = GetPlayerServerId(closestPlayer)

    local jailOptions = {}
    for jailId, jail in pairs(Config.Jails) do
        jailOptions[#jailOptions + 1] = { value = jailId, label = jail.label }
    end

    local input = lib.inputDialog('Spieler verhaften', {
        { type = 'select', label = 'Gefängnis', options = jailOptions, required = true },
        { type = 'number', label = 'Dauer (Minuten)', required = true, min = 1, default = 10 },
        { type = 'input', label = 'Grund', required = true },
    })

    if not input then return end

    TriggerServerEvent('esx_jail:arrestPlayer', targetServerId, tonumber(input[1]), tonumber(input[2]), input[3])
end, false)

-- ####################################################
-- ##                GEFÄNGNIS-BLIPS                  ##
-- ####################################################

CreateThread(function()
    for jailId, jail in pairs(Config.Jails) do
        local blip = AddBlipForCoord(jail.managementPed.coords.x, jail.managementPed.coords.y, jail.managementPed.coords.z)
        SetBlipSprite(blip, 141)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(jail.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ####################################################
-- ##             VERWALTUNGS-MENÜ (PED)               ##
-- ####################################################


local spawnedPeds = {}

CreateThread(function()
    for jailId, jail in pairs(Config.Jails) do
        local modelHash = jail.managementPed.model

        if not IsModelValid(modelHash) then
            print(('[esx_jail] WARNUNG: Ped-Modell "%s" für Gefängnis "%s" ist ungültig! Ped wird übersprungen.'):format(modelHash, jail.label))
            goto continue
        end

        RequestModel(modelHash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(modelHash) do
            Wait(10)
            if GetGameTimer() > timeout then
                print(('[esx_jail] WARNUNG: Ped-Modell "%s" für Gefängnis "%s" konnte nicht geladen werden (Timeout).'):format(modelHash, jail.label))
                goto continue
            end
        end

        local c = jail.managementPed.coords
        local ped = CreatePed(4, modelHash, c.x, c.y, c.z - 1.0, c.w, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GUARD_STAND', 0, true)
        spawnedPeds[#spawnedPeds + 1] = ped

        -- Native Interaktion statt ox_target: einfach in die Nähe gehen und [E] drücken
        local zoneCoords = vector3(c.x, c.y, c.z)
        lib.zones.sphere({
            coords = zoneCoords,
            radius = 1.5,
            onEnter = function()
                lib.showTextUI('[E] Gefängnis verwalten')
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustReleased(0, 38) then -- E
                    lib.hideTextUI()
                    OpenManagementMenu(jailId)
                end
            end
        })

        ::continue::
    end
end)

function OpenManagementMenu(jailId)
    local jail = Config.Jails[jailId]

    -- Eigenständiges Menü des jeweiligen Gefängnisses: keine Vermischung mehr mit
    -- dem Admin-Jail-System (/adminjail) - das bleibt komplett separat.
    local options = {
        {
            title = 'Insassen anzeigen',
            icon = 'user-group',
            onSelect = function() OpenInmatesMenu(jailId) end
        },
        {
            title = 'Protokoll anzeigen',
            icon = 'clipboard-list',
            onSelect = function() OpenLogMenu(jailId, 0) end
        },
        {
            title = 'Spieler einsperren',
            icon = 'user-lock',
            onSelect = function() OpenJailPlayerMenu(jailId, 'jail_main_menu') end
        },
    }

    lib.registerContext({
        id = 'jail_main_menu',
        title = jail.label,
        options = options
    })
    lib.showContext('jail_main_menu')
end

-- Sperrt einen Spieler direkt über das Verwaltungsmenü DIESES Gefängnisses ein.
-- Im Gegensatz zu /arrest (Nähe-Check) und dem Admin-Jail (fixer Ort) kann hier
-- gewählt werden, ob der Insasse in einer Zelle oder im Hof landet.
function OpenJailPlayerMenu(jailId, parentMenu)
    parentMenu = parentMenu or 'jail_main_menu'
    local jail = Config.Jails[jailId]

    ESX.TriggerServerCallback('esx_jail:getOnlinePlayers', function(players)
        local options = {}
        for _, p in ipairs(players) do
            options[#options + 1] = {
                -- Nur der Name wird angezeigt (keine ID mehr) - Wunsch: "nur Spieler-Name
                -- in der Liste". AdminJail-Menü (weiter unten) bleibt bewusst unverändert.
                title = p.name,
                icon = 'user',
                onSelect = function()
                    local locationOptions = {
                        { value = 'cell', label = 'Zelle' },
                        { value = 'yard', label = 'Hof' },
                    }

                    local input = lib.inputDialog(('%s einsperren'):format(p.name), {
                        { type = 'select', label = 'Ort', options = locationOptions, required = true, default = 'cell' },
                        { type = 'number', label = 'Dauer (Minuten)', required = true, min = 1, default = 10 },
                        { type = 'input', label = 'Grund', required = true },
                    })
                    if not input then return end

                    local location = input[1]
                    local minutes = tonumber(input[2])
                    local reason = input[3]

                    TriggerServerEvent('esx_jail:jailPlayerFromMenu', p.id, jailId, location, minutes, reason)
                end
            }
        end
        if #options == 0 then
            options[1] = { title = 'Keine Spieler online', disabled = true }
        end

        lib.registerContext({
            id = 'jail_player_menu_' .. jailId,
            title = 'Spieler einsperren - ' .. jail.label,
            menu = parentMenu,
            options = options
        })
        lib.showContext('jail_player_menu_' .. jailId)
    end)
end

function OpenInmatesMenu(jailId)
    ESX.TriggerServerCallback('esx_jail:getInmates', function(inmates)
        local options = {}
        for _, inmate in ipairs(inmates) do
            options[#options + 1] = {
                title = inmate.name,
                description = ('Reststrafe: %s Minute(n) | %s'):format(inmate.time, inmate.online and 'Online' or 'Offline'),
                icon = 'user',
                onSelect = function() OpenInmateActionsMenu(jailId, inmate) end
            }
        end
        if #options == 0 then
            options[1] = { title = 'Keine Insassen', disabled = true }
        end

        lib.registerContext({
            id = 'jail_inmates_menu',
            title = 'Insassen - ' .. Config.Jails[jailId].label,
            menu = 'jail_main_menu',
            options = options
        })
        lib.showContext('jail_inmates_menu')
    end, jailId)
end

function OpenInmateActionsMenu(jailId, inmate)
    lib.registerContext({
        id = 'jail_inmate_actions',
        title = inmate.name,
        menu = 'jail_inmates_menu',
        options = {
            {
                title = 'Reststrafe ändern',
                icon = 'clock',
                onSelect = function()
                    local input = lib.inputDialog('Reststrafe ändern', {
                        { type = 'number', label = 'Minuten', default = inmate.time, required = true, min = 0 }
                    })
                    if input then
                        TriggerServerEvent('esx_jail:updateTime', inmate.identifier, tonumber(input[1]))
                    end
                end
            },
            {
                title = 'Entlassen',
                icon = 'door-open',
                onSelect = function()
                    local confirmed = lib.alertDialog({
                        header = 'Insasse entlassen',
                        content = ('Möchtest du %s wirklich entlassen?'):format(inmate.name),
                        cancel = true
                    })
                    if confirmed == 'confirm' then
                        TriggerServerEvent('esx_jail:releaseByOfficer', inmate.identifier)
                    end
                end
            }
        }
    })
    lib.showContext('jail_inmate_actions')
end

function OpenLogMenu(jailId, page)
    ESX.TriggerServerCallback('esx_jail:getLog', function(logs)
        local options = {}
        for _, entry in ipairs(logs) do
            options[#options + 1] = {
                title = ('%s - %s'):format(entry.name, entry.action),
                description = ('%s | %s'):format(entry.details, entry.created_at),
            }
        end
        if #options == 0 then
            options[1] = { title = 'Keine Einträge', disabled = true }
        end

        lib.registerContext({
            id = 'jail_log_menu',
            title = 'Protokoll - ' .. Config.Jails[jailId].label,
            menu = 'jail_main_menu',
            options = options
        })
        lib.showContext('jail_log_menu')
    end, jailId, page)
end

-- ####################################################
-- ##                 ADMIN-MENÜ                      ##
-- ####################################################
-- /adminjail ist wieder ein eigenständiges Menü (nur "Spieler einsperren" /
-- "Insassen verwalten"), unabhängig vom Ped-Menü. Beim Einsperren gibt es keine
-- Gefängnis-Auswahl mehr - der Spieler wird immer zu Config.AdminJail.Position
-- teleportiert und bei Entlassung/Ablauf an seine ursprüngliche Position zurück.

if Config.AdminJail.enabled then
    RegisterCommand(Config.AdminJail.menuCommand, function()
        ESX.TriggerServerCallback('esx_jail:isAdmin', function(isAdmin)
            if not isAdmin then
                Notify('Keine Berechtigung.', 'error')
                return
            end

            lib.registerContext({
                id = 'jail_admin_menu',
                title = 'Jail - Admin',
                options = {
                    {
                        title = 'Spieler einsperren',
                        icon = 'user-lock',
                        onSelect = function() OpenAdminJailPlayerMenu() end
                    },
                    {
                        title = 'Insassen verwalten',
                        icon = 'people-group',
                        onSelect = function() OpenAdminInmatesMenu() end
                    }
                }
            })
            lib.showContext('jail_admin_menu')
        end)
    end, false)
end

-- Baut die Dauer-Optionen (inkl. Presets aus Config.AdminJail) für die Eingabemaske
local function BuildAdminDurationOptions()
    local durationOptions = {}
    for _, minutes in ipairs(Config.AdminJail.durationPresets or {}) do
        durationOptions[#durationOptions + 1] = { value = minutes, label = ('%s Minuten'):format(minutes) }
    end
    if Config.AdminJail.allowCustomDuration then
        durationOptions[#durationOptions + 1] = { value = 'custom', label = 'Eigene Eingabe...' }
    end
    return durationOptions
end

function OpenAdminJailPlayerMenu(parentMenu)
    parentMenu = parentMenu or 'jail_admin_menu'
    ESX.TriggerServerCallback('esx_jail:adminGetPlayers', function(players)
        local options = {}
        for _, p in ipairs(players) do
            options[#options + 1] = {
                title = ('[%s] %s'):format(p.id, p.name),
                icon = 'user',
                onSelect = function()
                    local durationOptions = BuildAdminDurationOptions()

                    local input = lib.inputDialog(('%s einsperren'):format(p.name), {
                        { type = 'select', label = 'Dauer', options = durationOptions, required = true },
                        { type = 'input', label = 'Grund', required = false },
                    })
                    if not input then return end

                    local duration = input[1]
                    local reason = input[2] or ''

                    if duration == 'custom' then
                        local customInput = lib.inputDialog('Eigene Dauer', {
                            { type = 'number', label = 'Dauer (Minuten)', required = true, min = 1, default = 10 }
                        })
                        if not customInput then return end
                        duration = tonumber(customInput[1])
                    else
                        duration = tonumber(duration)
                    end

                    TriggerServerEvent('esx_jail:adminJailPlayer', p.id, duration, reason)
                end
            }
        end
        if #options == 0 then
            options[1] = { title = 'Keine Spieler online', disabled = true }
        end

        lib.registerContext({
            id = 'jail_admin_player_menu',
            title = 'Spieler auswählen',
            menu = parentMenu,
            options = options
        })
        lib.showContext('jail_admin_player_menu')
    end)
end

function OpenAdminInmatesMenu(parentMenu)
    parentMenu = parentMenu or 'jail_admin_menu'
    ESX.TriggerServerCallback('esx_jail:adminGetAllInmates', function(inmates)
        local options = {}
        for _, inmate in ipairs(inmates) do
            options[#options + 1] = {
                title = inmate.name,
                description = ('Reststrafe: %s Minute(n) | %s'):format(inmate.time, inmate.online and 'Online' or 'Offline'),
                icon = 'user',
                onSelect = function() OpenAdminInmateActionsMenu(inmate) end
            }
        end
        if #options == 0 then
            options[1] = { title = 'Keine Insassen', disabled = true }
        end

        lib.registerContext({
            id = 'jail_admin_inmates_menu',
            title = 'Insassen',
            menu = parentMenu,
            options = options
        })
        lib.showContext('jail_admin_inmates_menu')
    end)
end

function OpenAdminInmateActionsMenu(inmate)
    lib.registerContext({
        id = 'jail_admin_inmate_actions',
        title = inmate.name,
        menu = 'jail_admin_inmates_menu',
        options = {
            {
                title = 'Reststrafe ändern',
                icon = 'clock',
                onSelect = function()
                    local input = lib.inputDialog('Reststrafe ändern', {
                        { type = 'number', label = 'Minuten', default = inmate.time, required = true, min = 0 }
                    })
                    if input then
                        TriggerServerEvent('esx_jail:adminUpdateTime', inmate.identifier, tonumber(input[1]))
                    end
                end
            },
            {
                title = 'Entlassen',
                icon = 'door-open',
                onSelect = function()
                    local confirmed = lib.alertDialog({
                        header = 'Insasse entlassen',
                        content = ('Möchtest du %s wirklich entlassen?'):format(inmate.name),
                        cancel = true
                    })
                    if confirmed == 'confirm' then
                        TriggerServerEvent('esx_jail:adminRelease', inmate.identifier)
                    end
                end
            }
        }
    })
    lib.showContext('jail_admin_inmate_actions')
end

-- ####################################################
-- ##                    CLEANUP                      ##
-- ####################################################

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, ped in ipairs(spawnedPeds) do
        DeleteEntity(ped)
    end
end)

-- ============================================================
-- MODUL: AntiVDM - CLIENT
-- ============================================================
-- Übernommen aus dem eigenständigen "AntiVDM"-Script.
-- Über Config.AntiVDM.enabled an/aus schaltbar (wird jeden Tick geprüft).
-- ============================================================

CreateThread(function()
    while true do
        Wait(0)
        if Config.AntiVDM.enabled then
            for _, hash in ipairs(Config.AntiVDM.weaponHashes) do
                SetWeaponDamageModifier(hash, Config.AntiVDM.damageModifier)
            end
        end
    end
end)

-- ============================================================
-- MODUL: PiggyBack - CLIENT
-- ============================================================
-- Übernommen aus dem eigenständigen "PiggyBack"-Script.
-- Über Config.PiggyBack.enabled an/aus schaltbar.
-- Hilfsfunktionen wurden mit "PB_" Präfix versehen, da TakeHostage
-- (ebenfalls unten gemergt) identisch benannte lokale Hilfsfunktionen
-- mitbringt (drawNativeNotification/GetClosestPlayer/ensureAnimDict).
-- ============================================================

local piggybackState = {
    InProgress = false,
    targetSrc = -1,
    type = "",
    personPiggybacking = {
        animDict = "anim@arena@celeb@flat@paired@no_props@",
        anim = "piggyback_c_player_a",
        flag = 49,
    },
    personBeingPiggybacked = {
        animDict = "anim@arena@celeb@flat@paired@no_props@",
        anim = "piggyback_c_player_b",
        attachX = 0.0,
        attachY = -0.07,
        attachZ = 0.45,
        flag = 33,
    }
}

local function PB_Notify(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

local function PB_GetClosestPlayer(radius)
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(targetCoords - playerCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    if closestDistance ~= -1 and closestDistance <= radius then
        return closestPlayer
    else
        return nil
    end
end

local function PB_EnsureAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end
    end
    return animDict
end

RegisterCommand(Config.PiggyBack.command, function(source, args)
    if not Config.PiggyBack.enabled then return end

    if not piggybackState.InProgress then
        local closestPlayer = PB_GetClosestPlayer(Config.PiggyBack.maxDistance)
        if closestPlayer then
            local targetSrc = GetPlayerServerId(closestPlayer)
            if targetSrc ~= -1 then
                piggybackState.InProgress = true
                piggybackState.targetSrc = targetSrc
                TriggerServerEvent("Piggyback:sync", targetSrc)
                PB_EnsureAnimDict(piggybackState.personPiggybacking.animDict)
                piggybackState.type = "piggybacking"
            else
                PB_Notify("~r~Niemand in der Nähe zum Huckepack-Tragen!")
            end
        else
            PB_Notify("~r~Niemand in der Nähe zum Huckepack-Tragen!")
        end
    else
        piggybackState.InProgress = false
        ClearPedSecondaryTask(PlayerPedId())
        DetachEntity(PlayerPedId(), true, false)
        TriggerServerEvent("Piggyback:stop", piggybackState.targetSrc)
        piggybackState.targetSrc = 0
    end
end, false)

RegisterNetEvent("Piggyback:syncTarget")
AddEventHandler("Piggyback:syncTarget", function(targetSrc)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
    piggybackState.InProgress = true
    PB_EnsureAnimDict(piggybackState.personBeingPiggybacked.animDict)
    AttachEntityToEntity(PlayerPedId(), targetPed, 0, piggybackState.personBeingPiggybacked.attachX, piggybackState.personBeingPiggybacked.attachY, piggybackState.personBeingPiggybacked.attachZ, 0.5, 0.5, 180, false, false, false, false, 2, false)
    piggybackState.type = "beingPiggybacked"
end)

RegisterNetEvent("Piggyback:cl_stop")
AddEventHandler("Piggyback:cl_stop", function()
    piggybackState.InProgress = false
    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
end)

CreateThread(function()
    while true do
        if piggybackState.InProgress then
            if piggybackState.type == "beingPiggybacked" then
                if not IsEntityPlayingAnim(PlayerPedId(), piggybackState.personBeingPiggybacked.animDict, piggybackState.personBeingPiggybacked.anim, 3) then
                    TaskPlayAnim(PlayerPedId(), piggybackState.personBeingPiggybacked.animDict, piggybackState.personBeingPiggybacked.anim, 8.0, -8.0, 100000, piggybackState.personBeingPiggybacked.flag, 0, false, false, false)
                end
            elseif piggybackState.type == "piggybacking" then
                if not IsEntityPlayingAnim(PlayerPedId(), piggybackState.personPiggybacking.animDict, piggybackState.personPiggybacking.anim, 3) then
                    TaskPlayAnim(PlayerPedId(), piggybackState.personPiggybacking.animDict, piggybackState.personPiggybacking.anim, 8.0, -8.0, 100000, piggybackState.personPiggybacking.flag, 0, false, false, false)
                end
            end
        end
        Wait(0)
    end
end)

-- ============================================================
-- MODUL: TakeHostage - CLIENT
-- ============================================================
-- Übernommen aus dem eigenständigen "TakeHostage"-Script.
-- Über Config.TakeHostage.enabled an/aus schaltbar.
-- Hilfsfunktionen wurden mit "TH_" Präfix versehen (Konflikt mit
-- identisch benannten lokalen Helpern aus dem PiggyBack-Modul oben).
-- ============================================================

local takeHostageState = {
    InProgress = false,
    type = "",
    targetSrc = -1,
    agressor = {
        animDict = "anim@gangops@hostage@",
        anim = "perp_idle",
        flag = 49,
    },
    hostage = {
        animDict = "anim@gangops@hostage@",
        anim = "victim_idle",
        attachX = -0.24,
        attachY = 0.11,
        attachZ = 0.0,
        flag = 49,
    }
}

local function TH_Notify(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

local function TH_GetClosestPlayer(radius)
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(targetCoords - playerCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    if closestDistance ~= -1 and closestDistance <= radius then
        return closestPlayer
    else
        return nil
    end
end

local function TH_EnsureAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end
    end
    return animDict
end

local function TH_DrawText(str)
    SetTextEntry_2("STRING")
    AddTextComponentString(str)
    EndTextCommandPrint(1000, 1)
end

local function TH_CallTakeHostage()
    if not Config.TakeHostage.enabled then return end

    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)

    local canTakeHostage = false
    local foundWeapon = nil
    for i = 1, #Config.TakeHostage.allowedWeapons do
        if HasPedGotWeapon(PlayerPedId(), Config.TakeHostage.allowedWeapons[i], false) then
            if GetAmmoInPedWeapon(PlayerPedId(), Config.TakeHostage.allowedWeapons[i]) > 0 then
                canTakeHostage = true
                foundWeapon = Config.TakeHostage.allowedWeapons[i]
                break
            end
        end
    end

    if not canTakeHostage then
        TH_Notify("Du brauchst eine Pistole mit Munition, um jemanden als Geisel zu nehmen!")
        return
    end

    if not takeHostageState.InProgress then
        local closestPlayer = TH_GetClosestPlayer(Config.TakeHostage.maxDistance)
        if closestPlayer then
            local targetSrc = GetPlayerServerId(closestPlayer)
            if targetSrc ~= -1 then
                SetCurrentPedWeapon(PlayerPedId(), foundWeapon, true)
                takeHostageState.InProgress = true
                takeHostageState.targetSrc = targetSrc
                TriggerServerEvent("TakeHostage:sync", targetSrc)
                TH_EnsureAnimDict(takeHostageState.agressor.animDict)
                takeHostageState.type = "agressor"
            else
                TH_Notify("~r~Niemand in der Nähe, um als Geisel genommen zu werden!")
            end
        else
            TH_Notify("~r~Niemand in der Nähe, um als Geisel genommen zu werden!")
        end
    end
end

RegisterCommand(Config.TakeHostage.command, function()
    TH_CallTakeHostage()
end, false)

RegisterCommand(Config.TakeHostage.shortCommand, function()
    TH_CallTakeHostage()
end, false)

RegisterNetEvent("TakeHostage:syncTarget")
AddEventHandler("TakeHostage:syncTarget", function(target)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(target))
    takeHostageState.InProgress = true
    TH_EnsureAnimDict(takeHostageState.hostage.animDict)
    AttachEntityToEntity(PlayerPedId(), targetPed, 0, takeHostageState.hostage.attachX, takeHostageState.hostage.attachY, takeHostageState.hostage.attachZ, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
    takeHostageState.type = "hostage"
end)

RegisterNetEvent("TakeHostage:releaseHostage")
AddEventHandler("TakeHostage:releaseHostage", function()
    takeHostageState.InProgress = false
    takeHostageState.type = ""
    DetachEntity(PlayerPedId(), true, false)
    TH_EnsureAnimDict("reaction@shove")
    TaskPlayAnim(PlayerPedId(), "reaction@shove", "shoved_back", 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(250)
    ClearPedSecondaryTask(PlayerPedId())
end)

RegisterNetEvent("TakeHostage:killHostage")
AddEventHandler("TakeHostage:killHostage", function()
    takeHostageState.InProgress = false
    takeHostageState.type = ""
    SetEntityHealth(PlayerPedId(), 0)
    DetachEntity(PlayerPedId(), true, false)
    TH_EnsureAnimDict("anim@gangops@hostage@")
    TaskPlayAnim(PlayerPedId(), "anim@gangops@hostage@", "victim_fail", 8.0, -8.0, -1, 168, 0, false, false, false)
end)

RegisterNetEvent("TakeHostage:cl_stop")
AddEventHandler("TakeHostage:cl_stop", function()
    takeHostageState.InProgress = false
    takeHostageState.type = ""
    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
end)

CreateThread(function()
    while true do
        if takeHostageState.type == "agressor" then
            if not IsEntityPlayingAnim(PlayerPedId(), takeHostageState.agressor.animDict, takeHostageState.agressor.anim, 3) then
                TaskPlayAnim(PlayerPedId(), takeHostageState.agressor.animDict, takeHostageState.agressor.anim, 8.0, -8.0, 100000, takeHostageState.agressor.flag, 0, false, false, false)
            end
        elseif takeHostageState.type == "hostage" then
            if not IsEntityPlayingAnim(PlayerPedId(), takeHostageState.hostage.animDict, takeHostageState.hostage.anim, 3) then
                TaskPlayAnim(PlayerPedId(), takeHostageState.hostage.animDict, takeHostageState.hostage.anim, 8.0, -8.0, 100000, takeHostageState.hostage.flag, 0, false, false, false)
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        if takeHostageState.type == "agressor" then
            DisableControlAction(0, 24, true) -- disable attack
            DisableControlAction(0, 25, true) -- disable aim
            DisableControlAction(0, 47, true) -- disable weapon
            DisableControlAction(0, 58, true) -- disable weapon
            DisableControlAction(0, 21, true) -- disable sprint
            DisablePlayerFiring(PlayerPedId(), true)
            TH_DrawText("Drücke [G] zum Freilassen, [H] zum Töten")

            if IsEntityDead(PlayerPedId()) then
                takeHostageState.type = ""
                takeHostageState.InProgress = false
                TH_EnsureAnimDict("reaction@shove")
                TaskPlayAnim(PlayerPedId(), "reaction@shove", "shove_var_a", 8.0, -8.0, -1, 168, 0, false, false, false)
                TriggerServerEvent("TakeHostage:releaseHostage", takeHostageState.targetSrc)
            end

            if IsDisabledControlJustPressed(0, 47) then -- release
                takeHostageState.type = ""
                takeHostageState.InProgress = false
                TH_EnsureAnimDict("reaction@shove")
                TaskPlayAnim(PlayerPedId(), "reaction@shove", "shove_var_a", 8.0, -8.0, -1, 168, 0, false, false, false)
                TriggerServerEvent("TakeHostage:releaseHostage", takeHostageState.targetSrc)
            elseif IsDisabledControlJustPressed(0, 74) then -- kill
                takeHostageState.type = ""
                takeHostageState.InProgress = false
                TH_EnsureAnimDict("anim@gangops@hostage@")
                TaskPlayAnim(PlayerPedId(), "anim@gangops@hostage@", "perp_fail", 8.0, -8.0, -1, 168, 0, false, false, false)
                TriggerServerEvent("TakeHostage:killHostage", takeHostageState.targetSrc)
                TriggerServerEvent("TakeHostage:stop", takeHostageState.targetSrc)
                Wait(100)
                SetPedShootsAtCoord(PlayerPedId(), 0.0, 0.0, 0.0, 0)
            end
        elseif takeHostageState.type == "hostage" then
            DisableControlAction(0, 21, true) -- disable sprint
            DisableControlAction(0, 24, true) -- disable attack
            DisableControlAction(0, 25, true) -- disable aim
            DisableControlAction(0, 47, true) -- disable weapon
            DisableControlAction(0, 58, true) -- disable weapon
            DisableControlAction(0, 263, true) -- disable melee
            DisableControlAction(0, 264, true) -- disable melee
            DisableControlAction(0, 257, true) -- disable melee
            DisableControlAction(0, 140, true) -- disable melee
            DisableControlAction(0, 141, true) -- disable melee
            DisableControlAction(0, 142, true) -- disable melee
            DisableControlAction(0, 143, true) -- disable melee
            DisableControlAction(0, 75, true) -- disable exit vehicle
            DisableControlAction(27, 75, true) -- disable exit vehicle
            DisableControlAction(0, 22, true) -- disable jump
            DisableControlAction(0, 32, true) -- disable move up
            DisableControlAction(0, 268, true)
            DisableControlAction(0, 33, true) -- disable move down
            DisableControlAction(0, 269, true)
            DisableControlAction(0, 34, true) -- disable move left
            DisableControlAction(0, 270, true)
            DisableControlAction(0, 35, true) -- disable move right
            DisableControlAction(0, 271, true)
        end
        Wait(0)
    end
end)

-- ============================================================
-- MODUL: Lifeinvader - CLIENT
-- ============================================================
-- Über Config.Lifeinvader.enabled an/aus schaltbar. Preis wird nur
-- zur Anzeige lokal berechnet - die verbindliche Berechnung und
-- alle Prüfungen (Länge, verbotene Wörter, Cooldown, Geld) laufen
-- ausschließlich serverseitig (siehe server.lua), damit nichts über
-- den Client manipuliert werden kann.
-- ============================================================

do
    local liOpen = false
    local liBlip = nil
    local liFeedCache = {} -- lokaler Spiegel des Server-Feeds, für sofortige Anzeige beim Öffnen

    CreateThread(function()
        if not Config.Lifeinvader.enabled then return end
        if not Config.Lifeinvader.location.blip.enabled then return end

        local b = Config.Lifeinvader.location.blip
        local loc = Config.Lifeinvader.location.coords

        liBlip = AddBlipForCoord(loc.x, loc.y, loc.z)
        SetBlipSprite(liBlip, b.sprite)
        SetBlipColour(liBlip, b.color)
        SetBlipScale(liBlip, b.scale)
        SetBlipAsShortRange(liBlip, true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(b.label)
        EndTextCommandSetBlipName(liBlip)
    end)

    -- Optionaler NPC direkt am Terminal (rein optisch, kein Dialog nötig)
    CreateThread(function()
        if not Config.Lifeinvader.enabled then return end

        local npc = Config.Lifeinvader.location.npc
        if not npc or not npc.enabled then return end

        RequestModel(npc.model)
        local timeout = 0
        while not HasModelLoaded(npc.model) and timeout < 5000 do
            Wait(10)
            timeout = timeout + 10
        end
        if not HasModelLoaded(npc.model) then return end

        local ped = CreatePed(4, npc.model, npc.coords.x, npc.coords.y, npc.coords.z - 1.0, npc.coords.w, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        FreezeEntityPosition(ped, true)
        SetPedCanRagdoll(ped, false)
        SetPedDiesWhenInjured(ped, false)
        SetEntityInvincible(ped, true)

        if npc.scenario and npc.scenario ~= '' then
            TaskStartScenarioInPlace(ped, npc.scenario, 0, true)
        end

        SetModelAsNoLongerNeeded(npc.model)
    end)

    local function OpenLifeinvaderMenu()
        if liOpen then return end
        liOpen = true

        if Config.Lifeinvader.openSound then
            PlaySoundFrontend(-1, Config.Lifeinvader.openSoundName, Config.Lifeinvader.openSoundSet, true)
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openLifeinvader",
            serverName = Config.Lifeinvader.serverName,
            logo = Config.Lifeinvader.logo,
            maxLength = Config.Lifeinvader.maxLength,
            priceMode = Config.Lifeinvader.price.mode,
            priceFixed = Config.Lifeinvader.price.fixed,
            pricePerChar = Config.Lifeinvader.price.perChar,
            allowName = Config.Lifeinvader.allowName,
            nameDefault = Config.Lifeinvader.nameDefault,
            fields = Config.Lifeinvader.fields,
            feedEnabled = Config.Lifeinvader.feed.enabled,
            feedMaxAgeMinutes = Config.Lifeinvader.feed.maxAgeMinutes,
            feed = liFeedCache,
        })

        if Config.Lifeinvader.feed.enabled then
            TriggerServerEvent(Config.Lifeinvader.eventPrefix .. ":requestFeed")
        end
    end

    RegisterNUICallback("closeLifeinvader", function(_, cb)
        liOpen = false
        SetNuiFocus(false, false)
        cb("ok")
    end)

    RegisterNUICallback("submitLifeinvader", function(data, cb)
        if data and data.text then
            TriggerServerEvent(
                Config.Lifeinvader.eventPrefix .. ":submit",
                data.text,
                data.withName and true or false,
                data.name or '',
                data.phone or ''
            )
        end
        cb("ok")
    end)

    RegisterNetEvent(Config.Lifeinvader.eventPrefix .. ":result")
    AddEventHandler(Config.Lifeinvader.eventPrefix .. ":result", function(success, message)
        SendNUIMessage({
            action = "lifeinvaderResult",
            success = success,
            message = message,
        })

        if success then
            liOpen = false
            SetNuiFocus(false, false)
            SendNUIMessage({ action = "closeLifeinvader" })
        end
    end)

    RegisterNetEvent(Config.Lifeinvader.eventPrefix .. ":broadcast")
    AddEventHandler(Config.Lifeinvader.eventPrefix .. ":broadcast", function(text)
        SendNUIMessage({
            action = "lifeinvaderBroadcast",
            serverName = Config.Lifeinvader.serverName,
            text = text,
            duration = Config.Lifeinvader.broadcastDuration,
        })

        MC_Notify(Config.Lifeinvader.notification.title, text, Config.Lifeinvader.notification.type)
    end)

    -- Feed: initialer Sync beim Öffnen (Server schickt kompletten aktuellen Stand)
    RegisterNetEvent(Config.Lifeinvader.eventPrefix .. ":feedSync")
    AddEventHandler(Config.Lifeinvader.eventPrefix .. ":feedSync", function(feed)
        liFeedCache = feed or {}
        SendNUIMessage({ action = "lifeinvaderFeedSync", feed = liFeedCache })
    end)

    -- Feed: neuer Post kommt live rein (auch während das Menü schon offen ist)
    RegisterNetEvent(Config.Lifeinvader.eventPrefix .. ":feedPush")
    AddEventHandler(Config.Lifeinvader.eventPrefix .. ":feedPush", function(entry)
        table.insert(liFeedCache, 1, entry)
        while #liFeedCache > (Config.Lifeinvader.feed.maxPosts or 20) do
            table.remove(liFeedCache)
        end
        SendNUIMessage({ action = "lifeinvaderFeedSync", feed = liFeedCache })
    end)

    if Config.Lifeinvader.command and Config.Lifeinvader.command ~= '' then
        RegisterCommand(Config.Lifeinvader.command, function()
            if not Config.Lifeinvader.enabled then return end
            OpenLifeinvaderMenu()
        end, false)
    end

    -- Export für Handy-Scripts (z.B. qs-smartphone): öffnet das Menü ohne dass man
    -- physisch am Terminal stehen muss. Nur aktiv, wenn phoneIntegration.enabled = true.
    -- Beispiel-Nutzung aus einem Phone-Script: exports['mc_core']:OpenLifeinvader()
    exports('OpenLifeinvader', function()
        if not Config.Lifeinvader.enabled then return end
        if not Config.Lifeinvader.phoneIntegration.enabled then return end
        OpenLifeinvaderMenu()
    end)

    CreateThread(function()
        while true do
            local sleep = 1000

            if Config.Lifeinvader.enabled then
                local loc = Config.Lifeinvader.location
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local dist = #(coords - loc.coords)
                local showDistance = loc.showDistance or 15.0

                if dist < showDistance then
                    sleep = 0

                    if loc.marker.enabled then
                        local m = loc.marker
                        DrawMarker(
                            m.type,
                            loc.coords.x, loc.coords.y, loc.coords.z - 1.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            m.size.x, m.size.y, m.size.z,
                            m.color.r, m.color.g, m.color.b, m.color.a,
                            false, true, 2, false, nil, nil, false
                        )
                    end

                    if dist < loc.radius then
                        MC_NotifyHelp("Drücke ~INPUT_CONTEXT~ um eine Werbung aufzugeben")

                        if IsControlJustPressed(0, 38) and not liOpen then
                            OpenLifeinvaderMenu()
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

-- ============================================================
-- SECTION: formular.lua  (übernommen aus mc_formular)
-- ============================================================
-- FIX: Config.Command war im Original definiert, aber nie als
-- Command registriert - das Formular ging NUR über den Standort auf.
-- Jetzt öffnet sowohl [E] am Standort als auch der Chat-Command
-- (/formular) dieselbe NUI.
do
    local function OpenFormularUI()
        local playerData = ESX.GetPlayerData()

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openFormular",
            fields = FormularConfig.Fields,
            -- automatisch ermittelte Werte (aktuell nur Telefonnummer) für
            -- Felder mit field.auto == "phone_number"
            autoValues = {
                phone_number = playerData and playerData.phone_number or nil
            }
        })
    end

    RegisterNetEvent("mc_core:formular:open")
    AddEventHandler("mc_core:formular:open", OpenFormularUI)

    CreateThread(function()
        while true do
            local sleep = 1000
            local coords = GetEntityCoords(PlayerPedId())
            local dist = #(coords - FormularConfig.Location)

            if dist < (FormularConfig.Radius or 3.0) then
                sleep = 0

                DrawText3D(
                    FormularConfig.Location.x,
                    FormularConfig.Location.y,
                    FormularConfig.Location.z + 1.0,
                    "~g~[E]~w~ Formular öffnen"
                )

                if IsControlJustReleased(0, 38) then
                    OpenFormularUI()
                end
            end

            Wait(sleep)
        end
    end)

    RegisterNUICallback("submitFormular", function(data, cb)
        SetNuiFocus(false, false)
        TriggerServerEvent("formular:submit", data)
        cb("ok")
    end)

    RegisterNUICallback("closeFormular", function(_, cb)
        SetNuiFocus(false, false)
        cb("ok")
    end)
end

-- ============================================================
-- SECTION: zombie.lua  (übernommen aus mc_zombie)
-- Feste Zone, geteilte (networked) Zombies
-- ============================================================
-- Nutzt ZombieConfig statt Config (siehe config.lua - eigene Config-
-- Tabelle, um Kollisionen mit dem Rest von mc_core zu vermeiden).
--
-- FIX: Das Original nutzte FiveM's Backtick-Hash-Literale (z.B.
-- `PLAYER`, `SCRIPT_TASK_COMBAT`), die nur im FiveM-eigenen Lua-
-- Runtime gültig sind. Hier durch GetHashKey(...) ersetzt - macht
-- exakt dasselbe, ist aber überall gültiges Lua (u.a. mit Standard-
-- Lua-Tools prüfbar).
do
    local hasShownZombieHelpNotify = false
    local zombieLocallyReportedDead = {}   -- [netId] = true, verhindert mehrfaches Melden desselben Zombies
    local zombieLastAttackTime = {}        -- Cooldown-Tracking pro Zombie (nur fuer waffenlose Zombies)

    -- Decorator, um Zombie-Peds eindeutig zu markieren (wichtig bei Freemode-Masken-Modus,
    -- da dort das Modell mit echten Spielern identisch sein kann - der Decorator unterscheidet
    -- zuverlaessig "das ist ein Script-Zombie" von "das ist ein echter Spieler")
    DecorRegister('zsc_zombie', 3) -- Typ 3 = int

    local function IsZombiePed(ped)
        return DecorExistOn(ped, 'zsc_zombie')
    end

    -- ------------------------------------------------
    -- Zombie-Look: torkelnder Gang, Wunden, gelegentliches Stoehnen
    -- ------------------------------------------------
    local function ApplyZombieLook(ped)
        local isMale = IsPedMale(ped)
        local clipSet = isMale and ZombieConfig.ZombieClipsetMale or ZombieConfig.ZombieClipsetFemale

        RequestClipSet(clipSet)
        local timeout = 0
        while not HasClipSetLoaded(clipSet) and timeout < 2000 do
            Wait(10)
            timeout = timeout + 10
        end
        if HasClipSetLoaded(clipSet) then
            SetPedMovementClipset(ped, clipSet, 1.0)
        end

        SetPedMoveRateOverride(ped, ZombieConfig.ZombieWalkSpeed)

        if ZombieConfig.ZombieDamagePacks and #ZombieConfig.ZombieDamagePacks > 0 then
            local pack = ZombieConfig.ZombieDamagePacks[math.random(#ZombieConfig.ZombieDamagePacks)]
            ApplyPedDamagePack(ped, pack, 0.0, 1.0)
        end

        if ZombieConfig.PlayZombieSounds then
            CreateThread(function()
                while DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) do
                    Wait(math.random(4000, 9000))
                    if DoesEntityExist(ped) then
                        PlayAmbientSpeech1(ped, ZombieConfig.ZombieSoundName, "SPEECH_PARAMS_FORCE")
                    end
                end
            end)
        end
    end

    -- ------------------------------------------------
    -- Einen Zombie an einer bestimmten Position erstellen (wird per Server-Event ausgeloest,
    -- damit garantiert nur EIN Client pro Spawn-Slot einen Ped erzeugt)
    -- ------------------------------------------------
    local function CreateZombieAt(slotIndex, coords)
        local model
        if ZombieConfig.UseFreemodeMasks then
            model = ZombieConfig.FreemodeModels[math.random(#ZombieConfig.FreemodeModels)]
        else
            model = ZombieConfig.ZombieModels[math.random(#ZombieConfig.ZombieModels)]
        end

        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 5000 do
            Wait(10)
            timeout = timeout + 10
        end
        if not HasModelLoaded(model) then
            return
        end

        local ped = CreatePed(4, model, coords.x, coords.y, coords.z, math.random(0, 360) + 0.0, true, true)

        if ZombieConfig.UseFreemodeMasks then
            SetPedDefaultComponentVariation(ped)
            SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
            SetPedComponentVariation(ped, 1, ZombieConfig.ZombieMaskDrawable, ZombieConfig.ZombieMaskTexture, 0)
            SetPedComponentVariation(ped, 11, ZombieConfig.ZombieDecalDrawable, ZombieConfig.ZombieDecalTexture, 0)
        end

        DecorSetInt(ped, 'zsc_zombie', 1)

        SetEntityAsMissionEntity(ped, true, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        SetPedCombatAttributes(ped, 5, true)
        SetPedCombatAbility(ped, ZombieConfig.PedWeapon and 2 or 0)
        SetPedCombatMovement(ped, ZombieConfig.PedWeapon and 2 or 0)
        SetPedAccuracy(ped, ZombieConfig.PedWeapon and 25 or 0)
        SetPedSeeingRange(ped, ZombieConfig.AggroRange + 10.0)
        SetPedHearingRange(ped, ZombieConfig.AggroRange + 10.0)
        SetPedAlertness(ped, 3)
        SetEntityMaxHealth(ped, ZombieConfig.ZombieHealth)
        SetEntityHealth(ped, ZombieConfig.ZombieHealth)
        SetPedCanRagdoll(ped, true)
        SetPedSuffersCriticalHits(ped, false)

        if ZombieConfig.PedWeapon and ZombieConfig.WeaponPed and #ZombieConfig.WeaponPed > 0 then
            local weapon = ZombieConfig.WeaponPed[math.random(#ZombieConfig.WeaponPed)]
            GiveWeaponToPed(ped, weapon, 250, false, true)
        end

        local group = GetHashKey("ZOMBIE_HOSTILE")
        AddRelationshipGroup("ZOMBIE_HOSTILE")
        SetPedRelationshipGroupHash(ped, group)
        SetRelationshipBetweenGroups(5, group, GetHashKey('PLAYER'))
        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), group)

        TaskWanderStandard(ped, 10.0, 10)
        ApplyZombieLook(ped)

        SetModelAsNoLongerNeeded(model)
        zombieLastAttackTime[ped] = 0

        local netId = NetworkGetNetworkIdFromEntity(ped)
        TriggerServerEvent('zombie-script:zombieSpawned', slotIndex, netId)
    end

    RegisterNetEvent('zombie-script:spawnAtSlot')
    AddEventHandler('zombie-script:spawnAtSlot', function(slotIndex, coords)
        CreateZombieAt(slotIndex, coords)
    end)

    RegisterNetEvent('zombie-script:deleteZombie')
    AddEventHandler('zombie-script:deleteZombie', function(netId)
        if NetworkDoesNetworkIdExist(netId) then
            local ped = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
    end)

    -- ------------------------------------------------
    -- Distanz-Helfer
    -- ------------------------------------------------
    local function DistanceToZombieZone()
        local coords = GetEntityCoords(PlayerPedId())
        return #(coords - ZombieConfig.Zone.coords)
    end

    -- ------------------------------------------------
    -- Spawn-Request-Loop: solange ich in der Naehe der Zone bin, frage ich regelmaessig
    -- den Server nach einem freien Spawn-Slot (der Server entscheidet, ob noch Platz ist)
    -- ------------------------------------------------
    CreateThread(function()
        while true do
            Wait(ZombieConfig.SpawnCheckInterval)

            if DistanceToZombieZone() <= ZombieConfig.ZoneCheckDistance then
                TriggerServerEvent('zombie-script:requestSpawnSlot')

                if not hasShownZombieHelpNotify then
                    hasShownZombieHelpNotify = true
                    BeginTextCommandDisplayHelp("STRING")
                    AddTextComponentSubstringPlayerName(ZombieConfig.HelpNotify)
                    EndTextCommandDisplayHelp(0, false, true, -1)
                end
            elseif DistanceToZombieZone() > ZombieConfig.ZoneCheckDistance + 20.0 then
                -- weit genug weg -> beim naechsten Betreten wieder anzeigen
                hasShownZombieHelpNotify = false
            end
        end
    end)

    -- ------------------------------------------------
    -- Sweeper: erkennt tote Zombies (unabhaengig davon, welcher Client sie erstellt hat)
    -- und meldet dies dem Server. So gibt es keine "Geister-Zombies" mehr, falls der
    -- urspruengliche Spawner-Client disconnectet.
    --
    -- FIX: Zombies sollen NUR innerhalb des Zonen-Kreises (ZombieConfig.Zone.radius)
    -- bleiben. Vorher gab es keine Begrenzung - ein Zombie, der einen fliehenden
    -- Spieler verfolgt hat (TaskCombatPed), ist ihm einfach bis ans Ende der Map
    -- hinterhergelaufen. Jetzt wird bei jedem Sweeper-Durchlauf geprüft, ob ein
    -- Zombie außerhalb des Kreises steht - falls ja, wird er zurück in Richtung
    -- Zonen-Mittelpunkt geschickt.
    -- ------------------------------------------------
    local zombieLeashCooldown = {}

    CreateThread(function()
        while true do
            Wait(500)

            if DistanceToZombieZone() <= ZombieConfig.ZoneCheckDistance then
                local playerPed = PlayerPedId()
                local pool = GetGamePool('CPed')
                local now = GetGameTimer()

                for _, ped in ipairs(pool) do
                    if DoesEntityExist(ped) and IsZombiePed(ped) then
                        local netId = NetworkGetNetworkIdFromEntity(ped)

                        if IsPedDeadOrDying(ped, true) and not zombieLocallyReportedDead[netId] then
                            zombieLocallyReportedDead[netId] = true

                            local killerPed = GetPedSourceOfDeath(ped)
                            local killedByMe = (killerPed == playerPed)

                            TriggerServerEvent('zombie-script:zombieDied', netId, killedByMe)
                        elseif not IsPedDeadOrDying(ped, true) then
                            local pedCoords = GetEntityCoords(ped)
                            local distFromCenter = #(pedCoords - ZombieConfig.Zone.coords)

                            if distFromCenter > ZombieConfig.Zone.radius then
                                -- nicht bei jedem Tick neu zwingen (würde ruckeln) - nur alle 2s pro Zombie
                                local lastLeash = zombieLeashCooldown[ped] or 0
                                if now - lastLeash >= 2000 then
                                    zombieLeashCooldown[ped] = now
                                    ClearPedTasksImmediately(ped)
                                    TaskGoToCoordAnyMeans(
                                        ped,
                                        ZombieConfig.Zone.coords.x, ZombieConfig.Zone.coords.y, ZombieConfig.Zone.coords.z,
                                        ZombieConfig.ZombieWalkSpeed, 0, false, 786603, 0xbf800000
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    -- ------------------------------------------------
    -- Nahkampf-Schaden fuer waffenlose Zombies (bei bewaffneten Zombies uebernimmt
    -- das normale Waffen-/Kampfsystem des Spiels automatisch den Schaden)
    -- ------------------------------------------------
    if not ZombieConfig.PedWeapon then
        CreateThread(function()
            while true do
                Wait(250)

                if DistanceToZombieZone() <= ZombieConfig.ZoneCheckDistance then
                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)
                    local playerInsideZone = #(playerCoords - ZombieConfig.Zone.coords) <= ZombieConfig.Zone.radius
                    local pool = GetGamePool('CPed')
                    local now = GetGameTimer()

                    for _, ped in ipairs(pool) do
                        if DoesEntityExist(ped) and IsZombiePed(ped) and not IsPedDeadOrDying(ped, true) then
                            local pedCoords = GetEntityCoords(ped)
                            local dist = #(playerCoords - pedCoords)

                            -- Nur angreifen/verfolgen, wenn der Spieler auch INNERHALB
                            -- der Zone steht - sonst würde der Zombie ihm aus dem Kreis
                            -- heraus hinterherlaufen.
                            if playerInsideZone and dist <= ZombieConfig.AggroRange then
                                if GetScriptTaskStatus(ped, GetHashKey('SCRIPT_TASK_COMBAT')) ~= 1 then
                                    TaskCombatPed(ped, playerPed, 0, 16)
                                end
                            end

                            if playerInsideZone and dist <= ZombieConfig.AttackRange then
                                local last = zombieLastAttackTime[ped] or 0
                                if now - last >= ZombieConfig.AttackCooldown then
                                    zombieLastAttackTime[ped] = now
                                    local newHealth = GetEntityHealth(playerPed) - ZombieConfig.AttackDamage
                                    SetEntityHealth(playerPed, math.max(newHealth, 0))
                                    ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.15)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    -- ------------------------------------------------
    -- Zonen-Marker + Blip
    -- ------------------------------------------------
    CreateThread(function()
        if ZombieConfig.Blip.enabled then
            local blip = AddBlipForCoord(ZombieConfig.Zone.coords.x, ZombieConfig.Zone.coords.y, ZombieConfig.Zone.coords.z)
            SetBlipSprite(blip, ZombieConfig.Blip.sprite)
            SetBlipDisplay(blip, ZombieConfig.Blip.display)
            SetBlipScale(blip, ZombieConfig.Blip.scale)
            SetBlipColour(blip, ZombieConfig.Blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(ZombieConfig.Blip.label)
            EndTextCommandSetBlipName(blip)
        end

        while true do
            Wait(0)

            if DistanceToZombieZone() <= ZombieConfig.Marker.drawDistance then
                DrawMarker(
                    ZombieConfig.Marker.id,
                    ZombieConfig.Zone.coords.x, ZombieConfig.Zone.coords.y, ZombieConfig.Zone.coords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    ZombieConfig.Marker.sizeX, ZombieConfig.Marker.sizeY, ZombieConfig.Marker.sizeZ,
                    ZombieConfig.Marker.r, ZombieConfig.Marker.g, ZombieConfig.Marker.b, ZombieConfig.Marker.a,
                    false, false, 2, false, nil, nil, false
                )
            else
                Wait(1000)
            end
        end
    end)

    -- ------------------------------------------------
    -- Aufraeumen beim Beenden der Ressource
    -- ------------------------------------------------
    AddEventHandler('onResourceStop', function(resourceName)
        if GetCurrentResourceName() ~= resourceName then
            return
        end

        local pool = GetGamePool('CPed')
        for _, ped in ipairs(pool) do
            if DoesEntityExist(ped) and IsZombiePed(ped) then
                DeleteEntity(ped)
            end
        end
    end)

    -- ================================
    --   MASKEN-FINDER (DEBUG-TOOL)
    -- ================================
    local finderMaskDrawable = 0
    local finderMaskTexture = 0
    local finderDecalDrawable = 0

    local function PrintFinderState()
        TriggerEvent('chat:addMessage', {
            args = { '^3[Zombie Maske]', ('Maske: %d / Textur: %d | Decal: %d'):format(
                finderMaskDrawable, finderMaskTexture, finderDecalDrawable) }
        })
    end

    RegisterCommand('zombiemask', function(source, args)
        local ped = PlayerPedId()
        local sub = args[1]

        if sub == 'mask+' then
            finderMaskDrawable = finderMaskDrawable + 1
            finderMaskTexture = 0
        elseif sub == 'mask-' then
            finderMaskDrawable = math.max(0, finderMaskDrawable - 1)
            finderMaskTexture = 0
        elseif sub == 'tex+' then
            finderMaskTexture = finderMaskTexture + 1
        elseif sub == 'tex-' then
            finderMaskTexture = math.max(0, finderMaskTexture - 1)
        elseif sub == 'decal+' then
            finderDecalDrawable = finderDecalDrawable + 1
        elseif sub == 'decal-' then
            finderDecalDrawable = math.max(0, finderDecalDrawable - 1)
        elseif sub == 'reset' then
            finderMaskDrawable, finderMaskTexture, finderDecalDrawable = 0, 0, 0
        else
            TriggerEvent('chat:addMessage', {
                args = { '^3[Zombie Maske]', 'Nutzung: /zombiemask mask+ | mask- | tex+ | tex- | decal+ | decal- | reset' }
            })
            return
        end

        SetPedComponentVariation(ped, 1, finderMaskDrawable, finderMaskTexture, 0)
        SetPedComponentVariation(ped, 11, finderDecalDrawable, 0, 0)
        PrintFinderState()
    end, false)
end
