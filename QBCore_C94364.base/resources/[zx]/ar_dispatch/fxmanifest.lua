fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ar_dispatch'
description 'بلاغات الأمن العام: إطلاق نار، سرقة سيارة، سرقة متجر/بنك، هروب من السجن، حركة مشبوهة'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependency 'qb-core'
