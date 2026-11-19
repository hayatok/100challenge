const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + '4dad0be801b6045d82b7443be5169730.data.unityweb-c141bb09183d595ced55a42e539a3054.wasm.unityweb';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/d42bfd0ef5d88c1164b1fcc9ceeee2f7.loader.js', 'Build/4dad0be801b6045d82b7443be5169730.data.unityweb',
    'Build/c141bb09183d595ced55a42e539a3054.wasm.unityweb', 'Build/8450ae0945c927a21c096c339af26368.framework.js.unityweb'];
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
