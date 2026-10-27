# Server inventory (T0.1)

Read on 2026-10-27 over `ssh oracle`, with read-only commands. Nothing was changed.

## The machine

- Ubuntu 24.04, aarch64, 4 CPUs, 23 GiB memory (1.2 GiB used), no swap.
- Disk: 96 GB, 30 GB used, 67 GB free. `/var/lib/docker` 15 GB, `/var/log/journal` 4 GB, `/home` 5 GB.
- `sudo` needs no password for the `ubuntu` user.

## What runs

| What | Listens on | Conflicts with the playbook? |
|---|---|---|
| sshd | 0.0.0.0:22 | No |
| T3 Code server (`~/.t3`, user `ubuntu`) | 127.0.0.1:3773 | No |
| Syncthing | 22000 tcp and udp, 21027 udp, 127.0.0.1:8384 | No |
| systemd-resolved | 127.0.0.53:53 | No |
| Oracle Cloud Agent, unified monitoring agent | none | No |

**Ports 80, 443 and 8448 are free.**

## Docker

- Installed (29.9.1), but `docker`, `docker.socket` and `containerd` are **disabled and
  stopped** since 2026-10-21. The playbook needs Docker running and enabled.
- No containers are left. Old data from earlier stacks (n8n, Caddy, Postiz) is still in
  `/var/lib/docker`:
  - Images, 13 GB: `caddy`, `n8nio/n8n` (two copies), `n8n-caddy`, `spotlight`,
    `postiz-app`, `postgres:16`, `postgres:17-alpine`, `redis:6-alpine`, `redis:7.2`.
  - Volumes, 294 MB: `caddy_data`, `db_storage`, `n8n_caddy_config`, `n8n_caddy_data`,
    `n8n_data`, `n8n_db_storage`, `n8n_n8n_storage`, `n8n_redis_storage`,
    `postiz_postgres-volume`, `postiz_postiz-config`, `postiz_postiz-redis-data`,
    `postiz_postiz-uploads`.
- None of this conflicts with the playbook: its containers have other names, and nothing
  holds ports 80 or 443.

## Firewall on the host

- `iptables -S INPUT` shows only the ACCEPT policy, but the nftables ruleset has rules,
  and `/etc/iptables/rules.v4` has 4 REJECT lines (Oracle's Ubuntu image blocks every
  port except 22). T0.4 must open 80, 443 and 8448 here and in Oracle's security list.
- **Correction (2026-10-27, T0.3, read only):** nothing loads `rules.v4`.
  `iptables-persistent` was removed on 2025-08-11 (`dpkg -l`: `rc`), so
  `/usr/share/netfilter-persistent/plugins.d/` is empty and the boot service loads no
  rules. The live `INPUT` chain is empty with policy ACCEPT; the nftables rules are only
  Docker's `FORWARD` and `nat` chains. So the host blocks no port, and T0.4 needs no host
  change. From the Mac, TCP 80 and 443 answer "connection refused" (they pass Oracle's
  security list); TCP 8448 times out (the security list blocks it). `rules.v4` still holds
  old n8n rules (port 5678); it is left as is.

## For Rami to decide

1. The old n8n and Postiz volumes (294 MB) may hold workflows or uploads. Keep them, or delete them?
2. The old images (13 GB) are not needed by the playbook. Delete them to free space, or keep them?
3. Is it fine that the playbook turns Docker back on, and keeps it on at boot?
