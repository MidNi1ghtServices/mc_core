-- ============================================================
--  MC CORE - COMBINED CLIENT.LUA
--  Automatisch zusammengeführt aus:
--  Abschleppsystem, antiafk, crafter, discord, elevator, event,
--  farming, Fraktionssperre, givecar, klingel, labor, maut,
--  mechanic_client, moneywash, npc_blocker, purge, sperrezone,
--  tow, verkauf
--
--  Jeder Abschnitt läuft in einem eigenen do...end Block, damit
--  lokale Variablen (z.B. mehrfaches "local ESX = ...") sich
--  nicht gegenseitig überschreiben. Globale Funktionen/Events
--  bleiben wie im Original global verfügbar.
-- ============================================================


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
-- SECTION: antiafk.lua
-- ============================================================
do
    local lastActivity = GetGameTimer()
    local lastPos = nil

    local function updateActivity()
        TriggerServerEvent('mc_core:updateActivity')
        lastActivity = GetGameTimer()
    end

    -- Raycast Funktion
    function RayCastGamePlayCamera(dist)
        local camRot = GetGameplayCamRot()
        local camCoord = GetGameplayCamCoord()

        local direction = RotAnglesToVec(camRot)
        local dest = camCoord + (direction * dist)

        local rayHandle = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

        return hit, endCoords, surfaceNormal, entityHit
    end

    function RotAnglesToVec(rot)
        local z = math.rad(rot.z)
        local x = math.rad(rot.x)
        local num = math.abs(math.cos(x))

        return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
    end

    local function playerMoved()
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        if lastPos == nil then
            lastPos = pos
            return true
        end

        -- Distanzcheck
        local dist = #(pos - lastPos)
        if dist > 0.15 then
            lastPos = pos
            return true
        end

        -- Velocity check
        local vel = GetEntityVelocity(ped)
        if #(vel) > 0.1 then
            lastPos = pos
            return true
        end

        -- Raycast check (Bewegung im Raum)
        local hit, _, _, _ = RayCastGamePlayCamera(5.0)
        if hit then
            lastPos = pos
            return true
        end

        return false
    end

    CreateThread(function()
        while true do
            Wait(1000)

            if playerMoved() then
                updateActivity()
            end
        end
    end)
end


-- ============================================================
-- SECTION: crafter.lua
-- ============================================================
do
    local ESX = exports["es_extended"]:getSharedObject()

    -------------------------------------------------
    -- CRAFT BLIPS
    -------------------------------------------------

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

        -- Nur alte Craft-Blips löschen
        for _, blip in pairs(CraftBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        CraftBlips = {}

        -- Neue Craft-Blips erstellen
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
        ESX.ShowNotification(craftBlipsVisible and "~g~Crafter-Blips aktiviert" or "~r~Crafter-Blips deaktiviert")
    end)

    -------------------------------------------------
    -- ox_target
    -------------------------------------------------

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

    -------------------------------------------------
    -- MARKER + E-INTERAKTION
    -------------------------------------------------

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
                            ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~, um den Crafter zu öffnen.")

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

    -------------------------------------------------
    -- NUI CALLBACKS
    -------------------------------------------------

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

            -- Großer Button
            SetDiscordRichPresenceAsset(Config.DiscordLogo)
            SetDiscordRichPresenceAssetText(Config.DiscordLogoText)

            -- Kleiner Button
            SetDiscordRichPresenceAssetSmall(Config.DiscordSmallLogo)
            SetDiscordRichPresenceAssetSmallText(Config.DiscordSmallLogoText)

            -- Status
            SetRichPresence(Config.DiscordStatusFormat:format(
                #GetActivePlayers(),
                GetPlayerServerId(PlayerId())
            ))

            -- Buttons
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
    -- AUTO-DETECT NOTIFY
    local function CoreNotifyHelp(msg)
        if TriggerEvent("mc_core:notify:help", msg) then return end
        if TriggerEvent("mc_core:notifyHelp", msg) then return end
        if TriggerEvent("mc_core:helpnotify", msg) then return end
        if TriggerEvent("hex_hud:notify", msg) then return end
        if TriggerEvent("hex_hud:announce", "Hinweis", msg, 3000) then return end

        -- Fallback
        SetTextComponentFormat("STRING")
        AddTextComponentString(msg)
        DisplayHelpTextFromStringLabel(0, false, true, -1)
    end

    -- AUTO-DETECT MENU
    local function CoreOpenMenu(title, options)
        if TriggerEvent("mc_core:menu:open", title, options) then return end
        if TriggerEvent("hex_hud:menu:open", title, options) then return end

        -- Fallback GTA menu
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
                    TriggerEvent("mc_core:notify", "Fahrstuhl", "Fahre zu: "..floor.label, 3000)
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
                        CoreNotifyHelp("Drücke ~INPUT_CONTEXT~ für Fahrstuhl")

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
        TriggerEvent('hex_hud:announce', title, msg, timeout)
    end)
end


-- ============================================================
-- SECTION: farming.lua
-- ============================================================
do
    local ESX = exports["es_extended"]:getSharedObject()

    local isFarming = false
    local currentFarm = nil
    local farmingThread = nil

    -------------------------------------------------
    -- Blips
    -------------------------------------------------

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

    -------------------------------------------------
    -- Marker + Zone Detection
    -------------------------------------------------

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

    -------------------------------------------------
    -- Moderner Fortschrittsbalken (Glow + Gradient)
    -------------------------------------------------

    function FarmingProgress(seconds)
        local start = GetGameTimer()
        local finish = start + (seconds * 1000)

        while GetGameTimer() < finish do
            Wait(0)

            local now = GetGameTimer()
            local progress = (now - start) / (seconds * 1000)
            if progress < 0 then progress = 0 end
            if progress > 1 then progress = 1 end

            -- Hintergrund
            DrawRect(0.50, 0.92, 0.22, 0.030, 10, 10, 14, 180)

            -- Fortschritt
            DrawRect(
                0.39 + (progress * 0.11),
                0.92,
                progress * 0.22,
                0.022,
                74, 163, 255, 255
            )

            -- Glow
            DrawRect(
                0.39 + (progress * 0.11),
                0.92,
                progress * 0.22,
                0.022,
                74, 163, 255, 120
            )

            -- Text
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

    -------------------------------------------------
    -- Auto-Farming starten
    -------------------------------------------------

    function StartFarming(farmName)
        if isFarming then return end

        local farm = Config.Farming[farmName]
        if not farm then return end

        isFarming = true
        currentFarm = farmName

        ESX.ShowNotification("~g~Auto-Farming gestartet.")

        farmingThread = CreateThread(function()
            while isFarming do

                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)

                -- Zone verlassen
                if #(coords - farm.coords) > farm.zonesize then
                    ESX.ShowNotification("~r~Zone verlassen – Auto-Farming gestoppt.")
                    StopFarming()
                    break
                end

                -- Animation
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

                -- Fortschrittsbalken → erst wenn voll → Item
                FarmingProgress(farm.time)

                -- Jetzt erst Item geben
                TriggerServerEvent("mc_core:farming:collect", farmName)

                Wait(250)
                ClearPedTasks(ped)
            end
        end)
    end

    -------------------------------------------------
    -- Auto-Farming stoppen
    -------------------------------------------------

    function StopFarming()
        isFarming = false
        currentFarm = nil
        ClearPedTasks(PlayerPedId())
    end

    -------------------------------------------------
    -- Taste E → Start/Stop
    -------------------------------------------------

    CreateThread(function()
        while true do
            Wait(0)

            if currentFarm then
                ESX.ShowHelpNotification("~INPUT_CONTEXT~ Auto-Farming starten/stoppen")

                if IsControlJustPressed(0, 38) then -- E
                    if not isFarming then
                        StartFarming(currentFarm)
                    else
                        StopFarming()
                        ESX.ShowNotification("~r~Auto-Farming beendet.")
                    end
                end
            end
        end
    end)

    -------------------------------------------------
    -- Taste X → Stop
    -------------------------------------------------

    CreateThread(function()
        while true do
            Wait(0)

            if isFarming and IsControlJustPressed(0, 73) then -- X
                StopFarming()
                ESX.ShowNotification("~r~Auto-Farming beendet.")
            end
        end
    end)

    -------------------------------------------------
    -- Anti AFK
    -------------------------------------------------

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
                    ESX.ShowNotification("~r~Auto-Farming wegen Inaktivität beendet.")
                end
            end
        end
    end)
end


-- ============================================================
-- SECTION: Fraktionssperre.lua
-- ============================================================
do
    -- ============================================================
    --  NOTIFICATION HANDLER
    --  hex_hud_notify hört bereits selbst auf FraksperreConfig.Notify.event
    --  ("esx:showNotification") und zeigt die Notification an.
    --  Hier daher KEINEN eigenen Handler mehr registrieren, sonst kommt
    --  die Notification doppelt (einmal von hex_hud_notify, einmal von uns).
    -- ============================================================

    RegisterNetEvent(FraksperreConfig.Notify.helpEvent)
    AddEventHandler(FraksperreConfig.Notify.helpEvent, function(message)
        -- Ausführliche Hilfe-Notification (z.B. beim Connect)
        BeginTextCommandDisplayHelp("STRING")
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandDisplayHelp(0, false, true, -1)
    end)

    -- ============================================================
    --  CHAT SUGGESTIONS FÜR ADMINS
    -- ============================================================
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

        ESX.Game.SpawnVehicle(model, coords, heading, function(vehicle)
            SetVehicleNumberPlateText(vehicle, plate)
            SetPedIntoVehicle(playerPed, vehicle, -1)

            -- Fahrzeug sicher machen
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

                    if IsControlJustPressed(0, 38) then -- E Taste
                        if (GetGameTimer() - lastPress) < Config.Klingel.Cooldown then
                            ESX.ShowNotification("⏳ Bitte warte kurz…")
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
    local ESX = exports["es_extended"]:getSharedObject()

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

    -------------------------------------------------
    -- Ox Target
    -------------------------------------------------

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

    -------------------------------------------------
    -- Marker
    -------------------------------------------------

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

                            ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~ um das Labor zu öffnen")

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

    -------------------------------------------------
    -- Server Status
    -------------------------------------------------

    RegisterNetEvent("mc_core:sendLaborStatus",function(data)

        SendNUIMessage({

            action="updateLabor",

            items=data.items,

            money=data.money,

            finish=data.finish

        })

    end)

    -------------------------------------------------
    -- NUI
    -------------------------------------------------

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
    local insideToll = {} -- [toll.name] = true/false, pro Mautstelle statt global
    local EXIT_BUFFER = 5.0 -- Meter Puffer: verhindert Flackern am Rand des Radius (Bodenwellen, Federung etc.)

    CreateThread(function()
        while true do
            local sleep = 500
            local ped = PlayerPedId()

            if IsPedInAnyVehicle(ped, false) then
                sleep = 0

                local veh = GetVehiclePedIsIn(ped, false)
                local coords = GetEntityCoords(veh)
                local speed = GetEntitySpeed(veh) * 3.6 -- km/h

                for _, toll in ipairs(MautConfig.Tolls) do
                    local dist = #(coords - toll.coords)

                    if dist <= toll.radius then

                        -- Nur beim EINTRITT in diese eine Mautstelle abrechnen,
                        -- nicht erneut, solange man noch drin steht
                        if not insideToll[toll.name] then
                            insideToll[toll.name] = true

                            local dynamicPrice = MautConfig.Price

                            -- 350+ km/h = Mindestpreis + dynamisch weiter
                            if speed >= 350 then
                                dynamicPrice = math.floor(
                                    MautConfig.HighSpeedBase + ((speed - 350) * MautConfig.SpeedFactor)
                                )

                            -- über 50 km/h = dynamischer Preis
                            elseif speed > 50 then
                                dynamicPrice = math.floor(
                                    MautConfig.Price + ((speed - 50) * MautConfig.SpeedFactor)
                                )
                            end

                            -- Notify für Fahrer
                            TriggerEvent("mc_core:notify", "Mautstelle",
                                ("Speed: %.1f km/h | Preis: %s$"):format(speed, dynamicPrice)
                            )

                            -- Zahlung
                            TriggerServerEvent("mc_core:maut:pay", toll.name, dynamicPrice, speed)

                            -- Polizei‑Alarm ab 200 km/h
                            if speed >= 200 then
                                TriggerServerEvent("mc_core:maut:policeAlert", toll.name, dynamicPrice, speed)
                            end
                        end

                    elseif dist > toll.radius + EXIT_BUFFER then
                        -- Erst HIER wieder scharf machen (Radius + Puffer), NICHT direkt
                        -- am Rand des Radius. Zwischen Radius und Radius+Puffer bleibt der
                        -- Zustand unverändert -> kein Retrigger durch kleines Wackeln.
                        insideToll[toll.name] = false
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
    -- Konsolidierte Client‑Datei für mc_core (vsMechanic / Insurance)
    -- Angepasst an deine config.lua (ESX)

    -- Erwartet: config.lua mit Feldern wie in deiner Vorlage
    -- Framework: ESX (Config.Framework == 'esx')

    -- Globals / Cache
    local currentInsuranceTier = "basic"        -- Standardwert bis DB geladen
    local insuranceCache = {}                  -- cache: plate -> tier
    local insuranceNPC = nil
    local lastDrivenVeh = 0
    local lastDrivenPlate = nil

    -- Hilfsfunktion: Tier‑Dauern aus Config holen
    local function getTierDurations(tier)
        if tier == 'basic' then
            return Config.MechanicDurationBasic, Config.RepairDurationBasic, Config.RequiredMechanicBasic
        elseif tier == 'default' then
            return Config.MechanicDurationDefault, Config.RepairDurationDefault, Config.RequiredMechanicDefault
        elseif tier == 'premium' then
            return Config.MechanicDurationPremium, Config.RepairDurationPremium, Config.RequiredMechanicPremium
        end

        -- Fallback
        return Config.MechanicDurationBasic, Config.RepairDurationBasic, Config.RequiredMechanicBasic
    end

    -- =========================
    -- NPC + Blip erstellen
    -- =========================
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

    -- =========================
    -- DrawText & Interaktion am NPC
    -- =========================
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

                if IsControlJustPressed(0, Config.Key or 38) then -- 38 = E
                    OpenInsuranceMenu()
                end
            end
        end
    end)

    -- =========================
    -- NUI / Menu öffnen (NUI bevorzugt)
    -- =========================
    function OpenInsuranceMenu()
        local playerPed = PlayerPedId()
        local veh = GetVehiclePedIsIn(playerPed, false)
        local plate = nil

        if veh ~= 0 then
            plate = GetVehicleNumberPlateText(veh)
        end

        -- Preise aus Config zusammenstellen (nutzt deine Config-Felder)
        local tiers = {
            basic = { price = Config.MechanicInsuranceBasicCost or Config.MechanicInsuranceBasicCost or 100 },
            default = { price = Config.MechanicInsuranceDefaultCost or 250 },
            premium = { price = Config.MechanicInsurancePremiumCost or 500 }
        }

        -- UI zurücksetzen (falls vorhanden)
        SendNUIMessage({ action = "resetInsuranceUI" })

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openInsurance",
            plate = plate,
            zone = "npc",
            tiers = tiers
        })
    end

    -- Optional: NUI mit Premium vorauswählen
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

    -- =========================
    -- NUI Callbacks
    -- =========================
    RegisterNUICallback("selectInsurance", function(data, cb)
        if not data or not data.tier or not data.plate then
            cb("error")
            return
        end

        -- Lokal speichern (optimistisch)
        insuranceCache[data.plate] = data.tier
        currentInsuranceTier = data.tier

        -- Server informieren und in DB speichern (Server implementiert DB logic)
        TriggerServerEvent("mc_insurance:buy", data.tier, data.plate)

        -- Feedback an Spieler (lokal)
        if Config and type(Config.Message) == "function" then
            Config.Message("Versicherung abgeschlossen: " .. tostring(data.tier) .. " für " .. tostring(data.plate))
        else
            print("[mc_vsMechanic] Versicherung abgeschlossen: " .. tostring(data.tier) .. " für " .. tostring(data.plate))
        end

        cb("ok")
    end)

    RegisterNUICallback("closeInsurance", function(_, cb)
        SetNuiFocus(false, false)
        cb("ok")
    end)

    -- =========================
    -- Server Events: Set Insurance Tier (z.B. nach DB fetch)
    -- =========================
    RegisterNetEvent("mc_insurance:setTier")
    AddEventHandler("mc_insurance:setTier", function(plate, tier)
        if not plate or not tier then return end
        insuranceCache[plate] = tier

        -- Wenn Spieler aktuell in diesem Fahrzeug sitzt, aktualisiere currentInsuranceTier
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then
            local myPlate = GetVehicleNumberPlateText(veh)
            if myPlate == plate then
                currentInsuranceTier = tier
            end
        end
    end)

    -- =========================
    -- Request flow: Server fordert Reparatur mit Versicherung
    -- =========================
    RegisterNetEvent("mc_vsMechanic:requestWithInsurance")
    AddEventHandler("mc_vsMechanic:requestWithInsurance", function(onlineMechs)
        -- Bestimme aktuelles Fahrzeug und Kennzeichen
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local plate = nil
        if veh ~= 0 then
            plate = GetVehicleNumberPlateText(veh)
        end

        -- Wenn Kennzeichen im Cache vorhanden, nutze dessen Tier, sonst currentInsuranceTier oder basic
        local tier = "basic"
        if plate and insuranceCache[plate] then
            tier = insuranceCache[plate]
        else
            tier = currentInsuranceTier or "basic"
        end

        local mechDuration, repairDuration, requiredMechs = getTierDurations(tier)

        -- Wenn genug Mechaniker online sind, abbrechen (Logik: onlineMechs >= requiredMechs)
        if onlineMechs >= requiredMechs then
            if Config and type(Config.Message) == "function" then
                Config.Message("Es sind genug Mechaniker online für deine Versicherungsstufe.")
            else
                print("[mc_vsMechanic] Es sind genug Mechaniker online für deine Versicherungsstufe.")
            end
            return
        end

        TriggerEvent('mc_vsMechanic:spawnNPCMechanic', mechDuration, repairDuration, 0)
    end)

    -- =========================
    -- Spawn Mechaniker NPC, fährt zum Spieler, repariert Fahrzeug
    -- =========================
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

        TriggerEvent('mc_vsMechanic:notify', "Mechaniker ist unterwegs...")

        Wait(mechDuration * 1000)

        TaskLeaveVehicle(npc, veh, 0)
        Wait(2000)

        TriggerEvent('mc_vsMechanic:notify', "Reparatur gestartet...")

        Wait(repairDuration * 1000)

        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            SetVehicleFixed(vehicle)
            SetVehicleEngineHealth(vehicle, 1000.0)
        end

        TriggerEvent('mc_vsMechanic:notify', "Fahrzeug repariert!")

        -- NPC und Fahrzeug aufräumen
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
        if DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
    end)

    -- =========================
    -- Notification Event (lokal)
    -- =========================
    RegisterNetEvent('mc_vsMechanic:notify')
    AddEventHandler('mc_vsMechanic:notify', function(msg)
        if Config and type(Config.Message) == "function" then
            Config.Message(msg)
        else
            print("[mc_vsMechanic] " .. tostring(msg))
        end
    end)

    -- =========================
    -- Helper: Request Insurance for current vehicle (fragt Server nach DB‑Wert)
    -- =========================
    function RequestInsuranceForCurrentVehicle()
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            if Config and type(Config.Message) == "function" then
                Config.Message("Du sitzt in keinem Fahrzeug.")
            else
                print("[mc_vsMechanic] Du sitzt in keinem Fahrzeug.")
            end
            return
        end

        local plate = GetVehicleNumberPlateText(veh)
        if not plate or plate == "" then
            if Config and type(Config.Message) == "function" then
                Config.Message("Kein Kennzeichen gefunden.")
            else
                print("[mc_vsMechanic] Kein Kennzeichen gefunden.")
            end
            return
        end

        TriggerServerEvent("mc_insurance:getForPlate", plate)
    end

    -- =========================
    -- Track zuletzt gefahrenes Fahrzeug (für "Buy Premium last driven")
    -- =========================
    CreateThread(function()
        while true do
            Wait(1000)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, true) -- true = last vehicle too
            if veh ~= 0 and veh ~= lastDrivenVeh then
                lastDrivenVeh = veh
                local plate = GetVehicleNumberPlateText(veh)
                if plate and plate ~= "" then
                    lastDrivenPlate = plate
                end
            end
        end
    end)

    -- =========================
    -- Funktion: Premium für zuletzt gefahrenes Fahrzeug kaufen/setzen
    -- =========================
    function BuyPremiumForLastDrivenVehicle()
        if not lastDrivenPlate or lastDrivenPlate == "" then
            if Config and type(Config.Message) == "function" then
                Config.Message("Kein zuletzt gefahrenes Fahrzeug gefunden.")
            else
                print("[mc_vsMechanic] Kein zuletzt gefahrenes Fahrzeug gefunden.")
            end
            return
        end

        -- Lokal speichern (optimistisch)
        insuranceCache[lastDrivenPlate] = "premium"
        currentInsuranceTier = "premium"

        -- Server informieren, DB‑Speicherung übernimmt der Server
        TriggerServerEvent("mc_insurance:buy", "premium", lastDrivenPlate)

        -- Feedback an Spieler
        if Config and type(Config.Message) == "function" then
            Config.Message("Premium‑Versicherung abgeschlossen für " .. lastDrivenPlate)
        else
            print("[mc_vsMechanic] Premium‑Versicherung abgeschlossen für " .. lastDrivenPlate)
        end
    end

    -- Optional: Kommando zum Testen (nur während Entwicklung)
    RegisterCommand("buyPremiumLast", function()
        BuyPremiumForLastDrivenVehicle()
    end, false)

    -- =========================
    -- Auto‑Update currentInsuranceTier beim Fahrzeugwechsel
    -- =========================
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
                        -- Fordere Server an, falls nicht im Cache
                        TriggerServerEvent("mc_insurance:getForPlate", plate)
                    end
                end
            end
        end
    end)

    -- =========================
    -- Exports (für andere mc_core Module)
    -- =========================
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
    local ESX = exports["es_extended"]:getSharedObject()

    if not Config or not Config.Moneywash then
        print("^1[mc_core] Moneywash-Konfiguration konnte nicht geladen werden!^7")
        return
    end

    local MW = Config.Moneywash
    local moneywashBlips = {}
    local moneywashOpen = false

    -------------------------------------------------
    -- Blips
    -------------------------------------------------

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

    -------------------------------------------------
    -- Menü öffnen
    -------------------------------------------------

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

    -------------------------------------------------
    -- Ox Target
    -------------------------------------------------

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

    -------------------------------------------------
    -- Marker + E-Fallback
    -------------------------------------------------

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

                            ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~ um Geld zu waschen")

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

    -------------------------------------------------
    -- Server-Status -> NUI
    -------------------------------------------------

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
        ESX.ShowNotification("Ein Passant meldet verdächtige Aktivitäten! Position auf der Karte markiert.")

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

    -------------------------------------------------
    -- NUI
    -------------------------------------------------

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

    -- Fahrzeuge merken, die bereits von Spielern benutzt wurden
    local PlayerVehicles = {}

    -- Check ob ein Punkt im Radius liegt
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

                        -- Prüfen ob irgendein Spieler im Fahrzeug sitzt
                        local playerInside = false

                        for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                            local ped = GetPedInVehicleSeat(veh, seat)

                            if ped ~= 0 and IsPedAPlayer(ped) then
                                playerInside = true
                                PlayerVehicles[netId] = true
                                break
                            end
                        end

                        -- Spieler sitzt drin -> niemals löschen
                        if playerInside then
                            goto continue
                        end

                        -- Fahrzeug wurde bereits einmal von einem Spieler benutzt
                        if PlayerVehicles[netId] then
                            goto continue
                        end

                        -- Kennzeichen prüfen
                        local plate = ESX.Math.Trim(GetVehicleNumberPlateText(veh))
                        local owned = lib.callback.await("npc_blocker:isOwnedVehicle", false, plate)

                        -- Spielerfahrzeug -> niemals löschen
                        if owned then
                            goto continue
                        end

                        local driver = GetPedInVehicleSeat(veh, -1)

                        -- NPC fährt
                        if driver ~= 0 and not IsPedAPlayer(driver) then
                            SetEntityAsMissionEntity(driver, true, true)
                            SetEntityAsMissionEntity(veh, true, true)

                            DeletePed(driver)
                            DeleteVehicle(veh)

                        -- Leeres NPC-Fahrzeug
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

    -- Debug Kreis
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

        TriggerEvent('hex_hud:announce', "🔥 PURGE AKTIV", "Alle Gesetze sind außer Kraft!", 8000)

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

        TriggerEvent('hex_hud:announce', "🧊 PURGE ENDE", "Die Stadt kehrt zur Normalität zurück.", 8000)
    end)

    CreateThread(function()
        while true do
            Wait(200) -- leicht verzögert, kein Spam

            if purge then
                local remaining = math.floor((purgeEnd - GetGameTimer()) / 1000)

                -- Nur die letzten 5 Sekunden anzeigen
                if remaining <= 5 and remaining > 0 then
                    if remaining ~= lastNotify then
                        lastNotify = remaining
                        TriggerEvent('hex_hud:notify', "Purge endet", remaining .. " Sekunden", "warning", 1200)
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
    local ESX = exports["es_extended"]:getSharedObject()
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
            ESX.ShowNotification("Du bist nicht bewusstlos.")
            CloseReviveUI()
            return
        end

        TriggerServerEvent("revive:doPaymentAndRevive")
    end)

    RegisterNetEvent("revive:doRevive", function()
        TriggerEvent("esx_ambulancejob:revive")
        CloseReviveUI()
    end)

    -- Dead-only interaction
    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for _, station in ipairs(Config.Revive.Stations) do
                if #(coords - station.coords) < 2.0 then
                    sleep = 0

                    if IsEntityDead(ped) then
                        ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~, um die Revive-Station zu öffnen")

                        if IsControlJustReleased(0, 38) and not reviveUiOpen then
                            OpenReviveUI()
                        end
                    else
                        ESX.ShowHelpNotification("Nur für bewusstlose Personen verfügbar")
                    end
                end
            end

            if reviveUiOpen and sleep == 1000 then
                CloseReviveUI()
            end

            Wait(sleep)
        end
    end)

    -- BLIPS
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

    -- MARKER
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
do
    ESX = exports['es_extended']:getSharedObject()

    local Zones = {}     -- [id] = { id, job, jobLabel, coords, radius, ownerId, ownerName, blip }
    local PlayerData = {}

    -- ────────────────────────────────────────────────
    -- ESX player data
    -- ────────────────────────────────────────────────
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

    -- ────────────────────────────────────────────────
    -- Sync: rebuild local zone table + blips whenever the server pushes an update
    -- (fires on join and on every create/remove)
    -- ────────────────────────────────────────────────
    RegisterNetEvent('mc_sperrzone:syncAll', function(serverZones)
        -- remove old blips
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

    -- ────────────────────────────────────────────────
    -- Notify bridge (HEX HUD)
    -- ────────────────────────────────────────────────
    RegisterNetEvent('mc_sperrzone:notify', function(msg, type)

        local title = "Sperrzone"
        local timeout = 10000

        if type == "success" then
            title = "✅ Sperrzone "
        elseif type == "error" then
            title = "❌ Sperrzone"
        elseif type == "warning" then
            title = "⚠️ Sperrzone"
        elseif type == "info" then
            title = "ℹ️ Sperrzone"
        end

        TriggerEvent('hex_hud:announce', title, msg, timeout)
    end)

    -- ────────────────────────────────────────────────
    -- Draw markers each frame for nearby zones only (perf-friendly)
    -- ────────────────────────────────────────────────
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

    -- ────────────────────────────────────────────────
    -- Helper: is the player currently allowed to create zones?
    -- ────────────────────────────────────────────────
    local function hasZonePermission()
        return PlayerData.job and Config.Jobs[PlayerData.job.name] ~= nil
    end

    -- ────────────────────────────────────────────────
    -- Helper: find a zone the local player is standing inside
    -- ────────────────────────────────────────────────
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

    -- ────────────────────────────────────────────────
    -- Command: create zone
    -- /sperrzone [radius]
    -- ────────────────────────────────────────────────
    RegisterCommand(Config.Commands.create, function(source, args)
        if not hasZonePermission() then
            Config.Notify(_L('no_permission'), 'error')
            return
        end

        local radius = tonumber(args[1]) or Config.DefaultRadius
        local coords = GetEntityCoords(PlayerPedId())

        TriggerServerEvent('mc_sperrzone:create', radius, { x = coords.x, y = coords.y, z = coords.z })
    end, false)

    -- ────────────────────────────────────────────────
    -- Command: remove zone (must be standing inside one you created)
    -- /sperrzone_del
    -- ────────────────────────────────────────────────
    RegisterCommand(Config.Commands.remove, function(source, args)
        local id, zone = findZoneImIn()
        if not id then
            Config.Notify(_L('not_in_own_zone'), 'error')
            return
        end

        local coords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('mc_sperrzone:remove', id, { x = coords.x, y = coords.y, z = coords.z })
    end, false)

    -- ────────────────────────────────────────────────
    -- Cleanup on resource stop
    -- ────────────────────────────────────────────────
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

    function GetVehicleBelowMe(cFrom, cTo) -- Function to get the vehicle under me
        local rayHandle = CastRayPointToPoint(cFrom.x, cFrom.y, cFrom.z, cTo.x, cTo.y, cTo.z, 10, PlayerPedId(), 0) -- Sends raycast under me
        local _, _, _, _, vehicle = GetRaycastResult(rayHandle) -- Stores the vehicle under me
        return vehicle -- Returns the vehicle under me
    end

    function contains(item, list)
        for _, value in ipairs(list) do
            if value == item then return true end
        end
        return false
    end

    function drawNotification(text)
        SetNotificationTextEntry("STRING")
        AddTextComponentString(text)
        DrawNotification(true, false)
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
    local ESX = exports["es_extended"]:getSharedObject()

    CreateThread(function()
        for name, data in pairs(Config.Verkauf) do
            local coords = data.coords

            -- Blip
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

            -- Marker / Interaktion
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

                        ESX.ShowHelpNotification(data.helpmsg)

                        if IsControlJustPressed(0, 38) then -- E
                            TriggerServerEvent("mc_core:verkauf:sell", name)
                        end
                    end

                    Wait(sleep)
                end
            end)
        end
    end)
end