import "react-native-url-polyfill/auto";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createClient } from "@supabase/supabase-js";

const runtimeEnv: Record<string, string | undefined> =
  typeof process !== "undefined" && process.env ? (process.env as Record<string, string | undefined>) : {};

const supabaseUrl = runtimeEnv.EXPO_PUBLIC_SUPABASE_URL ?? "https://jylwvumrzgihfndpurvq.supabase.co";
const supabaseAnonKey =
  runtimeEnv.EXPO_PUBLIC_SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp5bHd2dW1yemdpaGZuZHB1cnZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NjMyNzcsImV4cCI6MjA5MTQzOTI3N30.38v7y1y_tFRTAfEL4MPBdkS_gsAvOdRiylEhFlviyME";

const inMemoryStorage = new Map<string, string>();

const resilientStorage = {
  getItem: async (key: string): Promise<string | null> => {
    try {
      return await AsyncStorage.getItem(key);
    } catch {
      return inMemoryStorage.get(key) ?? null;
    }
  },
  setItem: async (key: string, value: string): Promise<void> => {
    try {
      await AsyncStorage.setItem(key, value);
    } catch {
      inMemoryStorage.set(key, value);
    }
  },
  removeItem: async (key: string): Promise<void> => {
    try {
      await AsyncStorage.removeItem(key);
    } catch {
      inMemoryStorage.delete(key);
    }
  },
};

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: resilientStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
