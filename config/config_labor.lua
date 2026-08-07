Config = Config or {}

---------------------------------------------------------------
-- MODUL: Labor
-- (Config.UseOxTarget wurde bereits im Crafter-Modul oben gesetzt,
--  beide Original-Dateien nutzten denselben Wert "false")
---------------------------------------------------------------
Config.Labors = {
    {
        id = 1,
        label = "Kokain Labor",
        coords = vector3(107.76, -326.56, 45.68),
        radius = 2.0,
        blip = { enabled = false, sprite = 499, color = 1, scale = 0.8 },
        marker = { r = 0, g = 255, b = 100, alpha = 150 },
        inputItem = "chemicals",
        processTime = 60000,
        moneyPerItem = 150
    }
}

