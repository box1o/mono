import type { ChangeEventHandler, KeyboardEventHandler } from "react";

type SearchInputProps = {
  value: string;
  onChange: ChangeEventHandler<HTMLInputElement>;
  onKeyDown?: KeyboardEventHandler<HTMLInputElement>;
};

export function SearchInput({ value, onChange, onKeyDown }: SearchInputProps) {
  return (
    <label className="flex h-16 items-center gap-4 border-b border-white/8 px-5">
      <svg
        aria-hidden="true"
        className="size-5 shrink-0 text-[var(--muted)]"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth="1.8"
      >
        <circle cx="11" cy="11" r="7" />
        <path strokeLinecap="round" d="m16.25 16.25 4 4" />
      </svg>
      <span className="sr-only">Search commands</span>
      <input
        autoFocus
        className="min-w-0 flex-1 bg-transparent text-lg text-[var(--foreground-strong)] outline-none placeholder:text-[var(--muted)]"
        placeholder="Search commands…"
        spellCheck={false}
        value={value}
        onChange={onChange}
        onKeyDown={onKeyDown}
      />
      <kbd className="rounded-md border border-white/10 bg-white/5 px-2 py-1 text-[10px] font-medium text-[var(--muted)]">
        ESC
      </kbd>
    </label>
  );
}
