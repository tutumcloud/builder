#!/bin/bash
set -e

print_msg() {
	echo -e "\e[1m${1}\e[0m"
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
			print_msg "=> Downloading Docker ${DOCKER_VERSION}"
			curl -o /usr/bin/docker https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}
		fi
	fi
	docker version > /dev/null 2>&1 || { print_msg "   Failed to connect to docker daemon at /var/run/docker.sock" && exit 1; }
	EXTERNAL_DOCKER=yes
	DOCKER_USED="Using external docker version ${DOCKER_VERSION} mounted at /var/run/docker.sock"
    export DOCKER_USED=${DOCKER_USED}
    export EXTERNAL_DOCKER=${EXTERNAL_DOCKER}
    export MOUNTED_DOCKER_FOLDER=${MOUNTED_DOCKER_FOLDER}
    /build.sh "$@"
else
	DOCKER_USED="Using docker-in-docker"
	if [ "$(ls -A /var/lib/docker)" ]; then
		print_msg "=> Detected pre-existing /var/lib/docker folder"
		MOUNTED_DOCKER_FOLDER=yes
		DOCKER_USED="Using docker-in-docker with an external /var/lib/docker folder"
	fi
    print_msg "=> Starting docker"
    export DOCKER_USED=${DOCKER_USED}
    export EXTERNAL_DOCKER=${EXTERNAL_DOCKER}
    export MOUNTED_DOCKER_FOLDER=${MOUNTED_DOCKER_FOLDER}
    wrapdocker /build.sh "$@"
fi
