{{flutter_js}}
{{flutter_build_config}}

(() => {
  let deferredInstallPrompt = null;

  function isStandaloneMode() {
    return (
      window.matchMedia?.('(display-mode: standalone)')?.matches === true ||
      window.navigator.standalone === true
    );
  }

  function isIosBrowser() {
    const ua = window.navigator.userAgent || '';
    const isIosUa = /iPad|iPhone|iPod/.test(ua);
    const isIpadOs =
      window.navigator.platform === 'MacIntel' &&
      (window.navigator.maxTouchPoints || 0) > 1;
    return isIosUa || isIpadOs;
  }

  function isMobileBrowser() {
    const ua = window.navigator.userAgent || '';
    const mobileUa = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(ua);
    const coarsePointer = window.matchMedia?.('(pointer: coarse)')?.matches === true;
    const narrowViewport = Math.min(window.innerWidth || 0, window.screen?.width || 0) <= 900;
    return mobileUa || isIosBrowser() || (coarsePointer && narrowViewport);
  }

  function readSafeAreaInsets() {
    const probe = document.getElementById('rc-safe-area-probe');
    if (!probe) {
      return { top: 0, right: 0, bottom: 0, left: 0 };
    }
    const style = window.getComputedStyle(probe);
    const px = (value) => {
      const parsed = parseFloat(value);
      return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
    };
    return {
      top: px(style.paddingTop),
      right: px(style.paddingRight),
      bottom: px(style.paddingBottom),
      left: px(style.paddingLeft),
    };
  }

  function notifyPwaState() {
    window.dispatchEvent(new CustomEvent('revocred-pwa-change'));
  }

  window.__revocredPwa = {
    canPrompt: () => deferredInstallPrompt !== null,
    isStandalone: isStandaloneMode,
    isMobileBrowser,
    isIos: isIosBrowser,
    safeAreaInsets: readSafeAreaInsets,
    promptInstall: async () => {
      if (!deferredInstallPrompt) {
        return 'unavailable';
      }
      const promptEvent = deferredInstallPrompt;
      deferredInstallPrompt = null;
      notifyPwaState();
      try {
        await promptEvent.prompt();
        const choice = await promptEvent.userChoice;
        return choice?.outcome === 'accepted' ? 'accepted' : 'dismissed';
      } catch (_) {
        return 'dismissed';
      }
    },
  };

  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    deferredInstallPrompt = event;
    notifyPwaState();
  });

  window.addEventListener('appinstalled', () => {
    deferredInstallPrompt = null;
    notifyPwaState();
  });

  window.addEventListener('resize', notifyPwaState, { passive: true });
  window.addEventListener('orientationchange', notifyPwaState, { passive: true });
  window.visualViewport?.addEventListener('resize', notifyPwaState, { passive: true });
})();

function showStartupError(error) {
  console.error('RevoCred failed to start:', error);

  const loader = document.getElementById('app-loader');
  const message = document.getElementById('app-loader-message');
  if (!loader || !message) {
    return;
  }

  loader.classList.add('app-loader--failed');
  message.textContent = 'RevoCred could not start in this browser. Reload the page to try again.';
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

async function maintainPwaServiceWorker() {
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(
        registrations.map((registration) => {
          const scriptUrl =
            registration.active?.scriptURL ||
            registration.waiting?.scriptURL ||
            registration.installing?.scriptURL ||
            '';
          // Unregister any legacy flutter_service_worker.js so stale bundles
          // are never served, while keeping our network-only /pwa_sw.js intact.
          if (scriptUrl.endsWith('/pwa_sw.js')) {
            return Promise.resolve();
          }
          return registration.unregister();
        }),
      );
    }

    if ('caches' in window) {
      const cacheNames = await caches.keys();
      await Promise.all(cacheNames.map((cacheName) => caches.delete(cacheName)));
    }

    if ('serviceWorker' in navigator && window.isSecureContext) {
      await navigator.serviceWorker.register('pwa_sw.js', {
        updateViaCache: 'none',
      });
    }
  } catch (error) {
    console.warn('Could not update PWA service worker:', error);
  }
}

(async () => {
  void maintainPwaServiceWorker();

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
