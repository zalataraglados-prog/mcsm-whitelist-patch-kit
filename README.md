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
- `scripts/install.ps1`: Windows production installer
- `scripts/rollback.sh`: rollback latest backup
- `scripts/rollback.ps1`: Windows rollback latest backup
- `scripts/healthcheck.sh`: patch verification
- `scripts/healthcheck.ps1`: Windows patch verification

## Production install target

The installer auto-detects the MCSManager root from:

1. `systemctl cat mcsm-web.service`
2. `systemctl cat mcsm-daemon.service`
3. Common fallback directories such as `/opt/mcsmanager`

## Intended one-liners

Linux panel host:
```bash
curl -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install.sh | bash
```

Windows panel host:

```powershell
curl.exe -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install.ps1 | powershell -NoProfile -ExecutionPolicy Bypass -Command -
```

Both installers bootstrap from the GitHub `main` branch and apply the packaged payload in this repo.

## Daemon-only one-liner

For remote game nodes where you only want the patched daemon.

Linux game node:
```bash
curl -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install-daemon.sh | bash
```

Windows game node:

```powershell
curl.exe -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install-daemon.ps1 | powershell -NoProfile -ExecutionPolicy Bypass -Command -
```

## Build flow

1. Start from upstream `MCSManager v10.16.1`
2. Apply `src-overlay/`
3. Build upstream project
4. Run `scripts/package.sh`
5. Publish repo + release asset
