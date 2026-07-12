import { useMemo, useState } from "react";

import { SearchInput } from "../../shared/components";
import { PALETTE_COMMANDS } from "./palette.constants";

export function Palette() {
  const [query, setQuery] = useState("");

  const commands = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    if (!normalized) return PALETTE_COMMANDS;
    return PALETTE_COMMANDS.filter(({ title, description }) =>
      `${title} ${description}`.toLocaleLowerCase().includes(normalized),
    );
  }, [query]);

  return (
    <main className="flex h-full w-full items-start justify-center p-[6vh]">
      <section
        aria-label="Command palette"
        className="w-full max-w-3xl overflow-hidden rounded-2xl border border-white/10 bg-[color:var(--panel)] shadow-2xl shadow-black/35 backdrop-blur-2xl"
      >
        <SearchInput
          value={query}
          onChange={(event) => setQuery(event.currentTarget.value)}
          onKeyDown={(event) => {
            if (event.key === "Escape") setQuery("");
          }}
        />
        <div className="max-h-72 overflow-y-auto p-2">
          <p className="px-3 pb-2 pt-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">
            Commands
          </p>
          {commands.length ? (
            <ul className="space-y-1">
              {commands.map((command, index) => (
                <li key={command.id}>
                  <button
                    className="group flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left outline-none transition hover:bg-white/6 focus-visible:bg-white/8 focus-visible:ring-1 focus-visible:ring-[var(--accent)]"
                    type="button"
                  >
                    <span className="grid size-9 shrink-0 place-items-center rounded-lg border border-white/8 bg-white/4 text-sm text-[var(--accent)]">
                      {index + 1}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block text-sm font-medium text-[var(--foreground-strong)]">
                        {command.title}
                      </span>
                      <span className="block truncate text-xs text-[var(--muted)]">
                        {command.description}
                      </span>
                    </span>
                    {command.shortcut && (
                      <kbd className="rounded border border-white/8 bg-black/10 px-2 py-1 text-[10px] text-[var(--muted)]">
                        {command.shortcut}
                      </kbd>
                    )}
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-3 py-10 text-center text-sm text-[var(--muted)]">
              No commands found
            </p>
          )}
        </div>
      </section>
    </main>
  );
}
