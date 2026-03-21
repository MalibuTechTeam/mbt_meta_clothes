-----------------------------------------------------------
-- Clothing Props System (client-side)
-- Spawns 3D prop models during clothing interactions:
--   - Self-undress: prop in hand during animation
--   - Steal/Mask Ripping: props scatter from victim with physics
-----------------------------------------------------------

MBT.ClothingProps = {}

-- Active props tracked for cleanup
local activeProps = {}

-- PED bone IDs
local BONE_RIGHT_HAND = 57005

-- Height offsets for scatter spawn based on slot body position
local SCATTER_OFFSETS = {
    head    = { z = 0.7,  forceZ = 3.0 },
    torso   = { z = 0.3,  forceZ = 2.0 },
    legs    = { z = -0.3, forceZ = 1.5 },
    feet    = { z = -0.8, forceZ = 1.0 },
    neck    = { z = 0.5,  forceZ = 2.5 },
    wrist   = { z = 0.0,  forceZ = 1.5 },
    ear     = { z = 0.6,  forceZ = 2.0 },
}

-- Map slot index → body zone for scatter height
local SLOT_ZONES = {
    Drawables = {
        [3]  = "torso",
        [4]  = "legs",
        [6]  = "feet",
        [7]  = "neck",
        [8]  = "torso",
        [11] = "torso",
    },
    Props = {
        [0] = "head",
        [1] = "head",
        [2] = "ear",
        [6] = "wrist",
    }
}

--- Check if a table contains a value (local helper to avoid dependency on MBT.Utils load order)
local function tableContains(tbl, val)
    if not tbl then return false end
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

-----------------------------------------------------------
-- Model loading
-----------------------------------------------------------

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(50)
        timeout = timeout + 50
    end
    if HasModelLoaded(hash) then return hash end
    return nil
end

-----------------------------------------------------------
-- Hand attachment (self-undress)
-----------------------------------------------------------

function MBT.ClothingProps.AttachToHand(ped, propModel)
    if not propModel then return nil end
    local hash = loadModel(propModel)
    if not hash then return nil end

    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z - 10.0, false, false, false)

    if not DoesEntityExist(obj) then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetEntityCollision(obj, false, false)

    AttachEntityToEntity(obj, ped,
        GetPedBoneIndex(ped, BONE_RIGHT_HAND),
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )

    activeProps[obj] = true
    SetModelAsNoLongerNeeded(hash)
    return obj
end

function MBT.ClothingProps.DetachAndDelete(obj)
    if not obj or not DoesEntityExist(obj) then
        activeProps[obj] = nil
        return
    end
    DetachEntity(obj, true, true)
    DeleteEntity(obj)
    activeProps[obj] = nil
end

-----------------------------------------------------------
-- Physics scatter (steal / mask ripping / death)
-----------------------------------------------------------

function MBT.ClothingProps.ScatterFromPed(ped, propModel, slotType, slotIndex)
    if not propModel then return nil end
    local hash = loadModel(propModel)
    if not hash then return nil end

    local zone = "torso"
    if SLOT_ZONES[slotType] and SLOT_ZONES[slotType][slotIndex] then
        zone = SLOT_ZONES[slotType][slotIndex]
    end
    local offset = SCATTER_OFFSETS[zone] or SCATTER_OFFSETS.torso

    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z + offset.z, false, false, false)

    if not DoesEntityExist(obj) then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetEntityDynamic(obj, true)
    ActivatePhysics(obj)

    local heading = GetEntityHeading(ped)
    local angle = math.rad(heading + math.random(-120, 120))
    local lateralForce = math.random(15, 40) / 10.0
    local verticalForce = offset.forceZ + (math.random(-5, 10) / 10.0)

    ApplyForceToEntity(obj, 1,
        -math.sin(angle) * lateralForce,
        math.cos(angle) * lateralForce,
        verticalForce,
        0.0, 0.0, 0.0,
        0, false, true, true, false, true
    )

    local spinForce = math.random(-20, 20) / 10.0
    ApplyForceToEntity(obj, 1,
        0.0, 0.0, 0.0,
        spinForce, spinForce * 0.5, spinForce * 0.3,
        0, false, true, true, false, true
    )

    activeProps[obj] = true
    SetModelAsNoLongerNeeded(hash)

    local cleanupMs = (MBT.PropCleanupTime or 60) * 1000
    Citizen.SetTimeout(cleanupMs, function()
        MBT.ClothingProps.CleanupProp(obj)
    end)

    return obj
end

function MBT.ClothingProps.ScatterAllFromPed(ped, sex)
    if not sex or sex == "customSkin" then return end

    for k, v in pairs(MBT.Drawables) do
        if v["PropModel"] and v["Default"][sex] then
            local current = GetPedDrawableVariation(ped, k)
            if not tableContains(v["Default"][sex], current) then
                MBT.ClothingProps.ScatterFromPed(ped, v["PropModel"], "Drawables", k)
            end
        end
    end

    for k, v in pairs(MBT.Props) do
        if v["PropModel"] and v["Default"][sex] then
            local current = GetPedPropIndex(ped, k)
            if not tableContains(v["Default"][sex], current) then
                MBT.ClothingProps.ScatterFromPed(ped, v["PropModel"], "Props", k)
            end
        end
    end
end

-----------------------------------------------------------
-- Cleanup
-----------------------------------------------------------

function MBT.ClothingProps.CleanupProp(obj)
    if obj and DoesEntityExist(obj) then
        DeleteEntity(obj)
    end
    activeProps[obj] = nil
end

function MBT.ClothingProps.CleanupAll()
    for obj, _ in pairs(activeProps) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    activeProps = {}
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        MBT.ClothingProps.CleanupAll()
    end
end)
