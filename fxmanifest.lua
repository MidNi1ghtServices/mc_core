fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Nigh1'
description 'MC Core'
version '1.1.5'

escrow_ignore {
    'config/config.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/audio.js',
    'html/sounds/klingel_police.mp3',
    'html/sounds/klingel_ems.mp3',
    'html/sounds/klingel_fib.mp3'
}