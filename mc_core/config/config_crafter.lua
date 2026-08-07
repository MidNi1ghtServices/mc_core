Config = Config or {}

---------------------------------------------------------------
-- MODUL: Crafter
---------------------------------------------------------------
Config.UseOxTarget = false -- (auch von Labor genutzt, gleicher Wert)

Config.CraftZones = {
        {
            name = "orange", label = "Crafter orange",
            coords = vector3(435.8295, 6505.3667, 28.6095), radius = 2.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "orangensaft", label = "Orange", craftingTime = 10,
                  reward = { item = "orangensaft", amount = 2 }, ingredients = { orange = 10 } }
            }
        },
        {
            name = "apfel", label = "Crafter apfel",
            coords = vector3(117.52, -329.98, 45.39), radius = 2.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "apfel", label = "Apfel", craftingTime = 10,
                  reward = { item = "apfelsaft", amount = 2 }, ingredients = { apfel = 10 } }
            }
        },
        {
            name = "Trauben", label = "Crafter Trauben",
            coords = vector3(1215.7689, 1846.4213, 78.9088), radius = 2.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "trauben", label = "Trauben", craftingTime = 10,
                  reward = { item = "traubensaft", amount = 2 }, ingredients = { trauben = 10 } }
            }
        },
        {
            name = "Kirsche", label = "Crafter Kirsche",
            coords = vector3(926.8948, -1560.3735, 30.7403), radius = 2.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "kirsche", label = "Kirsche", craftingTime = 10,
                  reward = { item = "kirschesaft", amount = 2 }, ingredients = { Kirsche = 10 } }
            }
        },
        {
            name = "Banane", label = "Crafter Banane",
            coords = vector3(821.9493, -3194.3872, 5.9008), radius = 5.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(5, 5, 0.4),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "bananen", label = "Banane", craftingTime = 10,
                  reward = { item = "bananensaft", amount = 2 }, ingredients = { bananen = 10 } }
            }
        },
        {
            name = "birne", label = "Crafter Birne",
            coords = vector3(232.0012, -3312.1704, 5.7903), radius = 5.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "birne", label = "Birne", craftingTime = 10,
                  reward = { item = "birnesaft", amount = 2 }, ingredients = { birne = 10 } }
            }
        },
        {
            name = "WaffenCraft", label = "Crafter Birne",
            coords = vector3(898.51, -3222.67, -98.3), radius = 5.0,
            blip = { enabled = false, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(5.0, 5.0, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "birne", label = "Birne", craftingTime = 10,
                  reward = { item = "birnesaft", amount = 2 }, ingredients = { birne = 10 } }
            }
        },
        {
            name = "waffenrahmen", label = "Crafter waffenrahmen",
            coords = vector3(754.13, -1841.54, 29.29), radius = 5.0,
            blip = { enabled = false, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(5.0, 5.0, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "waffenrahmen", label = "waffenrahmen", craftingTime = 10,
                  reward = { item = "waffenrahmen", amount = 3 }, ingredients = { metal_erz = 30 } }
            }
        }
    }

