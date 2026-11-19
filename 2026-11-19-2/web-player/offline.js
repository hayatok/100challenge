const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + 'a7f8b9e888dc91caee16809d8f4426b0.data.unityweb-e67e49d0f1ee2ad9af596f318d2a072e.wasm.unityweb';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/2a8d9fff000201cd6e4c05273a531e56.loader.js', 'Build/a7f8b9e888dc91caee16809d8f4426b0.data.unityweb',
    'Build/e67e49d0f1ee2ad9af596f318d2a072e.wasm.unityweb', 'Build/c22b649ee4e5394913cb8b6fc05758ec.framework.js.unityweb'];
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
