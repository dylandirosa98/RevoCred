import { registerRootComponent } from 'expo';
import { SafeAreaView, Text, View } from "react-native";
import { ComponentType, createElement } from "react";

let AppRoot: ComponentType | null = null;
let startupError: unknown = null;

try {
  const appModule = require("./App") as { default?: ComponentType };
  AppRoot = appModule.default ?? null;
} catch (error) {
  startupError = error;
}

function StartupFallback() {
  const message = startupError instanceof Error ? startupError.message : String(startupError ?? "Unknown startup error");
  return createElement(
    SafeAreaView,
    { style: { flex: 1, backgroundColor: "#060B17" } },
    createElement(
      View,
      { style: { flex: 1, justifyContent: "center", paddingHorizontal: 24, gap: 12 } },
      createElement(Text, { style: { color: "#EEF3FF", fontSize: 26, fontWeight: "800" } }, "App failed to boot"),
      createElement(
        Text,
        { style: { color: "#9BA8CC", fontSize: 14, lineHeight: 20 } },
        "A startup exception happened before the main app mounted."
      ),
      createElement(Text, { style: { color: "#9BA8CC", fontSize: 14, lineHeight: 20 } }, message)
    )
  );
}

registerRootComponent(AppRoot ?? StartupFallback);
