--[[
    ============================================================
    ZUSAMMENGEFÜHRTES SERVER-SCRIPT (mc_core)
    ============================================================
    Fasst zusammen: Abschleppsystem, antiafk, crafter, elevator, event,
    farming, Fraktionssperre, givecar, klingel, labor, maut,
    mechanic_server, moneywash, namecheck, npc_blocker, purge,
    sperrezone, verkauf.

    WICHTIGE VORAUSSETZUNGEN (fxmanifest.lua Reihenfolge!):
    Mehrere Module lesen Config-Felder BEIM LADEN (nicht erst beim
    Aufruf), z.B.:
      - mechanic_server: RegisterCommand(Config.RequestMechanic, ...)
      - sperrezone:      RegisterCommand(Config.Commands.adminList, ...)
      - Fraktionssperre:  RegisterServerEvent(FraksperreConfig.Events.setjob)
    Das heißt: config.lua (und framework.lua, wegen Framework.GetPlayer
    etc. im Mechanic-Modul) MÜSSEN in der fxmanifest.lua VOR dieser
    Datei geladen werden, sonst gibt es beim Start einen Script-Error
    "attempt to index a nil value (global 'Config'/'FraksperreConfig')".

    Empfohlene fxmanifest.lua-Reihenfolge (Auszug):
        shared_script  'config.lua'
        server_script   'framework.lua'
        server_script   'server.lua'   -- diese Datei

    ÄNDERUNGEN GEGENÜBER DEN ORIGINALEN EINZELDATEIEN:
    1) ESX wird jetzt NUR EINMAL global gesetzt (siehe unten). Alle
       Stellen, die vorher "local ESX = exports[...]" oder
       "ESX = exports[...]" wiederholt haben, wurden entfernt und
       nutzen jetzt die eine globale ESX-Variable. Funktional identisch,
       da überall derselbe Aufruf stand.
    2) Im Crafter-Modul gab es einen Schutz "if not Config then ...
       return end" GANZ AM ANFANG der Datei. Als einzelne Ressourcen-
       Datei war das ok (ein "return" auf oberster Ebene beendet nur
       diese eine Datei). In EINER gemeinsamen Datei würde dasselbe
       "return" aber die gesamte restliche server.lua abbrechen
       (Elevator, Event, Farming, ... würden dann NICHT mehr laden!).
       Ich habe das deshalb in ein "if Config then ... end"
       umgebaut, das nur den Crafter-Teil überspringt und den Rest
       der Datei nicht beeinflusst.
    3) Ein paar generische Hilfsnamen, die in mehreren Original-
       Dateien identisch vorkamen (z.B. "local Cooldowns", "SendLog",
       "isAdmin", "sendDiscordLog"), wurden modulspezifisch umbenannt
       (z.B. "MautCooldowns", "SendMautLog", "isSperrzoneAdmin",
       "sendSperrzoneDiscordLog"), damit in dieser einen Datei alles
       eindeutig ist. Das war vorher als separate Dateien kein
       Problem, da jede Datei ihre eigenen "local"-Variablen hatte.
    ============================================================
]]

---------------------------------------------------------------
-- Gemeinsames ESX-Objekt (ersetzt alle einzelnen
-- "ESX = exports['es_extended']:getSharedObject()" Zeilen)
---------------------------------------------------------------
ESX = ESX or exports["es_extended"]:getSharedObject()

---------------------------------------------------------------
-- MODUL: Abschleppsystem
---------------------------------------------------------------

-- Fahrzeugbewegung speichern
RegisterNetEvent("vehicleTrack:updateMovement")
AddEventHandler("vehicleTrack:updateMovement", function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    MySQL.Async.execute(
        "REPLACE INTO vehicle_tracking (plate, owner, last_move, status) VALUES (@plate, @owner, @last_move, 'active')",
        {
            ["@plate"] = plate,
            ["@owner"] = xPlayer.identifier,
            ["@last_move"] = os.time()
        }
    )
end)

-- Automatisches Abschleppen
CreateThread(function()
    while true do
        Wait(600000) -- alle 10 Minuten prüfen

        MySQL.Async.fetchAll("SELECT * FROM vehicle_tracking WHERE status = 'active'", {}, function(result)
            for _, v in ipairs(result) do
                local now = os.time()
                local days = (now - v.last_move) / 86400

                if days >= 3 then
                    print("Automatisches Abschleppen: " .. v.plate)

                    MySQL.Async.execute(
                        "UPDATE vehicle_tracking SET status = 'towed', tow_time = @tow WHERE plate = @plate",
                        {
                            ["@tow"] = now,
                            ["@plate"] = v.plate
                        }
                    )

                    TriggerEvent("vehicleTrack:autoTow", v.plate, v.owner)
                end
            end
        end)
    end
end)

-- Abschlepp-Event
local towDepot = vector3(409.12, -1623.55, 29.29)

RegisterNetEvent("vehicleTrack:autoTow")
AddEventHandler("vehicleTrack:autoTow", function(plate, owner)
    -- Fahrzeug aus der Welt entfernen
    for _, veh in ipairs(GetAllVehicles()) do
        if GetVehicleNumberPlateText(veh) == plate then
            DeleteEntity(veh)
        end
    end

    -- Spieler benachrichtigen
    local xPlayers = ESX.GetPlayers()
    for _, id in ipairs(xPlayers) do
        local xP = ESX.GetPlayerFromId(id)
        if xP and xP.identifier == owner then
            TriggerClientEvent("chat:addMessage", id, {
                args = { "^1Dein Fahrzeug (" .. plate .. ") wurde abgeschleppt, da es 3 Tage nicht bewegt wurde." }
            })
        end
    end

    print("Fahrzeug " .. plate .. " wurde automatisch abgeschleppt.")
end)

-- Abgeschleppte Fahrzeuge abrufen
ESX.RegisterServerCallback("vehicleTrack:getTowedVehicles", function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    MySQL.Async.fetchAll(
        "SELECT * FROM vehicle_tracking WHERE owner = @owner AND status = 'towed'",
        {["@owner"] = xPlayer.identifier},
        function(result)
            cb(result)
        end
    )
end)

---------------------------------------------------------------
-- MODUL: AntiAFK
---------------------------------------------------------------
local AFK_TIME = 30 * 60
local WARNING_TIME = 25 * 60

local playerActivity = {}

local JobWhitelist = {
    ["police"] = true,
    ["ambulance"] = true,
    ["mechanic"] = true,
    ["admin"] = true
}

AddEventHandler('playerJoining', function()
    playerActivity[source] = os.time()
end)

AddEventHandler('playerDropped', function()
    playerActivity[source] = nil
end)

RegisterNetEvent('mc_core:updateActivity')
AddEventHandler('mc_core:updateActivity', function()
    playerActivity[source] = os.time()
end)

-- Discord Logging
local function sendAfkDiscordLog(title, message, color)
    if not Config.AFKWebhook then return end

    local data = {
        embeds = {{
            title = title,
            description = message,
            color = color
        }}
    }

    PerformHttpRequest(Config.AFKWebhook, function() end, "POST", json.encode(data), { ["Content-Type"] = "application/json" })
end

-- SQL Logging
local function logAFK(identifier, name, event)
    MySQL.insert.await(
        "INSERT INTO mc_afk_logs (identifier, name, event) VALUES (?, ?, ?)",
        {identifier, name, event}
    )
end

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()

        for src, lastActive in pairs(playerActivity) do
            local xPlayer = ESX.GetPlayerFromId(src)
            if not xPlayer then goto continue end

            local job = xPlayer.job.name
            local identifier = xPlayer.identifier
            local name = xPlayer.getName()

            -- Whitelist Jobs ignorieren
            if JobWhitelist[job] then
                goto continue
            end

            local diff = now - lastActive

            -- Warnung
            if diff >= WARNING_TIME and diff < AFK_TIME then
                TriggerClientEvent('mc_core:afkWarning', src)

                logAFK(identifier, name, "warning")
                sendAfkDiscordLog(
                    "AFK Warnung",
                    ("**%s** (%s) ist seit 25 Minuten AFK."):format(name, identifier),
                    16776960 -- Gelb
                )
            end

            -- Kick
            if diff >= AFK_TIME then
                logAFK(identifier, name, "kick")
                sendAfkDiscordLog(
                    "AFK Kick",
                    ("**%s** (%s) wurde wegen 30 Minuten AFK gekickt."):format(name, identifier),
                    16711680 -- Rot
                )

                DropPlayer(src, "Du warst 30 min AFK")
            end

            ::continue::
        end
    end
end)

---------------------------------------------------------------
-- MODUL: Crafter
-- (Original hatte hier ein "if not Config then ... return end" auf
--  Dateiebene - umgebaut in ein "if Config then ... end", damit ein
--  fehlendes Config die restlichen Module unten nicht mitreißt)
---------------------------------------------------------------
if not Config then
    print("^1[mc_core] ERROR: Config wurde nicht geladen! Prüfe deine fxmanifest.lua.^7")
else

-- Sucht ein Rezept anhand von Zone + Craft-Name in der Config
local function FindCraft(zoneName, craftName)
    for _, zone in pairs(Config.CraftZones) do
        if zone.name == zoneName then
            for _, craft in pairs(zone.crafts) do
                if craft.name == craftName then
                    return craft
                end
            end
        end
    end
    return nil
end

-- Verhindert, dass ein Spieler mehrere Crafting-Vorgänge gleichzeitig startet
local playerCrafting = {}

-- Fertige, aber noch nicht abgeholte Herstellungen pro Spieler
-- readyCrafts[src] = { [jobId] = { label, item, amount } }
local readyCrafts = {}
local jobCounter = 0

local function NextJobId()
    jobCounter = jobCounter + 1
    return jobCounter
end

-- Baut die Warteschlangen-Anzeige für einen Spieler aus dessen
-- fertigen (aber nicht abgeholten) Herstellungen zusammen.
local function SendReadyQueue(src)
    local queue = {}

    for jobId, job in pairs(readyCrafts[src] or {}) do
        queue[#queue + 1] = {
            id = jobId,
            label = job.label,
            amount = job.amount,
            status = "Fertig",
            collectable = true
        }
    end

    TriggerClientEvent("mc_core:craftQueueUpdate", src, queue)
end

RegisterNetEvent("mc_core:craftItem")
AddEventHandler("mc_core:craftItem", function(data)

    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then return end

    if playerCrafting[src] then
        TriggerClientEvent("esx:showNotification", src, "Du stellst bereits etwas her.")
        return
    end

    local craft = FindCraft(data.zone, data.craft)

    if not craft then
        TriggerClientEvent("esx:showNotification", src, "Unbekanntes Rezept.")
        return
    end

    local amount = tonumber(data.amount) or 1
    amount = math.max(1, math.min(amount, 50)) -- Sicherheitslimit gegen Missbrauch

    -- Zutaten für die GESAMTE Menge prüfen, bevor irgendetwas passiert
    for item, needed in pairs(craft.ingredients) do
        local have = xPlayer.getInventoryItem(item).count

        if have < (needed * amount) then
            TriggerClientEvent(
                "esx:showNotification", src,
                "Nicht genug " .. item .. " (benötigt: " .. (needed * amount) .. ")"
            )
            return
        end
    end

    -- Zutaten für die gesamte Menge sofort abziehen
    for item, needed in pairs(craft.ingredients) do
        xPlayer.removeInventoryItem(item, needed * amount)
    end

    playerCrafting[src] = true

    CreateThread(function()

        for i = 1, amount do

            -- xPlayer kann sich zwischenzeitlich ändern (z.B. nach Reconnect), neu holen
            xPlayer = ESX.GetPlayerFromId(src)

            if not xPlayer then
                playerCrafting[src] = nil
                return
            end

            TriggerClientEvent("mc_core:craftQueueUpdate", src, {
                {
                    label = craft.label,
                    amount = (amount - i + 1),
                    status = "In Arbeit (" .. i .. "/" .. amount .. ")"
                }
            })

            Wait((craft.craftingTime or 10) * 1000) -- z.B. 10 Sekunden pro Item

        end

        -- Fertig! Item wird NICHT automatisch vergeben - der Spieler
        -- muss es im UI über den "Abholen"-Button einsammeln.
        readyCrafts[src] = readyCrafts[src] or {}

        local jobId = NextJobId()
        readyCrafts[src][jobId] = {
            label = craft.label,
            item = craft.reward.item,
            amount = craft.reward.amount * amount
        }

        SendReadyQueue(src)

        TriggerClientEvent(
            "esx:showNotification", src,
            craft.label .. " ist fertig - im Crafter abholen!"
        )

        playerCrafting[src] = nil

    end)

end)

-- Spieler holt eine fertige Herstellung ab
RegisterNetEvent("mc_core:collectCraftItem")
AddEventHandler("mc_core:collectCraftItem", function(jobId)

    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then return end

    local jobs = readyCrafts[src]
    local job = jobs and jobs[jobId]

    if not job then
        TriggerClientEvent("esx:showNotification", src, "Nichts zum Abholen gefunden.")
        SendReadyQueue(src)
        return
    end

    xPlayer.addInventoryItem(job.item, job.amount)
    jobs[jobId] = nil

    TriggerClientEvent(
        "esx:showNotification", src,
        job.amount .. "x " .. job.item .. " abgeholt!"
    )

    SendReadyQueue(src)

end)

-- Beim (Wieder-)Öffnen des Crafter-UI: zeigt an, was schon fertig
-- zum Abholen bereitliegt (z.B. nach dem Schließen/erneut Öffnen)
RegisterNetEvent("mc_core:requestCraftQueue")
AddEventHandler("mc_core:requestCraftQueue", function()
    SendReadyQueue(source)
end)

-- Falls der Spieler disconnected während er craftet, Sperre aufheben
AddEventHandler("playerDropped", function()
    playerCrafting[source] = nil
end)

end -- Ende "if Config then" (Crafter-Modul)

---------------------------------------------------------------
-- MODUL: Elevator
---------------------------------------------------------------
RegisterNetEvent("mc_core:elevator:log", function(name, floor)
    print(("Elevator benutzt: %s -> %s"):format(name, floor))
end)

---------------------------------------------------------------
-- MODUL: Event
---------------------------------------------------------------
RegisterCommand('event', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Admin Check (ACE)
    if not IsPlayerAceAllowed(source, "event.use") then
        TriggerClientEvent('esx:showNotification', source, 'Du hast keine Berechtigung.')
        return
    end

    if #args < 2 then
        TriggerClientEvent('esx:showNotification', source, 'Benutzung: /event <Titel> <Nachricht>')
        return
    end

    local title = args[1]
    table.remove(args, 1)
    local msg = table.concat(args, " ")

    -- Timeout (in Sekunden)
    local timeout = 8000  -- 8 Sekunden

    -- Send to all players
    TriggerClientEvent('mc_event:announce', -1, title, msg, timeout)

    print(("EVENT von %s: %s - %s"):format(GetPlayerName(source), title, msg))
end)

---------------------------------------------------------------
-- MODUL: Farming
---------------------------------------------------------------
local FarmingCooldowns = {}

RegisterNetEvent("mc_core:farming:collect", function(routeName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then return end

    local route = Config.Farming[routeName]
    if not route then return end

    -------------------------------------------------
    -- Cooldown
    -------------------------------------------------

    local cooldown = math.floor(((route.autoFarm and route.autoFarm.interval) or (route.time * 1000) or 5000) / 1000)

    if FarmingCooldowns[src] and FarmingCooldowns[src] > os.time() then
        return
    end

    FarmingCooldowns[src] = os.time() + cooldown

    -------------------------------------------------
    -- Job-Check
    -------------------------------------------------

    if route.disallowed_jobs and #route.disallowed_jobs > 0 then
        local job = xPlayer.getJob().name

        for _, disallowed in ipairs(route.disallowed_jobs) do
            if job == disallowed then
                xPlayer.showNotification("~r~Du darfst hier nicht farmen.")
                return
            end
        end
    end

    -------------------------------------------------
    -- Benötigte Items
    -------------------------------------------------

    if route.needed and #route.needed > 0 then
        for _, need in ipairs(route.needed) do
            if need.type == "item" then
                local item = xPlayer.getInventoryItem(need.name)

                if not item or item.count < (need.amount or 1) then
                    xPlayer.showNotification(("Du benötigst %s x%d")
                        :format(need.label or need.name, need.amount or 1))
                    return
                end
            end
        end
    end

    -------------------------------------------------
    -- Menge bestimmen
    -------------------------------------------------

    local amount = route.outputanzahl or 1

    if route.random and route.random.enabled then
        amount = math.random(route.random.min, route.random.max)
    end

    -------------------------------------------------
    -- BONUS aus der CONFIG
    -------------------------------------------------

    if Config.FarmingBonus and Config.FarmingBonus.enabled then
        local hour = tonumber(os.date("%H"))

        if hour >= Config.FarmingBonus.startHour and hour < Config.FarmingBonus.endHour then
            amount = amount * Config.FarmingBonus.multiplier
            xPlayer.showNotification("~y~Bonuszeit aktiv!~s~ Du erhältst x" .. Config.FarmingBonus.multiplier .. " Loot.")
        end
    end

    -------------------------------------------------
    -- Item geben
    -------------------------------------------------

    xPlayer.addInventoryItem(route.output, amount)

    xPlayer.showNotification(
        ("Du hast %dx %s erhalten.")
        :format(amount, route.output)
    )

    -------------------------------------------------
    -- Bonusitems
    -------------------------------------------------

    if route.random_items
        and route.random_items.enabled
        and route.random_items.items
        and #route.random_items.items > 0 then

        if math.random(1, 100) <= route.random_items.chance then

            local reward = route.random_items.items[
                math.random(1, #route.random_items.items)
            ]

            if reward.type == "item" then

                xPlayer.addInventoryItem(
                    reward.name,
                    reward.amount or 1
                )

                xPlayer.showNotification(
                    ("Bonus erhalten: %s x%d")
                    :format(reward.label or reward.name, reward.amount or 1)
                )

            elseif reward.type == "weapon" then

                if xPlayer.addWeapon then
                    xPlayer.addWeapon(reward.name, 250)
                else
                    xPlayer.addInventoryItem(reward.name, 1)
                end

                xPlayer.showNotification(
                    ("Bonus erhalten: %s")
                    :format(reward.label or reward.name)
                )

            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    FarmingCooldowns[source] = nil
end)

---------------------------------------------------------------
-- MODUL: Fraktionssperre
-- (Original nutzte hier eine eigene "local ESX", die bei Verwendung
--  von TriggerEvent(...) asynchron gesetzt wird. Umgestellt auf die
--  gemeinsame globale ESX-Variable, damit sie sich nicht mit den
--  anderen Modulen überschneidet - Verhalten bleibt identisch, sofern
--  ESX bereits gesetzt ist, was durch die Zeile ganz oben der Fall ist)
---------------------------------------------------------------
if not ESX then
    if FraksperreConfig.ESX.sharedObject.export.use then
        ESX = FraksperreConfig.ESX.sharedObject.export.get()
    else
        TriggerEvent(FraksperreConfig.ESX.sharedObject.event, function(obj) ESX = obj end)
    end
end

-- ============================================================
--  LOKALER CACHE  [identifier] = { until = <unix_ts>, hours = <number> }
-- ============================================================
local FrakSperren = {}

local function frakDbg(msg)
    if FraksperreConfig.Debug then
        print(("^3[FRAKSPERRE]^0 %s"):format(msg))
    end
end

-- WICHTIG: "exports.oxmysql" ist wegen der Export-Metatable in FiveM
-- IMMER ein truthy Table, auch wenn oxmysql gar nicht läuft.
-- Deshalb hier den tatsächlichen Resource-State prüfen.
local function OxmysqlReady()
    return GetResourceState('oxmysql') == 'started'
end

-- ============================================================
--  IDENTIFIER HELPER
-- ============================================================
local function GetIdentifier(xPlayer)
    if not xPlayer then return nil end
    if FraksperreConfig.UseLicense then
        for _, id in pairs(GetPlayerIdentifiers(xPlayer.source)) do
            if string.find(id, "license:") then
                return id
            end
        end
    end
    return xPlayer.identifier
end

-- ============================================================
--  SQL - TABELLE per sql/fraksperre.sql anlegen (siehe README)
-- ============================================================
CreateThread(function()
    if not FraksperreConfig.UseSQL then return end

    if OxmysqlReady() then
        exports.oxmysql:execute([[
            CREATE TABLE IF NOT EXISTS `fraksperre` (
                `identifier` VARCHAR(60) NOT NULL,
                `until` INT(11) NOT NULL,
                `hours` INT(11) NOT NULL,
                PRIMARY KEY (`identifier`)
            )
        ]], {})

        Wait(500)

        exports.oxmysql:query('SELECT * FROM fraksperre', {}, function(result)
            if result then
                local loaded, skipped = 0, 0
                for _, row in ipairs(result) do
                    local untilTs = tonumber(row['until'])
                    local hours   = tonumber(row.hours)

                    -- Defensiv: kaputte/NULL-Zeilen (z.B. manuell in der DB angelegt)
                    -- überspringen und direkt aus der DB entfernen statt den Server crashen zu lassen
                    if untilTs and row.identifier then
                        FrakSperren[row.identifier] = { ['until'] = untilTs, hours = hours or 0 }
                        loaded = loaded + 1
                    else
                        skipped = skipped + 1
                        exports.oxmysql:execute('DELETE FROM fraksperre WHERE identifier = ?', { row.identifier })
                        print(("^1[FRAKSPERRE] Ungültige Zeile für identifier '%s' in der DB gefunden und entfernt (until war NULL/ungültig)^0"):format(tostring(row.identifier)))
                    end
                end
                frakDbg(("%s aktive Fraksperren aus der Datenbank geladen (%s ungültige übersprungen/entfernt)"):format(loaded, skipped))
            end
        end)
    else
        print("^1[FRAKSPERRE] FEHLER: oxmysql läuft nicht! Bitte oxmysql vor mc_core starten oder FraksperreConfig.UseSQL = false setzen.^0")
    end
end)

local function SQL_Save(identifier, untilTs, hours)
    if not FraksperreConfig.UseSQL then return end
    if OxmysqlReady() then
        exports.oxmysql:execute(
            'INSERT INTO fraksperre (identifier, `until`, hours) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `until` = ?, hours = ?',
            { identifier, untilTs, hours, untilTs, hours }
        )
    end
end

local function SQL_Delete(identifier)
    if not FraksperreConfig.UseSQL then return end
    if OxmysqlReady() then
        exports.oxmysql:execute('DELETE FROM fraksperre WHERE identifier = ?', { identifier })
    end
end

-- ============================================================
--  NOTIFY HELPER
-- ============================================================
local function FrakNotify(src, message)
    if not src or src == 0 then return end
    TriggerClientEvent(FraksperreConfig.Notify.event, src, message)
end

local function FrakHelpNotify(src, message)
    if not src or src == 0 then return end
    if FraksperreConfig.Notify.useHelpOnJoin then
        TriggerClientEvent(FraksperreConfig.Notify.helpEvent, src, message)
    end
end

-- ============================================================
--  DISCORD LOG
-- ============================================================
local function FrakDiscordLog(description, fields)
    local D = FraksperreConfig.Discord
    if not D.enabled or not D.webhook or D.webhook == "" then return end

    PerformHttpRequest(D.webhook, function() end, 'POST', json.encode({
        username = D.username,
        avatar_url = D.avatar_url,
        embeds = {
            {
                title = D.title,
                description = description,
                color = D.color,
                fields = fields or {},
                thumbnail = { url = D.icon_url },
                footer = { text = os.date('%d.%m.%Y %H:%M:%S') }
            }
        }
    }), { ['Content-Type'] = 'application/json' })
end

-- ============================================================
--  CORE FUNKTIONEN
-- ============================================================

-- Prüft ob ein Identifier aktuell gesperrt ist.
-- Gibt: isBlocked (bool), untilTimestamp (number|nil)
local function IsBlocked(identifier)
    if not identifier then return false, nil end

    local entry = FrakSperren[identifier]
    if not entry then return false, nil end

    -- Defensiv: falls entry['until'] aus irgendeinem Grund kein gültiger Zahlenwert ist
    -- (kaputte Daten, manuelle DB-Eingriffe, etc.), Eintrag verwerfen statt zu crashen
    local untilTs = tonumber(entry['until'])
    if not untilTs then
        frakDbg(("Ungültiger 'until'-Wert für Identifier '%s' im Cache gefunden, Eintrag wird entfernt"):format(tostring(identifier)))
        FrakSperren[identifier] = nil
        SQL_Delete(identifier)
        return false, nil
    end

    if untilTs <= os.time() then
        -- Sperre abgelaufen -> aufräumen
        FrakSperren[identifier] = nil
        SQL_Delete(identifier)
        return false, nil
    end

    return true, untilTs
end

local function SetBlock(identifier, hours)
    local untilTs = os.time() + (hours * 3600)
    FrakSperren[identifier] = { ['until'] = untilTs, hours = hours }
    SQL_Save(identifier, untilTs, hours)
    return untilTs
end

local function RemoveBlock(identifier)
    FrakSperren[identifier] = nil
    SQL_Delete(identifier)
end

-- Prüft ob ein Spieler laut ESX-Group berechtigt ist
local function IsFrakAdmin(xPlayer)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    return FraksperreConfig.Admins[group] == true
end

-- Prüft ob ein Job von der Sperre ausgenommen ist
local function IsWhitelistedJob(jobName)
    for _, whitelisted in ipairs(FraksperreConfig.Jobs.whitelist) do
        if whitelisted == jobName then
            return true
        end
    end
    return false
end

-- ============================================================
--  EXPORTS  (damit andere Module wie crafter/labor/farming/verkauf
--  den Sperrstatus abfragen können)
-- ============================================================
exports('FraksperreIsBlocked', function(identifier)
    return IsBlocked(identifier)
end)

exports('FraksperreIsPlayerBlocked', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    return IsBlocked(GetIdentifier(xPlayer))
end)

exports('FraksperreSetBlock', function(identifier, hours)
    return SetBlock(identifier, hours)
end)

exports('FraksperreRemoveBlock', function(identifier)
    return RemoveBlock(identifier)
end)

-- ============================================================
--  JOB-SETZEN ABFANGEN
--  Erwartete Nutzung durch Job-Menüs/Resourcen:
--  TriggerServerEvent(FraksperreConfig.Events.setjob, jobName, grade)
-- ============================================================
RegisterServerEvent(FraksperreConfig.Events.setjob)
AddEventHandler(FraksperreConfig.Events.setjob, function(jobName, grade)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = GetIdentifier(xPlayer)
    local blocked = IsBlocked(identifier)

    if blocked and not IsWhitelistedJob(jobName) then
        FrakNotify(src, FraksperreConfig.Language.blockedjob)
        frakDbg(("%s hat versucht während aktiver Fraksperre den Job '%s' anzunehmen (blockiert)"):format(xPlayer.getName(), jobName))
        return
    end

    xPlayer.setJob(jobName, grade or 0)
end)

-- ============================================================
--  PLAYER LOADED -> Sperrstatus prüfen und ggf. informieren
--  ESX feuert dieses Event als: TriggerEvent('esx:playerLoaded', playerId, xPlayer, ...)
--  Der erste Parameter ist also die Spieler-ID (number), NICHT das xPlayer-Objekt!
-- ============================================================
AddEventHandler(FraksperreConfig.Events.playerLoaded, function(playerId, xPlayer)
    if not xPlayer then return end
    local src = xPlayer.source or playerId
    local identifier = GetIdentifier(xPlayer)

    local blocked, untilTs = IsBlocked(identifier)
    if blocked then
        local dateStr = os.date('%d.%m.%Y %H:%M:%S', untilTs)
        FrakNotify(src, FraksperreConfig.Language.blocktimeleft:format(dateStr))
        FrakHelpNotify(src, FraksperreConfig.Language.blocktimeleft:format(dateStr))
    end
end)

-- ============================================================
--  COMMAND: setfraksperre [id] [stunden]
-- ============================================================
RegisterCommand(FraksperreConfig.Commands.setblock, function(source, args)
    local src = source
    if src == 0 then return end -- Konsole nicht erlaubt (Sicherheit), ggf. anpassen

    local L = FraksperreConfig.Language
    local xPlayer = ESX.GetPlayerFromId(src)
    if not IsFrakAdmin(xPlayer) then
        FrakNotify(src, L.noperms)
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        FrakNotify(src, L.targetidmissing)
        return
    end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        FrakNotify(src, L.targetnotfound)
        return
    end

    local hours = tonumber(args[2]) or FraksperreConfig.Hours
    if not hours or hours <= 0 then
        FrakNotify(src, L.invalidhours)
        return
    end

    local identifier = GetIdentifier(targetPlayer)
    local alreadyBlocked = IsBlocked(identifier)
    if alreadyBlocked then
        FrakNotify(src, L.targethasblock)
        return
    end

    local untilTs = SetBlock(identifier, hours)

    FrakNotify(targetId, L.blockset:format(hours))
    FrakNotify(src, L.setsuccess:format(targetPlayer.getName(), hours))

    frakDbg(("%s (%s) hat %s (%s) für %s Stunden gesperrt"):format(
        xPlayer.getName(), src, targetPlayer.getName(), targetId, hours
    ))

    FrakDiscordLog("**Fraksperre gesetzt**", {
        { name = "Admin",     value = ("%s (ID: %s)"):format(xPlayer.getName(), src), inline = true },
        { name = "Ziel",      value = ("%s (ID: %s)"):format(targetPlayer.getName(), targetId), inline = true },
        { name = "Dauer",     value = ("%s Stunden"):format(hours), inline = true },
        { name = "Aktiv bis", value = os.date('%d.%m.%Y %H:%M:%S', untilTs), inline = false },
    })
end, false)

-- ============================================================
--  COMMAND: removefraksperre [id]
-- ============================================================
RegisterCommand(FraksperreConfig.Commands.removeblock, function(source, args)
    local src = source
    if src == 0 then return end

    local L = FraksperreConfig.Language
    local xPlayer = ESX.GetPlayerFromId(src)
    if not IsFrakAdmin(xPlayer) then
        FrakNotify(src, L.noperms)
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        FrakNotify(src, L.targetidmissing)
        return
    end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        FrakNotify(src, L.targetnotfound)
        return
    end

    local identifier = GetIdentifier(targetPlayer)
    local blocked = IsBlocked(identifier)
    if not blocked then
        FrakNotify(src, L.targetnotblocked)
        return
    end

    RemoveBlock(identifier)

    FrakNotify(targetId, L.teamler)
    FrakNotify(src, L.removesuccess:format(targetPlayer.getName()))

    frakDbg(("%s (%s) hat die Fraksperre von %s (%s) entfernt"):format(
        xPlayer.getName(), src, targetPlayer.getName(), targetId
    ))

    FrakDiscordLog("**Fraksperre entfernt**", {
        { name = "Admin", value = ("%s (ID: %s)"):format(xPlayer.getName(), src), inline = true },
        { name = "Ziel",  value = ("%s (ID: %s)"):format(targetPlayer.getName(), targetId), inline = true },
    })
end, false)

-- ============================================================
--  COMMAND: getfraksperre [id]
-- ============================================================
RegisterCommand(FraksperreConfig.Commands.getblocktime, function(source, args)
    local src = source
    if src == 0 then return end

    local L = FraksperreConfig.Language
    local xPlayer = ESX.GetPlayerFromId(src)
    if not IsFrakAdmin(xPlayer) then
        FrakNotify(src, L.noperms)
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        FrakNotify(src, L.targetidmissing)
        return
    end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        FrakNotify(src, L.targetnotfound)
        return
    end

    local identifier = GetIdentifier(targetPlayer)
    local blocked, untilTs = IsBlocked(identifier)

    if not blocked then
        FrakNotify(src, L.targetnotblocked)
        return
    end

    local dateStr = os.date('%d.%m.%Y %H:%M:%S', untilTs)
    FrakNotify(src, L.targetblocktimeleft:format(targetPlayer.getName(), dateStr))
end, false)

-- ============================================================
--  AUFRÄUM-THREAD: entfernt abgelaufene Sperren periodisch aus dem Cache/DB
-- ============================================================
CreateThread(function()
    while true do
        Wait(60000) -- jede Minute
        local now = os.time()
        for identifier, entry in pairs(FrakSperren) do
            local untilTs = tonumber(entry['until'])
            if not untilTs or untilTs <= now then
                frakDbg(("Fraksperre von %s ist abgelaufen und wurde entfernt"):format(identifier))
                FrakSperren[identifier] = nil
                SQL_Delete(identifier)

                -- Falls der Spieler online ist, informieren
                local players = ESX.GetPlayers and ESX.GetPlayers() or {}
                for _, playerId in ipairs(players) do
                    local xTarget = ESX.GetPlayerFromId(playerId)
                    if xTarget and GetIdentifier(xTarget) == identifier then
                        FrakNotify(playerId, FraksperreConfig.Language.blockexpired)
                        break
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------
-- MODUL: GiveCar
---------------------------------------------------------------
ConfigGiveCar = ConfigGiveCar or {}

-- RandomString Fix (ESX Legacy hat diese Funktion nicht)
local function GenerateRandomString(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = ""

    for i = 1, length do
        local rand = math.random(1, #charset)
        result = result .. charset:sub(rand, rand)
    end

    return result
end

RegisterCommand("givecar", function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)

    -- Admin Check
    if not ConfigGiveCar.AdminGroups[xPlayer.getGroup()] then
        xPlayer.showNotification(ConfigGiveCar.Messages.noPerms)
        return
    end

    -- Args
    local targetId = tonumber(args[1])
    local vehicleModel = args[2]
    local plate = args[3]

    if not targetId or not vehicleModel then
        xPlayer.showNotification(ConfigGiveCar.Messages.usage)
        return
    end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        xPlayer.showNotification(ConfigGiveCar.Messages.playerNotFound)
        return
    end

    -- Auto Plate
    if not plate and ConfigGiveCar.AutoPlate.enabled then
        plate = ConfigGiveCar.AutoPlate.prefix .. "" .. GenerateRandomString(ConfigGiveCar.AutoPlate.length)
    end

    -- Fahrzeug-Daten
    local props = {
        model = GetHashKey(vehicleModel),
        plate = plate
    }

    -- DB Insert
    MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle, stored) VALUES (?, ?, ?, ?)', {
        target.identifier,
        plate,
        json.encode(props),
        1
    })

    -- Logging
    if ConfigGiveCar.Logging.enabled and ConfigGiveCar.Logging.webhook ~= "" then
        PerformHttpRequest(ConfigGiveCar.Logging.webhook, function() end, "POST", json.encode({
            username = "GiveCar Log",
            embeds = {{
                title = "Fahrzeug vergeben",
                color = 3066993,
                fields = {
                    { name = "Admin", value = xPlayer.getName() .. " (" .. xPlayer.identifier .. ")" },
                    { name = "Spieler", value = target.getName() .. " (" .. target.identifier .. ")" },
                    { name = "Modell", value = vehicleModel },
                    { name = "Kennzeichen", value = plate }
                }
            }}
        }), { ["Content-Type"] = "application/json" })
    end

    -- Notifications
    xPlayer.showNotification(
        ConfigGiveCar.Messages.carGivenAdmin
            :gsub("%%model%%", vehicleModel)
            :gsub("%%plate%%", plate)
            :gsub("%%id%%", targetId)
    )

    target.showNotification(
        ConfigGiveCar.Messages.carGivenPlayer
            :gsub("%%model%%", vehicleModel)
            :gsub("%%plate%%", plate)
    )

    -- Auto Spawn
    if ConfigGiveCar.SpawnVehicleOnGive then
        TriggerClientEvent("givecar:spawn", targetId, vehicleModel, plate)
    end
end)

---------------------------------------------------------------
-- MODUL: Klingel
---------------------------------------------------------------
RegisterNetEvent("mc_core:klingel:trigger")
AddEventHandler("mc_core:klingel:trigger", function(job)
    local cfg = Config.Klingel.Jobs[job]
    if not cfg then return end

    for _, id in ipairs(GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(id)
        if xPlayer and xPlayer.job.name == job then
            TriggerClientEvent("mc_core:klingel:play", id, cfg.label, cfg.sound)
            TriggerClientEvent("esx:showNotification", id, "🔔 " .. cfg.notify)
        end
    end

    -- Hinweis: "src" war im Original hier nicht definiert (Bug in der
    -- Originaldatei - hätte einen Fehler geworfen). Auf "source" korrigiert.
    print(("Klingel ausgelöst von %s für Job %s"):format(source, job))
end)

---------------------------------------------------------------
-- MODUL: Labor
---------------------------------------------------------------
local laborData = {}

RegisterServerEvent("mc_core:getLaborStatus")
AddEventHandler("mc_core:getLaborStatus", function(id)
    local src = source

    if not laborData[id] then
        laborData[id] = {
            items = 0,
            money = 0,
            finish = 0
        }
    end

    TriggerClientEvent("mc_core:sendLaborStatus", src, laborData[id])
end)

RegisterServerEvent("mc_core:depositLabor")
AddEventHandler("mc_core:depositLabor", function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    local id = data.labor
    local amount = tonumber(data.amount)

    if not laborData[id] then return end

    if xPlayer.getInventoryItem(Config.Labors[id].inputItem).count < amount then
        xPlayer.showNotification("Nicht genug Material!")
        return
    end

    xPlayer.removeInventoryItem(Config.Labors[id].inputItem, amount)

    laborData[id].items = laborData[id].items + amount
    laborData[id].finish = Date.now() + Config.Labors[id].processTime

    xPlayer.showNotification("Produktion gestartet!")
end)

RegisterServerEvent("mc_core:collectLabor")
AddEventHandler("mc_core:collectLabor", function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    local id = data.labor

    if not laborData[id] then return end

    local payout = laborData[id].items * Config.Labors[id].moneyPerItem

    xPlayer.addAccountMoney("black_money", payout)

    laborData[id].items = 0
    laborData[id].money = 0
    laborData[id].finish = 0

    xPlayer.showNotification("Schwarzgeld abgeholt!")
end)

---------------------------------------------------------------
-- MODUL: Maut
---------------------------------------------------------------
local MautCooldowns = {}

RegisterNetEvent("mc_core:maut:pay")
AddEventHandler("mc_core:maut:pay", function(tollName, price, speed)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local now = os.time()

    MautCooldowns[identifier] = MautCooldowns[identifier] or {}

    if MautCooldowns[identifier][tollName] and MautCooldowns[identifier][tollName] > now then
        return
    end

    MautCooldowns[identifier][tollName] = now + MautConfig.Cooldown

    if MautConfig.FreeJobs[xPlayer.job.name] then
        TriggerClientEvent("hex_hud:notify", source, "Mautstelle", "Du darfst kostenlos passieren.")
        SendMautLog(xPlayer, tollName, price, speed, "FREEJOB")
        return
    end

    local paid = false

    if MautConfig.UseBank then
        if xPlayer.getAccount("bank").money >= price then
            xPlayer.removeAccountMoney("bank", price)
            paid = true
        end
    end

    if not paid then
        if xPlayer.getMoney() >= price then
            xPlayer.removeMoney(price)
            paid = true
        end
    end

    if paid then
        TriggerClientEvent("hex_hud:notify", source, "Mautstelle", price .. "$ wurden abgebucht.")
        SendMautLog(xPlayer, tollName, price, speed, "PAID_SPEED")
    else
        TriggerClientEvent("hex_hud:notify", source, "Mautstelle", "Nicht genügend Geld für die Maut.")
        SendMautLog(xPlayer, tollName, price, speed, "FAILED")
    end
end)

RegisterNetEvent("mc_core:maut:policeAlert")
AddEventHandler("mc_core:maut:policeAlert", function(tollName, price, speed)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    for _, id in ipairs(ESX.GetPlayers()) do
        local p = ESX.GetPlayerFromId(id)
        if p and p.job and p.job.name == "police" then
            TriggerClientEvent("hex_hud:notify", id, "Maut-Alarm",
                ("Raser erkannt: %.1f km/h an %s"):format(speed, tollName)
            )
        end
    end

    SendMautLog(xPlayer, tollName, price, speed, "POLICE_ALERT")
end)

-- Hinweis: im Original hieß diese Funktion "SendLog" (global). Umbenannt
-- auf "SendMautLog", zur Übersichtlichkeit/Robustheit in dieser
-- gemeinsamen Datei.
function SendMautLog(xPlayer, tollName, price, speed, status)
    if not MautConfig.Webhook or MautConfig.Webhook == "" then return end

    local msg = ("**%s** (%s)\n%s\nPreis: **%s$**\nSpeed: **%.1f km/h**\nStatus: **%s**")
        :format(xPlayer.getName(), xPlayer.identifier, tollName, price, speed, status)

    PerformHttpRequest(MautConfig.Webhook, function() end, "POST", json.encode({
        username = "Mautsystem",
        embeds = {{
            title = "Maut-Log",
            description = msg,
            color = 3066993
        }}
    }), { ["Content-Type"] = "application/json" })
end

---------------------------------------------------------------
-- MODUL: Mechanic (mechanic_server)
-- Erwartet: config.lua und framework.lua bereits geladen (siehe Hinweis
-- ganz oben in dieser Datei)
---------------------------------------------------------------
local PlayerInsurance = {} -- PlayerInsurance[source] = { [plate] = tier, ... }

-- DB helper: supports mysql-async or oxmysql
local function mechDbExecute(query, params, cb)
    if exports and exports.oxmysql then
        exports.oxmysql:execute(query, params or {}, function(affected)
            if cb then cb(affected) end
        end)
    else
        MySQL.Async.execute(query, params or {}, function(affected)
            if cb then cb(affected) end
        end)
    end
end

local function mechDbFetchScalar(query, params, cb)
    if exports and exports.oxmysql then
        exports.oxmysql:scalar(query, params or {}, function(result)
            if cb then cb(result) end
        end)
    else
        MySQL.Async.fetchScalar(query, params or {}, function(result)
            if cb then cb(result) end
        end)
    end
end

local function mechDbFetchAll(query, params, cb)
    if exports and exports.oxmysql then
        exports.oxmysql:execute(query, params or {}, function(result)
            if cb then cb(result) end
        end)
    else
        MySQL.Async.fetchAll(query, params or {}, function(result)
            if cb then cb(result) end
        end)
    end
end

-- Ensure table exists (run once on resource start)
CreateThread(function()
    local q = [[
        CREATE TABLE IF NOT EXISTS vs_insurance (
            plate VARCHAR(20) PRIMARY KEY,
            tier VARCHAR(20) NOT NULL
        );
    ]]
    mechDbExecute(q, {}, function() end)
end)

-- Helper: save plate -> tier to DB
local function saveInsuranceToDB(plate, tier)
    local q = "REPLACE INTO vs_insurance (plate, tier) VALUES (@plate, @tier)"
    local params = {["@plate"] = plate, ["@tier"] = tier}
    mechDbExecute(q, params)
end

-- Helper: remove insurance from DB (if needed)
local function removeInsuranceFromDB(plate)
    local q = "DELETE FROM vs_insurance WHERE plate = @plate"
    mechDbExecute(q, {["@plate"] = plate})
end

-- Helper: load insurance for plate and send to player
RegisterServerEvent("mc_insurance:getForPlate")
AddEventHandler("mc_insurance:getForPlate", function(plate)
    local src = source
    if not plate or plate == "" then
        TriggerClientEvent("mc_insurance:setTier", src, plate, "basic")
        return
    end

    mechDbFetchScalar("SELECT tier FROM vs_insurance WHERE plate = @plate", {["@plate"] = plate}, function(tier)
        if not tier then tier = "basic" end
        -- send tier to requesting client
        TriggerClientEvent("mc_insurance:setTier", src, plate, tier)
    end)
end)

-- Buy insurance (expects plate param)
RegisterServerEvent("mc_insurance:buy")
AddEventHandler("mc_insurance:buy", function(tier, plate)
    local src = source
    if not tier or not plate then
        TriggerClientEvent("mc_vsMechanic:notify", src, "Ungültige Versicherungsdaten.")
        return
    end

    local xPlayer = Framework.GetPlayer(src)
    if not xPlayer then return end

    local cost, mode
    if tier == 'basic' then
        mode = Config.MechanicInsuranceBasic
        cost = Config.MechanicInsuranceBasicCost
    elseif tier == 'default' then
        mode = Config.MechanicInsuranceDefault
        cost = Config.MechanicInsuranceDefaultCost
    elseif tier == 'premium' then
        mode = Config.MechanicInsurancePremium
        cost = Config.MechanicInsurancePremiumCost
    else
        TriggerClientEvent("mc_vsMechanic:notify", src, "Unbekannter Tarif.")
        return
    end

    local payAmount = cost
    if mode == 'percentage' then
        local salary = Framework.GetMoney(xPlayer)
        payAmount = math.floor((salary * cost) / 100)
    end

    if Framework.GetMoney(xPlayer) < payAmount then
        TriggerClientEvent('mc_vsMechanic:notify', src, "Du hast nicht genug Geld für diese Versicherung.")
        return
    end

    -- Remove money and persist
    Framework.RemoveMoney(xPlayer, payAmount)

    -- Update in-memory mapping for this player (support multiple plates)
    PlayerInsurance[src] = PlayerInsurance[src] or {}
    PlayerInsurance[src][plate] = tier

    -- Persist to DB per plate
    saveInsuranceToDB(plate, tier)

    -- Notify client and set tier on client side
    TriggerClientEvent('mc_vsMechanic:notify', src, "Versicherung abgeschlossen: "..tier)
    TriggerClientEvent("mc_insurance:setTier", src, plate, tier)
end)

-- Periodic billing: iterate PlayerInsurance table (per online player)
CreateThread(function()
    while true do
        Wait((Config.PayIntervall or 15) * 60000) -- minutes -> ms

        for src, plates in pairs(PlayerInsurance) do
            local xPlayer = Framework.GetPlayer(src)
            if xPlayer then
                for plate, tier in pairs(plates) do
                    local cost, mode
                    if tier == 'basic' then
                        mode = Config.MechanicInsuranceBasic
                        cost = Config.MechanicInsuranceBasicCost
                    elseif tier == 'default' then
                        mode = Config.MechanicInsuranceDefault
                        cost = Config.MechanicInsuranceDefaultCost
                    elseif tier == 'premium' then
                        mode = Config.MechanicInsurancePremium
                        cost = Config.MechanicInsurancePremiumCost
                    else
                        cost = 0
                    end

                    local payAmount = cost
                    if mode == 'percentage' then
                        local salary = Framework.GetMoney(xPlayer)
                        payAmount = math.floor((salary * cost) / 100)
                    end

                    -- If player has enough money, charge; otherwise cancel insurance for that plate
                    if Framework.GetMoney(xPlayer) >= payAmount and payAmount > 0 then
                        Framework.RemoveMoney(xPlayer, payAmount)
                        TriggerClientEvent('mc_vsMechanic:notify', src, "Versicherungsrate abgebucht: $"..payAmount.." für "..plate)
                    else
                        -- optional: cancel insurance if cannot pay
                        PlayerInsurance[src][plate] = nil
                        removeInsuranceFromDB(plate)
                        TriggerClientEvent('mc_vsMechanic:notify', src, "Versicherung für "..plate.." wurde gekündigt (unzureichende Mittel).")
                        -- inform client to update cache if they are in that vehicle
                        TriggerClientEvent("mc_insurance:setTier", src, plate, "basic")
                    end
                end
            else
                -- Player offline: we keep DB entry; billing will occur when they are online via PlayerInsurance mapping
                -- Optionally: you can implement offline billing by storing identifiers and charging on login
            end
        end
    end
end)

-- Helper: when player connects, load their insured plates into PlayerInsurance
-- This requires a server event to be called on player spawn/login from client or core
RegisterServerEvent("mc_insurance:loadPlayerInsurances")
AddEventHandler("mc_insurance:loadPlayerInsurances", function()
    local src = source
    PlayerInsurance[src] = PlayerInsurance[src] or {}

    -- Load all DB entries and check which plates belong to this player
    -- Note: mapping plate -> owner is not trivial server-side; we assume player wants to load plates they own.
    -- Simpler approach: send all DB entries to client and let client decide which plates belong to them (client can call getForPlate per vehicle)
    -- Here we do nothing heavy; client will request per-plate via mc_insurance:getForPlate when needed.
end)

-- Clean up PlayerInsurance on player disconnect
AddEventHandler('playerDropped', function(reason)
    local src = source
    PlayerInsurance[src] = nil
end)

-- Command: request mechanic (uses mc_vsMechanic events)
local mechLastCommandUse = {}

RegisterCommand(Config.RequestMechanic or "requestmechanic", function(source)
    local now = os.time()
    if mechLastCommandUse[source] and now - mechLastCommandUse[source] < (Config.CommandDelay or 15) then
        -- Use server-side message helper if available
        local xPlayer = Framework.GetPlayer(source)
        if xPlayer and Framework.ShowNotification then
            Framework.ShowNotification("Bitte warte kurz, bevor du erneut einen Mechaniker rufst.")
        else
            print("[mc_vsMechanic] Bitte warte kurz, bevor du erneut einen Mechaniker rufst.")
        end
        return
    end

    mechLastCommandUse[source] = now

    local onlineMechs = Framework.GetOnlineMechanics and Framework.GetOnlineMechanics() or 0

    if Config.MechanicInsurance then
        -- client will request plate and determine tier via cache or server
        TriggerClientEvent('mc_vsMechanic:requestWithInsurance', source, onlineMechs)
    else
        if onlineMechs > Config.RequiredMechanic then
            if Framework.ShowNotification then
                Framework.ShowNotification("Es sind genug Mechaniker online – nutze das RP.")
            else
                print("[mc_vsMechanic] Es sind genug Mechaniker online – nutze das RP.")
            end
            return
        end
        TriggerClientEvent('mc_vsMechanic:spawnNPCMechanic', source, Config.MechanicDuration, Config.RepairDuration, Config.MechanicCost)
    end
end, false)

-- Optional: server command to set insurance for a plate (admin)
RegisterCommand("mc_setinsurance", function(source, args, raw)
    -- args: plate, tier
    if #args < 2 then
        TriggerClientEvent('mc_vsMechanic:notify', source, "Usage: /mc_setinsurance <plate> <basic|default|premium>")
        return
    end
    local plate = tostring(args[1])
    local tier = tostring(args[2])

    saveInsuranceToDB(plate, tier)
    TriggerClientEvent('mc_vsMechanic:notify', source, "Versicherung gesetzt: "..plate.." -> "..tier)
end, true)

---------------------------------------------------------------
-- MODUL: Moneywash
---------------------------------------------------------------
local lastMoneywashPoliceAlert = 0

-------------------------------------------------
-- Datenbank
-------------------------------------------------

CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `mc_moneywash_jobs` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier`   VARCHAR(60) NOT NULL,
            `amount`       INT NOT NULL,
            `fee`          INT NOT NULL,
            `clean_amount` INT NOT NULL,
            `started_at`   BIGINT NOT NULL,
            `finish_at`    BIGINT NOT NULL
        )
    ]])
end)

-------------------------------------------------
-- Helper
-------------------------------------------------

local function ComputeCustomFee(amount)
    for _, tier in ipairs(Config.Moneywash.custom.feeTiers) do
        if amount <= tier.upto then
            return tier.fee
        end
    end
    return Config.Moneywash.custom.feeTiers[#Config.Moneywash.custom.feeTiers].fee
end

local function ComputeCustomTime(amount)
    local minutes = Config.Moneywash.custom.baseTimeMinutes
        + (amount / 1000000) * Config.Moneywash.custom.minutesPerMillion

    if minutes > Config.Moneywash.custom.maxTimeMinutes then
        minutes = Config.Moneywash.custom.maxTimeMinutes
    end

    return math.floor(minutes)
end

local function GetMoneywashJobs(identifier, cb)
    exports.oxmysql:execute(
        "SELECT id, amount, fee, clean_amount, started_at, finish_at FROM mc_moneywash_jobs WHERE identifier = ? ORDER BY id ASC",
        { identifier },
        function(result) cb(result or {}) end
    )
end

local function GetCleanMoney(xPlayer)
    if Config.Moneywash.cleanMoneyType == "bank" then
        return xPlayer.getAccount("bank").money
    end
    return xPlayer.getMoney()
end

local function SendMoneywashStatus(src, xPlayer)
    local blackMoney = xPlayer.getAccount(Config.Moneywash.blackMoneyAccount).money
    local cleanMoney = GetCleanMoney(xPlayer)

    GetMoneywashJobs(xPlayer.identifier, function(jobs)
        TriggerClientEvent("mc_core:sendMoneywashStatus", src, {
            blackMoney = blackMoney,
            cleanMoney = cleanMoney,
            jobs = jobs,
            now = os.time(),
        })
    end)
end

local function TryMoneywashPoliceAlert(src)
    local cfg = Config.Moneywash.policeNotify
    if not cfg.enabled then return end
    if (os.time() - lastMoneywashPoliceAlert) < (cfg.cooldown * 60) then return end
    if math.random(100) > cfg.chance then return end

    lastMoneywashPoliceAlert = os.time()

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)

    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xTarget = ESX.GetPlayerFromId(playerId)
        if xTarget and xTarget.job then
            for _, j in ipairs(cfg.jobs) do
                if xTarget.job.name == j then
                    TriggerClientEvent("mc_core:moneywashPoliceAlert", xTarget.source, coords, cfg.blipTime)
                    break
                end
            end
        end
    end
end

-------------------------------------------------
-- Status abrufen
-------------------------------------------------

RegisterServerEvent("mc_core:getMoneywashStatus")
AddEventHandler("mc_core:getMoneywashStatus", function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    SendMoneywashStatus(src, xPlayer)
end)

-------------------------------------------------
-- Wäsche starten
-------------------------------------------------

RegisterServerEvent("mc_core:startMoneywash")
AddEventHandler("mc_core:startMoneywash", function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(data) ~= "table" then return end

    local amount, fee, timeMinutes

    if data.type == "package" then
        local pkg
        for _, p in ipairs(Config.Moneywash.packages) do
            if p.id == tonumber(data.packageId) then
                pkg = p
                break
            end
        end
        if not pkg then
            xPlayer.showNotification("Ungültiges Paket.")
            return
        end
        amount, fee, timeMinutes = pkg.amount, pkg.fee, pkg.time

    elseif data.type == "custom" then
        amount = tonumber(data.amount)
        if not amount or amount < Config.Moneywash.custom.minAmount or amount > Config.Moneywash.custom.maxAmount then
            xPlayer.showNotification("Ungültiger Betrag.")
            return
        end
        fee = ComputeCustomFee(amount)
        timeMinutes = ComputeCustomTime(amount)

    else
        return
    end

    GetMoneywashJobs(xPlayer.identifier, function(jobs)
        if #jobs >= Config.Moneywash.maxActiveJobs then
            xPlayer.showNotification("Du hast bereits zu viele aktive Wäschen laufen.")
            return
        end

        local blackMoney = xPlayer.getAccount(Config.Moneywash.blackMoneyAccount).money
        if blackMoney < amount then
            xPlayer.showNotification("Du hast nicht genug Schwarzgeld.")
            return
        end

        local cleanAmount = math.floor(amount - (amount * (fee / 100)))
        local startedAt   = os.time()
        local finishAt     = startedAt + (timeMinutes * 60)

        xPlayer.removeAccountMoney(Config.Moneywash.blackMoneyAccount, amount)
        if xPlayer.save then xPlayer.save() end

        exports.oxmysql:insert(
            "INSERT INTO mc_moneywash_jobs (identifier, amount, fee, clean_amount, started_at, finish_at) VALUES (?, ?, ?, ?, ?, ?)",
            { xPlayer.identifier, amount, fee, cleanAmount, startedAt, finishAt },
            function()
                xPlayer.showNotification("Geldwäsche gestartet!")
                SendMoneywashStatus(src, xPlayer)
            end
        )
    end)
end)

-------------------------------------------------
-- Gewaschenes Geld abholen
-------------------------------------------------

RegisterServerEvent("mc_core:collectMoneywash")
AddEventHandler("mc_core:collectMoneywash", function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(data) ~= "table" then return end

    exports.oxmysql:execute(
        "SELECT * FROM mc_moneywash_jobs WHERE id = ? AND identifier = ? LIMIT 1",
        { data.jobId, xPlayer.identifier },
        function(result)
            if not result or #result == 0 then
                xPlayer.showNotification("Diese Wäsche wurde nicht gefunden.")
                return
            end

            local job = result[1]
            if os.time() < job.finish_at then
                xPlayer.showNotification("Diese Wäsche ist noch nicht fertig.")
                return
            end

            if Config.Moneywash.cleanMoneyType == "bank" then
                xPlayer.addAccountMoney("bank", job.clean_amount)
            else
                xPlayer.addMoney(job.clean_amount)
            end
            if xPlayer.save then xPlayer.save() end

            exports.oxmysql:execute("DELETE FROM mc_moneywash_jobs WHERE id = ?", { job.id })

            xPlayer.showNotification("Du hast " .. job.clean_amount .. "$ abgeholt!")
            SendMoneywashStatus(src, xPlayer)

            TryMoneywashPoliceAlert(src)
        end
    )
end)

---------------------------------------------------------------
-- MODUL: Namecheck
---------------------------------------------------------------
local namecheckCfg = config_namecheck

local function namecheckLog(msg)
    if namecheckCfg.console_prints then
        print("^5[NAMECHECK]^7 " .. msg)
    end
end

-- Gibt den ROHEN Hash zurück (ohne "license:" Prefix), egal was cfg.identifier.prefix sagt
local function getRawHash(src)
    local identifiers = GetPlayerIdentifiers(src)
    local idType = namecheckCfg.identifier.type .. ":"

    for _, id in ipairs(identifiers) do
        if id:find(idType) then
            return id:gsub(idType, "")
        end
    end

    return nil
end

local function isBypass(hash)
    for _, v in ipairs(namecheckCfg.bypass.identifiers) do
        if hash == v then return true end
    end
    return false
end

local function buildName(job, firstname, lastname)
    local template = namecheckCfg.naming.standard

    if namecheckCfg.job.job_shorts[job] then
        job = namecheckCfg.job.job_shorts[job]
    end

    return template:gsub("{job}", job)
                   :gsub("{firstname}", firstname)
                   :gsub("{lastname}", lastname)
end

-- Holt alle Charaktere des Spielers.
-- multichar.enabled = true  -> char1:/char2:/char3: Format (LIKE-Suche über alle Slots)
-- multichar.enabled = false -> normales Single-Char Format (identifier = license:hash)
local function getCharacterRows(hash)
    if namecheckCfg.multichar.enabled then
        local likePattern = namecheckCfg.multichar.db_prefix_pattern:format(hash) -- z.B. "char%:d349c528..."
        local query = ("SELECT firstname, lastname, job, identifier FROM %s WHERE %s LIKE ?"):format(
            namecheckCfg.multichar.table,
            namecheckCfg.multichar.identifier_column
        )
        local rows = MySQL.query.await(query, { likePattern })
        return rows or {}
    else
        local row = MySQL.single.await(
            "SELECT firstname, lastname, job FROM users WHERE identifier = ?",
            { namecheckCfg.identifier.type .. ":" .. hash }
        )
        return row and { row } or {}
    end
end

AddEventHandler("playerConnecting", function(playerName, setKickReason, deferrals)
    local src = source
    deferrals.defer()

    Wait(500)

    local lang = namecheckCfg.ui.language
    local t = namecheckCfg.ui.translations[lang]

    deferrals.update(t.checking_name)

    local hash = getRawHash(src)
    if not hash then
        return deferrals.done(t.identifier_not_found)
    end

    if isBypass(hash) then
        namecheckLog(("Bypass erkannt für %s (%s)"):format(playerName, hash))
        return deferrals.done()
    end

    local rows = getCharacterRows(hash)

    if not rows or #rows == 0 then
        return deferrals.done(t.no_chars_found)
    end

    -- Multichar: prüfen ob EINER der Charaktere passt
    -- Single-Char: es gibt eh nur einen Eintrag -> gleiches Verhalten wie vorher
    local matched = false
    local lastExpectedName = nil

    for _, result in ipairs(rows) do
        local expectedName = buildName(result.job, result.firstname, result.lastname)
        lastExpectedName = expectedName

        if playerName == expectedName then
            matched = true
            break
        end
    end

    if not matched then
        local reason = [[WS NameCheck - Verbindung abgelehnt
Zugriff verweigert

Grund:
Dein Name entspricht nicht dem vorgegebenen Schema
Dein Name muss lauten: ]] .. lastExpectedName

        namecheckLog(("Namecheck fehlgeschlagen: %s != %s"):format(playerName, lastExpectedName))
        return deferrals.done(reason)
    end

    namecheckLog(("Namecheck korrekt: %s"):format(playerName))
    deferrals.done()
end)

---------------------------------------------------------------
-- MODUL: NpcBlocker
---------------------------------------------------------------
lib.callback.register("npc_blocker:isOwnedVehicle", function(source, plate)

    if not plate or plate == "" then
        return false
    end

    plate = ESX.Math.Trim(plate)

    local result = MySQL.single.await(
        "SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1",
        { plate }
    )

    return result ~= nil
end)

---------------------------------------------------------------
-- MODUL: Purge
---------------------------------------------------------------
local purgeActive = false
local purgeEndTime = 0

RegisterCommand("purge", function(source)
    if purgeActive then
        print("Purge läuft bereits.")
        return
    end

    purgeActive = true
    purgeEndTime = os.time() + Config.Purge.Duration

    TriggerClientEvent("mc_core:purgeStart", -1, Config.Purge.Duration)

    sendPurgeWebhook("🔥 PURGE gestartet! Dauer: " .. Config.Purge.Duration .. " Sekunden")
end)

RegisterCommand("purge_stop", function(source)
    stopPurge()
end)

CreateThread(function()
    while true do
        Wait(1000)
        if purgeActive and os.time() >= purgeEndTime then
            stopPurge()
        end
    end
end)

function stopPurge()
    purgeActive = false
    TriggerClientEvent("mc_core:purgeStop", -1)
    sendPurgeWebhook("🧊 PURGE beendet!")
end

function sendPurgeWebhook(msg)
    if Config.Purge.Webhook == "" then return end

    PerformHttpRequest(Config.Purge.Webhook, function() end, "POST", json.encode({
        username = "Midnight City – Purge",
        embeds = {{
            title = "Purge System",
            description = msg,
            color = 16711680
        }}
    }), { ["Content-Type"] = "application/json" })
end

---------------------------------------------------------------
-- MODUL: Revive
---------------------------------------------------------------
local function sendReviveDiscordLog(title, message)
    local wh = Config.Revive.Discord
    if not wh.enabled then return end

    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["color"] = tonumber(wh.color),
            ["footer"] = {
                ["text"] = wh.servername,
                ["icon_url"] = wh.icon
            }
        }
    }

    PerformHttpRequest(wh.webhook, function(err, text, headers) end, "POST", json.encode({
        username = wh.username,
        embeds = embed
    }), { ["Content-Type"] = "application/json" })
end

RegisterNetEvent("revive:requestRevive", function()
    local src = source
    TriggerClientEvent("revive:verifyDead", src)
end)

RegisterNetEvent("revive:doPaymentAndRevive", function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    local price = Config.Revive.Price
    local money = Config.Revive.UseBank and xPlayer.getAccount('bank').money or xPlayer.getMoney()

    if money >= price then
        if Config.Revive.UseBank then
            xPlayer.removeAccountMoney('bank', price)
        else
            xPlayer.removeMoney(price)
        end

        TriggerClientEvent("revive:doRevive", src)

        sendReviveDiscordLog(
            "Revive durchgeführt",
            ("Spieler **%s** wurde für **$%s** wiederbelebt."):format(xPlayer.getName(), Config.Revive.Price)
        )
    else
        TriggerClientEvent("esx:showNotification", src, "Nicht genug Geld.")
    end
end)


---------------------------------------------------------------
-- MODUL: Sperrzone
---------------------------------------------------------------
local SperrzoneZones = {}       -- [zoneId] = { id, job, jobLabel, coords, radius, ownerId, ownerName, color }
local SperrzoneNextZoneId = 1

-- ────────────────────────────────────────────────
-- Helpers
-- ────────────────────────────────────────────────
local function isSperrzoneAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    return Config.AdminGroups[group] == true
end

local function sendSperrzoneDiscordLog(title, description, color)
    if not Config.Discord.webhook or Config.Discord.webhook == '' then return end

    PerformHttpRequest(Config.Discord.webhook, function() end, 'POST', json.encode({
        username = Config.Discord.botName,
        embeds = {
            {
                title = title,
                description = description,
                color = color,
                footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
            }
        }
    }), { ['Content-Type'] = 'application/json' })
end

local function sperrzoneZonesAsArray()
    local arr = {}
    for _, z in pairs(SperrzoneZones) do
        arr[#arr + 1] = z
    end
    return arr
end

-- ────────────────────────────────────────────────
-- Sync
-- ────────────────────────────────────────────────
-- Send full zone list to a specific player (used on join)
RegisterNetEvent('mc_sperrzone:requestSync', function()
    local src = source
    TriggerClientEvent('mc_sperrzone:syncAll', src, sperrzoneZonesAsArray())
end)

-- ────────────────────────────────────────────────
-- Create zone
-- ────────────────────────────────────────────────
RegisterNetEvent('mc_sperrzone:create', function(radius, coords)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local job = xPlayer.job.name
    local jobCfg = Config.Jobs[job]

    if not jobCfg then
        TriggerClientEvent('mc_sperrzone:notify', src, _L('no_permission'), 'error')
        return
    end

    radius = tonumber(radius) or Config.DefaultRadius
    if radius < Config.MinRadius or radius > Config.MaxRadius then
        TriggerClientEvent('mc_sperrzone:notify', src,
            _L('invalid_radius', Config.MinRadius, Config.MaxRadius), 'error')
        return
    end

    -- basic sanity check on coords (must be a table with x/y/z, sent from client's own position)
    if type(coords) ~= 'table' or not coords.x or not coords.y or not coords.z then
        return
    end

    local zone = {
        id = SperrzoneNextZoneId,
        job = job,
        jobLabel = jobCfg.label,
        coords = coords,
        radius = radius,
        ownerId = xPlayer.identifier,
        ownerServerId = src,
        ownerName = GetPlayerName(src) or 'Unknown',
    }

    SperrzoneZones[zone.id] = zone
    SperrzoneNextZoneId = SperrzoneNextZoneId + 1

    TriggerClientEvent('mc_sperrzone:syncAll', -1, sperrzoneZonesAsArray())
    TriggerClientEvent('mc_sperrzone:notify', src, _L('zone_created', radius), 'success')

    sendSperrzoneDiscordLog(
        'Sperrzone erstellt / Zone created',
        string.format('**Faction:** %s\n**Player:** %s\n**Radius:** %sm\n**Coords:** %.1f, %.1f, %.1f',
            zone.jobLabel, zone.ownerName, zone.radius, coords.x, coords.y, coords.z),
        Config.Discord.colorCreate
    )
end)

-- ────────────────────────────────────────────────
-- Remove zone (creator only, must be inside it — checked client-side + re-validated here)
-- ────────────────────────────────────────────────
RegisterNetEvent('mc_sperrzone:remove', function(zoneId, coords)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local zone = SperrzoneZones[zoneId]
    if not zone then return end

    -- must be the owner, or an admin
    if zone.ownerId ~= xPlayer.identifier and not isSperrzoneAdmin(src) then
        TriggerClientEvent('mc_sperrzone:notify', src, _L('not_in_own_zone'), 'error')
        return
    end

    -- re-validate distance server-side to avoid trusting the client blindly
    if type(coords) == 'table' and coords.x then
        local dx, dy, dz = coords.x - zone.coords.x, coords.y - zone.coords.y, coords.z - zone.coords.z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist > zone.radius + 2.0 and not isSperrzoneAdmin(src) then
            TriggerClientEvent('mc_sperrzone:notify', src, _L('not_in_own_zone'), 'error')
            return
        end
    end

    SperrzoneZones[zoneId] = nil
    TriggerClientEvent('mc_sperrzone:syncAll', -1, sperrzoneZonesAsArray())
    TriggerClientEvent('mc_sperrzone:notify', src, _L('zone_removed'), 'success')

    sendSperrzoneDiscordLog(
        'Sperrzone entfernt / Zone removed',
        string.format('**Faction:** %s\n**Removed by:** %s', zone.jobLabel, GetPlayerName(src) or 'Unknown'),
        Config.Discord.colorRemove
    )
end)

-- ────────────────────────────────────────────────
-- Admin: list zones
-- ────────────────────────────────────────────────
RegisterCommand(Config.Commands.adminList, function(source, args)
    local src = source
    if src == 0 then return end -- console: skip, use in-game
    if not isSperrzoneAdmin(src) then
        TriggerClientEvent('mc_sperrzone:notify', src, _L('no_admin'), 'error')
        return
    end

    local count = 0
    for _ in pairs(SperrzoneZones) do count = count + 1 end
    TriggerClientEvent('mc_sperrzone:notify', src, _L('zone_list_header', count), 'info')
end, false)

-- ────────────────────────────────────────────────
-- Admin: clear all zones
-- ────────────────────────────────────────────────
RegisterCommand(Config.Commands.adminClear, function(source, args)
    local src = source
    if src ~= 0 and not isSperrzoneAdmin(src) then
        TriggerClientEvent('mc_sperrzone:notify', src, _L('no_admin'), 'error')
        return
    end

    SperrzoneZones = {}
    TriggerClientEvent('mc_sperrzone:syncAll', -1, {})

    if src ~= 0 then
        TriggerClientEvent('mc_sperrzone:notify', src, _L('all_cleared'), 'success')
    end

    sendSperrzoneDiscordLog(
        'Alle Sperrzonen gelöscht / All zones cleared',
        string.format('**By:** %s', src == 0 and 'Console' or (GetPlayerName(src) or 'Unknown')),
        Config.Discord.colorClear
    )
end, false)

-- ────────────────────────────────────────────────
-- Clean up zones tied to a player who dropped, if you want owner-only removal
-- to survive reconnects, we key by identifier, not source, so nothing to do here.
-- ────────────────────────────────────────────────

exports('GetActiveZones', function()
    return sperrzoneZonesAsArray()
end)

---------------------------------------------------------------
-- MODUL: Verkauf
---------------------------------------------------------------
RegisterNetEvent("mc_core:verkauf:sell")
AddEventHandler("mc_core:verkauf:sell", function(routeName, amount)

    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local route = Config.Verkauf[routeName]

    if not xPlayer or not route then return end

    amount = tonumber(amount) or 1
    amount = math.max(1, math.min(amount, 50))

    -- Job-Check
    if route.disallowed_jobs and #route.disallowed_jobs > 0 then
        local job = xPlayer.getJob().name
        for _, dis in ipairs(route.disallowed_jobs) do
            if dis == job then
                TriggerClientEvent("mc_core:verkauf:result", src, {
                    success = false,
                    message = "Du darfst hier nicht verkaufen."
                })
                return
            end
        end
    end

    local itemName = route.input.item
    local perBatch = route.input.anzahl or 1
    local totalNeeded = perBatch * amount

    local invCount = xPlayer.getInventoryItem(itemName).count

    if invCount < totalNeeded then
        TriggerClientEvent("mc_core:verkauf:result", src, {
            success = false,
            message = "Du hast nicht genug " .. (route.input.label or itemName)
        })
        return
    end

    -- Preis pro Durchgang (einmal ausgewürfelt, dann mit der Menge multipliziert)
    local unitPrice = route.outputprice or 0
    if route.generatePrice and route.generatePrice.enabled then
        unitPrice = math.random(route.generatePrice.min, route.generatePrice.max)
    end

    local totalPrice = unitPrice * amount

    xPlayer.removeInventoryItem(itemName, totalNeeded)

    if route.blackmoney then
        xPlayer.addAccountMoney("black_money", totalPrice)
    else
        xPlayer.addMoney(totalPrice)
    end

    TriggerClientEvent("mc_core:verkauf:result", src, {
        success = true,
        message = ("Du hast %dx %s für $%d verkauft."):format(totalNeeded, route.input.label or itemName, totalPrice)
    })

end)