# MCSManager whitelist patch kit

Patch kit for `MCSManager 10.16.1 / Daemon 4.16.1`.

## Goal

- Add `whitelist.json` to the panel **服务端配置** list
- Render `whitelist.json` as an interactive table
- Keep production install as a single-command patch with backup and rollback

## Repo layout

- `src-overlay/`: source-level patch overlay applied onto upstream `MCSManager v10.16.1`
- `payload/v10.16.1/`: built production files copied by `scripts/package.sh`
- `scripts/install.sh`: production installer
- `scripts/rollback.sh`: rollback latest backup
- `scripts/healthcheck.sh`: patch verification

## Production install target

The installer auto-detects the MCSManager root from:

1. `systemctl cat mcsm-web.service`
2. `systemctl cat mcsm-daemon.service`
3. Common fallback directories such as `/opt/mcsmanager`

## Intended one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install.sh | bash
```

This installer bootstraps from the GitHub `main` branch tarball and applies the packaged payload in this repo.

## Build flow

1. Start from upstream `MCSManager v10.16.1`
2. Apply `src-overlay/`
3. Build upstream project
4. Run `scripts/package.sh`
5. Publish repo + release asset
