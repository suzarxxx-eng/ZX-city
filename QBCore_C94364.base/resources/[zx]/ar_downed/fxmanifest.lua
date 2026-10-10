fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ar_downed'
description 'تأثير السقوط: شاشة دم + دقات قلب + طرش + المايك بس'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependency 'qb-core'
