const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + 'd740760e2cd51698739564b0a2497697.data.unityweb-ac13e3edf380aabd3bd96a7afdf920cf.wasm.unityweb';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/9c27f35441cca52d25a2bd2950eb942a.loader.js', 'Build/d740760e2cd51698739564b0a2497697.data.unityweb',
    'Build/ac13e3edf380aabd3bd96a7afdf920cf.wasm.unityweb', 'Build/9c2f9c05ab665f705b18923d004c6593.framework.js.unityweb'];
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
