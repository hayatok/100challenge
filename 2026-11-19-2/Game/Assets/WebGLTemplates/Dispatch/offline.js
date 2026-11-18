const prefix = 'evacuation-control-' + new URL(self.registration.scope).pathname + '-';
const version = prefix + '{{{ DATA_FILENAME }}}-{{{ CODE_FILENAME }}}';
const assets = ['index.html','game.webmanifest','train-192.png','train-512.png','Build/{{{ LOADER_FILENAME }}}', 'Build/{{{ DATA_FILENAME }}}',
    'Build/{{{ CODE_FILENAME }}}', 'Build/{{{ FRAMEWORK_FILENAME }}}'];
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
