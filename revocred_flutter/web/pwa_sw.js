// Minimal network-only PWA service worker for RevoCred.
//
// Intentional design:
// - Never writes Flutter bundles or HTML to CacheStorage, eliminating stale-app
//   updates across deploys (freshness is enforced via HTTP Cache-Control).
// - Clears any legacy flutter_service_worker.js caches on activation.
// - Omits a no-op fetch listener to avoid Chromium navigation overhead and
//   console warnings while keeping PWA registration healthy.

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    if ('caches' in self) {
      const names = await caches.keys();
      await Promise.all(names.map((name) => caches.delete(name)));
    }
    await self.clients.claim();
  })());
});
