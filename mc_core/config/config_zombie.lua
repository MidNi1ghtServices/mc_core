Config = Config or {}

---------------------------------------------------------------
-- MODUL: Zombie  (übernommen aus mc_zombie)
---------------------------------------------------------------
-- Eigene Config-Tabelle statt Feldern direkt auf "Config" - der
-- globale "Config"-Table wird in mc_core schon von etlichen anderen
-- Modulen benutzt (u.a. Config.Framework existiert schon). Hätte man
-- die Felder von mc_zombie einfach in "Config" reingemischt, wäre
-- "Config.Framework" zwar (zufällig) derselbe Wert gewesen, aber bei
-- generischen Namen wie "Config.Marker" oder "Config.Blip" wäre es
-- nur eine Frage der Zeit, bis sich zwei Module in die Quere kommen.
-- Nutzt für ESX/Framework-Zwecke einfach das bereits global gesetzte
-- Config.Framework / ESX-Objekt von mc_core mit.
ZombieConfig = {}

-- ============================================================
--   ZONE
-- ============================================================
-- Mittelpunkt der Zombie-Zone und Radius (in Metern), in dem die Zone aktiv ist.
ZombieConfig.Zone = {
    coords = vector3(1532.379, 3540.450, 35.362),
    radius = 30.0,
}

-- Ab welcher Entfernung zum Zonen-Mittelpunkt ein Client ueberhaupt anfaengt,
-- Spawns anzufragen bzw. Kills zu ueberwachen (etwas groesser als radius, damit
-- man nicht exakt an der Kante rein/raus flackert).
ZombieConfig.ZoneCheckDistance = 40.0

-- Text, der einmalig angezeigt wird, wenn ein Spieler die Zone betritt
ZombieConfig.HelpNotify = "~r~Du befindest dich jetzt in der Zombie Zone!~s~"

-- Marker, der die Zone am Boden visuell markiert
ZombieConfig.Marker = {
    id = 28,
    r = 255, g = 0, b = 0, a = 50,
    sizeX = 30.0, sizeY = 30.0, sizeZ = 30.0,
    drawDistance = 100.0,
}

-- Blip auf der Karte
ZombieConfig.Blip = {
    enabled = true,
    sprite = 303,
    display = 4,
    scale = 0.8,
    color = 75,
    label = "Zombie Zone",
}

-- ============================================================
--   ZOMBIE SPAWNS
-- ============================================================
-- Feste Spawnpunkte innerhalb der Zone. Zombies erscheinen NUR an diesen Punkten,
-- nicht zufaellig irgendwo. Fuege beliebig viele hinzu.
ZombieConfig.ZombieSpawnPoints = {
    vector3(1519.193, 3554.295, 35.362),
    vector3(1532.327, 3555.318, 35.362),
    vector3(1539.287, 3531.986, 35.362),
    vector3(1551.550, 3532.700, 35.611),
    vector3(1552.608, 3549.358, 35.362),
    vector3(1534.843, 3546.164, 35.363),
}

-- Maximale Anzahl GLEICHZEITIG lebender Zombies IN DER GESAMTEN ZONE (nicht pro Spieler!).
-- Das ist ein geteilter Wert, damit alle Spieler dieselben Zombies sehen und die Zone
-- nicht durch mehrere Spieler gleichzeitig ueberflutet wird.
ZombieConfig.MaxZombiesInZone = 8

-- Wie oft (ms) ein Client in der Zone prueft, ob er einen neuen Zombie anfragen soll
ZombieConfig.SpawnCheckInterval = 2000

-- Soll ein toter Zombie nach einiger Zeit automatisch geloescht werden (Leiche entfernen)?
ZombieConfig.DeleteDeadPeds = true
ZombieConfig.WaitForDelete = 30 * 1000 -- 30 Sekunden, nachdem er gestorben ist

-- Zombie-Modelle. u_m_y_zombie_01 ist ein ECHTES GTA-Basisspiel-Ped-Modell
-- (wird z.B. in einer Traum-Mission von Michael verwendet) - kein Addon noetig.
ZombieConfig.ZombieModels = {
    GetHashKey("u_m_y_zombie_01"),
}

-- Lebenspunkte eines Zombies
ZombieConfig.ZombieHealth = 250

-- Bewegungsgeschwindigkeit (0.0 - 3.0), simuliert das "torkelnde" Zombie-Tempo
ZombieConfig.ZombieWalkSpeed = 1.0

-- Ab welcher Distanz ein Zombie einen Spieler bemerkt und angreift
ZombieConfig.AggroRange = 25.0

-- Ab welcher Distanz ein Zombie tatsaechlich zuschlaegt (nur relevant, falls er
-- KEINE Waffe hat - mit Waffe uebernimmt das normale Kampfsystem des Spiels)
ZombieConfig.AttackRange = 1.6

-- Schaden pro Nahkampf-Angriff (nur ohne Waffe)
ZombieConfig.AttackDamage = 8

-- Abklingzeit zwischen zwei Nahkampf-Angriffen desselben Zombies (ms)
ZombieConfig.AttackCooldown = 1500

-- Sollen Zombies Waffen tragen und damit auf Spieler schiessen/angreifen koennen?
ZombieConfig.PedWeapon = true
ZombieConfig.WeaponPed = {
    GetHashKey("weapon_switchblade"),
    GetHashKey("weapon_dagger"),
}

-- Movement-Clipsets, die den torkelnden "Zombie-Gang" erzeugen (maennlich/weiblich getrennt,
-- da Clipsets an das Skelett gebunden sind)
ZombieConfig.ZombieClipsetMale = "move_m@drunk@verydrunk"
ZombieConfig.ZombieClipsetFemale = "move_f@drunk@verydrunk"

-- Wunden/Blut-Overlays, die zufaellig zusaetzlich auf die Zombies angewendet werden
ZombieConfig.ZombieDamagePacks = {
    "sc1_facial_cut",
    "sc1_facial_bruised",
    "sc1_facial_scarred",
    "sc1_torso_bruised",
}

-- Soll periodisch ein Zombie-Stoehn-Sound abgespielt werden?
ZombieConfig.PlayZombieSounds = true
ZombieConfig.ZombieSoundName = "Grunzen" -- generischer Ped-Speech-Context, klingt am ehesten nach "Grunzen"

-- ============================================================
--   FREEMODE-MASKE (optional, alternativ zu ZombieConfig.ZombieModels)
-- ============================================================
-- Falls du statt u_m_y_zombie_01 lieber einen Freemode-Charakter mit einer der
-- Rockstar-Halloween-Zombie-Masken nutzen willst. Findet die IDs ueber /zombiemask (siehe README).
ZombieConfig.UseFreemodeMasks = false
ZombieConfig.FreemodeModels = {
    GetHashKey("mp_m_freemode_01"),
    GetHashKey("mp_f_freemode_01"),
}
ZombieConfig.ZombieMaskDrawable = 0
ZombieConfig.ZombieMaskTexture = 0
ZombieConfig.ZombieDecalDrawable = 0
ZombieConfig.ZombieDecalTexture = 0

-- ============================================================
--   LOOT (ESX)
-- ============================================================
-- Nutzt das bereits global gesetzte Config.Framework von mc_core mit
-- (ist dort schon "esx") statt eines eigenen, doppelten Feldes.

-- Zufaellige Geld-Belohnung pro getoetetem Zombie (min, max). 0,0 = kein Geld-Loot.
ZombieConfig.LootMoneyMin = 5
ZombieConfig.LootMoneyMax = 40

-- Normale Item-Loot-Tabelle. Jeder Eintrag braucht:
--   item   = exakter ESX-Item-Name (muss in deiner items-Tabelle in der DB existieren!)
--   chance = Wahrscheinlichkeit in Prozent (0-100), unabhaengig pro Item geprueft
--   min/max = wie viel man bei einem Treffer bekommt
ZombieConfig.LootTable = {
    { item = "bandage", chance = 35, min = 1, max = 2 },
    { item = "water",   chance = 40, min = 1, max = 1 },
    { item = "bread",   chance = 30, min = 1, max = 1 },
    { item = "phone",   chance = 5,  min = 1, max = 1 },
}

-- Chat-Benachrichtigung anzeigen, wenn Loot erhalten wurde?
ZombieConfig.NotifyOnLoot = true

-- "Jackpot"-System: alle X Kills (serverweit, zufaellig zwischen min/max) bekommt
-- derjenige, der GENAU diesen Kill macht, ein besonders seltenes Item obendrauf.
ZombieConfig.JackpotEnabled = true
ZombieConfig.JackpotItem = "goldbar"
ZombieConfig.JackpotThresholdMin = 8
ZombieConfig.JackpotThresholdMax = 15

-- ============================================================
--   DISCORD KILL-RANGLISTE
-- ============================================================
ZombieConfig.Webhook = {
    -- Komplette Webhook-URL aus deinem Discord-Kanal (Kanal-Einstellungen > Integrationen > Webhooks)
    -- WICHTIG: hier stand eine echte, bereits genutzte Webhook-URL im Klartext -
    -- die wurde entfernt. Trag deine eigene ein, sonst wird nichts gepostet.
    url = "",

    -- Leer lassen beim ERSTEN Start! Das Script postet dann einmalig eine neue Nachricht
    -- und gibt dir die Message-ID in der Server-Konsole aus. Diese ID hier eintragen,
    -- damit ab dann IMMER dieselbe Nachricht aktualisiert (editiert) wird, statt neue zu posten.
    messageId = "",

    botName = "MC_ZombieZones",
    avatarUrl = "",
    color = 16711680, -- Dezimalwert, siehe https://convertingcolors.com
    title = "» Zombie Zone × Top 10",
    footerText = "VIN_ZombieZone",

    -- Wie oft (ms) die Rangliste neu berechnet und die Discord-Nachricht aktualisiert wird
    refreshTime = 300 * 1000, -- 5 Minuten

    topCount = 10,
}
