const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + 'dc6deff925d2a0568d2cfbfb6455ac81.data.unityweb-2aa70095e04a7dc967ce96067a063d13.wasm.unityweb';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/c7af467149c18981c6c6c7de8db16e3f.loader.js', 'Build/dc6deff925d2a0568d2cfbfb6455ac81.data.unityweb',
    'Build/2aa70095e04a7dc967ce96067a063d13.wasm.unityweb', 'Build/4b0bffc1bfdb664dbfa1847cc3c79f90.framework.js.unityweb'];
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
