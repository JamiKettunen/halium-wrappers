#!/bin/sh

error() {
	echo "E: $@" >&2
	exit 1
}

HOST_BINARY="${0##*/}"
TARGET_BINARY="${HOST_BINARY#android_}"
LXC_CONTAINER_NAME="android"
LXC_CONTAINER_PATH="/var/lib/lxc/${LXC_CONTAINER_NAME}/rootfs"
ANDROID_SEARCH_PATH="${LXC_CONTAINER_PATH}/system/bin ${LXC_CONTAINER_PATH}/system/xbin ${LXC_CONTAINER_PATH}/vendor/bin"

########################################################################

[ $(id -u) -eq 0 ] || error "This wrapper must be run as root"
[ -e "${LXC_CONTAINER_PATH}" ] || error "Unable to find LXC container"

found_path=$(whereis -b -B ${ANDROID_SEARCH_PATH} -f ${TARGET_BINARY} | awk '{ print $2 }')

[ -n "${found_path}" ] || error "Unable to find ${TARGET_BINARY}"

# Unset eventual LD_PRELOAD
unset LD_PRELOAD

# Finally execute
exec /usr/bin/lxc-attach -n ${LXC_CONTAINER_NAME} -- ${found_path#${LXC_CONTAINER_PATH}} "${@}" \;
