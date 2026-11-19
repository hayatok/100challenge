const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + '8c441c270e925301c1add122d8982fda.data.unityweb-35f1953a5bb33ce509e92dcbb8ccccd6.wasm.unityweb';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/5cc8e28c937d947010e5b1183c6041ab.loader.js', 'Build/8c441c270e925301c1add122d8982fda.data.unityweb',
    'Build/35f1953a5bb33ce509e92dcbb8ccccd6.wasm.unityweb', 'Build/241cd0ce04e895a1156fef31e623ceca.framework.js.unityweb'];
self.addEventListener('install', event => {
    event.waitUntil(caches.open(version).then(cache => cache.addAll(assets)));
});
self.addEventListener('activate', event => {
    event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key =>
        key.startsWith(prefix) && key !== version).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
    if (event.request.method !== 'GET' || !event.request.url.startsWith(self.registration.scope)) return;
    event.respondWith(caches.open(version).then(async cache => {
        if (event.request.mode === 'navigate') {
            try { return await fetch(event.request); } catch { return await cache.match('index.html'); }
        }
        return await cache.match(event.request) || fetch(event.request);
    }));
});
