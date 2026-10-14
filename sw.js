/* يخلي الموقع ينحفظ على الشاشة الرئيسية ويفتح بسرعة. البيانات دائماً من الإنترنت. */
var C="qarmasha-v1",SHELL=["./","index.html","style.css","core.js","config.js","icon-192.png","icon-512.png"];
self.addEventListener("install",function(e){e.waitUntil(caches.open(C).then(function(c){return c.addAll(SHELL);}).then(function(){return self.skipWaiting();}));});
self.addEventListener("activate",function(e){e.waitUntil(caches.keys().then(function(k){return Promise.all(k.filter(function(x){return x!==C;}).map(function(x){return caches.delete(x);}));}).then(function(){return self.clients.claim();}));});
self.addEventListener("fetch",function(e){var u=new URL(e.request.url);if(e.request.method!=="GET"||u.origin!==location.origin)return;
  e.respondWith(fetch(e.request).then(function(r){if(r.ok&&/\.(jpg|png|css|js|html|svg)$|\/$/.test(u.pathname)){var cp=r.clone();caches.open(C).then(function(c){c.put(e.request,cp);});}return r;}).catch(function(){return caches.match(e.request).then(function(r){return r||caches.match("index.html");});}));});
