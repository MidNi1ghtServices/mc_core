---------------------------------------------------------------
-- MODUL: CombatLog
---------------------------------------------------------------
Config = Config or {}

Config.CombatLog = {
    Enabled = true,

    -- Umkreis (Meter), in dem ein anderer Spieler sein muss, damit
    -- ein Disconnect als CombatLog zaehlt.
    Range = 10,

    -- Wie lange (in Millisekunden) Marker + Text am Ort des
    -- Disconnects angezeigt werden.
    MarkerTime = 6500,

    -- %s 1 = Uhrzeit/Datum, %s 2 = Spielername, %s 3 = Disconnect-Grund
    Message = "[%s] Der Spieler %s hat den Server verlassen\n~w~Grund: %s",

    MarkerColor = { r = 255, g = 0, b = 0 },
    TextColor   = { r = 255, g = 0, b = 0 },

    Webhook = {
        Enabled = true,
        Url = "https://ptb.discord.com/api/webhooks/1458380808560574516/BUDYRq98jPRk__eJMNYsGsU426RxQovyEwa-rXWxCi7Od_pEnvIO2QBAipbDXiSGul7I", -- eigene Discord-Webhook-URL eintragen
        Username = "Anti CombatLog",
        Title = "AntiCombatLog",
        Color = 16776960, -- gelb
        AvatarUrl = "",
        IconUrl = ""
    }
}
