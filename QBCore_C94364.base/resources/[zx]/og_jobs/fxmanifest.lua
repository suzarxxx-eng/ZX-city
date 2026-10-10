fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'og_jobs'
author 'OG'
description 'OG - نظام وظائف كامل (خشاب، تنقيب، صيد، دواجن، نفط، تكسي) مع مركز توظيف، وتضيف وظائف جديدة من ملفات الإعدادات'
version '1.1.0'

shared_scripts {
    'config.lua',
    'jobs/*.lua',
}

client_scripts {
    'client.lua',
    'taxi_client.lua',
}

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/script.js', 'html/center.css', 'html/center.js', 'html/sell.css', 'html/sell.js', 'html/img/*.svg' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
    'taxi_server.lua',
}

dependencies { 'qb-core', 'qb-target', 'qb-menu', 'qb-inventory', 'oxmysql' }
