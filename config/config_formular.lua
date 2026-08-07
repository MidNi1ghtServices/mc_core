Config = Config or {}

---------------------------------------------------------------
-- MODUL: Formular  (übernommen aus mc_formular)
---------------------------------------------------------------
-- Standort-Trigger ([E] am definierten Ort) UND ein Chat-Command tun
-- exakt dasselbe - im Original-Script war Config.Command definiert,
-- aber nirgends als echter Command registriert (toter Config-Wert,
-- man konnte das Formular NUR über den Standort öffnen). Jetzt geht
-- beides.
FormularConfig = {
    Webhook = "", -- WICHTIG: hier stand eine echte, bereits genutzte Webhook-URL im Klartext - die wurde entfernt. Trag deine eigene ein.

    Command = "formular",

    Location = vector3(939.54, -1490.77, 30.09),
    Radius = 3.0,

    BotName = "Formular System",
    Title = "📋 Neues Formular",
    EmbedColor = 3447003,

    Fields = {
        {
            id = "plz",
            label = "Postleitzahl",
            type = "text"
        },
        {
            id = "ort",
            label = "Ort",
            type = "select",
            options = { "Stadt", "Sandy Shores" }
        },
        {
            id = "telefon",
            label = "Telefonnummer",
            type = "number",
            -- Wird NICHT mehr manuell eingegeben - kommt automatisch aus den
            -- ESX-Spielerdaten (users.phone_number). Feld wird in der NUI nur
            -- noch schreibgeschützt angezeigt, damit der Spieler sieht, welche
            -- Nummer mitgeschickt wird.
            auto = "phone_number"
        },
        {
            id = "grund",
            label = "Grund",
            type = "textarea",
            maxlength = 5000
        }
    }
}

