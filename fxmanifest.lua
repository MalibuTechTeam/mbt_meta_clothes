fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'mbt_meta_clothes'
author 'Malibù Tech Team'
version '2.0.0'
repository 'https://github.com/MalibuTechTeam/mbt_meta_clothes'
description 'mbt_meta_clothes'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
}

shared_scripts {
    'modules/shared.lua',
    'locales/*.lua',
    'config.lua',
    'modules/snapshot/shared.lua',
    'data/clothing_states.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- 1. Server utilities (MBT.ServerUtils)
    'modules/utils/server.lua',
    -- 2. Player wearing state manager (MBT.PlayerState)
    'modules/state/server.lua',
    -- 3. Acknowledged snapshot protocol (MBT.SnapshotServer)
    'modules/snapshot/server.lua',
    -- 4. Shared inventory give functions (MBT.GiveItems)
    'modules/bridge/inventory/give_items.lua',
    'modules/bridge/inventory/qb_useable.lua',
    -- 5. Drip reputation engine (MBT.Drip)
    'modules/drip/server.lua',
    -- 6. Framework bridges (one activates based on resource check)
    'modules/bridge/**/server.lua',
    -- 7. Core server logic
    'core/**/server.lua',
    -- 8. Deterministic server-console self-tests (debug only)
    'tests/snapshot_spec.lua',
}

client_scripts {
    -- 1. Client utilities (MBT.Utils)
    'modules/utils/client.lua',
    -- 2. Target module (MBT.TargetModule)
    'modules/target/client.lua',
    -- 3. Clothing props system (MBT.ClothingProps)
    'modules/props/client.lua',
    -- 4. Shared bridge logic (MBT.SharedClient)
    'modules/bridge/client.lua',
    -- 5. Shared inventory item handlers (MBT.OxItems, MBT.QbItems)
    'modules/bridge/inventory/ox_items.lua',
    'modules/bridge/inventory/qb_items.lua',
    -- 6. Framework bridges (one activates based on resource check)
    'modules/bridge/**/client.lua',
    -- 7. Core client logic
    'core/**/client.lua',
}

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/*.svg',
    'web/dist/*.png',
    'web/dist/assets/*',
    'web/dist/layers/*',
}
