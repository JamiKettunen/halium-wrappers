#!/bin/sh

ANDROID_SERVICE_ACTION="${2}"
ANDROID_SERVICE_STAMP_DIRECTORY="/run/android-service"
LXC_CONTAINER_NAME="android"

error() {
	echo "E: ${@}" >&2
	exit 1
}

: "${ANDROID_SERVICE:=${1}}"
service=$(grep -Er "service ${ANDROID_SERVICE} /.*" /system/etc/init /vendor/etc/init | head -n 1)
if [ -z "${service}" ]; then
	error "Unable to detect service"
fi
service_service=$(echo ${service} | awk '{ print $2 }')
service_path=$(echo ${service} | awk '{ print $3 }')
service_process=$(echo ${service_path} | awk -F "/" '{print $NF}')
ANDROID_SERVICE_STAMP="${ANDROID_SERVICE_STAMP_DIRECTORY}/${service_service}-stamp"

current_status() {
	getprop init.svc.${service_service}
}

start() {
	[ "$(current_status)" = "running" ] && return 0

	# Start operation is weird since it's kickstarted by Android's
	# init - thus we assume that if ${ANDROID_SERVICE_STAMP} doesn't
	# exist the startup has already been triggered.
	#
	# If it does exist, instead, we should indeed start the service by
	# ourselves.
	if [ -e "${ANDROID_SERVICE_STAMP}" ]; then
		android_start ${service_service}
	fi

	# Now, wait
	waitforservice init.svc.${service_service}

	# Once we return, create the stamp file
	touch ${ANDROID_SERVICE_STAMP}
}

stop() {
	[ "$(current_status)" = "stopped" ] && return 0

	# Try to gracefully stop via the Android-provided facilities
	android_stop ${service_service}

	if [ -z "${ANDROID_SERVICE_FORCE_KILL}" ]; then
		WAITFORSERVICE_VALUE="stopped" timeout 5 waitforservice init.svc.${service_service}
	else
		pid=$(lxc-attach -n ${LXC_CONTAINER_NAME} -- /bin/pidof ${service_process} \;)
		[ -n "${pid}" ] && android_kill -9 ${pid}
		setprop init.svc.${service_service} stopped
	fi
}

mkdir -p "${ANDROID_SERVICE_STAMP_DIRECTORY}"

case "${ANDROID_SERVICE_ACTION}" in
	"start")
		start
		;;
	"stop")
		stop
		;;
	"restart")
		stop
		start
		;;
	*)
		error "USAGE: ${0} <service> start|stop|restart"
		;;
esac
