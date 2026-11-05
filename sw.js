/* Freelio: viser push-varsler om nye tilbud og nye meldinger (se supabase/functions/varsle).
   Den mellomlagrer ingenting, så nettsiden lastes og oppdateres akkurat som før. */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (x) { d = { body: e.data ? e.data.text() : '' }; }
  const scope = self.registration.scope;
  // Lenken i varselet går alltid til Freelio
  const url = typeof d.url === 'string' && d.url.startsWith(scope) ? d.url : scope;
  e.waitUntil(self.registration.showNotification(d.title || 'Freelio', {
    body: d.body || '',
    icon: 'img/ikon-192.png',
    badge: 'img/varsel-badge.png',
    tag: d.tag || undefined,
    renotify: !!d.tag,
    lang: 'nb',
    data: { url }
  }));
});

// Trykk på varselet: åpne siden det gjelder, i en fane som allerede er åpen hvis det finnes en
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || self.registration.scope;
  e.waitUntil((async () => {
    const list = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of list) {
      if (!c.url.startsWith(self.registration.scope)) continue;
      try { await c.focus(); if ('navigate' in c) await c.navigate(url); return; } catch (x) {}
    }
    await self.clients.openWindow(url);
  })());
});
