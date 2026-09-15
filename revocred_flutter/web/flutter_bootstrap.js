{{flutter_js}}
{{flutter_build_config}}

function showStartupError(error) {
  console.error('RevoCred failed to start:', error);

  const loader = document.getElementById('app-loader');
  const message = document.getElementById('app-loader-message');
  if (!loader || !message) {
    return;
  }

  loader.classList.add('app-loader--failed');
  message.textContent = 'The preview could not start in this browser. Reload the page to try again.';
}

window.addEventListener('flutter-first-frame', () => {
  document.getElementById('app-loader')?.remove();
}, { once: true });

window.addEventListener('error', (event) => {
  if (event.target instanceof HTMLScriptElement) {
    showStartupError(event.error ?? new Error(`Could not load ${event.target.src}`));
  }
}, true);

window.addEventListener('unhandledrejection', (event) => {
  showStartupError(event.reason);
});

(async () => {
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.map((registration) => registration.unregister()));
    }

    if ('caches' in window) {
      const cacheNames = await caches.keys();
      await Promise.all(cacheNames.map((cacheName) => caches.delete(cacheName)));
    }
  } catch (error) {
    console.warn('Could not clear legacy Flutter caches:', error);
  }

  try {
    await _flutter.loader.load({
      onEntrypointLoaded: async (engineInitializer) => {
        try {
          const appRunner = await engineInitializer.initializeEngine();
          await appRunner.runApp();
        } catch (error) {
          showStartupError(error);
        }
      },
    });
  } catch (error) {
    showStartupError(error);
  }
})();
