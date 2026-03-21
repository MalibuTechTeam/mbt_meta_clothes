fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

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
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- 1. Server utilities (MBT.ServerUtils)
    'modules/utils/server.lua',
    -- 2. Player wearing state manager (MBT.PlayerState)
    'modules/state/wearing.lua',
    -- 3. Shared inventory give functions (MBT.GiveItems)
    'modules/bridge/inventory/give_items.lua',
    'modules/bridge/inventory/qb_useable.lua',
    -- 4. Framework bridges (one activates based on resource check)
    'modules/bridge/**/server.lua',
    -- 5. Core server logic
    'core/**/server.lua',
}

client_scripts {
    -- 1. Client utilities (MBT.Utils)
    'modules/utils/client.lua',
    -- 2. Clothing props system (MBT.ClothingProps)
    'modules/props/clothing_props.lua',
    -- 3. Shared bridge logic (MBT.SharedClient)
    'modules/bridge/shared_client.lua',
    -- 4. Shared inventory item handlers (MBT.OxItems, MBT.QbItems)
    'modules/bridge/inventory/ox_items.lua',
    'modules/bridge/inventory/qb_items.lua',
    -- 5. Framework bridges (one activates based on resource check)
    'modules/bridge/**/client.lua',
    -- 6. Core client logic
    'core/**/client.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/index.js',
    'web/image/*.png',
}
