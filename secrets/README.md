# Encrypted Secrets

This directory stores private home files as a passphrase-encrypted `age`
archive that is safe to commit publicly:

```text
configs/secret.tar.gz.age
```

The archive is built from home-relative paths listed in `include.list`.
Current defaults:

## Commands

```bash
scripts/secrets.sh pack
scripts/secrets.sh list
scripts/secrets.sh restore
scripts/secrets.sh verify
```

`pack` asks for a strong passphrase and writes only the encrypted archive.
`restore` asks for the passphrase, decrypts into a temporary staging directory,
then copies files back to `$HOME` and asks before replacing existing files.

Keep the passphrase outside Git, preferably in a password manager.
