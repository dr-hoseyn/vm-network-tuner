# vm-network-tuner

Network optimization script for tunnel VMs — tunes sysctl buffers, connection
backlog, conntrack, and enables BBR congestion control where available.
Tailored for reverse-tunnel engines (e.g. [Backhaul via
tunnel-manager](https://github.com/dr-hoseyn/tunnel-manager)) that hold many
concurrent connections: it widens capacity rather than narrowing it, and
auto-detects ports already in use so they're excluded from the ephemeral
range instead of colliding with it.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/dr-hoseyn/vm-network-tuner/master/tunnel-vm-tune.sh | sudo bash
```

Or clone and run manually:

```bash
git clone https://github.com/dr-hoseyn/vm-network-tuner.git
cd vm-network-tuner
sudo bash tunnel-vm-tune.sh
```

Re-run any time after adding a new tunnel/port, so the reserved-port list
stays current.

## What it does

- Applies buffer, backlog, and connection-capacity sysctls tuned for high
  concurrent-connection tunnel workloads.
- Enables BBR + `fq` where the kernel supports it, and persists the module
  load across reboots (`/etc/modules-load.d`) instead of only enabling it for
  the current boot.
- Applies `fq` to already-up interfaces immediately via `tc qdisc replace`,
  since `net.core.default_qdisc` alone only affects newly-created interfaces.
- Tunes connection tracking (`nf_conntrack_max`/hashsize) when the
  kernel/namespace exposes it, and tolerates containers (OpenVZ/LXC) where it
  doesn't, via `sysctl -e`.
- Detects ports already in `LISTEN` state and adds them to
  `net.ipv4.ip_local_reserved_ports`, so the (deliberately wide) ephemeral
  port range never gets handed out as an outgoing port that collides with a
  tunnel's own bind port.
- Raises `rmem_default`/`wmem_default` in addition to the `_max` ceiling, and
  adds a systemd `DefaultLimitNOFILE` drop-in for services other than
  tunnel-manager (whose own Backhaul units already set `LimitNOFILE`
  themselves).
- Adds TCP keepalive tuning for long-lived tunnel connections, `tcp_fastopen`,
  and `tcp_no_metrics_save`.

## Rollback

Every run generates a rollback script:

```bash
sudo bash /root/tunnel-vm-tune-rollback.sh
```

A backup of prior sysctl settings is saved to `/root/sysctl-backup-<date>-<pid>.txt`
before any changes are applied.

## Notes if you're running Backhaul (tunnel-manager)

- `so_rcvbuf`/`so_sndbuf` in your Backhaul TOML config are capped by
  `net.core.rmem_max`/`wmem_max`. This script raises that ceiling to 64MB, so
  values like `so_rcvbuf=4194304` in your tunnel config will actually take
  effect instead of being silently clamped down.
- If a tunnel uses TUN mode with `ipx` encapsulation (gre/ipip/icmp/...), set
  `mss` explicitly in that tunnel's config (e.g. 1200–1360) — `tcp_mtu_probing`
  alone doesn't fully cover the extra encapsulation overhead.
