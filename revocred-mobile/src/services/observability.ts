import * as Sentry from "@sentry/react-native";
import { JsonType } from "@posthog/core";
import PostHog from "posthog-react-native";

type EventProps = Record<string, JsonType | undefined>;

const sentryDsn = process.env.EXPO_PUBLIC_SENTRY_DSN;
const posthogApiKey = process.env.EXPO_PUBLIC_POSTHOG_API_KEY;
const posthogHost = process.env.EXPO_PUBLIC_POSTHOG_HOST ?? "https://us.i.posthog.com";
const appEnv = process.env.EXPO_PUBLIC_APP_ENV ?? (__DEV__ ? "development" : "production");

let isInitialized = false;
let posthog: PostHog | null = null;
const sentryEnabled = Boolean(sentryDsn);

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
    Sentry.init({
      dsn: sentryDsn,
      environment: appEnv,
      tracesSampleRate: 0.2,
      enableNativeFramesTracking: true,
    });
  }

  if (posthogApiKey) {
    posthog = new PostHog(posthogApiKey, {
      host: posthogHost,
      captureAppLifecycleEvents: true,
    });
    void posthog.register({
      app_env: appEnv,
    });
  }
}

export function identifyUser(distinctId: string, email?: string | null): void {
  initializeObservability();
  if (sentryEnabled) {
    Sentry.setUser({
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
  if (sentryEnabled) {
    Sentry.setUser(null);
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
  if (sentryEnabled) {
    Sentry.captureException(error, {
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
