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
-- SECTION: Abschleppsystem.lua
-- ============================================================
do
    CreateThread(function()
        while true do
            Wait(3000)

            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 then
                local plate = GetVehicleNumberPlateText(veh)
                TriggerServerEvent("vehicleTrack:updateMovement", plate)
            end
        end
    end)
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

    function RotAnglesToVec(rot)
        local z = math.rad(rot.z)
        local x = math.rad(rot.x)
        local num = math.abs(math.cos(x))

        return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
    end

    function RayCastGamePlayCamera(dist)
        local camRot = GetGameplayCamRot()
        local camCoord = GetGameplayCamCoord()

        local direction = RotAnglesToVec(camRot)
        local dest = camCoord + (direction * dist)

        local rayHandle = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

        return hit, endCoords, surfaceNormal, entityHit
    end

    local function playerMoved()
        local cfg = Config.AntiAFK
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        if lastPos == nil then
            lastPos = pos
            return true
        end

        local dist = #(pos - lastPos)
        if dist > cfg.MoveThreshold then
            lastPos = pos
            return true
        end

        local vel = GetEntityVelocity(ped)
        if #(vel) > cfg.VelocityThreshold then
            lastPos = pos
            return true
        end

        local hit = RayCastGamePlayCamera(cfg.CamRayCastDist)
        if hit then
            lastPos = pos
            return true
        end

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
        end
    end)

    CreateThread(function()
        while DebugNPCBlocker do
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