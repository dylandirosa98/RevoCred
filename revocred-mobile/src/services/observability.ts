type JsonType = string | number | boolean | null | JsonType[] | { [key: string]: JsonType };
type SentryUser = { id?: string; email?: string } | null;
type SentryLike = {
  init: (options: Record<string, unknown>) => void;
  setUser: (user: SentryUser) => void;
  captureException: (error: unknown, context?: Record<string, unknown>) => void;
};
type PostHogLike = {
  register: (properties: Record<string, JsonType>) => Promise<void>;
  identify: (distinctId: string, properties?: Record<string, JsonType>) => Promise<void>;
  reset: () => void;
  capture: (event: string, properties?: Record<string, JsonType>) => Promise<void>;
};

type EventProps = Record<string, JsonType | undefined>;

const sentryDsn = process.env.EXPO_PUBLIC_SENTRY_DSN;
const posthogApiKey = process.env.EXPO_PUBLIC_POSTHOG_API_KEY;
const posthogHost = process.env.EXPO_PUBLIC_POSTHOG_HOST ?? "https://us.i.posthog.com";
const appEnv = process.env.EXPO_PUBLIC_APP_ENV ?? (__DEV__ ? "development" : "production");

let isInitialized = false;
let posthog: PostHogLike | null = null;
let sentry: SentryLike | null = null;
let sentryEnabled = Boolean(sentryDsn);

function loadSentry(): SentryLike | null {
  try {
    // Lazy require prevents Expo Go startup crashes when the native SDK is unavailable.
    const sentryModule = require("@sentry/react-native") as SentryLike;
    return sentryModule;
  } catch {
    return null;
  }
}

function loadPostHogCtor():
  | (new (apiKey: string, options?: { host?: string; captureAppLifecycleEvents?: boolean }) => PostHogLike)
  | null {
  try {
    const posthogModule = require("posthog-react-native");
    const ctor = (posthogModule?.default ?? posthogModule) as new (
      apiKey: string,
      options?: { host?: string; captureAppLifecycleEvents?: boolean },
    ) => PostHogLike;
    return ctor;
  } catch {
    return null;
  }
}

function sanitizeProperties(properties?: EventProps): Record<string, JsonType> | undefined {
  if (!properties) {
    return undefined;
  }

  const cleanEntries = Object.entries(properties).filter(([, value]) => value !== undefined) as Array<[string, JsonType]>;
  if (!cleanEntries.length) {
    return undefined;
  }

  return Object.fromEntries(cleanEntries);
}

export function initializeObservability(): void {
  if (isInitialized) {
    return;
  }
  isInitialized = true;

  if (sentryEnabled) {
    sentry = loadSentry();
    if (sentry) {
      try {
        sentry.init({
          dsn: sentryDsn,
          environment: appEnv,
          tracesSampleRate: 0.2,
          enableNativeFramesTracking: true,
        });
      } catch {
        // Expo Go can fail native SDK init on some devices; keep app booting.
        sentryEnabled = false;
        sentry = null;
      }
    } else {
      sentryEnabled = false;
    }
  }

  if (posthogApiKey) {
    const PostHogCtor = loadPostHogCtor();
    if (!PostHogCtor) {
      posthog = null;
      return;
    }
    try {
      posthog = new PostHogCtor(posthogApiKey, {
        host: posthogHost,
        captureAppLifecycleEvents: true,
      });
      void posthog.register({
        app_env: appEnv,
      });
    } catch {
      // Never block app startup if analytics init fails in Expo Go.
      posthog = null;
    }
  }
}

export function identifyUser(distinctId: string, email?: string | null): void {
  initializeObservability();
  if (sentryEnabled && sentry) {
    sentry.setUser({
      id: distinctId,
      email: email ?? undefined,
    });
  }
  if (!posthog) {
    return;
  }
  void posthog.identify(distinctId, email ? { email } : undefined);
}

export function resetUserIdentity(): void {
  initializeObservability();
  if (sentryEnabled && sentry) {
    sentry.setUser(null);
  }
  if (!posthog) {
    return;
  }
  posthog.reset();
}

export function trackEvent(event: string, properties?: EventProps): void {
  initializeObservability();
  if (!posthog) {
    return;
  }
  void posthog.capture(event, sanitizeProperties(properties));
}

export function trackScreen(screenName: string): void {
  trackEvent("screen_viewed", { screen: screenName });
}

export function trackScreenView(screenName: string): void {
  trackScreen(screenName);
}

export function captureException(error: unknown, metadata?: EventProps): void {
  initializeObservability();
  const message = error instanceof Error ? error.message : String(error);
  const contextValue = metadata?.context;
  const context = typeof contextValue === "string" ? contextValue : undefined;
  const sanitizedMetadata = sanitizeProperties(metadata);
  if (sentryEnabled && sentry) {
    sentry.captureException(error, {
      tags: context ? { context } : undefined,
      extra: sanitizedMetadata,
    });
  }

  trackEvent("app_error", {
    context: context ?? "unknown",
    message,
    ...sanitizedMetadata,
  });
}

export function captureError(error: unknown, context?: string, metadata?: EventProps): void {
  captureException(error, {
    context,
    ...metadata,
  });
}
