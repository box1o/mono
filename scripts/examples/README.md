# adb-tunnel mock (mono examples)

Log-only copy of `repo/ug/adb-tunnel/d.bl.sh` for testing `d` in mono.  
**No ssh, adb, curl, or network.** Every command prints `[MOCK] …` instead of running.

## Try it

```bash
cd ~/mono/scripts/examples

d help
d list_mgw
d set_target_mgw MGW-3
d show_target_mgw
d tunnel_start
d tunnel_status
d adb_status
d clean_mock

# Tab completion
d <Tab>         # complete gblcmd_* names (bash/zsh)
d help          # list all commands
```

After updating mono, reload shell config (fixes `bash: \t: command not found`):

```bash
source ~/.bashrc    # or: source ~/.shellrc
```


## Commands (same names as real adb-tunnel)

| Command | Mock behaviour |
| --- | --- |
| `list_mgw` | Prints MGW table (fake IPs/ports) |
| `set_target_mgw` | Writes `.example_mgw_target` only |
| `show_target_mgw` | Reads mock target file |
| `check_target` | Logs ssh/nc command |
| `tunnel_start` / `stop` / `status` / `restart` | Logs ssh/adb; fake PID in `.example_adb_tunnel.pid` |
| `adb_*` | Logs what adb would run; fake output where needed |
| `adb_wait` | Logs poll steps; **does not** loop or wait |
| `clean_mock` | Deletes `.example_*` state files |

## Header (matches real repo scripts)

Real FMC scripts use GBashLib-style headers unchanged:

```bash
. $(gbl log)
. $(gbl d_lib docs)
error_trap
```

Mono `d` provides stubs for `gbl log`, `gbl d_lib docs`, and `error_trap` via `d-log.lib.sh` / `d-stub.lib.sh`.

## Real repo

Use the real `d.bl.sh` in your ugw repo for production. Do not commit mock state:

```gitignore
.example_mgw_target
.example_adb_tunnel.pid
```
