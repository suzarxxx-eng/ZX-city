fx_version 'cerulean'
game 'gta5'

name 'mt_radialmenu'
description 'MT Quick Radial Menu'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/compat.lua',
    'client/cl_main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/ui.html'

files {
    'html/assets/Alexandria-VariableFont_wght.ttf',
    'html/ui.html',
    'html/css/RadialMenu.css',
    'html/css/all.min.css',
    'html/js/RadialMenu.js',
    'html/js/all.min.js',
    'html/js/jquery.js',
    'html/js/mockData.js'
}

lua54 'yes'