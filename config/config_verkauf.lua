Config = Config or {}

---------------------------------------------------------------
-- MODUL: Verkauf
---------------------------------------------------------------
Config.Verkauf = {

    ["orangensaft"] = {
        coords = vector3(-1504.9540, 1511.6925, 115.2885),
        input = { item = "orangensaft", label = "Orangensaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 80, max = 115 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Orangen zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 47, scale = 1.0, shortrange = true, name = "Orangen Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["apfelsaft"] = {
        coords = vector3(-46.2101, 1945.8883, 190.1862),
        input = { item = "apfelsaft", label = "Apfelsaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 70, max = 105 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Apfel zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 69, scale = 1.0, shortrange = true, name = "Apfel Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["traubensaft"] = {
        coords = vector3(1477.1738, 2722.0024, 37.6274),
        input = { item = "traubensaft", label = "Traubensaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 90, max = 135 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Trauben zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 83, scale = 1.0, shortrange = true, name = "Trauben Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["kirschesaft"] = {
        coords = vector3(446.0303, 84.0746, 98.9259),
        input = { item = "Kirschesaft", label = "Kirschesaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 105, max = 160 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Kirsche zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 1, scale = 1.0, shortrange = true, name = "Kirsche Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["bananensaft"] = {
        coords = vector3(-1005.3513, -308.9769, 37.8649),
        input = { item = "bananensaft", label = "Bananesaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 80, max = 120 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Bananen zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 5, scale = 1.0, shortrange = true, name = "Bananen Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["birnesaft"] = {
        coords = vector3(-1037.6805, -1397.1294, 5.5532),
        input = { item = "birnesaft", label = "Birnesaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 75, max = 110 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Birne zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 25, scale = 1.0, shortrange = true, name = "Birne Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    }
}

