#!/bin/ash

# see https://stackoverflow.com/a/18622662/1834100
set -eu

alias mkdir='mkdir -p'

# internal constants
export C_DATA="/data"
export C_CONTAINER_NAME="container"
export C_ROOTFS="$C_DATA/$C_CONTAINER_NAME/rootfs"
export C_SETUP_COMPLETE="$C_DATA/.setup_complete"
export C_USER="lxcuser"
export C_MAC=$(echo $HOSTNAME|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
export C_HOSTNAME=$(cat /etc/hostname)


# lxc container will take over out network config, so we need to extract current config
export HOST_IP_CIDR="$(ip -o -4 addr list eth0 | awk '{print $4}')"
export HOST_IP="$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d'/' -f1)"
export HOST_GATEWAY="$(ip route | awk '/default/ { print $3 }')"
export HOST_NAMESERVER="$(cat /etc/resolv.conf | grep nameserver | cut -d' ' -f2 | paste -sd ',')"
cidr=$(echo $HOST_IP_CIDR | cut -d'/' -f2)

# (https://gist.github.com/kwilczynski/5d37e1cced7e76c7c9ccfdf875ba6c5b)
bits=$(( 0xffffffff ^ ((1 << (32 - $cidr)) - 1) ))
export HOST_NETMASK=$(( (bits >> 24) & 0xff )).$(( (bits >> 16) & 0xff )).$(( (bits >> 8) & 0xff )).$(( bits & 0xff ))

# write static network for container. this files is included by each container start
envsubst < /templates/lxc-network > "/lxc-network.conf"

# initial setup is done by checking if lxc container exists
if [[ ! -f "$C_SETUP_COMPLETE" ]]; then
	echo "First run detected, setting up container"
	
	envsubst < /templates/lxc-config > "/etc/lxc/default.conf"
	
	mkdir "$C_ROOTFS"
	lxc-create \
		-f "/etc/lxc/default.conf" \
		-P "$C_DATA" \
		-t download \
		-n "$C_CONTAINER_NAME" -- \
		-d "$DIST_NAME" \
		-r "$DIST_FLAVOUR" \
		-a ${DIST_ARCH:-amd64}
	
	# container templates push random config settings that may break setup, so we override it
	envsubst < /templates/lxc-config > "$C_DATA/$C_CONTAINER_NAME/config"
	
	echo "Initial setup complete, future executions will skip this step"
	touch "$C_SETUP_COMPLETE"
fi

# resolv.conf is overriden by docker each start to reflect changes on host
if [[ ${OVERRIDE_RESOLV:-true} == "true" ]]; then

	# resolvd is managing /etc/resolv.conf on some systems with a symlink, removing it changes that
	if [[ ! -f "$C_ROOTFS/etc/resolv.conf" ]]; then
		mkdir "$C_ROOTFS/etc/"
		rm -f "$C_ROOTFS/etc/resolv.conf"
	fi
	cat "/etc/resolv.conf" > "$C_ROOTFS/etc/resolv.conf"
fi

# in order to play nicely with the surround docker daemon, we need to properly setup the network stack
# the most easiest way to accomplish that is to simply drop our our own network config and let the lxc container impersonate us
echo "Setup container network"

#	1. after we have captured the current network config, we drop it from our own interface, effectively rendering us unreachable
ip addr flush dev eth0

#	2. we then create a new bridge for lxc to attach to and link it with our own interface (which in turn allows the container to reach docker)
brctl addbr br0
brctl addif br0 eth0
ip link set br0 up

# registering trap for sigterm handling
function sigterm() {
	echo "SIGTERM received, stopping container"
	ret=0
	lxc-stop "$C_CONTAINER_NAME" || ret=$?
	if [[ $ret -eq 0 ]]; then
		echo "Container successfully shut down"
		exit 0
	else
		echo "Failed to shutdown container, exit code: $ret"
		exit $ret
	fi
}
trap sigterm TERM

echo "starting lxc container"
ret=0
lxc-start \
	-n "$C_CONTAINER_NAME" \
	--foreground || ret=$?
if [[ $ret -eq 0 ]]; then
	echo "Container stopped"
else
	echo "Failed to start container, exit code: $ret"
fi
exit $ret
