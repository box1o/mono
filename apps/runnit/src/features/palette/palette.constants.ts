import type { PaletteCommand } from "./palette.types";

export const PALETTE_COMMANDS: readonly PaletteCommand[] = [
  {
    id: "runnit.settings",
    title: "Open Settings",
    description: "Configure Runnit and its integrations",
    shortcut: "Ctrl ,",
  },
  {
    id: "runnit.extensions",
    title: "Manage Extensions",
    description: "Review installed extensions and permissions",
  },
  {
    id: "runnit.doctor",
    title: "Run Diagnostics",
    description: "Check desktop integration and sandbox status",
  },
];
