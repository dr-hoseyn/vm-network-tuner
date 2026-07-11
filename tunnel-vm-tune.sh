#!/bin/bash
# tunnel-vm-tune.sh — Network optimization for tunnel VMs
# Usage: bash tunnel-vm-tune.sh
# Rollback: rm /etc/sysctl.d/99-tunnel-vm.conf && sysctl --system

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root."
    exit 1
fi

echo "=== [1/5] Backing up current settings ==="
sysctl -a > /root/sysctl-backup-$(date +%F-%H%M).txt 2>/dev/null
cp -n /etc/security/limits.conf /root/limits.conf.bak 2>/dev/null || true
echo "Backup saved to /root/"

echo "=== [2/5] Checking BBR support ==="
if ! sysctl net.ipv4.tcp_available_congestion_control | grep -q bbr; then
    modprobe tcp_bbr 2>/dev/null || true
fi
if sysctl net.ipv4.tcp_available_congestion_control | grep -q bbr; then
    echo "BBR is available ✓"
    BBR_OK=1
else
    echo "Warning: BBR not available in this kernel — applying buffer tuning only"
    BBR_OK=0
fi

echo "=== [3/5] Applying sysctl settings ==="
cat > /etc/sysctl.d/99-tunnel-vm.conf << 'EOF'
# --- Network buffers ---
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.core.netdev_max_backlog = 30000
# --- Connection capacity ---
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
# --- Misc improvements ---
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
EOF

if [ "$BBR_OK" = "1" ]; then
cat >> /etc/sysctl.d/99-tunnel-vm.conf << 'EOF'
# --- BBR ---
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
fi

sysctl -p /etc/sysctl.d/99-tunnel-vm.conf > /dev/null
echo "Sysctl settings applied ✓"

echo "=== [4/5] Raising open-file limits ==="
if ! grep -q "tunnel-vm-tune" /etc/security/limits.conf; then
cat >> /etc/security/limits.conf << 'EOF'
# tunnel-vm-tune
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
fi
echo "limits.conf updated ✓"

echo "=== [5/5] Final verification ==="
echo "--------------------------------"
echo "Congestion Control: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "Qdisc:              $(sysctl -n net.core.default_qdisc)"
echo "Backlog:            $(sysctl -n net.core.netdev_max_backlog)"
echo "somaxconn:          $(sysctl -n net.core.somaxconn)"
echo "--------------------------------"
echo "Done. Sysctl settings are active now."
echo "Note: new file limits apply after restarting your tunnel service or re-login."
