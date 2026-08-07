---------------------------------------------------------------
-- MODUL: Elevator  (eigenstaendige globale Tabelle, wie im Original)
---------------------------------------------------------------
-- Jeder Eintrag in "Elevators" ist ein eigener Fahrstuhl mit eigener
-- Standposition ("pos"). Steht man davor, oeffnet sich ein Menue mit
-- allen unter "floors" definierten Zielen - man waehlt also selbst
-- aus, wohin der Fahrstuhl fahren soll. Weitere Fahrstuehle einfach
-- als zusaetzliche Eintraege in "Elevators" ergaenzen.
---------------------------------------------------------------
ElevatorConfig = {
    Key = 38, -- E

    Marker = {
        size = vec3(0.25, 0.25, 0.25),
        color = { r = 0, g = 120, b = 255, a = 180 },
        drawDist = 10.0,
        interactDist = 1.4
    },

    Elevators = {
        {
            name = "Krankenhaus Fahrstuhl",
            pos = vec3(298.47, -584.76, 43.26),
            floors = {
                { label = "EG",        coords = vec3(298.47, -584.76, 43.26) },
                { label = "1. Stock",  coords = vec3(298.47, -584.76, 48.26) },
                { label = "Dach",      coords = vec3(298.47, -584.76, 54.26) }
            }
        },

        -- Beispiel fuer einen zweiten Fahrstuhl - Koordinaten anpassen
        -- und bei Bedarf beliebig viele weitere Ziele in "floors" ergaenzen.
        -- {
        --     name = "Rathaus Fahrstuhl",
        --     pos = vec3(0.0, 0.0, 0.0),
        --     floors = {
        --         { label = "EG",       coords = vec3(0.0, 0.0, 0.0) },
        --         { label = "1. Stock", coords = vec3(0.0, 0.0, 5.0) },
        --         { label = "2. Stock", coords = vec3(0.0, 0.0, 10.0) }
        --     }
        -- }
    }
}
