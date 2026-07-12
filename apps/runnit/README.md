# Runnit

Minimal React, TypeScript, Tailwind CSS, React Router, and Tauri application shell. It opens one empty, semi-transparent window centered on the primary monitor at 75% of that monitor's logical width and height.

```bash
npm ci
npm run desktop
```

The React source follows a small `src/main` and `src/shared` structure. The router has one `/` route, and `App` intentionally renders nothing. Production installation is handled from the Mono root:

```bash
./setup.sh --apps -y
```

## Configuration

Runnit creates `$XDG_CONFIG_HOME/runnit/config.yaml`, falling back to
`~/.config/runnit/config.yaml`, on its first launch. Set `RUNNIT_CONFIG` to use
an explicit file path. The current schema is:

```yaml
version: 1
window:
  size_ratio: 0.75
  always_on_top: true
  resizable: false
sandbox:
  enabled: true
  allow_network: false
  allow_process: false
  max_module_bytes: 16777216
  max_commands_per_extension: 128
```

Configuration is parsed into typed Rust values and validated before the window
is created. Unknown keys and unsupported schema versions are rejected so that
misspellings do not silently change behavior. Writes use a private temporary
file followed by an atomic rename; an invalid existing file is never replaced.

The webview has an explicit deny-by-default Tauri capability and a restrictive
Content Security Policy. Extension policy separately denies network and process
access by default, confines storage paths to an extension-owned directory, and
enforces module and command-count limits. This policy is the admission boundary
for extension code; Runnit does not execute third-party modules yet.

Create a feature only when it has real code to own:

```bash
npm run scaffold -- feature-name
```
