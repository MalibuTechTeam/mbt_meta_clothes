-----------------------------------------------------------
-- Target System (client-side)
-- Auto-detects ox_target, qb-target, or qtarget
-- Registers steal player dress interaction on all players
-----------------------------------------------------------

MBT.TargetModule = {}

local activeTarget = nil

--- Detect which target script is running
local function detectTarget()
    if GetResourceState('ox_target') == 'started' then
        return 'ox_target'
    elseif GetResourceState('qb-target') == 'started' then
        return 'qb-target'
    elseif GetResourceState('qtarget') == 'started' then
        return 'qtarget'
    end
    return nil
end

--- Check if target entity can be stolen from (hands up, dead, or ragdoll).
--- Hands-up animations are configurable via MBT.HandsUpAnims in config.lua.
local function canStealFrom(entity)
    if IsPedDeadOrDying(entity, false) or IsPedRagdoll(entity) then
        return true
    end
    for _, anim in ipairs(MBT.HandsUpAnims or {}) do
        if IsEntityPlayingAnim(entity, anim.dict, anim.clip, 3) then
            return true
        end
    end
    return false
end

--- Register the steal dress target on all players
function MBT.TargetModule.Setup()
    if not MBT.TargetEnabled then return end

    activeTarget = detectTarget()
    if not activeTarget then
        MBT.Debugger("Target: No supported target script found (ox_target, qb-target, qtarget)")
        return
    end

    MBT.Debugger("Target: Using", activeTarget)

    if activeTarget == 'ox_target' then
        -- Remove existing target before re-adding (prevents duplicate on ensure)
        pcall(function() exports.ox_target:removeGlobalPlayer('mbt_steal_dress') end)
        exports.ox_target:addGlobalPlayer({
            {
                name = 'mbt_steal_dress',
                icon = 'fa-solid fa-shirt',
                label = MBT.Locale["steal_dress"],
                event = 'mbt_meta_clothes:stealPlayerDress',
                distance = MBT.TargetDistance or 2.0,
                canInteract = function(entity)
                    return canStealFrom(entity)
                end
            }
        })
    elseif activeTarget == 'qb-target' or activeTarget == 'qtarget' then
        local targetExport = exports[activeTarget]
        targetExport:AddGlobalPlayer({
            options = {
                {
                    name = 'mbt_steal_dress',
                    icon = 'fa-solid fa-shirt',
                    label = MBT.Locale["steal_dress"],
                    type = 'client',
                    event = 'mbt_meta_clothes:stealPlayerDress',
                    canInteract = function(entity)
                        return canStealFrom(entity)
                    end
                }
            },
            distance = MBT.TargetDistance or 2.0
        })
    end
end
