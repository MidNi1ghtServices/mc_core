Config = Config or {}

---------------------------------------------------------------
-- MODUL: Farming
---------------------------------------------------------------
Config.FarmingBonus = {
    enabled = true,      -- Bonus aktiv?
    multiplier = 2,      -- 2 = doppelt sammeln
    startHour = 16,      -- Startzeit (16 Uhr)
    endHour = 19          -- Endzeit (19 Uhr)
}

Config.Farming = {

        ["Kirsche"] = {
            coords = vector3(5035.4941, -4700.4673, 7.5553),
            output = "Kirsche", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um Kirsche zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 1, scale = 1.0, shortrange = true, name = "kirschefarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["bananen"] = {
            coords = vector3(5062.43, -4818.24, 16.81),
            output = "bananen", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um bananen zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 5, scale = 1.0, shortrange = true, name = "bananenfarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["birne"] = {
            coords = vector3(5513.9424, -5338.4414, 20.1274),
            output = "birne", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um birne zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 25, scale = 1.0, shortrange = true, name = "Birnefarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["trauben"] = {
            coords = vector3(-1713.2019, 2330.2693, 63.9261),
            output = "trauben", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um Trauben zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 83, scale = 1.0, shortrange = true, name = "Traubenfarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["orange"] = {
            coords = vector3(2419.0820, 4673.5991, 33.9015),
            output = "orange", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um Orange zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 47, scale = 1.0, shortrange = true, name = "Orangefarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["apfel"] = {
            coords = vector3(233.9311, 6512.4971, 31.2423),
            output = "apfel", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um Apfel zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 69, scale = 1.0, shortrange = true, name = "Apfelfarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        -- Waffenfarm
        ["waffen"] = {
            coords = vector3(-554.8976, 5324.3403, 73.5995),
            output = "waffen", outputanzahl = 5,
            random = { enabled = false, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um metal zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = true, chance = 40,
                items = {
                    { type = "item", name = "steel", label = "Steel", amount = 5 },
                    { type = "item", name = "rubber", label = "Rubber", amount = 5 },
                    { type = "item", name = "metalscrap", label = "Metal Scrap", amount = 5 }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = { "police" },
            blip = { id = 238, color = 69, scale = 1.0, shortrange = true, name = "waffenfarm", enabled = false },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        }
    }

