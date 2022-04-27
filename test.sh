#!/bin/bash

set -x
set -e

die() {
    printf "%s\n" "$@"
    exit 1
}

do_cleanup() {

    pkill -F "/tmp/nm-dnsmasq-tt1-2.pid" dnsmasq &>/dev/null || :
    rm -rf "/tmp/nm-dnsmasq-tt1-2.pid"

    ip netns del test1 &>/dev/null || :
    nmcli connection delete t-br0 t-v t-net1 2>/dev/null || :

    ip link del br0 || :

    nm-env-prepare.sh cleanup
}

do_setup() {
    nm-env-prepare.sh setup

    ip -netns tt1 addr add 192.168.166.1/23 dev d_1
    ip netns exec "tt1" \
        dnsmasq \
            --conf-file=/dev/null \
            --pid-file="/tmp/nm-dnsmasq-tt1-2.pid" \
            --no-hosts \
            --keep-in-foreground \
            --bind-interfaces \
            --log-debug \
            --log-queries \
            --log-dhcp \
            --except-interface=lo \
            --clear-on-reload \
            --listen-address="192.168.166.1" \
            --dhcp-range="192.168.166.100,192.168.166.150" \
            &

    ip netns add test1
    ip -netns test1 link set lo up
    ip -netns test1 link add name v type veth peer w
    ip -netns test1 link set v up
    ip -netns test1 link set w up

    if [ "$CONFLICTS" != 0 ]; then
        for i in {100..150}; do
            ip -netns test1 addr add 192.168.121.$i/23 dev w
        done
    fi
    ip -netns test1 link set v netns $$

    nmcli connection add type ethernet autoconnect no con-name t-v slave-type bridge master br0 ifname v
    nmcli connection add type ethernet autoconnect no con-name t-net1 slave-type bridge master br0 ifname net1
    nmcli connection add type bridge autoconnect no con-name t-br0 connection.autoconnect-slaves yes ipv6.method disabled ipv4.method auto ifname br0 stp no \
        ipv4.dad-timeout 2000

    nmcli connection up t-br0
}

case "$1" in
    ""|setup)
        do_cleanup
        do_setup
        ;;
    cleanup)
        do_cleanup
        ;;
    *)
        die "Invalid command"
        ;;
esac
