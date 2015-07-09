#!/bin/bash
set -e

IMAGE_NAME=${IMAGE_NAME:-$1}

run_hook() {
	HOOK=hooks/$1
	if [ -f "$HOOK" ]; then
		echo "=> Executing $HOOK hook"
		./$HOOK
		if [ $? -ne 0 ]; then
			echo "ERROR: $HOOK failed with exit code $?"
			exit 1
		fi
	fi
}

EXTERNAL_DOCKER=no
MOUNTED_DOCKER_FOLDER=no
if [ -S /var/run/docker.sock ]; then
	echo "=> Detected unix socket at /var/run/docker.sock"
	echo "=> Testing if docker version matches"
	if ! docker version > /dev/null 2>&1 ; then
	export DOCKER_VERSION=$(cat version_list | grep -P "^$(docker version 2>&1 > /dev/null | grep -iF "client and server don't have same version" | grep -oP 'server: *\d*\.\d*' | grep -oP '\d*\.\d*') .*$" | cut -d " " -f2)
		if [ "${DOCKER_VERSION}" != "" ]; then
			echo "=> Downloading Docker ${DOCKER_VERSION}"
			curl -o /usr/bin/docker https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}
		fi
	fi
	docker version > /dev/null 2>&1 || (echo "   Failed to connect to docker daemon at /var/run/docker.sock" && exit 1)
	EXTERNAL_DOCKER=yes
else
	if [ "$(ls -A /var/lib/docker)" ]; then
		echo "=> Detected pre-existing /var/lib/docker folder"
		MOUNTED_DOCKER_FOLDER=yes
	fi
	echo "=> Starting docker"
	wrapdocker > /dev/null 2>&1 &
	sleep 10
	echo "=> Checking docker daemon"
	docker version > /dev/null 2>&1 || (echo "   Failed to start docker (did you use --privileged when running this container?)" && exit 1)
fi

echo "=> Loading docker auth configuration"
if [ -f /.dockercfg ]; then
	echo "   Using existing configuration in /.dockercfg"
	ln -s /.dockercfg /root/.dockercfg
elif [ ! -z "$DOCKERCFG" ]; then
	echo "   Detected configuration in \$DOCKERCFG"
	echo "$DOCKERCFG" > /root/.dockercfg
	unset DOCKERCFG
elif [ ! -z "$USERNAME" ] && [ ! -z "$PASSWORD" ]; then
	REGISTRY=$(echo $IMAGE_NAME | tr "/" "\n" | head -n1 | grep "\." || true)
	echo "   Logging into registry using $USERNAME"
	docker login -u $USERNAME -p $PASSWORD -e ${EMAIL-no-email@test.com} $REGISTRY
else
	echo "   WARNING: no \$USERNAME/\$PASSWORD or \$DOCKERCFG found - unable to load any credentials for pushing/pulling"
fi

rm -fr /src && mkdir -p /src
echo "=> Detecting application"
if [ ! -d /app ]; then
	if [ ! -z "$GIT_REPO" ]; then
		echo "   Cloning repo from ${GIT_REPO##*@}"
		git clone $GIT_REPO /src
		if [ $? -ne 0 ]; then
			echo "   ERROR: Error cloning $GIT_REPO"
			exit 1
		fi
		unset GIT_REPO
		cd /src
		git checkout $GIT_TAG
		export GIT_SHA1=$(git rev-list $GIT_TAG | head -n 1)
	elif [ ! -z "$TGZ_URL" ]; then
		echo "   Downloading $TGZ_URL"
		curl -sL $TGZ_URL | tar zx -C /src
	else
		echo "   ERROR: No application found in /app, and no \$GIT_REPO defined"
		exit 1
	fi
	run_hook post_checkout
else
	echo "   Using existing app in /app"
	cp -r /app/. /src
fi
cd /src${DOCKERFILE_PATH:-/}
if [ -d "hooks" ]; then
	chmod +x hooks/*
fi

if [ ! -f Dockerfile ]; then
	echo "   WARNING: no Dockerfile detected! Created one using tutum/buildstep"
	echo "FROM tutum/buildstep" >> Dockerfile
fi

echo "=> Building repository"
run_hook pre_build
if [ -f "hooks/build" ]; then
	run_hook build
else
	docker build --rm --force-rm -t this .
fi
run_hook post_build

run_hook pre_test
if [ -f "hooks/test" ]; then
	run_hook test
else
	shopt -s nullglob
	for TEST_FILENAME in *{.test.yml,-test.yml}
	do
		echo "=>  Executing tests in $TEST_FILENAME"
		# Next command is to workaround the fact that docker-compose does not use .dockercfg to pull images
		IMAGES=$(cat ./${TEST_FILENAME} | grep "image:" | awk '{print $2}')
		if [ ! -z "$IMAGES" ]; then
			echo $IMAGES | xargs -n1 docker pull
		fi

		docker-compose -f ${TEST_FILENAME} -p app build sut

		if [ -z "$IMAGE_NAME" ]; then
			rm -f /root/.dockercfg
		fi

		docker-compose -f ${TEST_FILENAME} -p app up sut
		RET=$(docker wait app_sut_1)
		docker-compose -f ${TEST_FILENAME} -p app kill
		docker-compose -f ${TEST_FILENAME} -p app rm --force -v
		if [ "$RET" != "0" ]; then
			echo "   Tests in $TEST_FILENAME FAILED: $RET"
			exit 1
		else
			echo "   Tests in $TEST_FILENAME PASSED"
		fi
	done
fi
run_hook post_test

if [ ! -z "$IMAGE_NAME" ]; then
	if [ ! -z "$USERNAME" ] || [ -f /root/.dockercfg ]; then
		echo "=>  Pushing image $IMAGE_NAME"
		run_hook pre_push
		if [ -f "hooks/push" ]; then
			run_hook push
		else
			docker tag -f this $IMAGE_NAME
			docker push $IMAGE_NAME
			run_hook post_push
			echo "=>  Pushed image $IMAGE_NAME"
			if [ "$EXTERNAL_DOCKER" == "no" ] && [ "$MOUNTED_DOCKER_FOLDER" == "no" ]; then
				echo "=>  Cleaning up images"
				docker rmi -f $(docker images -q --no-trunc -a) > /dev/null 2>&1 || true
			fi
		fi
	fi
else
	echo "   Skipping push"
fi
