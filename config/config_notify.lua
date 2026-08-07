---------------------------------------------------------------
-- MODUL: NotifyConfig
---------------------------------------------------------------

NotifyConfig = {
    system = "esx",             -- "auto" | "hex_hud" | "ox_lib" | "esx" | "qbcore" | "custom"
    customEvent = nil,           -- z.B. "mc_core:notify", nur bei system = "custom"
    customHelpEvent = nil,       -- eigenes Event für Help-Texte, optional
    defaultDuration = 5000
}

