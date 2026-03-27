-----------------------------------------------------------
-- Default Clothing States (Vanilla GTA V drawable pairs)
-- Pre-populated toggle pairs for jackets, hats, and hair.
-- Server owners can add custom addon pairs below or in config.lua.
-- Source: GTA V vanilla drawables mapped by community.
-----------------------------------------------------------

MBT.ClothingStates = MBT.ClothingStates or {}
MBT.ClothingStates.Drawables = MBT.ClothingStates.Drawables or {}
MBT.ClothingStates.Props = MBT.ClothingStates.Props or {}
MBT.ClothingStates.Hair = MBT.ClothingStates.Hair or {}

-- =============================================================================
-- HAIR (Component Slot 2) — tied up / let down toggle
-- =============================================================================
MBT.ClothingStates.Hair = {
    -- Male
    { sex = "male",   from = 7,  to = 15 },
    { sex = "male",   from = 43, to = 15 },
    { sex = "male",   from = 9,  to = 43 },
    { sex = "male",   from = 11, to = 43 },
    { sex = "male",   from = 15, to = 43 },
    { sex = "male",   from = 16, to = 43 },
    { sex = "male",   from = 17, to = 43 },
    { sex = "male",   from = 20, to = 43 },
    { sex = "male",   from = 22, to = 43 },
    { sex = "male",   from = 45, to = 43 },
    { sex = "male",   from = 47, to = 43 },
    { sex = "male",   from = 49, to = 43 },
    { sex = "male",   from = 51, to = 43 },
    { sex = "male",   from = 52, to = 43 },
    { sex = "male",   from = 53, to = 43 },
    { sex = "male",   from = 56, to = 43 },
    { sex = "male",   from = 58, to = 43 },
    -- Female
    { sex = "female", from = 1,  to = 49 },
    { sex = "female", from = 2,  to = 49 },
    { sex = "female", from = 7,  to = 49 },
    { sex = "female", from = 9,  to = 49 },
    { sex = "female", from = 10, to = 49 },
    { sex = "female", from = 11, to = 48 },
    { sex = "female", from = 14, to = 53 },
    { sex = "female", from = 15, to = 42 },
    { sex = "female", from = 21, to = 42 },
    { sex = "female", from = 23, to = 42 },
    { sex = "female", from = 31, to = 53 },
    { sex = "female", from = 39, to = 49 },
    { sex = "female", from = 40, to = 49 },
    { sex = "female", from = 42, to = 53 },
    { sex = "female", from = 45, to = 49 },
    { sex = "female", from = 48, to = 49 },
    { sex = "female", from = 49, to = 48 },
    { sex = "female", from = 52, to = 53 },
    { sex = "female", from = 53, to = 42 },
    { sex = "female", from = 54, to = 55 },
    { sex = "female", from = 59, to = 42 },
    { sex = "female", from = 68, to = 53 },
    { sex = "female", from = 76, to = 48 },
}

-- =============================================================================
-- JACKETS (Component Slot 11) — open/close, zip/unzip toggle
-- =============================================================================
MBT.ClothingStates.Drawables[11] = {
    -- Male
    { from = 29,  to = 30,  label = "open_close", sex = "male" },
    { from = 31,  to = 32,  label = "open_close", sex = "male" },
    { from = 42,  to = 43,  label = "open_close", sex = "male" },
    { from = 68,  to = 69,  label = "open_close", sex = "male" },
    { from = 74,  to = 75,  label = "open_close", sex = "male" },
    { from = 87,  to = 88,  label = "open_close", sex = "male" },
    { from = 99,  to = 100, label = "open_close", sex = "male" },
    { from = 101, to = 102, label = "open_close", sex = "male" },
    { from = 103, to = 104, label = "open_close", sex = "male" },
    { from = 126, to = 127, label = "open_close", sex = "male" },
    { from = 129, to = 130, label = "open_close", sex = "male" },
    { from = 184, to = 185, label = "open_close", sex = "male" },
    { from = 188, to = 189, label = "open_close", sex = "male" },
    { from = 194, to = 195, label = "open_close", sex = "male" },
    { from = 196, to = 197, label = "open_close", sex = "male" },
    { from = 198, to = 199, label = "open_close", sex = "male" },
    { from = 200, to = 203, label = "open_close", sex = "male" },
    { from = 202, to = 205, label = "open_close", sex = "male" },
    { from = 206, to = 207, label = "open_close", sex = "male" },
    { from = 210, to = 211, label = "open_close", sex = "male" },
    { from = 217, to = 218, label = "open_close", sex = "male" },
    { from = 229, to = 230, label = "open_close", sex = "male" },
    { from = 232, to = 233, label = "open_close", sex = "male" },
    { from = 251, to = 253, label = "open_close", sex = "male" },
    { from = 256, to = 261, label = "open_close", sex = "male" },
    { from = 262, to = 263, label = "open_close", sex = "male" },
    { from = 265, to = 266, label = "open_close", sex = "male" },
    { from = 267, to = 268, label = "open_close", sex = "male" },
    { from = 279, to = 280, label = "open_close", sex = "male" },
    -- Female
    { from = 53,  to = 52,  label = "open_close", sex = "female" },
    { from = 57,  to = 58,  label = "open_close", sex = "female" },
    { from = 62,  to = 63,  label = "open_close", sex = "female" },
    { from = 90,  to = 91,  label = "open_close", sex = "female" },
    { from = 92,  to = 93,  label = "open_close", sex = "female" },
    { from = 94,  to = 95,  label = "open_close", sex = "female" },
    { from = 187, to = 186, label = "open_close", sex = "female" },
    { from = 190, to = 191, label = "open_close", sex = "female" },
    { from = 196, to = 197, label = "open_close", sex = "female" },
    { from = 198, to = 199, label = "open_close", sex = "female" },
    { from = 200, to = 201, label = "open_close", sex = "female" },
    { from = 202, to = 205, label = "open_close", sex = "female" },
    { from = 204, to = 207, label = "open_close", sex = "female" },
    { from = 210, to = 211, label = "open_close", sex = "female" },
    { from = 214, to = 215, label = "open_close", sex = "female" },
    { from = 227, to = 228, label = "open_close", sex = "female" },
    { from = 239, to = 240, label = "open_close", sex = "female" },
    { from = 242, to = 243, label = "open_close", sex = "female" },
    { from = 259, to = 261, label = "open_close", sex = "female" },
    { from = 265, to = 270, label = "open_close", sex = "female" },
    { from = 271, to = 272, label = "open_close", sex = "female" },
    { from = 274, to = 275, label = "open_close", sex = "female" },
    { from = 276, to = 277, label = "open_close", sex = "female" },
    { from = 292, to = 293, label = "open_close", sex = "female" },
}

-- =============================================================================
-- HATS / VISORS (Prop Slot 0) — brim forward/backward toggle
-- =============================================================================
MBT.ClothingStates.Props[0] = {
    -- Male
    { from = 9,   to = 10,  label = "visor_toggle", sex = "male" },
    { from = 18,  to = 67,  label = "visor_toggle", sex = "male" },
    { from = 82,  to = 67,  label = "visor_toggle", sex = "male" },
    { from = 44,  to = 45,  label = "visor_toggle", sex = "male" },
    { from = 50,  to = 68,  label = "visor_toggle", sex = "male" },
    { from = 51,  to = 69,  label = "visor_toggle", sex = "male" },
    { from = 52,  to = 70,  label = "visor_toggle", sex = "male" },
    { from = 53,  to = 71,  label = "visor_toggle", sex = "male" },
    { from = 62,  to = 72,  label = "visor_toggle", sex = "male" },
    { from = 65,  to = 66,  label = "visor_toggle", sex = "male" },
    { from = 73,  to = 74,  label = "visor_toggle", sex = "male" },
    { from = 76,  to = 77,  label = "visor_toggle", sex = "male" },
    { from = 79,  to = 78,  label = "visor_toggle", sex = "male" },
    { from = 80,  to = 81,  label = "visor_toggle", sex = "male" },
    { from = 91,  to = 92,  label = "visor_toggle", sex = "male" },
    { from = 104, to = 105, label = "visor_toggle", sex = "male" },
    { from = 109, to = 110, label = "visor_toggle", sex = "male" },
    { from = 116, to = 117, label = "visor_toggle", sex = "male" },
    { from = 118, to = 119, label = "visor_toggle", sex = "male" },
    { from = 123, to = 124, label = "visor_toggle", sex = "male" },
    { from = 125, to = 126, label = "visor_toggle", sex = "male" },
    { from = 127, to = 128, label = "visor_toggle", sex = "male" },
    { from = 130, to = 131, label = "visor_toggle", sex = "male" },
    -- Female
    { from = 43,  to = 44,  label = "visor_toggle", sex = "female" },
    { from = 49,  to = 67,  label = "visor_toggle", sex = "female" },
    { from = 64,  to = 65,  label = "visor_toggle", sex = "female" },
    { from = 51,  to = 69,  label = "visor_toggle", sex = "female" },
    { from = 50,  to = 68,  label = "visor_toggle", sex = "female" },
    { from = 52,  to = 70,  label = "visor_toggle", sex = "female" },
    { from = 62,  to = 71,  label = "visor_toggle", sex = "female" },
    { from = 72,  to = 73,  label = "visor_toggle", sex = "female" },
    { from = 75,  to = 76,  label = "visor_toggle", sex = "female" },
    { from = 78,  to = 77,  label = "visor_toggle", sex = "female" },
    { from = 79,  to = 80,  label = "visor_toggle", sex = "female" },
    { from = 18,  to = 66,  label = "visor_toggle", sex = "female" },
    { from = 86,  to = 84,  label = "visor_toggle", sex = "female" },
    { from = 90,  to = 91,  label = "visor_toggle", sex = "female" },
    { from = 103, to = 104, label = "visor_toggle", sex = "female" },
    { from = 108, to = 109, label = "visor_toggle", sex = "female" },
    { from = 115, to = 116, label = "visor_toggle", sex = "female" },
    { from = 117, to = 118, label = "visor_toggle", sex = "female" },
    { from = 122, to = 123, label = "visor_toggle", sex = "female" },
    { from = 124, to = 125, label = "visor_toggle", sex = "female" },
    { from = 126, to = 127, label = "visor_toggle", sex = "female" },
    { from = 129, to = 130, label = "visor_toggle", sex = "female" },
}

-- =============================================================================
-- HAIR (Component Slot 2) — hair up/down toggle
-- single = true: one-way mapping (long hair → tied up, no reverse)
-- The player uses the NUI button to toggle back to their original hair.
-- =============================================================================
MBT.ClothingStates.Drawables[2] = {
    -- Male (most map to drawable 43 = short/bald)
    { from = 7,  to = 15, label = "hair_toggle", sex = "male",   single = true },
    { from = 9,  to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 11, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 15, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 16, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 17, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 20, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 22, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 43, to = 15, label = "hair_toggle", sex = "male",   single = true },
    { from = 45, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 47, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 49, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 51, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 52, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 53, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 56, to = 43, label = "hair_toggle", sex = "male",   single = true },
    { from = 58, to = 43, label = "hair_toggle", sex = "male",   single = true },
    -- Female (map to various tied-up styles)
    { from = 1,  to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 2,  to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 7,  to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 9,  to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 10, to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 11, to = 48, label = "hair_toggle", sex = "female", single = true },
    { from = 14, to = 53, label = "hair_toggle", sex = "female", single = true },
    { from = 15, to = 42, label = "hair_toggle", sex = "female", single = true },
    { from = 21, to = 42, label = "hair_toggle", sex = "female", single = true },
    { from = 23, to = 42, label = "hair_toggle", sex = "female", single = true },
    { from = 31, to = 53, label = "hair_toggle", sex = "female", single = true },
    { from = 39, to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 40, to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 42, to = 53, label = "hair_toggle", sex = "female", single = true },
    { from = 45, to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 48, to = 49, label = "hair_toggle", sex = "female", single = true },
    { from = 49, to = 48, label = "hair_toggle", sex = "female", single = true },
    { from = 52, to = 53, label = "hair_toggle", sex = "female", single = true },
    { from = 53, to = 42, label = "hair_toggle", sex = "female", single = true },
    { from = 54, to = 55, label = "hair_toggle", sex = "female", single = true },
    { from = 59, to = 42, label = "hair_toggle", sex = "female", single = true },
    { from = 68, to = 53, label = "hair_toggle", sex = "female", single = true },
    { from = 76, to = 48, label = "hair_toggle", sex = "female", single = true },
}

-----------------------------------------------------------
-- Server owners: add your custom addon pairs below
-- Example:
-- MBT.ClothingStates.Drawables[11][#MBT.ClothingStates.Drawables[11]+1] =
--     { from = 300, to = 301, label = "open_close", sex = "male" }
-----------------------------------------------------------
