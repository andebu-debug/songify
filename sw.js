// Songify – gjør at appen kan åpnes uten nett.
// Musikk du har lagret offline ligger i et eget lager ("songify-offline") og røres ikke her.
const C = 'songify-app-v15';
const SHELL = ['/', '/config.js', '/manifest.json', '/icon-192.png', '/icon-512.png',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(C).then(c => Promise.all(SHELL.map(u => c.add(u).catch(() => {})))));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k.startsWith('songify-app') && k !== C).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const r = e.request;
  if (r.method !== 'GET') return;
  const u = new URL(r.url);
  if (u.hostname.endsWith('supabase.co')) return;        // låter og data: alltid fra nett
  if (u.hostname.includes('unpkg.com')) return;           // WMA-omgjøring: bare med nett
  const same = u.origin === location.origin;

  // Selve appen: prøv nett først (så du alltid får nyeste versjon), ellers lagret kopi
  if (r.mode === 'navigate' || (same && /\.(html|js|json)$/.test(u.pathname))) {
    const key = r.mode === 'navigate' ? '/' : r;
    e.respondWith(fetch(r).then(res => {
      if (res.ok) { const cp = res.clone(); caches.open(C).then(c => c.put(key, cp)); }
      return res;
    }).catch(() => caches.match(key)));
    return;
  }

  // Ikoner, skrift og Supabase-biblioteket: lagret kopi først
  if (same || u.hostname.includes('jsdelivr') || u.hostname.includes('fonts.g')) {
    e.respondWith(caches.match(r).then(m => m || fetch(r).then(res => {
      if (res.ok || res.type === 'opaque') { const cp = res.clone(); caches.open(C).then(c => c.put(r, cp)); }
      return res;
    })));
  }
});
