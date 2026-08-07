--[[
    ============================================================
    ZUSAMMENGEFÜHRTES SERVER-SCRIPT (mc_core)
    ============================================================
    Fasst zusammen: antiafk, crafter, elevator, event,
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

-- ============================================================
-- SECTION: antiafk (SERVER)
-- ============================================================
do
    local playerActivity = {}
    local playerNameCache = {} -- src -> Name, damit wir ihn nach dem Kick noch kennen

    ---------------------------------------------------------------
    -- Discord Webhook Helper
    ---------------------------------------------------------------
    local function SendDiscordEmbed(title, description, color)
        if not Config.DiscordLogging.Enabled then return end
        if not Config.AFKWebhook or Config.AFKWebhook == "" then return end

        local payload = {
            username = "MC-Core Logs",
            embeds = {
                {
                    title = title,
                    description = description,
                    color = color or 15158332,
                    footer = { text = os.date("%d.%m.%Y %H:%M:%S") }
                }
            }
        }

        PerformHttpRequest(Config.AFKWebhook, function(_, _, _) end, 'POST',
            json.encode(payload),
            { ['Content-Type'] = 'application/json' }
        )
    end

    ---------------------------------------------------------------
    -- Bypass Check
    ---------------------------------------------------------------
    local function hasBypass(src)
        local cfg = Config.AntiAFK.Bypass

        if cfg.UseAcePermission and IsPlayerAceAllowed(src, cfg.AcePermission) then
            return true
        end

        for _, job in ipairs(cfg.Jobs) do
            -- Beispiel für Frameworks mit ESX/QBCore, anpassen falls nötig:
            -- local xPlayer = ESX.GetPlayerFromId(src)
            -- if xPlayer and xPlayer.job.name == job then return true end
        end

        local ids = GetPlayerIdentifiers(src)
        for _, id in ipairs(ids) do
            for _, allowedId in ipairs(cfg.Identifiers) do
                if id == allowedId then
                    return true
                end
            end
        end

        return false
    end

    ---------------------------------------------------------------
    -- AFK Events
    ---------------------------------------------------------------
    RegisterServerEvent('mc_core:updateActivity')
    AddEventHandler('mc_core:updateActivity', function()
        local src = source
        playerActivity[src] = os.time()
    end)

    RegisterServerEvent('mc_core:afkKickCheck')
    AddEventHandler('mc_core:afkKickCheck', function()
        local src = source
        local cfg = Config.AntiAFK

        if not cfg.Enabled then return end
        if hasBypass(src) then return end

        local last = playerActivity[src] or os.time()
        local elapsedMin = (os.time() - last) / 60

        if elapsedMin >= cfg.KickAfterMinutes then
            if Config.DiscordLogging.LogAFKKicks then
                local name = playerNameCache[src] or GetPlayerName(src) or ("ID " .. src)
                SendDiscordEmbed(
                    "🚫 AFK-Kick",
                    string.format("**Spieler:** %s (ID: %d)\n**Grund:** %s", name, src, cfg.KickMessage),
                    15158332 -- rot
                )
            end

            DropPlayer(src, cfg.KickMessage)
        end
    end)

    AddEventHandler('playerJoining', function()
        local src = source
        playerActivity[src] = os.time()
        playerNameCache[src] = GetPlayerName(src)
    end)

    AddEventHandler('playerDropped', function()
        local src = source
        playerActivity[src] = nil
        playerNameCache[src] = nil
    end)

    -- Debug: /afkbypass zeigt dir, ob dein Account einen Bypass hat (z.B. Ace-Permission)
    RegisterCommand('afkbypass', function(src)
        local bypass = hasBypass(src)
        TriggerClientEvent('chat:addMessage', src, {
            args = { "[AntiAFK]", bypass and "Du hast einen Bypass und wirst NIE gekickt." or "Du hast keinen Bypass." }
        })
    end, false)

    ---------------------------------------------------------------
    -- txAdmin Event: playerKicked
    -- Wird gefeuert, wenn ein Spieler über txAdmin (Panel/Ingame-Menü) gekickt wird.
    -- Event-Daten laut txAdmin-Doku: target, author, reason, dropMessage
    -- Hinweis: target kann -1 sein, wenn "alle kicken" ausgeführt wurde.
    ---------------------------------------------------------------
    AddEventHandler('txAdmin:events:playerKicked', function(eventData)
        if not Config.DiscordLogging.LogTxAdminKicks then return end

        local target = eventData and eventData.target
        local author = (eventData and eventData.author) or "txAdmin"
        local reason = (eventData and eventData.reason) or "Kein Grund angegeben"

        local targetName = "Alle Spieler"
        if target and target ~= -1 then
            targetName = playerNameCache[target] or GetPlayerName(target) or ("ID " .. tostring(target))
        end

        SendDiscordEmbed(
            "👢 Spieler gekickt (txAdmin)",
            string.format(
                "**Spieler:** %s%s\n**Von:** %s\n**Grund:** %s",
                targetName,
                (target and target ~= -1) and (" (ID: " .. tostring(target) .. ")") or "",
                author,
                reason
            ),
            3447003 -- blau
        )
    end)
end


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
--  JOB-SETZEN ABFANGEN (ROBUST)
--  Problem vorher: Es wurde NUR abgefangen, wenn ein Script
--  TriggerServerEvent(FraksperreConfig.Events.setjob, job, grade)
--  aufruft. In der Praxis setzen Boss-Menüs/Society-Scripts/etc.
--  den Job aber direkt über xPlayer.setJob(...), ohne über dieses
--  Event zu gehen -> die Sperre griff nie, Jobwechsel war trotz
--  aktiver Fraksperre möglich.
--
--  Fix: xPlayer.setJob wird pro Spieler einmal "umgebogen" (gewrappt).
--  Dadurch greift die Prüfung IMMER, egal welches Script/Event am
--  Ende xPlayer.setJob() aufruft.
-- ============================================================
local function WrapSetJob(xPlayer)
    if not xPlayer or xPlayer.__frakSperreWrapped then return end
    if type(xPlayer.setJob) ~= 'function' then return end

    local originalSetJob = xPlayer.setJob

    xPlayer.setJob = function(jobName, grade, ...)
        local identifier = GetIdentifier(xPlayer)
        local blocked = IsBlocked(identifier)

        if blocked and not IsWhitelistedJob(jobName) then
            FrakNotify(xPlayer.source, FraksperreConfig.Language.blockedjob)
            frakDbg(("%s hat versucht (setJob) während aktiver Fraksperre den Job '%s' anzunehmen (blockiert)"):format(xPlayer.getName(), jobName))
            return
        end

        return originalSetJob(jobName, grade, ...)
    end

    xPlayer.__frakSperreWrapped = true
end

-- Beim Neustart von mc_core (z.B. "restart mc_core") sind bereits
-- eingeloggte Spieler-Objekte schon vorhanden -> auch die sofort wrappen,
-- sonst wäre die Sperre erst nach erneutem Login wieder aktiv.
CreateThread(function()
    Wait(1000)
    local players = ESX.GetPlayers and ESX.GetPlayers() or {}
    for _, playerId in ipairs(players) do
        local xTarget = ESX.GetPlayerFromId(playerId)
        if xTarget then WrapSetJob(xTarget) end
    end
end)

-- Bleibt als Kompatibilitäts-Event erhalten, falls irgendein Script
-- explizit TriggerServerEvent(FraksperreConfig.Events.setjob, ...) nutzt.
-- Ruft am Ende ebenfalls nur xPlayer.setJob auf, ist also durch den
-- Wrapper oben zusätzlich abgesichert.
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
--  PLAYER LOADED -> Sperrstatus prüfen, informieren UND setJob wrappen
--  ESX feuert dieses Event als: TriggerEvent('esx:playerLoaded', playerId, xPlayer, ...)
--  Der erste Parameter ist also die Spieler-ID (number), NICHT das xPlayer-Objekt!
-- ============================================================
AddEventHandler(FraksperreConfig.Events.playerLoaded, function(playerId, xPlayer)
    if not xPlayer then return end
    local src = xPlayer.source or playerId

    WrapSetJob(xPlayer)

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

RegisterCommand(ConfigGiveCar.Commands.giveCar, function(source, args)
    -- source 0 = Server-/txAdmin-Konsole -> gilt immer als berechtigt, es gibt kein ESX-Player-Objekt dafür
    local isConsole = source == 0
    local xPlayer

    if not isConsole then
        xPlayer = ESX.GetPlayerFromId(source)

        -- Admin Check
        if not ConfigGiveCar.AdminGroups[xPlayer.getGroup()] then
            xPlayer.showNotification(ConfigGiveCar.Messages.noPerms)
            return
        end
    end

    -- Args
    local targetId = tonumber(args[1])
    local vehicleModel = args[2]
    local plate = args[3]

    if not targetId or not vehicleModel then
        if isConsole then
            print("[GiveCar] " .. ConfigGiveCar.Messages.usage)
        else
            xPlayer.showNotification(ConfigGiveCar.Messages.usage)
        end
        return
    end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        if isConsole then
            print("[GiveCar] " .. ConfigGiveCar.Messages.playerNotFound)
        else
            xPlayer.showNotification(ConfigGiveCar.Messages.playerNotFound)
        end
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
            username = ConfigGiveCar.Logging.username,
            embeds = {{
                title = ConfigGiveCar.Logging.titleGiveCar,
                color = ConfigGiveCar.Logging.color,
                fields = {
                    { name = "Admin", value = isConsole and "Server-Konsole" or (xPlayer.getName() .. " (" .. xPlayer.identifier .. ")") },
                    { name = "Spieler", value = target.getName() .. " (" .. target.identifier .. ")" },
                    { name = "Modell", value = vehicleModel },
                    { name = "Kennzeichen", value = plate }
                }
            }}
        }), { ["Content-Type"] = "application/json" })
    end

    -- Notifications
    local adminMessage = ConfigGiveCar.Messages.carGivenAdmin
        :gsub("%%model%%", vehicleModel)
        :gsub("%%plate%%", plate)
        :gsub("%%id%%", targetId)

    if isConsole then
        print("[GiveCar] " .. adminMessage)
    else
        xPlayer.showNotification(adminMessage)
    end

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
-- MODUL: SetCar (aktuelles Fahrzeug des Admins an einen Spieler vergeben)
---------------------------------------------------------------
RegisterNetEvent("mc_core:setcar")
AddEventHandler("mc_core:setcar", function(targetId, vehicleProps, displayName)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then return end

    -- Admin Check (gleiche Gruppen wie GiveCar)
    if not ConfigGiveCar.AdminGroups[xPlayer.getGroup()] then
        xPlayer.showNotification(ConfigGiveCar.Messages.noPerms)
        return
    end

    if type(vehicleProps) ~= "table" or not vehicleProps.model then
        return
    end

    targetId = tonumber(targetId)
    local target = targetId and ESX.GetPlayerFromId(targetId)

    if not target then
        xPlayer.showNotification(ConfigGiveCar.Messages.playerNotFound)
        return
    end

    -- Plate übernehmen, sonst Auto-Plate wie bei GiveCar
    local plate = vehicleProps.plate and vehicleProps.plate:gsub("%s+", "") or ""

    if plate == "" and ConfigGiveCar.AutoPlate.enabled then
        plate = ConfigGiveCar.AutoPlate.prefix .. "" .. GenerateRandomString(ConfigGiveCar.AutoPlate.length)
    end

    vehicleProps.plate = plate

    local modelLabel = displayName or tostring(vehicleProps.model)

    -- DB Insert
    MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle, stored) VALUES (?, ?, ?, ?)', {
        target.identifier,
        plate,
        json.encode(vehicleProps),
        1
    })

    -- Logging
    if ConfigGiveCar.Logging.enabled and ConfigGiveCar.Logging.webhook ~= "" then
        PerformHttpRequest(ConfigGiveCar.Logging.webhook, function() end, "POST", json.encode({
            username = ConfigGiveCar.Logging.username,
            embeds = {{
                title = ConfigGiveCar.Logging.titleSetCar,
                color = ConfigGiveCar.Logging.color,
                fields = {
                    { name = "Admin", value = xPlayer.getName() .. " (" .. xPlayer.identifier .. ")" },
                    { name = "Spieler", value = target.getName() .. " (" .. target.identifier .. ")" },
                    { name = "Modell", value = modelLabel },
                    { name = "Kennzeichen", value = plate }
                }
            }}
        }), { ["Content-Type"] = "application/json" })
    end

    -- Notifications
    xPlayer.showNotification(
        ConfigGiveCar.Messages.carGivenAdmin
            :gsub("%%model%%", modelLabel)
            :gsub("%%plate%%", plate)
            :gsub("%%id%%", targetId)
    )

    target.showNotification(
        ConfigGiveCar.Messages.carGivenPlayer
            :gsub("%%model%%", modelLabel)
            :gsub("%%plate%%", plate)
    )
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
local MautCooldowns = {}   -- [identifier][tollName] = timestamp, wann wieder bezahlt werden darf (nach Verlassen)
local MautActive = {}      -- [identifier][tollName] = true, solange der Spieler NOCH in der Zone steht (harte Sperre)

RegisterNetEvent("mc_core:maut:pay")
AddEventHandler("mc_core:maut:pay", function(tollName, price, speed)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local now = os.time()

    MautActive[identifier] = MautActive[identifier] or {}
    MautCooldowns[identifier] = MautCooldowns[identifier] or {}

    -- HARTE SPERRE: Solange der Spieler laut Client noch in der Zone steht,
    -- wird niemals ein zweites Mal abgerechnet – unabhängig vom Cooldown-Wert.
    if MautActive[identifier][tollName] then
        return
    end

    -- Cooldown gilt erst NACH dem Verlassen der Zone (wird im exit-Event
    -- gesetzt, siehe unten) - verhindert sofortiges erneutes Abbuchen,
    -- wenn man knapp am Zonenrand kurz raus und wieder reinfährt.
    if MautCooldowns[identifier][tollName] and MautCooldowns[identifier][tollName] > now then
        return
    end

    -- Sperre setzen: Spieler gilt jetzt als "in der Maut", bis Client den Austritt meldet
    MautActive[identifier][tollName] = true

    if MautConfig.FreeJobs[xPlayer.job.name] then
        TriggerClientEvent("mc_core:notifyClient", source, "Mautstelle", "Du darfst kostenlos passieren.", "info")
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
        TriggerClientEvent("mc_core:notifyClient", source, "Mautstelle",
            ("Speed: %.1f km/h | %s$ wurden abgebucht."):format(speed, price), "success")
        SendMautLog(xPlayer, tollName, price, speed, "PAID_SPEED")
    else
        TriggerClientEvent("mc_core:notifyClient", source, "Mautstelle", "Nicht genügend Geld für die Maut.", "error")
        SendMautLog(xPlayer, tollName, price, speed, "FAILED")
    end
end)

-- Client meldet, dass die Zone verlassen wurde -> Sperre aufheben und
-- den Cooldown erst JETZT starten (3 Sekunden, siehe MautConfig.Cooldown)
RegisterNetEvent("mc_core:maut:exit")
AddEventHandler("mc_core:maut:exit", function(tollName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local identifier = xPlayer.identifier

    if MautActive[identifier] then
        MautActive[identifier][tollName] = nil
    end

    MautCooldowns[identifier] = MautCooldowns[identifier] or {}
    MautCooldowns[identifier][tollName] = os.time() + MautConfig.Cooldown
end)

RegisterNetEvent("mc_core:maut:policeAlert")
AddEventHandler("mc_core:maut:policeAlert", function(tollName, price, speed)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    for _, id in ipairs(ESX.GetPlayers()) do
        local p = ESX.GetPlayerFromId(id)
        if p and p.job and p.job.name == "police" then
            TriggerClientEvent("mc_core:notifyClient", id, "Maut-Alarm",
                ("Raser erkannt: %.1f km/h an %s"):format(speed, tollName), "warning"
            )
        end
    end

    SendMautLog(xPlayer, tollName, price, speed, "POLICE_ALERT")
end)

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

-- Set aus team_groups für schnellen Lookup (statt jedes Mal die Liste zu durchlaufen)
local teamJobSet = {}
for _, job in ipairs(namecheckCfg.bypass.team_groups) do
    teamJobSet[job] = true
end

-- Team-Erkennung läuft über die ESX-Gruppe (users.group) aus der DB,
-- NICHT über den Job (kein ACE, kein add_ace/add_principal nötig).
-- Sobald die Gruppe eines Charakters in bypass.team_groups steht,
-- gilt er als Teammitglied - unabhängig davon welchen Job er gerade hat.
local function isTeamJob(group)
    return namecheckCfg.naming.team.enabled and teamJobSet[group] == true
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

-- Team-Namensschema: IMMER "[MC] | Vorname Nachname", unabhängig davon
-- welcher Job es konkret ist (überschreibt also das normale Job-Schema).
local function buildTeamName(firstname, lastname)
    local template = namecheckCfg.naming.team.template

    return template:gsub("{firstname}", firstname)
                   :gsub("{lastname}", lastname)
end


-- Holt alle Charaktere des Spielers.
-- multichar.enabled = true  -> char1:/char2:/char3: Format (LIKE-Suche über alle Slots)
-- multichar.enabled = false -> normales Single-Char Format (identifier = license:hash)
local function getCharacterRows(hash)
    if namecheckCfg.multichar.enabled then
        local likePattern = namecheckCfg.multichar.db_prefix_pattern:format(hash) -- z.B. "char%:d349c528..."
        local query = ("SELECT firstname, lastname, job, `group`, identifier FROM %s WHERE %s LIKE ?"):format(
            namecheckCfg.multichar.table,
            namecheckCfg.multichar.identifier_column
        )
        local rows = MySQL.query.await(query, { likePattern })
        return rows or {}
    else
        local row = MySQL.single.await(
            "SELECT firstname, lastname, job, `group` FROM users WHERE identifier = ?",
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

    -- FIX: Wenn (noch) kein Charakter existiert, ist das ein neuer
    -- Spieler, der sich gerade erst einen Charakter erstellen will.
    -- Der Namecheck kann in diesem Fall gar nicht greifen (es gibt
    -- ja noch keinen Namen zum Prüfen) - vorher wurde hier fälschlich
    -- abgelehnt, wodurch neue Spieler nie einen Charakter anlegen
    -- konnten. Jetzt einfach durchlassen; der Check greift erst wieder,
    -- sobald ein Charakter (mit Job/Namen) in der DB existiert.
    if not rows or #rows == 0 then
        namecheckLog(("Kein Charakter für %s (%s) - neuer Spieler, wird durchgelassen"):format(playerName, hash))
        return deferrals.done()
    end

    -- Multichar: prüfen ob EINER der Charaktere passt
    -- Single-Char: es gibt eh nur einen Eintrag -> gleiches Verhalten wie vorher
    -- Ist die Gruppe (users.group) des Charakters in bypass.team_groups
    -- gelistet, gilt NUR das Team-Schema "[MC] | Vorname Nachname" - das
    -- normale Job-Schema wird dafür nicht mehr geprüft, auch wenn der
    -- Job z.B. "police" wäre.
    local matched = false
    local lastExpectedName = nil

    for _, result in ipairs(rows) do
        local expectedName
        if isTeamJob(result.group) then
            expectedName = buildTeamName(result.firstname, result.lastname)
        else
            expectedName = buildName(result.job, result.firstname, result.lastname)
        end

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

---------------------------------------------------------------
-- MODUL: CarryPeople (SERVER)
---------------------------------------------------------------
-- Ersetzt das vorherige selbstgebaute Carry-System.
local carrying = {}
-- carrying[source] = targetSource, source trägt targetSource
local carried = {}
-- carried[targetSource] = source, targetSource wird von source getragen

RegisterServerEvent("CarryPeople:sync")
AddEventHandler("CarryPeople:sync", function(targetSrc)
    if not Config.CarryPeople.enabled then return end
    local source = source
    local sourcePed = GetPlayerPed(source)
    local sourceCoords = GetEntityCoords(sourcePed)
    local targetPed = GetPlayerPed(targetSrc)
    local targetCoords = GetEntityCoords(targetPed)
    if #(sourceCoords - targetCoords) <= Config.CarryPeople.maxDistance then
        TriggerClientEvent("CarryPeople:syncTarget", targetSrc, source)
        carrying[source] = targetSrc
        carried[targetSrc] = source
    end
end)

RegisterServerEvent("CarryPeople:stop")
AddEventHandler("CarryPeople:stop", function(targetSrc)
    local source = source

    if carrying[source] then
        TriggerClientEvent("CarryPeople:cl_stop", targetSrc)
        carrying[source] = nil
        carried[targetSrc] = nil
    elseif carried[source] then
        TriggerClientEvent("CarryPeople:cl_stop", carried[source])
        carrying[carried[source]] = nil
        carried[source] = nil
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source

    if carrying[source] then
        TriggerClientEvent("CarryPeople:cl_stop", carrying[source])
        carried[carrying[source]] = nil
        carrying[source] = nil
    end

    if carried[source] then
        TriggerClientEvent("CarryPeople:cl_stop", carried[source])
        carrying[carried[source]] = nil
        carried[source] = nil
    end
end)

---------------------------------------------------------------
-- MODUL: Jail (esx_jail)
---------------------------------------------------------------
-- Uebernommen aus dem eigenstaendigen "esx_jail"-Script.
-- Config.Locale wurde zu Config.JailLocale umbenannt (Konflikt mit
-- mc_core's Config.Locale = 'de', siehe config.lua).
---------------------------------------------------------------

ESX = ESX or exports['es_extended']:getSharedObject() -- bereits oben in server.lua gesetzt, hier nur zur Sicherheit idempotent

-- ActiveInmates[identifier] = { jailId, time, name, source (falls online, sonst nil) }
local ActiveInmates = {}
-- AdminInmates[identifier] = { time, name, reason, source, returnCoords = {x,y,z,h} }
-- Eigenständiges System für /adminjail: keine Gefängnis-Zuordnung, fixer Ort (Config.AdminJail.Position),
-- Rückkehr an die Position, an der der Spieler stand, als er eingesperrt wurde.
local AdminInmates = {}
local WorkCooldowns = {}
local BribeCooldowns = {}
local EscapeCooldowns = {}

-- ####################################################
-- ##                   HELPERS                       ##
-- ####################################################

local function HasJob(xPlayer, jobList)
    for _, job in ipairs(jobList) do
        if xPlayer.job.name == job then return true end
    end
    return false
end

local function Log(identifier, name, action, details, jailId)
    MySQL.insert('INSERT INTO jail_log (identifier, name, action, details, jail_id) VALUES (?, ?, ?, ?, ?)',
        { identifier, name, action, details or '', jailId or 0 })
end

-- ####################################################
-- ##             LADEN BEIM RESOURCE-START           ##
-- ####################################################

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    MySQL.query('SELECT * FROM jail_inmates', {}, function(rows)
        if not rows then return end
        for _, row in ipairs(rows) do
            ActiveInmates[row.identifier] = {
                jailId = row.jail_id,
                time = row.time,
                name = row.name,
                reason = row.reason,
                source = nil
            }
        end
    end)

    MySQL.query('SELECT * FROM admin_jail WHERE in_jail = 1', {}, function(rows)
        if not rows then return end
        for _, row in ipairs(rows) do
            AdminInmates[row.identifier] = {
                time = row.jail_time,
                name = row.name,
                reason = row.jail_reason,
                source = nil,
                returnCoords = { x = row.return_x, y = row.return_y, z = row.return_z, h = row.return_h }
            }
        end
    end)
end)


-- ####################################################
-- ##                VERHAFTEN                        ##
-- ####################################################

local function JailPlayer(officerSource, targetId, jailId, minutes, reason, location, jobList)
    local xOfficer = ESX.GetPlayerFromId(officerSource)
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xOfficer or not xTarget then return false end

    if not HasJob(xOfficer, jobList) then
        TriggerClientEvent('esx_jail:notify', officerSource, Config.JailLocale.not_allowed_job, 'error')
        return false
    end

    local jail = Config.Jails[jailId]
    if not jail then return false end

    location = (location == 'yard') and 'yard' or 'cell'

    local identifier = xTarget.identifier
    local name = xTarget.getName()

    -- Inventar / Waffen sichern
    if Config.RemoveWeaponsOnArrest or Config.RemoveItemsOnArrest then
        local loadout = Config.RemoveWeaponsOnArrest and xTarget.getLoadout() or {}
        local inventory = Config.RemoveItemsOnArrest and xTarget.getInventory() or {}

        MySQL.insert('INSERT INTO jail_storage (identifier, skin, loadout, inventory, jail_id) VALUES (?, ?, ?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE loadout = VALUES(loadout), inventory = VALUES(inventory), jail_id = VALUES(jail_id)',
            { identifier, '', json.encode(loadout), json.encode(inventory), jailId })

        if Config.RemoveWeaponsOnArrest then
            for _, weapon in ipairs(loadout) do
                xTarget.removeWeapon(weapon.name)
            end
        end
        if Config.RemoveItemsOnArrest then
            for _, item in ipairs(inventory) do
                if item.count and item.count > 0 then
                    xTarget.removeInventoryItem(item.name, item.count)
                end
            end
        end
    end

    reason = (reason and reason ~= '') and reason or 'Kein Grund angegeben'

    MySQL.insert('INSERT INTO jail_inmates (identifier, name, jail_id, time, officer, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { identifier, name, jailId, minutes, xOfficer.getName(), reason })

    ActiveInmates[identifier] = { jailId = jailId, time = minutes, name = name, reason = reason, source = targetId }

    Log(identifier, name, 'jailed', ('von %s | Grund: %s'):format(xOfficer.getName(), reason), jailId)

    TriggerClientEvent('esx_jail:sendToJail', targetId, jailId, minutes, reason, location)
    TriggerClientEvent('esx_jail:notify', officerSource, ('%s wurde verhaftet.'):format(name), 'success')

    return true
end

-- /arrest (Nähe-Check, Config.ArrestJobs) -> landet immer in der Zelle
local function ArrestPlayer(officerSource, targetId, jailId, minutes, reason)
    return JailPlayer(officerSource, targetId, jailId, minutes, reason, 'cell', Config.ArrestJobs)
end

RegisterNetEvent('esx_jail:arrestPlayer', function(targetId, jailId, minutes, reason)
    local officerSource = source
    ArrestPlayer(officerSource, targetId, jailId, minutes, reason)
end)

-- Einsperren über das Verwaltungsmenü DES jeweiligen Gefängnisses: prüft die
-- managementJobs dieses Gefängnisses (nicht Config.ArrestJobs) und erlaubt die
-- Wahl zwischen Zelle und Hof.
RegisterNetEvent('esx_jail:jailPlayerFromMenu', function(targetId, jailId, location, minutes, reason)
    local officerSource = source
    local jail = Config.Jails[jailId]
    if not jail then return end

    JailPlayer(officerSource, targetId, jailId, minutes, reason, location, jail.managementJobs)
end)

-- Liste aller Online-Spieler für das "Spieler einsperren"-Menü eines Gefängnisses
-- (die eigentliche Berechtigungsprüfung erfolgt beim Einsperren selbst über managementJobs)
ESX.RegisterServerCallback('esx_jail:getOnlinePlayers', function(source, cb)
    local list = {}
    for _, playerId in ipairs(ESX.GetPlayers()) do
        if playerId ~= source then
            local xTarget = ESX.GetPlayerFromId(playerId)
            if xTarget then
                list[#list + 1] = { id = playerId, name = xTarget.getName() }
            end
        end
    end
    cb(list)
end)

-- ####################################################
-- ##                 ENTLASSEN                       ##
-- ####################################################

local function ReleasePlayer(identifier, byOfficerName)
    local inmate = ActiveInmates[identifier]
    if not inmate then return false end

    local jailId = inmate.jailId
    local xTarget = inmate.source and ESX.GetPlayerFromId(inmate.source) or nil

    -- Inventar / Waffen wiederherstellen
    MySQL.query('SELECT * FROM jail_storage WHERE identifier = ?', { identifier }, function(rows)
        if rows and rows[1] and xTarget then
            local loadout = json.decode(rows[1].loadout or '[]') or {}
            local inventory = json.decode(rows[1].inventory or '[]') or {}

            for _, weapon in ipairs(loadout) do
                xTarget.addWeapon(weapon.name, weapon.ammo or 0)
            end
            for _, item in ipairs(inventory) do
                if item.count and item.count > 0 then
                    xTarget.addInventoryItem(item.name, item.count)
                end
            end
        end
        MySQL.query('DELETE FROM jail_storage WHERE identifier = ?', { identifier })
    end)

    MySQL.query('DELETE FROM jail_inmates WHERE identifier = ?', { identifier })
    Log(identifier, inmate.name, 'released', byOfficerName and ('entlassen von ' .. byOfficerName) or 'Strafe abgesessen', jailId)

    if inmate.source then
        TriggerClientEvent('esx_jail:releaseFromJail', inmate.source, jailId)
    end

    ActiveInmates[identifier] = nil
    return true
end

-- Entlässt einen Insassen aus dem separaten Admin-Jail-System und teleportiert ihn
-- zurück an die Position, an der er ursprünglich eingesperrt wurde.
local function ReleaseAdminInmate(identifier, byOfficerName)
    local inmate = AdminInmates[identifier]
    if not inmate then return false end

    local xTarget = inmate.source and ESX.GetPlayerFromId(inmate.source) or nil

    -- Inventar / Waffen wiederherstellen
    MySQL.query('SELECT * FROM jail_storage WHERE identifier = ?', { identifier }, function(rows)
        if rows and rows[1] and xTarget then
            local loadout = json.decode(rows[1].loadout or '[]') or {}
            local inventory = json.decode(rows[1].inventory or '[]') or {}

            for _, weapon in ipairs(loadout) do
                xTarget.addWeapon(weapon.name, weapon.ammo or 0)
            end
            for _, item in ipairs(inventory) do
                if item.count and item.count > 0 then
                    xTarget.addInventoryItem(item.name, item.count)
                end
            end
        end
        MySQL.query('DELETE FROM jail_storage WHERE identifier = ?', { identifier })
    end)

    MySQL.update('UPDATE admin_jail SET in_jail = 0 WHERE identifier = ?', { identifier })
    Log(identifier, inmate.name, 'released', byOfficerName and ('entlassen von ' .. byOfficerName) or 'Strafe abgesessen (Admin-Jail)', 0)

    if inmate.source then
        TriggerClientEvent('esx_jail:releaseFromAdminJail', inmate.source, inmate.returnCoords)
    end

    AdminInmates[identifier] = nil
    return true
end

RegisterNetEvent('esx_jail:releaseByOfficer', function(identifier)
    local src = source
    local xOfficer = ESX.GetPlayerFromId(src)
    if not xOfficer then return end

    local inmate = ActiveInmates[identifier]
    if not inmate then return end

    local jail = Config.Jails[inmate.jailId]
    if not jail or not HasJob(xOfficer, jail.managementJobs) then
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.not_allowed_job, 'error')
        return
    end

    ReleasePlayer(identifier, xOfficer.getName())
    TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.time_updated, 'success')
end)

RegisterNetEvent('esx_jail:updateTime', function(identifier, newMinutes)
    local src = source
    local xOfficer = ESX.GetPlayerFromId(src)
    if not xOfficer then return end

    local inmate = ActiveInmates[identifier]
    if not inmate then return end

    local jail = Config.Jails[inmate.jailId]
    if not jail or not HasJob(xOfficer, jail.managementJobs) then
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.not_allowed_job, 'error')
        return
    end

    newMinutes = tonumber(newMinutes) or inmate.time
    inmate.time = newMinutes
    MySQL.update('UPDATE jail_inmates SET time = ? WHERE identifier = ?', { newMinutes, identifier })
    Log(identifier, inmate.name, 'time_updated', ('neue Reststrafe: %s Minuten (von %s)'):format(newMinutes, xOfficer.getName()), inmate.jailId)

    if inmate.source then
        TriggerClientEvent('esx_jail:updateTimeDisplay', inmate.source, newMinutes)
    end
    TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.time_updated, 'success')
end)

-- ####################################################
-- ##                  TIMER-LOOP                     ##
-- ####################################################

CreateThread(function()
    while true do
        Wait(60000) -- jede Minute
        for identifier, inmate in pairs(ActiveInmates) do
            inmate.time = inmate.time - 1
            if inmate.time <= 0 then
                ReleasePlayer(identifier, nil)
            else
                MySQL.update('UPDATE jail_inmates SET time = ? WHERE identifier = ?', { inmate.time, identifier })
                if inmate.source then
                    TriggerClientEvent('esx_jail:updateTimeDisplay', inmate.source, inmate.time)
                end
            end
        end

        for identifier, inmate in pairs(AdminInmates) do
            inmate.time = inmate.time - 1
            if inmate.time <= 0 then
                ReleaseAdminInmate(identifier, nil)
            else
                MySQL.update('UPDATE admin_jail SET jail_time = ? WHERE identifier = ?', { inmate.time, identifier })
                if inmate.source then
                    TriggerClientEvent('esx_jail:updateAdminTimeDisplay', inmate.source, inmate.time)
                end
            end
        end
    end
end)

-- ####################################################
-- ##      SPIELER JOINT WIEDER (war schon inhaftiert) ##
-- ####################################################

ESX.RegisterServerCallback('esx_jail:checkOnLoad', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end

    local identifier = xPlayer.identifier

    local inmate = ActiveInmates[identifier]
    if inmate then
        inmate.source = source
        return cb({ type = 'jail', jailId = inmate.jailId, time = inmate.time, reason = inmate.reason })
    end

    local adminInmate = AdminInmates[identifier]
    if adminInmate then
        adminInmate.source = source
        return cb({ type = 'admin', time = adminInmate.time, reason = adminInmate.reason })
    end

    cb(nil)
end)

-- ####################################################
-- ##                MANAGEMENT-MENÜ                  ##
-- ####################################################

ESX.RegisterServerCallback('esx_jail:getInmates', function(source, cb, jailId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local jail = Config.Jails[jailId]
    if not xPlayer or not jail or not HasJob(xPlayer, jail.managementJobs) then
        return cb({})
    end

    local list = {}
    for identifier, inmate in pairs(ActiveInmates) do
        if inmate.jailId == jailId then
            list[#list + 1] = {
                identifier = identifier,
                name = inmate.name,
                time = inmate.time,
                online = inmate.source ~= nil
            }
        end
    end
    cb(list)
end)

ESX.RegisterServerCallback('esx_jail:getLog', function(source, cb, jailId, page)
    local xPlayer = ESX.GetPlayerFromId(source)
    local jail = Config.Jails[jailId]
    if not xPlayer or not jail or not HasJob(xPlayer, jail.managementJobs) then
        return cb({})
    end

    page = page or 0
    MySQL.query('SELECT * FROM jail_log WHERE jail_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
        { jailId, Config.LogEntriesPerPage, page * Config.LogEntriesPerPage }, function(rows)
        cb(rows or {})
    end)
end)

-- ####################################################
-- ##                    ARBEITEN                     ##
-- ####################################################

RegisterNetEvent('esx_jail:workComplete', function(workIndex, jailId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not Config.Work.enabled then return end

    local jail = Config.Jails[jailId]
    if not jail then return end
    local work = jail.workPoints[workIndex]
    if not work then return end

    local identifier = xPlayer.identifier
    local inmate = ActiveInmates[identifier]
    if not inmate then return end -- kein Insasse -> keine Belohnung

    local now = os.time()
    WorkCooldowns[identifier] = WorkCooldowns[identifier] or {}
    if WorkCooldowns[identifier][workIndex] and now < WorkCooldowns[identifier][workIndex] then
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.work_cooldown, 'error')
        return
    end
    WorkCooldowns[identifier][workIndex] = now + work.cooldown

    inmate.time = math.max(0, inmate.time - work.reward)
    MySQL.update('UPDATE jail_inmates SET time = ? WHERE identifier = ?', { inmate.time, identifier })
    Log(identifier, inmate.name, 'work', ('%s | -%s Minuten'):format(work.label, work.reward), jailId)

    TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.work_done:format(work.reward), 'success')
    TriggerClientEvent('esx_jail:updateTimeDisplay', src, inmate.time)

    if inmate.time <= 0 then
        ReleasePlayer(identifier, nil)
    end
end)

-- ####################################################
-- ##                  BESTECHUNG                     ##
-- ####################################################

RegisterNetEvent('esx_jail:bribeAttempt', function(nearbyGuardIds)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not Config.Bribe.enabled then return end

    local identifier = xPlayer.identifier
    local inmate = ActiveInmates[identifier]
    if not inmate then return end

    if Config.Bribe.requireNearbyGuard then
        local hasGuard = false
        for _, guardId in ipairs(nearbyGuardIds or {}) do
            local xGuard = ESX.GetPlayerFromId(guardId)
            if xGuard and HasJob(xGuard, Config.Bribe.guardJobs) then
                hasGuard = true
                break
            end
        end
        if not hasGuard then
            TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.bribe_no_guard, 'error')
            return
        end
    end

    local now = os.time()
    if BribeCooldowns[identifier] and now < BribeCooldowns[identifier] then
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.bribe_cooldown, 'error')
        return
    end
    BribeCooldowns[identifier] = now + Config.Bribe.cooldown

    if xPlayer.getMoney() < Config.Bribe.cost then
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.bribe_no_money, 'error')
        return
    end
    xPlayer.removeMoney(Config.Bribe.cost)

    local success = math.random(1, 100) <= Config.Bribe.chance

    if success then
        inmate.time = math.max(0, inmate.time - Config.Bribe.successTimeReduction)
        Log(identifier, inmate.name, 'bribed_success', ('-%s Minuten'):format(Config.Bribe.successTimeReduction), inmate.jailId)
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.bribe_success:format(Config.Bribe.successTimeReduction), 'success')
    else
        inmate.time = inmate.time + Config.Bribe.failPunishment
        Log(identifier, inmate.name, 'bribed_fail', ('+%s Minuten'):format(Config.Bribe.failPunishment), inmate.jailId)
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.bribe_fail:format(Config.Bribe.failPunishment), 'error')
    end

    MySQL.update('UPDATE jail_inmates SET time = ? WHERE identifier = ?', { inmate.time, identifier })
    TriggerClientEvent('esx_jail:updateTimeDisplay', src, inmate.time)

    if Config.Bribe.notifyGuardsOnAttempt then
        for _, guardId in ipairs(nearbyGuardIds or {}) do
            TriggerClientEvent('esx_jail:notify', guardId,
                ('%s hat versucht dich zu bestechen (%s).'):format(inmate.name, success and 'Erfolg' or 'Fehlschlag'),
                success and 'error' or 'success')
        end
    end

    if inmate.time <= 0 then
        ReleasePlayer(identifier, nil)
    end
end)

-- ####################################################
-- ##                 FLUCHT-ALARM                    ##
-- ####################################################

RegisterNetEvent('esx_jail:escapeAttempt', function(jailId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not Config.Escape.enabled then return end

    local identifier = xPlayer.identifier
    local inmate = ActiveInmates[identifier]
    if not inmate then return end

    local now = os.time()
    if EscapeCooldowns[identifier] and now < EscapeCooldowns[identifier] then return end
    EscapeCooldowns[identifier] = now + Config.Escape.alertCooldown

    local jail = Config.Jails[jailId]
    Log(identifier, inmate.name, 'escaped', 'Fluchtversuch erkannt', jailId)

    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xTarget = ESX.GetPlayerFromId(playerId)
        if xTarget and HasJob(xTarget, Config.Escape.alertJobs) then
            TriggerClientEvent('esx_jail:escapeAlert', xTarget.source, jail and jail.label or 'Unbekanntes Gefängnis', inmate.name)
        end
    end
end)

RegisterNetEvent('esx_jail:escapeCoords', function(jailId, coords)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xTarget = ESX.GetPlayerFromId(playerId)
        if xTarget and HasJob(xTarget, Config.Escape.alertJobs) then
            TriggerClientEvent('esx_jail:escapeBlip', xTarget.source, coords)
        end
    end
end)

-- ####################################################
-- ##       AUSBRUCH PER MINISPIEL (/ausbrechen)      ##
-- ####################################################
-- Nur relevant für ActiveInmates (normales Jail) - AdminJail-Insassen landen
-- nie in dieser Tabelle, das Minispiel kann dort also gar nicht greifen.
RegisterNetEvent('esx_jail:escapeMinigameSuccess', function(jailId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not Config.Escape.enabled or not Config.Escape.minigame.enabled then return end

    local identifier = xPlayer.identifier
    local inmate = ActiveInmates[identifier]
    if not inmate then return end

    local jail = Config.Jails[jailId]

    Log(identifier, inmate.name, 'escaped', 'Erfolgreicher Ausbruch (Minispiel)', jailId)
    TriggerClientEvent('esx_jail:notify', src, 'Ausbruch erfolgreich!', 'success')

    -- Wachen trotzdem alarmieren, wie beim "klassischen" Fluchtversuch
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xTarget = ESX.GetPlayerFromId(playerId)
        if xTarget and HasJob(xTarget, Config.Escape.alertJobs) then
            TriggerClientEvent('esx_jail:escapeAlert', xTarget.source, jail and jail.label or 'Unbekanntes Gefängnis', inmate.name)
        end
    end

    -- Vollständige Entlassung (Inventar/Waffen zurück, Teleport zu jail.releaseCoords) -
    -- exakt dieselbe Funktion, die auch beim regulären Entlassen genutzt wird.
    ReleasePlayer(identifier, 'Ausbruch (Minispiel)')
end)

RegisterNetEvent('esx_jail:escapeMinigameFail', function(jailId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local inmate = ActiveInmates[identifier]
    if not inmate then return end

    Log(identifier, inmate.name, 'escape_failed', 'Fehlgeschlagener Ausbruchsversuch (Minispiel)', jailId)

    local penalty = Config.Escape.minigame and Config.Escape.minigame.failPenaltyMinutes or 0
    if penalty and penalty > 0 then
        inmate.time = inmate.time + penalty
        MySQL.update('UPDATE jail_inmates SET time = ? WHERE identifier = ?', { inmate.time, identifier })
        TriggerClientEvent('esx_jail:updateTimeDisplay', src, inmate.time)
        TriggerClientEvent('esx_jail:notify', src, ('Fehlgeschlagener Ausbruch! +%d Minuten Strafe.'):format(penalty), 'error')
    end
end)


-- ####################################################
-- ##               ESSEN / TRINKEN                   ##
-- ####################################################

RegisterNetEvent('esx_jail:giveFood', function(targetId, itemConfig)
    local src = source
    local xGuard = ESX.GetPlayerFromId(src)
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xGuard or not xTarget then return end

    if not HasJob(xGuard, Config.ArrestJobs) then
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.not_allowed_job, 'error')
        return
    end

    if xGuard.getInventoryItem(itemConfig.item).count < 1 then
        TriggerClientEvent('esx_jail:notify', src, 'Du hast diesen Gegenstand nicht.', 'error')
        return
    end

    xGuard.removeInventoryItem(itemConfig.item, 1)
    TriggerClientEvent('esx_jail:consumeFood', targetId, itemConfig)
    TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.food_given, 'success')
end)

-- ####################################################
-- ##                ADMIN-FUNKTIONEN                 ##
-- ####################################################
-- Eigenständiges, von Config.Jails komplett unabhängiges System:
-- kein Gefängnis auswählbar, fixer Teleport-Ort (Config.AdminJail.Position),
-- Rückkehr an die ursprüngliche Position nach Ablauf/Entlassung.

local function IsAdmin(source)
    if not Config.AdminJail.enabled then return false end
    if source == 0 then return true end -- Server-Konsole

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    return Config.AdminJail.admingroups[xPlayer.getGroup()] == true
end

-- Erlaubt dem Client zu prüfen, ob der Spieler die Admin-Jail-Berechtigung hat
ESX.RegisterServerCallback('esx_jail:isAdmin', function(source, cb)
    cb(IsAdmin(source))
end)

local function SendAdminWebhook(text)
    if not Config.AdminJail.webhook or Config.AdminJail.webhook == '' then return end
    PerformHttpRequest(Config.AdminJail.webhook, function() end, 'POST', json.encode({ content = text }), { ['Content-Type'] = 'application/json' })
end

-- Sperrt einen Spieler unabhängig von managementJobs/ArrestJobs ein (nur ACE-Permission aus Config.AdminJail).
-- Kein jailId mehr: Teleport immer zu Config.AdminJail.Position, Rückkehr-Koordinaten werden vor dem
-- Teleport gesichert und bei Entlassung/Ablauf wiederhergestellt.
local function AdminJailPlayer(adminName, targetId, minutes, reason)
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return false, 'Ungültige Spieler-ID.' end

    local identifier = xTarget.identifier
    local name = xTarget.getName()
    reason = (reason and reason ~= '') and reason or Config.AdminJail.defaultReason

    local targetPed = GetPlayerPed(targetId)
    local coords = GetEntityCoords(targetPed)
    local heading = GetEntityHeading(targetPed)

    if Config.RemoveWeaponsOnArrest or Config.RemoveItemsOnArrest then
        local loadout = Config.RemoveWeaponsOnArrest and xTarget.getLoadout() or {}
        local inventory = Config.RemoveItemsOnArrest and xTarget.getInventory() or {}

        MySQL.insert('INSERT INTO jail_storage (identifier, skin, loadout, inventory, jail_id) VALUES (?, ?, ?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE loadout = VALUES(loadout), inventory = VALUES(inventory), jail_id = VALUES(jail_id)',
            { identifier, '', json.encode(loadout), json.encode(inventory), 0 })

        if Config.RemoveWeaponsOnArrest then
            for _, weapon in ipairs(loadout) do xTarget.removeWeapon(weapon.name) end
        end
        if Config.RemoveItemsOnArrest then
            for _, item in ipairs(inventory) do
                if item.count and item.count > 0 then xTarget.removeInventoryItem(item.name, item.count) end
            end
        end
    end

    MySQL.insert('INSERT INTO admin_jail (identifier, name, jail_time, jail_reason, in_jail, return_x, return_y, return_z, return_h) '
        .. 'VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE name = VALUES(name), jail_time = VALUES(jail_time), jail_reason = VALUES(jail_reason), '
        .. 'in_jail = 1, return_x = VALUES(return_x), return_y = VALUES(return_y), return_z = VALUES(return_z), return_h = VALUES(return_h)',
        { identifier, name, minutes, reason, coords.x, coords.y, coords.z, heading })

    AdminInmates[identifier] = {
        time = minutes,
        name = name,
        reason = reason,
        source = targetId,
        returnCoords = { x = coords.x, y = coords.y, z = coords.z, h = heading }
    }

    if Config.AdminJail.logActions then
        Log(identifier, name, 'jailed', ('ADMIN (%s) | Grund: %s'):format(adminName or 'Konsole', reason), 0)
    end

    TriggerClientEvent('esx_jail:sendToAdminJail', targetId, minutes, reason)
    SendAdminWebhook(('🔒 **%s** wurde von **%s** ins Admin-Jail gesperrt (%s Min.) | Grund: %s')
        :format(name, adminName or 'Konsole', minutes, reason))
    return true
end

-- Liste aller Online-Spieler für das Admin-Menü
ESX.RegisterServerCallback('esx_jail:adminGetPlayers', function(source, cb)
    if not IsAdmin(source) then return cb({}) end

    local list = {}
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xTarget = ESX.GetPlayerFromId(playerId)
        if xTarget then
            list[#list + 1] = { id = playerId, name = xTarget.getName() }
        end
    end
    cb(list)
end)

-- Alle aktuellen Admin-Jail-Insassen (unabhängig von Config.Jails)
ESX.RegisterServerCallback('esx_jail:adminGetAllInmates', function(source, cb)
    if not IsAdmin(source) then return cb({}) end

    local list = {}
    for identifier, inmate in pairs(AdminInmates) do
        list[#list + 1] = {
            identifier = identifier,
            name = inmate.name,
            time = inmate.time,
            online = inmate.source ~= nil
        }
    end
    cb(list)
end)

RegisterNetEvent('esx_jail:adminJailPlayer', function(targetId, minutes, reason)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('esx_jail:notify', src, 'Keine Berechtigung.', 'error')
        return
    end

    local xAdmin = ESX.GetPlayerFromId(src)
    local ok, err = AdminJailPlayer(xAdmin and xAdmin.getName() or 'Admin', targetId, minutes, reason)
    if ok then
        TriggerClientEvent('esx_jail:notify', src, 'Spieler wurde eingesperrt.', 'success')
    else
        TriggerClientEvent('esx_jail:notify', src, err, 'error')
    end
end)

RegisterNetEvent('esx_jail:adminUpdateTime', function(identifier, newMinutes)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('esx_jail:notify', src, 'Keine Berechtigung.', 'error')
        return
    end

    local inmate = AdminInmates[identifier]
    if not inmate then return end

    newMinutes = tonumber(newMinutes) or inmate.time
    inmate.time = newMinutes
    MySQL.update('UPDATE admin_jail SET jail_time = ? WHERE identifier = ?', { newMinutes, identifier })
    if Config.AdminJail.logActions then
        Log(identifier, inmate.name, 'time_updated', ('neue Reststrafe: %s Minuten (Admin)'):format(newMinutes), 0)
    end

    if inmate.source then
        TriggerClientEvent('esx_jail:updateAdminTimeDisplay', inmate.source, newMinutes)
    end
    TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.time_updated, 'success')
end)

RegisterNetEvent('esx_jail:adminRelease', function(identifier)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('esx_jail:notify', src, 'Keine Berechtigung.', 'error')
        return
    end

    local xAdmin = ESX.GetPlayerFromId(src)
    if ReleaseAdminInmate(identifier, xAdmin and xAdmin.getName() or 'ADMIN') then
        TriggerClientEvent('esx_jail:notify', src, Config.JailLocale.time_updated, 'success')
    end
end)

-- /putinjail [id] [minuten] [grund] -- Konsole/Chat-Variante
if Config.AdminJail.enabled then
    RegisterCommand(Config.AdminJail.consoleCommand, function(source, args)
        if not IsAdmin(source) then
            TriggerClientEvent('esx_jail:notify', source, 'Keine Berechtigung.', 'error')
            return
        end

        local targetId = tonumber(args[1])
        local minutes = tonumber(args[2])
        local reason = table.concat(args, ' ', 3) or ''

        if not targetId or not minutes then
            print(('Verwendung: /%s [id] [minuten] [grund]'):format(Config.AdminJail.consoleCommand))
            return
        end

        local adminName = 'Konsole'
        if source ~= 0 then
            local xAdmin = ESX.GetPlayerFromId(source)
            adminName = xAdmin and xAdmin.getName() or ('Server-ID ' .. source)
        end

        local ok, err = AdminJailPlayer(adminName, targetId, minutes, reason)
        if not ok then print(err) end
    end, false)
end

-- ####################################################
-- ##                    EXPORTS                      ##
-- ####################################################

exports('IsPlayerJailed', function(identifier)
    return ActiveInmates[identifier] ~= nil
end)

exports('JailPlayer', function(source, jailId, minutes, reason)
    return ArrestPlayer(source, source, jailId, minutes, reason)
end)

---------------------------------------------------------------
-- MODUL: PiggyBack (SERVER)
---------------------------------------------------------------
local piggybacking = {}
-- piggybacking[source] = targetSource, source trägt targetSource huckepack
local beingPiggybacked = {}
-- beingPiggybacked[targetSource] = source, targetSource wird von source getragen

RegisterServerEvent("Piggyback:sync")
AddEventHandler("Piggyback:sync", function(targetSrc)
    if not Config.PiggyBack.enabled then return end
    local source = source
    local sourcePed = GetPlayerPed(source)
    local sourceCoords = GetEntityCoords(sourcePed)
    local targetPed = GetPlayerPed(targetSrc)
    local targetCoords = GetEntityCoords(targetPed)
    if #(sourceCoords - targetCoords) <= Config.PiggyBack.maxDistance then
        TriggerClientEvent("Piggyback:syncTarget", targetSrc, source)
        piggybacking[source] = targetSrc
        beingPiggybacked[targetSrc] = source
    end
end)

RegisterServerEvent("Piggyback:stop")
AddEventHandler("Piggyback:stop", function(targetSrc)
    local source = source

    if piggybacking[source] then
        TriggerClientEvent("Piggyback:cl_stop", targetSrc)
        piggybacking[source] = nil
        beingPiggybacked[targetSrc] = nil
    elseif beingPiggybacked[source] then
        TriggerClientEvent("Piggyback:cl_stop", beingPiggybacked[source])
        beingPiggybacked[source] = nil
        piggybacking[beingPiggybacked[source]] = nil
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source

    if piggybacking[source] then
        TriggerClientEvent("Piggyback:cl_stop", piggybacking[source])
        beingPiggybacked[piggybacking[source]] = nil
        piggybacking[source] = nil
    end

    if beingPiggybacked[source] then
        TriggerClientEvent("Piggyback:cl_stop", beingPiggybacked[source])
        piggybacking[beingPiggybacked[source]] = nil
        beingPiggybacked[source] = nil
    end
end)

---------------------------------------------------------------
-- MODUL: TakeHostage (SERVER)
---------------------------------------------------------------
local takingHostage = {}
-- takingHostage[source] = targetSource, source nimmt targetSource als Geisel
local takenHostage = {}
-- takenHostage[targetSource] = source, targetSource wird von source als Geisel gehalten

RegisterServerEvent("TakeHostage:sync")
AddEventHandler("TakeHostage:sync", function(targetSrc)
    if not Config.TakeHostage.enabled then return end
    local source = source

    TriggerClientEvent("TakeHostage:syncTarget", targetSrc, source)
    takingHostage[source] = targetSrc
    takenHostage[targetSrc] = source
end)

RegisterServerEvent("TakeHostage:releaseHostage")
AddEventHandler("TakeHostage:releaseHostage", function(targetSrc)
    local source = source
    if takenHostage[targetSrc] then
        TriggerClientEvent("TakeHostage:releaseHostage", targetSrc, source)
        takingHostage[source] = nil
        takenHostage[targetSrc] = nil
    end
end)

RegisterServerEvent("TakeHostage:killHostage")
AddEventHandler("TakeHostage:killHostage", function(targetSrc)
    local source = source
    if takenHostage[targetSrc] then
        TriggerClientEvent("TakeHostage:killHostage", targetSrc, source)
        takingHostage[source] = nil
        takenHostage[targetSrc] = nil
    end
end)

RegisterServerEvent("TakeHostage:stop")
AddEventHandler("TakeHostage:stop", function(targetSrc)
    local source = source

    if takingHostage[source] then
        TriggerClientEvent("TakeHostage:cl_stop", targetSrc)
        takingHostage[source] = nil
        takenHostage[targetSrc] = nil
    elseif takenHostage[source] then
        TriggerClientEvent("TakeHostage:cl_stop", targetSrc)
        takenHostage[source] = nil
        takingHostage[targetSrc] = nil
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source

    if takingHostage[source] then
        TriggerClientEvent("TakeHostage:cl_stop", takingHostage[source])
        takenHostage[takingHostage[source]] = nil
        takingHostage[source] = nil
    end

    if takenHostage[source] then
        TriggerClientEvent("TakeHostage:cl_stop", takenHostage[source])
        takingHostage[takenHostage[source]] = nil
        takenHostage[source] = nil
    end
end)

---------------------------------------------------------------
-- MODUL: Lifeinvader (SERVER)
---------------------------------------------------------------
-- Alle sicherheitsrelevanten Prüfungen laufen HIER, nicht im Client:
-- Länge, verbotene Wörter, Cooldown und der zu zahlende Preis werden
-- ausschließlich aus dem Server-Config berechnet. Der Client schickt
-- nur den rohen Text - alles andere kann er nicht beeinflussen, das
-- verhindert sowohl Preis-Manipulation als auch doppeltes Abschicken.
do
    local liEsx = exports[Config.Lifeinvader.esxSharedObject]:getSharedObject()
    local liCooldowns = {} -- liCooldowns[identifier] = os.time() der letzten Werbung
    local liSubmitting = {} -- liSubmitting[source] = true, während eine Anfrage verarbeitet wird (Anti-Dupe)
    local liFeed = {} -- { {text=, name=, phone=, playerName=, time=os.time()}, ... } neueste zuerst, auf feed.maxPosts gedeckelt

    local function liContainsForbiddenWord(text)
        local lower = text:lower()
        for _, word in ipairs(Config.Lifeinvader.forbiddenWords) do
            if word ~= '' and lower:find(word:lower(), 1, true) then
                return true
            end
        end
        return false
    end

    -- Fügt einen Post vorne in den Feed ein und kappt ihn danach auf feed.maxPosts
    -- (ältester fliegt automatisch raus, siehe Config.feed.maxPosts).
    local function liPushFeed(entry)
        if not Config.Lifeinvader.feed.enabled then return end

        table.insert(liFeed, 1, entry)

        local max = Config.Lifeinvader.feed.maxPosts or 20
        while #liFeed > max do
            table.remove(liFeed)
        end
    end

    -- Admin-Protokoll: loggt JEDEN Versuch (erfolgreich, geblockt, gekickt, ...) mit
    -- Spieler-Identifier - unabhängig vom öffentlichen "discord"-Webhook.
    local function liSendAdminDiscord(src, xPlayer, text, status, extra)
        local ad = Config.Lifeinvader.adminDiscord
        if not ad or not ad.enabled or not ad.webhook or ad.webhook == '' then return end

        local playerLabel = xPlayer and ('%s (ID: %s | %s)'):format(GetPlayerName(src) or '?', src, xPlayer.identifier)
            or ('ID: %s'):format(src)

        PerformHttpRequest(ad.webhook, function() end, 'POST', json.encode({
            username = ad.botName,
            embeds = {{
                title = 'Lifeinvader - Versuch',
                color = ad.color,
                fields = {
                    { name = 'Spieler', value = playerLabel, inline = false },
                    { name = 'Status', value = status, inline = true },
                    { name = 'Text', value = (text ~= '' and text or '*(leer)*'), inline = false },
                },
                footer = { text = extra or '' },
            }},
        }), { ['Content-Type'] = 'application/json' })
    end

    local function liComputePrice(text)
        if Config.Lifeinvader.price.mode == 'perChar' then
            return #text * Config.Lifeinvader.price.perChar
        end
        return Config.Lifeinvader.price.fixed
    end

    -- Baut den rohen multipart/form-data Request-Body, damit wir Bilder direkt
    -- MIT dem Webhook-Aufruf hochladen können (Discords "attachment://"-Feature).
    -- Dadurch ist keine externe Bild-Hosting-URL nötig - die Bilder liegen im
    -- Script selbst unter assets/discord/ und werden bei jedem Aufruf mitgeschickt.
    local function liBuildMultipart(payloadJson, files, boundary)
        local parts = {}

        table.insert(parts, '--' .. boundary .. '\r\n')
        table.insert(parts, 'Content-Disposition: form-data; name="payload_json"\r\n')
        table.insert(parts, 'Content-Type: application/json\r\n\r\n')
        table.insert(parts, payloadJson)
        table.insert(parts, '\r\n')

        for _, f in ipairs(files) do
            table.insert(parts, '--' .. boundary .. '\r\n')
            table.insert(parts, ('Content-Disposition: form-data; name="%s"; filename="%s"\r\n'):format(f.name, f.filename))
            table.insert(parts, ('Content-Type: %s\r\n\r\n'):format(f.contentType))
            table.insert(parts, f.data)
            table.insert(parts, '\r\n')
        end

        table.insert(parts, '--' .. boundary .. '--\r\n')

        return table.concat(parts)
    end

    local function liSendDiscord(playerName, text, price, name, phone)
        if not Config.Lifeinvader.discord.enabled or Config.Lifeinvader.discord.webhook == '' then
            return
        end

        local d = Config.Lifeinvader.discord
        local anonymName = (Config.Lifeinvader.locales and Config.Lifeinvader.locales.anonymName) or 'ANONYM'

        local displayName = (name ~= nil and name ~= '') and name or anonymName
        local displayPhone = (phone ~= nil and phone ~= '') and phone or '-'

        local embed = {
            author = { name = 'LIFEINVADER' },
            description = text,
            color = d.color,
            fields = {
                { name = 'Name', value = displayName, inline = true },
                { name = 'Telefon', value = displayPhone, inline = true },
                { name = '\u{200B}', value = ('📍 %s'):format(playerName), inline = false },
            },
            footer = { text = ('Preis: %s$'):format(price) },
        }

        local files = {}

        -- Logo: eigene URL aus der Config hat Vorrang, sonst wird das mitgelieferte
        -- Bild aus assets/discord/discord_logo.png direkt mit hochgeladen.
        if d.logoUrl ~= '' then
            embed.author.icon_url = d.logoUrl
        else
            local logoData = LoadResourceFile(GetCurrentResourceName(), 'assets/discord/discord_logo.png')
            if logoData then
                embed.author.icon_url = 'attachment://discord_logo.png'
                table.insert(files, { name = ('files[%d]'):format(#files), filename = 'discord_logo.png', contentType = 'image/png', data = logoData })
            end
        end

        -- Balken: eigene URL aus der Config hat Vorrang, sonst das mitgelieferte
        -- Bild aus assets/discord/discord_bar.png (roter Balken wie im Referenzbild).
        if d.progressBarImage ~= '' then
            embed.image = { url = d.progressBarImage }
        else
            local barData = LoadResourceFile(GetCurrentResourceName(), 'assets/discord/discord_bar.png')
            if barData then
                embed.image = { url = 'attachment://discord_bar.png' }
                table.insert(files, { name = ('files[%d]'):format(#files), filename = 'discord_bar.png', contentType = 'image/png', data = barData })
            end
        end

        local payload = json.encode({ username = d.botName, embeds = { embed } })

        if #files > 0 then
            local boundary = ('mc_core_%d_%d'):format(os.time(), math.random(100000, 999999))
            local body = liBuildMultipart(payload, files, boundary)

            PerformHttpRequest(d.webhook, function() end, 'POST', body, {
                ['Content-Type'] = 'multipart/form-data; boundary=' .. boundary
            })
        else
            PerformHttpRequest(d.webhook, function() end, 'POST', payload, {
                ['Content-Type'] = 'application/json'
            })
        end
    end

    RegisterServerEvent(Config.Lifeinvader.eventPrefix .. ':submit')
    AddEventHandler(Config.Lifeinvader.eventPrefix .. ':submit', function(text, withName, name, phone)
        if not Config.Lifeinvader.enabled then return end

        local src = source
        local m = Config.Lifeinvader.messages

        -- Anti-Dupe: solange eine vorherige Anfrage dieses Spielers noch läuft,
        -- wird eine weitere ignoriert (verhindert doppeltes Spam-Klicken).
        if liSubmitting[src] then return end
        liSubmitting[src] = true

        local xPlayer = liEsx.GetPlayerFromId(src)
        if not xPlayer then
            liSubmitting[src] = nil
            return
        end

        if type(text) ~= 'string' then
            liSubmitting[src] = nil
            return
        end

        text = text:gsub('^%s+', ''):gsub('%s+$', '')
        name = (type(name) == 'string') and name:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 60) or ''
        phone = (type(phone) == 'string') and phone:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 30) or ''

        if text == '' then
            TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':result', src, false, m.empty)
            liSendAdminDiscord(src, xPlayer, text, 'Abgelehnt: leer')
            liSubmitting[src] = nil
            return
        end

        if #text > Config.Lifeinvader.maxLength then
            TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':result', src, false, m.tooLong:format(Config.Lifeinvader.maxLength))
            liSendAdminDiscord(src, xPlayer, text, 'Abgelehnt: zu lang')
            liSubmitting[src] = nil
            return
        end

        -- Blacklist deckt Text, Name UND Telefonnummer ab, da alle drei öffentlich
        -- sichtbar landen (Broadcast + Feed).
        if liContainsForbiddenWord(text) or liContainsForbiddenWord(name) or liContainsForbiddenWord(phone) then
            TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':result', src, false, m.forbiddenWord)

            if Config.Lifeinvader.kickOnForbiddenWord then
                liSendAdminDiscord(src, xPlayer, text, 'GEKICKT: verbotenes Wort/Zeichen', ('Name: %s | Telefon: %s'):format(name, phone))
                liSubmitting[src] = nil
                DropPlayer(src, Config.Lifeinvader.kickReason)
                return
            end

            liSendAdminDiscord(src, xPlayer, text, 'Abgelehnt: verbotenes Wort/Zeichen', ('Name: %s | Telefon: %s'):format(name, phone))
            liSubmitting[src] = nil
            return
        end

        local identifier = xPlayer.identifier
        local lastSent = liCooldowns[identifier]

        if lastSent then
            local elapsedMinutes = (os.time() - lastSent) / 60
            local remaining = math.ceil(Config.Lifeinvader.cooldown - elapsedMinutes)

            if remaining > 0 then
                TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':result', src, false, m.cooldown:format(remaining))
                liSubmitting[src] = nil
                return
            end
        end

        local price = liComputePrice(text)

        if xPlayer.getMoney() < price then
            TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':result', src, false, m.notEnoughMoney:format(price))
            liSendAdminDiscord(src, xPlayer, text, 'Abgelehnt: kein Geld')
            liSubmitting[src] = nil
            return
        end

        xPlayer.removeMoney(price)
        liCooldowns[identifier] = os.time()

        -- Name nur anhängen, wenn das Modul es erlaubt UND der Spieler es im UI ausgewählt hat
        local playerName = GetPlayerName(src)
        local finalText = text

        if Config.Lifeinvader.allowName and withName then
            finalText = Config.Lifeinvader.nameFormat:format(text, playerName)
        end

        TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':result', src, true, m.success)
        TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':broadcast', -1, finalText)

        local feedEntry = {
            text = finalText,
            name = name,
            phone = phone,
            time = os.time(),
        }
        liPushFeed(feedEntry)
        TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':feedPush', -1, feedEntry)

        liSendDiscord(GetPlayerName(src), text, price, name, phone)
        liSendAdminDiscord(src, xPlayer, text, 'Veröffentlicht', ('Preis: %s$ | Name: %s | Telefon: %s'):format(price, name, phone))

        liSubmitting[src] = nil
    end)

    -- Ein Client fragt beim Öffnen des Menüs den aktuellen Feed-Stand ab (z.B. für
    -- Spieler, die erst NACH den letzten Posts dazugekommen sind).
    RegisterServerEvent(Config.Lifeinvader.eventPrefix .. ':requestFeed')
    AddEventHandler(Config.Lifeinvader.eventPrefix .. ':requestFeed', function()
        local src = source
        TriggerClientEvent(Config.Lifeinvader.eventPrefix .. ':feedSync', src, liFeed)
    end)

    AddEventHandler('playerDropped', function()
        local src = source
        liSubmitting[src] = nil
    end)
end

---------------------------------------------------------------
-- MODUL: Formular  (übernommen aus mc_formular)
---------------------------------------------------------------
-- Chat-Command zusätzlich zum Standort-Trigger (siehe client.lua) -
-- öffnet clientseitig einfach dieselbe NUI wie das [E] am Standort.
RegisterCommand(FormularConfig.Command or "formular", function(source)
    local src = source
    if src == 0 then return end
    TriggerClientEvent("mc_core:formular:open", src)
end, false)

RegisterNetEvent("formular:submit")
AddEventHandler("formular:submit", function(data)
    local src = source
    if not src or src == 0 then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    data = data or {}

    -- Für Felder mit "auto" NIE den vom Client geschickten Wert übernehmen -
    -- der könnte manipuliert sein. Stattdessen serverseitig aus den echten
    -- ESX-Spielerdaten nachschlagen (aktuell nur "phone_number").
    for _, v in ipairs(FormularConfig.Fields) do
        if v.auto == "phone_number" then
            data[v.id] = xPlayer.get and xPlayer.get('phone_number') or xPlayer.phone_number
        end
    end

    local fields = {
        {
            name = "Spieler",
            value = ("%s (ID: %s)"):format(GetPlayerName(src) or "Unbekannt", src),
            inline = false
        }
    }

    -- ipairs statt pairs, damit die Reihenfolge immer stimmt
    for _, v in ipairs(FormularConfig.Fields) do
        local value = data and data[v.id]

        -- Discord lehnt Embeds mit leeren "value"-Feldern komplett ab -> dann kommt GAR KEIN Webhook an!
        -- Deshalb IMMER einen gültigen, nicht-leeren String sicherstellen:
        if value == nil or tostring(value):gsub("%s+", "") == "" then
            value = "*(nicht ausgefüllt)*"
        else
            value = tostring(value)
        end

        table.insert(fields, {
            name = v.label,
            value = value,
            inline = false
        })
    end

    if not FormularConfig.Webhook or FormularConfig.Webhook == "" then return end

    PerformHttpRequest(FormularConfig.Webhook, function(err, text, headers)
        if err ~= 200 and err ~= 204 then
            print(("[formular] Discord Webhook fehlgeschlagen! Status: %s | Antwort: %s"):format(tostring(err), tostring(text)))
        end
    end, "POST", json.encode({
        username = FormularConfig.BotName,
        embeds = {{
            title = FormularConfig.Title,
            color = FormularConfig.EmbedColor,
            fields = fields
        }}
    }), { ["Content-Type"] = "application/json" })
end)

---------------------------------------------------------------
-- MODUL: Zombie  (übernommen aus mc_zombie)
---------------------------------------------------------------
-- Zonen-Spawn-Verwaltung + Loot + persistente Kill-Rangliste (Discord).
-- Nutzt ZombieConfig (siehe config.lua) statt eines eigenen "Config",
-- und das bereits global gesetzte ESX-Objekt von mc_core (kein eigenes
-- "local ESX = exports[...]" mehr nötig/möglich, da mc_core ESX schon
-- ganz oben in dieser Datei global setzt).
do
    -- spawnSlots[index] = { occupied = bool, netId = number|nil }
    local spawnSlots = {}
    for i = 1, #ZombieConfig.ZombieSpawnPoints do
        spawnSlots[i] = { occupied = false, netId = nil }
    end

    local activeZombieCount = 0
    local reportedDead = {}      -- [netId] = true, verhindert doppelte Kill-Verarbeitung
    local jackpotCounter = 0
    local jackpotThreshold = math.random(ZombieConfig.JackpotThresholdMin, ZombieConfig.JackpotThresholdMax)

    -- ------------------------------------------------
    -- Spawn-Slot anfragen (Client -> Server)
    -- ------------------------------------------------
    RegisterNetEvent('zombie-script:requestSpawnSlot')
    AddEventHandler('zombie-script:requestSpawnSlot', function()
        local src = source

        if activeZombieCount >= ZombieConfig.MaxZombiesInZone then
            return
        end

        -- ersten freien Slot suchen
        for index, slot in pairs(spawnSlots) do
            if not slot.occupied then
                slot.occupied = true
                activeZombieCount = activeZombieCount + 1
                TriggerClientEvent('zombie-script:spawnAtSlot', src, index, ZombieConfig.ZombieSpawnPoints[index])
                return
            end
        end
    end)

    -- ------------------------------------------------
    -- Client bestaetigt, dass der Zombie tatsaechlich erstellt wurde
    -- ------------------------------------------------
    RegisterNetEvent('zombie-script:zombieSpawned')
    AddEventHandler('zombie-script:zombieSpawned', function(slotIndex, netId)
        local slot = spawnSlots[slotIndex]
        if slot then
            slot.netId = netId
        end
    end)

    -- ------------------------------------------------
    -- Loot-Vergabe (ESX): Geld, normale Items, Jackpot
    -- ------------------------------------------------
    local function GiveZombieLoot(src)
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end

        local lootedItems = {}

        if ZombieConfig.LootMoneyMax and ZombieConfig.LootMoneyMax > 0 then
            local amount = math.random(ZombieConfig.LootMoneyMin, ZombieConfig.LootMoneyMax)
            if amount > 0 then
                xPlayer.addMoney(amount)
                table.insert(lootedItems, ('$%d'):format(amount))
            end
        end

        if ZombieConfig.LootTable then
            for _, entry in ipairs(ZombieConfig.LootTable) do
                if math.random(1, 100) <= entry.chance then
                    local count = math.random(entry.min, entry.max)
                    if count > 0 then
                        xPlayer.addInventoryItem(entry.item, count)
                        table.insert(lootedItems, ('%dx %s'):format(count, entry.item))
                    end
                end
            end
        end

        -- Jackpot: alle X Kills (serverweit) bekommt GENAU dieser Kill ein Extra-Item
        if ZombieConfig.JackpotEnabled then
            jackpotCounter = jackpotCounter + 1
            if jackpotCounter >= jackpotThreshold then
                xPlayer.addInventoryItem(ZombieConfig.JackpotItem, 1)
                table.insert(lootedItems, ('★ JACKPOT: %s'):format(ZombieConfig.JackpotItem))
                jackpotCounter = 0
                jackpotThreshold = math.random(ZombieConfig.JackpotThresholdMin, ZombieConfig.JackpotThresholdMax)
            end
        end

        if ZombieConfig.NotifyOnLoot and #lootedItems > 0 then
            TriggerClientEvent("chat:addMessage", src, {
                args = { "^2[Loot]", "Erhalten: " .. table.concat(lootedItems, ", ") }
            })
        end

        -- Kill fuer die Rangliste zaehlen
        AddZombieKillForLeaderboard(src)
    end

    -- ------------------------------------------------
    -- Ein Client meldet, dass ein Zombie gestorben ist.
    -- killedByMe = true, wenn genau DIESER Client der Killer war (siehe Client-Code)
    -- ------------------------------------------------
    RegisterNetEvent('zombie-script:zombieDied')
    AddEventHandler('zombie-script:zombieDied', function(netId, killedByMe)
        if reportedDead[netId] then
            return -- schon verarbeitet (z.B. von einem anderen Client gemeldet)
        end
        reportedDead[netId] = true

        -- passenden Slot finden, um ihn wieder freizugeben
        local foundSlot = nil
        for index, slot in pairs(spawnSlots) do
            if slot.netId == netId then
                foundSlot = index
                break
            end
        end

        -- Loot nur vergeben, wenn dieser Client tatsaechlich der Killer war
        if killedByMe then
            GiveZombieLoot(source)
        end

        -- Slot nach Ablauf der Delete-Zeit wieder freigeben + Leiche loeschen lassen
        SetTimeout(ZombieConfig.WaitForDelete, function()
            if foundSlot then
                spawnSlots[foundSlot].occupied = false
                spawnSlots[foundSlot].netId = nil
            end
            activeZombieCount = math.max(0, activeZombieCount - 1)
            reportedDead[netId] = nil

            if ZombieConfig.DeleteDeadPeds then
                TriggerClientEvent('zombie-script:deleteZombie', -1, netId)
            end
        end)
    end)

    print('[zombie] Server-Modul geladen.')
end

-- ============================================================
--  ZOMBIE LEADERBOARD - persistente Kill-Zaehlung + Discord-Webhook
-- ============================================================
-- Läuft weiterhin als eigene JSON-Datei (leaderboard.json im
-- mc_core-Ordner) statt DB-Tabelle - identisch zum Original, überlebt
-- also Server-Neustarts ohne dass eine neue SQL-Tabelle nötig wäre.
do
    local killData = {} -- [identifier] = { name = "...", kills = 0 }
    local dirty = false

    local function LoadZombieLeaderboard()
        local raw = LoadResourceFile(GetCurrentResourceName(), 'leaderboard.json')
        if raw then
            local ok, decoded = pcall(json.decode, raw)
            if ok and decoded then
                killData = decoded
            end
        end
    end

    local function SaveZombieLeaderboard()
        SaveResourceFile(GetCurrentResourceName(), 'leaderboard.json', json.encode(killData), -1)
        dirty = false
    end

    CreateThread(function()
        LoadZombieLeaderboard()
    end)

    -- Alle 60s speichern, aber nur wenn sich seit dem letzten Mal was geaendert hat
    CreateThread(function()
        while true do
            Wait(60 * 1000)
            if dirty then
                SaveZombieLeaderboard()
            end
        end
    end)

    -- ------------------------------------------------
    -- Kill fuer einen Spieler zaehlen (global, wird oben vom Loot-Handler aufgerufen)
    -- ------------------------------------------------
    function AddZombieKillForLeaderboard(src)
        local identifier = GetPlayerIdentifierByType(src, 'license')
        if not identifier then
            return
        end

        local name = GetPlayerName(src) or 'Unknown'

        if not killData[identifier] then
            killData[identifier] = { name = name, kills = 0 }
        end

        killData[identifier].name = name -- Namen aktuell halten, falls er sich geaendert hat
        killData[identifier].kills = killData[identifier].kills + 1
        dirty = true
    end

    -- ------------------------------------------------
    -- Top-N Liste bauen
    -- ------------------------------------------------
    local function GetTopZombieKillers(count)
        local list = {}
        for _, data in pairs(killData) do
            table.insert(list, data)
        end

        table.sort(list, function(a, b) return a.kills > b.kills end)

        local top = {}
        for i = 1, math.min(count, #list) do
            table.insert(top, list[i])
        end

        return top
    end

    -- ------------------------------------------------
    -- Discord-Embed bauen und per Webhook posten/editieren
    -- ------------------------------------------------
    local function BuildZombieDescription(topList)
        if #topList == 0 then
            return 'Noch keine Kills erfasst.'
        end

        local lines = {}
        for i, entry in ipairs(topList) do
            table.insert(lines, ('**#%d %s** - Kills: %d'):format(i, entry.name, entry.kills))
        end

        return table.concat(lines, '\n')
    end

    local function SendOrEditZombieWebhook()
        local cfg = ZombieConfig.Webhook
        if not cfg or not cfg.url or cfg.url == '' or cfg.url:find('DEINE_WEBHOOK_ID') then
            print('[zombie] Webhook-URL ist nicht konfiguriert (config.lua -> ZombieConfig.Webhook.url) - Rangliste wird uebersprungen.')
            return
        end

        local topList = GetTopZombieKillers(cfg.topCount or 10)

        local embed = {
            {
                title = cfg.title,
                description = BuildZombieDescription(topList),
                color = cfg.color,
                footer = { text = cfg.footerText .. ' - ' .. os.date('%d.%m.%Y | %H:%M') },
            }
        }

        local payload = {
            username = cfg.botName,
            avatar_url = (cfg.avatarUrl ~= '' and cfg.avatarUrl or nil),
            embeds = embed,
        }

        local headers = { ['Content-Type'] = 'application/json' }

        if cfg.messageId and cfg.messageId ~= '' then
            -- Vorhandene Nachricht editieren (kein Spam im Kanal)
            local editUrl = cfg.url .. '/messages/' .. cfg.messageId
            PerformHttpRequest(editUrl, function(statusCode, response, respHeaders)
                if statusCode ~= 200 then
                    print(('[zombie] Webhook-Edit fehlgeschlagen (Status %s). Pruefe messageId/URL in config.lua.'):format(tostring(statusCode)))
                end
            end, 'PATCH', json.encode(payload), headers)
        else
            -- Erste Nachricht erstellen (wait=true, damit wir die ID in der Antwort bekommen)
            local postUrl = cfg.url .. '?wait=true'
            PerformHttpRequest(postUrl, function(statusCode, response, respHeaders)
                if statusCode == 200 or statusCode == 201 then
                    local ok, decoded = pcall(json.decode, response)
                    if ok and decoded and decoded.id then
                        print('[zombie] Discord-Nachricht erstellt. Trage diese ID in config.lua unter ZombieConfig.Webhook.messageId ein, damit sie ab jetzt aktualisiert statt neu gepostet wird:')
                        print('[zombie] messageId = "' .. decoded.id .. '"')
                    end
                else
                    print(('[zombie] Webhook-Post fehlgeschlagen (Status %s). Pruefe die Webhook-URL in config.lua.'):format(tostring(statusCode)))
                end
            end, 'POST', json.encode(payload), headers)
        end
    end

    CreateThread(function()
        Wait(5000) -- kurz warten, bis alles geladen ist
        SendOrEditZombieWebhook()

        while true do
            Wait(ZombieConfig.Webhook.refreshTime or (300 * 1000))
            SendOrEditZombieWebhook()
        end
    end)

    -- Beim Runterfahren der Ressource den aktuellen Stand sichern, falls noch nicht gespeichert
    AddEventHandler('onResourceStop', function(resourceName)
        if GetCurrentResourceName() ~= resourceName then
            return
        end
        if dirty then
            SaveZombieLeaderboard()
        end
    end)
end

---------------------------------------------------------------
-- MODUL: CombatLog
---------------------------------------------------------------
do
    local function SendCombatLogWebhook(name, reason)
        local wh = Config.CombatLog.Webhook
        if not wh.Enabled or wh.Url == "" then return end

        PerformHttpRequest(wh.Url, function() end, "POST", json.encode({
            username = wh.Username,
            avatar_url = wh.AvatarUrl ~= "" and wh.AvatarUrl or nil,
            embeds = {{
                title = wh.Title,
                color = wh.Color,
                description = string.format("**%s** hat den Server verlassen.\nGrund: %s", name, reason),
                thumbnail = wh.IconUrl ~= "" and { url = wh.IconUrl } or nil
            }}
        }), { ["Content-Type"] = "application/json" })
    end

    AddEventHandler('playerDropped', function(reason)
        local src = source
        if not Config.CombatLog.Enabled then return end

        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end

        local coords = GetEntityCoords(ped)
        local name = GetPlayerName(src) or "Unbekannt"

        -- Pruefen, ob ein anderer Spieler in Reichweite ist
        local enemyNearby = false
        for _, playerId in ipairs(GetPlayers()) do
            if tonumber(playerId) ~= src then
                local otherPed = GetPlayerPed(playerId)
                if otherPed and otherPed ~= 0 then
                    local otherCoords = GetEntityCoords(otherPed)
                    if #(coords - otherCoords) <= Config.CombatLog.Range then
                        enemyNearby = true
                        break
                    end
                end
            end
        end

        if not enemyNearby then return end

        local text = string.format(
            Config.CombatLog.Message,
            os.date(Config.DateFormat or '%d.%m.%Y %H:%M'),
            name,
            reason
        )

        for _, playerId in ipairs(GetPlayers()) do
            TriggerClientEvent('mc_core:combatlog:showMarker', tonumber(playerId), coords, text)
        end

        SendCombatLogWebhook(name, reason)
    end)
end

---------------------------------------------------------------
-- MODUL: Kampfunfaehig
---------------------------------------------------------------
do
    local downedPlayers = {} -- [source] = { identifier = ..., startedAt = ..., forced = bool }

    CreateThread(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `mc_kampfunfaehig` (
                `identifier` VARCHAR(60) PRIMARY KEY,
                `started_at` BIGINT NOT NULL,
                `duration` INT NOT NULL
            )
        ]])
    end)

    local function IsWhitelisted(xPlayer)
        if not xPlayer then return false end

        if Config.Kampfunfaehig.WhitelistedGroups[xPlayer.getGroup()] == true then
            return true
        end

        local job = xPlayer.job and xPlayer.job.name
        if job and Config.Kampfunfaehig.WhitelistedJobs[job] == true then
            return true
        end

        return false
    end

    local function ClearDbEntry(identifier)
        if not identifier then return end
        MySQL.query('DELETE FROM mc_kampfunfaehig WHERE identifier = ?', { identifier })
    end

    local function SendWebhook(title, message)
        if not Config.Kampfunfaehig.Webhook.Enabled or Config.Kampfunfaehig.Webhook.Url == "" then return end

        PerformHttpRequest(Config.Kampfunfaehig.Webhook.Url, function() end, "POST", json.encode({
            username = "Kampfunfähig Log",
            embeds = {{
                title = title,
                description = message,
                color = 15158332
            }}
        }), { ["Content-Type"] = "application/json" })
    end

    local function HasCommandPermission(xPlayer, cmdCfg)
        if not xPlayer then return false end
        return cmdCfg.groups[xPlayer.getGroup()] == true
    end

    ---------------------------------------------------------------
    -- Normaler Ablauf: Spieler wird selbst kampfunfaehig (Tod)
    ---------------------------------------------------------------

    RegisterNetEvent('mc_core:kampfunfaehig:start', function()
        local src = source
        if not Config.Kampfunfaehig.Enabled then return end

        local xPlayer = ESX.GetPlayerFromId(src)
        if IsWhitelisted(xPlayer) then
            TriggerClientEvent('mc_core:kampfunfaehig:skip', src)
            return
        end

        local now = os.time()
        downedPlayers[src] = { identifier = xPlayer and xPlayer.identifier, startedAt = now, duration = Config.Kampfunfaehig.Duration }

        if Config.Kampfunfaehig.PersistOnRestart and xPlayer then
            MySQL.query(
                'INSERT INTO mc_kampfunfaehig (identifier, started_at, duration) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE started_at = ?, duration = ?',
                { xPlayer.identifier, now, Config.Kampfunfaehig.Duration, now, Config.Kampfunfaehig.Duration }
            )
        end
    end)

    RegisterNetEvent('mc_core:kampfunfaehig:stop', function()
        local src = source
        local data = downedPlayers[src]
        downedPlayers[src] = nil

        if data and Config.Kampfunfaehig.PersistOnRestart then
            ClearDbEntry(data.identifier)
        end
    end)

    RegisterNetEvent('mc_core:kampfunfaehig:autoRespawn', function()
        local src = source
        local coords = Config.Kampfunfaehig.Hospitals[1] or vector3(0.0, 0.0, 0.0)

        TriggerClientEvent('mc_core:kampfunfaehig:autoRespawnClient', src, coords)

        local data = downedPlayers[src]
        downedPlayers[src] = nil

        if data and Config.Kampfunfaehig.PersistOnRestart then
            ClearDbEntry(data.identifier)
        end
    end)

    -- Nach Reconnect pruefen, ob der Spieler noch kampfunfaehig sein muesste
    AddEventHandler(Config.Kampfunfaehig.SpawnEvent, function(playerId, xPlayer)
        if not Config.Kampfunfaehig.Enabled or not Config.Kampfunfaehig.PersistOnRestart then return end
        if not xPlayer then xPlayer = ESX.GetPlayerFromId(playerId) end
        if IsWhitelisted(xPlayer) then return end

        SetTimeout(Config.Kampfunfaehig.SpawnWait, function()
            MySQL.single('SELECT started_at, duration FROM mc_kampfunfaehig WHERE identifier = ?', { xPlayer.identifier }, function(result)
                if not result then return end

                local elapsed = os.time() - result.started_at
                local remaining = (result.duration or Config.Kampfunfaehig.Duration) - elapsed

                if remaining <= 0 then
                    ClearDbEntry(xPlayer.identifier)
                    return
                end

                downedPlayers[playerId] = { identifier = xPlayer.identifier, startedAt = result.started_at, duration = result.duration }
                TriggerClientEvent('mc_core:kampfunfaehig:resume', playerId, remaining)
            end)
        end)
    end)

    AddEventHandler('playerDropped', function()
        local src = source
        downedPlayers[src] = nil
    end)

    ---------------------------------------------------------------
    -- Admin-Befehle: dtstart / dtclear / dtclearradius
    ---------------------------------------------------------------

    local function RegisterDtCommand(key)
        local cmdCfg = Config.Kampfunfaehig.Commands[key]
        if not cmdCfg or not cmdCfg.enabled then return end

        RegisterCommand(cmdCfg.commandName, function(source, args)
            local isConsole = source == 0
            local L = Config.Kampfunfaehig.L

            if isConsole and not cmdCfg.allowedFromConsole then
                print(L("cannotBeUsedByConsole"))
                return
            end

            local xPlayer = not isConsole and ESX.GetPlayerFromId(source) or nil

            if not isConsole then
                if not HasCommandPermission(xPlayer, cmdCfg) then
                    MC_Notify("Kampfunfähig", L("noPermission"), "error")
                    return
                end

                if not cmdCfg.allowedWhenDead and downedPlayers[source] then
                    MC_Notify("Kampfunfähig", L("notAllowedWhenDead"), "error")
                    return
                end
            end

            if key == "dtstart" then
                local targetId = tonumber(args[1])
                local duration = tonumber(args[2])
                local reason = table.concat(args, " ", 3)

                if not targetId then
                    if isConsole then print(L("noIdEntered")) else MC_Notify("Kampfunfähig", L("noIdEntered"), "error") end
                    return
                end

                if not duration then
                    if isConsole then print(L("noDurationEntered")) else MC_Notify("Kampfunfähig", L("noDurationEntered"), "error") end
                    return
                end

                if cmdCfg.enterReason == "must" and reason == "" then
                    if isConsole then print(L("noReasonEntered")) else MC_Notify("Kampfunfähig", L("noReasonEntered"), "error") end
                    return
                end

                local targetPlayer = ESX.GetPlayerFromId(targetId)
                if not targetPlayer then
                    if isConsole then print(L("playerNotOnline")) else MC_Notify("Kampfunfähig", L("playerNotOnline"), "error") end
                    return
                end

                if downedPlayers[targetId] then
                    if isConsole then print(L("playerAlreadyInDt")) else MC_Notify("Kampfunfähig", L("playerAlreadyInDt"), "error") end
                    return
                end

                downedPlayers[targetId] = { identifier = targetPlayer.identifier, startedAt = os.time(), duration = duration, forced = true }
                TriggerClientEvent('mc_core:kampfunfaehig:forceStart', targetId, duration)

                if isConsole then
                    if reason ~= "" then
                        SendWebhook(L("webhookDtStartConsoleTitle"), string.format(L("webhookDtStartConsoleMsg"), duration, targetPlayer.getName(), reason))
                    else
                        SendWebhook(L("webhookDtStartConsoleTitle"), string.format(L("webhookDtStartConsoleMsgNoReason"), duration, targetPlayer.getName()))
                    end
                else
                    MC_Notify("Kampfunfähig", string.format(L("startedDt"), targetPlayer.getName()), "success")

                    if reason ~= "" then
                        SendWebhook(L("webhookDtStartClientTitle"), string.format(L("webhookDtStartClientMsg"), duration, targetPlayer.getName(), xPlayer.getName(), reason))
                    else
                        SendWebhook(L("webhookDtStartClientTitle"), string.format(L("webhookDtStartClientMsgNoReason"), duration, targetPlayer.getName(), xPlayer.getName()))
                    end
                end

            elseif key == "dtclear" then
                local targetId = tonumber(args[1])
                local reason = table.concat(args, " ", 2)

                if not targetId then
                    if isConsole then print(L("noIdEntered")) else MC_Notify("Kampfunfähig", L("noIdEntered"), "error") end
                    return
                end

                if cmdCfg.enterReason == "must" and reason == "" then
                    if isConsole then print(L("noReasonEntered")) else MC_Notify("Kampfunfähig", L("noReasonEntered"), "error") end
                    return
                end

                local targetPlayer = ESX.GetPlayerFromId(targetId)
                if not targetPlayer then
                    if isConsole then print(L("playerNotOnline")) else MC_Notify("Kampfunfähig", L("playerNotOnline"), "error") end
                    return
                end

                if not downedPlayers[targetId] then
                    if isConsole then print(L("playerNotInDt")) else MC_Notify("Kampfunfähig", L("playerNotInDt"), "error") end
                    return
                end

                local data = downedPlayers[targetId]
                downedPlayers[targetId] = nil
                if data and Config.Kampfunfaehig.PersistOnRestart then ClearDbEntry(data.identifier) end

                TriggerClientEvent('mc_core:kampfunfaehig:forceClear', targetId)

                if isConsole then
                    if reason ~= "" then
                        SendWebhook(L("webhookDtClearConsoleTitle"), string.format(L("webhookDtClearConsoleMsg"), targetPlayer.getName(), reason))
                    else
                        SendWebhook(L("webhookDtClearConsoleTitle"), string.format(L("webhookDtClearConsoleMsgNoReason"), targetPlayer.getName()))
                    end
                else
                    MC_Notify("Kampfunfähig", string.format(L("removedDt"), targetPlayer.getName()), "success")

                    if reason ~= "" then
                        SendWebhook(L("webhookDtClearClientTitle"), string.format(L("webhookDtClearClientMsg"), targetPlayer.getName(), xPlayer.getName(), reason))
                    else
                        SendWebhook(L("webhookDtClearClientTitle"), string.format(L("webhookDtClearClientMsgNoReason"), targetPlayer.getName(), xPlayer.getName()))
                    end
                end

            elseif key == "dtclearradius" then
                if isConsole then return end -- ergibt ohne eigene Position keinen Sinn

                local radius = tonumber(args[1])
                local reason = table.concat(args, " ", 2)

                if not radius then
                    MC_Notify("Kampfunfähig", L("noReasonEntered"), "error")
                    return
                end

                if cmdCfg.enterReason == "must" and reason == "" then
                    MC_Notify("Kampfunfähig", L("noReasonEntered"), "error")
                    return
                end

                local ped = GetPlayerPed(source)
                local myCoords = GetEntityCoords(ped)
                local clearedNames = {}
                local clearedCount = 0

                for targetId, data in pairs(downedPlayers) do
                    local targetPed = GetPlayerPed(targetId)
                    if targetPed and targetPed ~= 0 then
                        local dist = #(myCoords - GetEntityCoords(targetPed))
                        if dist <= radius then
                            local targetPlayer = ESX.GetPlayerFromId(targetId)
                            downedPlayers[targetId] = nil
                            if Config.Kampfunfaehig.PersistOnRestart then ClearDbEntry(data.identifier) end
                            TriggerClientEvent('mc_core:kampfunfaehig:forceClear', targetId)
                            clearedCount = clearedCount + 1
                            clearedNames[#clearedNames + 1] = targetPlayer and targetPlayer.getName() or tostring(targetId)
                        end
                    end
                end

                if clearedCount == 0 then
                    MC_Notify("Kampfunfähig", L("noPlayersNearby"), "error")
                    return
                end

                MC_Notify("Kampfunfähig", string.format(L("removedDtRadius"), clearedCount), "success")

                local namesStr = table.concat(clearedNames, ", ")
                local coordsStr = string.format("%.1f, %.1f, %.1f", myCoords.x, myCoords.y, myCoords.z)

                if reason ~= "" then
                    SendWebhook(L("webhookDtClearRadiusClientTitle"), string.format(L("webhookDtClearRadiusClientMsg"), clearedCount, xPlayer.getName(), coordsStr, radius, namesStr, reason))
                else
                    SendWebhook(L("webhookDtClearRadiusClientTitle"), string.format(L("webhookDtClearRadiusClientMsgNoReason"), clearedCount, xPlayer.getName(), coordsStr, radius, namesStr))
                end
            end
        end, false)
    end

    RegisterDtCommand("dtstart")
    RegisterDtCommand("dtclear")
    RegisterDtCommand("dtclearradius")
end
