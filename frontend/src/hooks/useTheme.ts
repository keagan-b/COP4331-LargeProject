import { useState, useEffect, useCallback } from "react";

export type Theme = "default" | "tropical";

const STORAGE_KEY = "app-theme";

export function useTheme(): [Theme, (t: Theme) => void] {
  const [theme, setThemeState] = useState<Theme>(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored === "tropical" ? "tropical" : "default";
  });

  // Keep document attribute in sync so CSS :root overrides work globally
  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  const setTheme = useCallback((t: Theme) => {
    localStorage.setItem(STORAGE_KEY, t);
    setThemeState(t);
    document.documentElement.setAttribute("data-theme", t);
  }, []);

  return [theme, setTheme];
}
