const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + 'fe2ed7d6ea6811e39e525ca3bcff3c26.data.unityweb-fe02e291bc1d8283efd73ddf2c9c68ae.wasm.unityweb';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/c20f18e83cf0e105d4c0f9b1e620e9fc.loader.js', 'Build/fe2ed7d6ea6811e39e525ca3bcff3c26.data.unityweb',
    'Build/fe02e291bc1d8283efd73ddf2c9c68ae.wasm.unityweb', 'Build/ddca46f8fe3e16cb5d1886c079d4b56b.framework.js.unityweb'];
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
