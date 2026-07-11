# vm-network-tuner

Network optimization script for tunnel VMs — tunes sysctl buffers, connection
backlog, and enables BBR congestion control where available.

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

## Rollback

```bash
rm /etc/sysctl.d/99-tunnel-vm.conf && sysctl --system
```

A backup of prior sysctl settings is saved to `/root/sysctl-backup-<date>.txt`
before any changes are applied.
