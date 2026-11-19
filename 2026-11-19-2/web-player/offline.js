const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + '25b4db7f3b9efda40d303b1f1e3ad522.data.unityweb-7a72ddac59dd86abed2a10c0be9ee08b.wasm.unityweb';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/8e4b1998f9a4c9703aedcd9de7af52d5.loader.js', 'Build/25b4db7f3b9efda40d303b1f1e3ad522.data.unityweb',
    'Build/7a72ddac59dd86abed2a10c0be9ee08b.wasm.unityweb', 'Build/a90571013a1031c73bb3824783bd6eee.framework.js.unityweb'];
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
