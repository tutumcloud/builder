#!/bin/bash
set -e

# Ensure that all nodes in /dev/mapper correspond to mapped devices currently loaded by the device-mapper kernel driver
dmsetup mknodes

# Now, close extraneous file descriptors.
pushd /proc/self/fd >/dev/null
for FD in *
do
	case "$FD" in
	# Keep stdin/stdout/stderr
	[012])
		;;
	# Nuke everything else
	*)
		eval exec "$FD>&-"
		;;
	esac
done
popd >/dev/null


print_msg() {
	echo -e "\e[1m${1}\e[0m"
}

run_docker() {
	udevd --daemon
	print_msg "=> Starting docker"
	docker daemon \
		--host=unix:///var/run/docker.sock \
		$DOCKER_DAEMON_ARGS > /var/log/docker.log 2>&1 &
	print_msg "=> Checking docker daemon"
	LOOP_LIMIT=60
	for (( i=0; ; i++ )); do
		if [ ${i} -eq ${LOOP_LIMIT} ]; then
			cat /var/log/docker.log
			print_msg "   Failed to start docker (did you use --privileged when running this container?)"
			exit 1
		fi
		sleep 1
		docker version > /dev/null 2>&1 && break
	done
}

#
# Start docker-in-docker or use an external docker daemon via mounted socket
#
DOCKER_USED=""
EXTERNAL_DOCKER=no
MOUNTED_DOCKER_FOLDER=no
if [ -S /var/run/docker.sock ]; then
	print_msg "=> Detected unix socket at /var/run/docker.sock"
	print_msg "=> Testing if docker version matches"
	if ! docker version > /dev/null 2>&1 ; then
		export DOCKER_VERSION=$(cat version_list | grep -P "^$(docker version 2>&1 > /dev/null | grep -iF "client and server don't have same version" | grep -oP 'server: *\d*\.\d*' | grep -oP '\d*\.\d*') .*$" | cut -d " " -f2)
		if [ "${DOCKER_VERSION}" != "" ]; then
			print_msg "=> Downloading docker ${DOCKER_VERSION}"
			curl -o /usr/bin/docker https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}
		fi
	fi
	docker version > /dev/null 2>&1 || { print_msg "   Failed to connect to docker daemon at /var/run/docker.sock" && exit 1; }
	EXTERNAL_DOCKER=yes
	DOCKER_USED="Using external docker ${DOCKER_VERSION} mounted at /var/run/docker.sock"
    export DOCKER_USED=${DOCKER_USED}
    export EXTERNAL_DOCKER=${EXTERNAL_DOCKER}
    export MOUNTED_DOCKER_FOLDER=${MOUNTED_DOCKER_FOLDER}
    /build.sh "$@"
else
	DOCKER_USED="Using docker-in-docker ${DOCKER_VERSION}"
	if [ "$(ls -A /var/lib/docker)" ]; then
		print_msg "=> Detected pre-existing /var/lib/docker folder"
		MOUNTED_DOCKER_FOLDER=yes
		DOCKER_USED="Using docker-in-docker with an external /var/lib/docker folder"
	fi
    export DOCKER_USED=${DOCKER_USED}
    export EXTERNAL_DOCKER=${EXTERNAL_DOCKER}
    export MOUNTED_DOCKER_FOLDER=${MOUNTED_DOCKER_FOLDER}
    run_docker
    /build.sh "$@"
fi
