// web/firebase-messaging-sw.js
// Brikol.ma — FCM Service Worker for Web Push
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDlmEFN2NjlAIa-5LERz5PaYYCRGoj6_xE',
  authDomain: 'sallahapp-63361.firebaseapp.com',
  projectId: 'sallahapp-63361',
  storageBucket: 'sallahapp-63361.firebasestorage.app',
  messagingSenderId: '951073788486',
  appId: '1:951073788486:web:e82566b75dbfebdbadb047',
});

const messaging = firebase.messaging();

// ── Background push handler ──────────────────────────────────────
// كيشتغل لما الـ tab مغلق أو browser في background
messaging.onBackgroundMessage((payload) => {
  console.log('[SW] Background message:', payload.notification?.title);

  const title = payload.notification?.title || 'Brikol.ma';
  const body  = payload.notification?.body  || '';
  const data  = payload.data || {};

  // Icon حسب نوع الـ notification
  const icon = '/icons/Icon-192.png';
  const badge = '/icons/Icon-192.png';

  return self.registration.showNotification(title, {
    body,
    icon,
    badge,
    data,
    tag: data.requestId || data.type || 'brikol',
    requireInteraction: data.type === 'new_request', // تقني يشوفها حتى يضغط
    vibrate: [200, 100, 200],
    actions: data.type === 'new_request' ? [
      { action: 'view', title: 'Voir la demande' },
      { action: 'dismiss', title: 'Ignorer' },
    ] : [],
  });
});

// ── Notification click ───────────────────────────────────────────
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked:', event.action, event.notification.data);
  event.notification.close();

  if (event.action === 'dismiss') return;

  const data = event.notification.data || {};
  const urlToOpen = self.location.origin + '/?app=1';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      // إلا الـ app مفتوح — focus عليه
      for (const client of list) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // إلا مغلق — افتحو
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});

// ── Install & Activate ───────────────────────────────────────────
// skipWaiting باش ما يعملش reload لما يتحدث الـ SW
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));