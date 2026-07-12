# scripts

All scripts share the include layer in `scripts/lib`.

Runtime config lives in:

```text
~/.config/mono/mono.conf
~/.config/mono/<script>.conf
~/.config/mono/dcmd.json
```

Real machine-specific config stays local in `~/.config/mono` and is not stored in this repo.

## Device Flow

```bash
mgw.sh <device>
bridge.sh relay <device>
bridge.sh listen <device>
bridge.sh line full
```

## Project Commands

```bash
d-init.sh
d help
d command
```

## Deployment

Do not run setup while editing the scripts. After review:

```bash
./setup.sh --scripts --dry-run
./setup.sh --configs --dry-run
./setup.sh --scripts --replace
```
