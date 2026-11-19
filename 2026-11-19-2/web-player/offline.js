const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + '9c841c847e034f6afc6ff541a68f3745.data.unityweb-1c2a6662397e1db7d90fcba9ed932440.wasm.unityweb';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/d9bc50b2d2c97d4ff723d56c213c0fd8.loader.js', 'Build/9c841c847e034f6afc6ff541a68f3745.data.unityweb',
    'Build/1c2a6662397e1db7d90fcba9ed932440.wasm.unityweb', 'Build/81eea8a6d4be6bfb234333cf63e96d8c.framework.js.unityweb'];
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
