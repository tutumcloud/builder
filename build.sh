#!/bin/bash
set -e

IMAGE_NAME=${IMAGE_NAME:-$1}

run_hook() {
	HOOK=hooks/$1
	if [ -f "$HOOK" ]; then
		echo "=> Executing $HOOK hook"
		./$HOOK
	fi
}

EXTERNAL_DOCKER=no
MOUNTED_DOCKER_FOLDER=no
if [ -S /var/run/docker.sock ]; then
	echo "=> Detected unix socket at /var/run/docker.sock"
	docker version > /dev/null 2>&1 || (echo "   Failed to connect to docker daemon at /var/run/docker.sock" && exit 1)
	EXTERNAL_DOCKER=yes
else
	if [ "$(ls -A /var/lib/docker)" ]; then
		echo "=> Detected pre-existing /var/lib/docker folder"
		MOUNTED_DOCKER_FOLDER=yes
	fi
	echo "=> Starting docker"
	wrapdocker > /dev/null 2>&1 &
	sleep 2
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
elif [ ! -z "$USERNAME" ] && [ ! -z "$PASSWORD" ]; then
	REGISTRY=$(echo $IMAGE_NAME | tr "/" "\n" | head -n1 | grep "\." || true)
	echo "   Logging into registry using $USERNAME"
	docker login -u $USERNAME -p $PASSWORD -e ${EMAIL-no-email@test.com} $REGISTRY
else
	echo "   WARNING: no \$USERNAME/\$PASSWORD or \$DOCKERCFG found - unable to load any credentials for pushing/pulling"
fi

echo "=> Detecting application"
if [ ! -d /app ]; then
	if [ ! -z "$GIT_REPO" ]; then
		echo "   Cloning repo from ${GIT_REPO##*@}"
		git clone $GIT_REPO /src
		if [ $? -ne 0 ]; then
			echo "   ERROR: Error cloning $GIT_REPO"
			exit 1
		fi
		cd /src
		git checkout $GIT_TAG
	elif [ ! -z "$TGZ_URL" ]; then
		echo "   Downloading $TGZ_URL"
		mkdir -p /src
		curl -sL $TGZ_URL | tar zx -C /src
		cd /src
	else
		echo "   ERROR: No application found in /app, and no \$GIT_REPO defined"
		exit 1
	fi
	run_hook post_checkout
else
	echo "   Using existing app in /app"
	mkdir -p /src
	cp -r /app/* /src
	cd /src
fi
cd .${DOCKERFILE_PATH:-/}
if [ -d "hooks" ]; then
	chmod +x hooks/*
fi

if [ ! -f Dockerfile ]; then
	echo "   WARNING: no Dockerfile detected! Created one using tutum/buildstep"
	echo "FROM tutum/buildstep" >> Dockerfile
fi

echo "=> Building repository"
run_hook pre_build
docker build --rm --force-rm -t this .
run_hook post_build

echo "=> Testing repo"
TEST_FILENAME=${TEST_FILENAME:-docker-compose.test.yml}
if [ ! -f "./${TEST_FILENAME}" ] && [ -f "./docker-compose-test.yml" ]; then
	echo "   WARNING: docker-compose-test.yml is deprecated. Rename your test file to docker-compose.test.yml"
	TEST_FILENAME=docker-compose-test.yml
fi

run_hook pre_test
if [ -f "./${TEST_FILENAME}" ]; then
	echo "=>  Executing tests"
	# Next command is to workaround the fact that docker-compose does not use .dockercfg to pull images
	# cat ./${TEST_FILENAME} | grep "image:" | awk '{print $2}' | xargs -n1 docker pull
	docker-compose -f ${TEST_FILENAME} -p app build sut
	docker-compose -f ${TEST_FILENAME} -p app up sut
	RET=$(docker wait app_sut_1)
	docker-compose -f ${TEST_FILENAME} -p app kill
	docker-compose -f ${TEST_FILENAME} -p app rm --force -v
	if [ "$RET" != "0" ]; then
		echo "   Tests FAILED: $RET"
		exit 1
	else
		echo "   Tests PASSED"
	fi
else
	echo "   No tests found - skipping (have you created a ${TEST_FILENAME} file?)"
fi
run_hook post_test

if [ ! -z "$IMAGE_NAME" ]; then
	if [ ! -z "$USERNAME" ] || [ ! -z "$DOCKERCFG" ] || [ -f /.dockercfg ]; then
		echo "=>  Pushing image $IMAGE_NAME"
		run_hook pre_push
		docker tag -f this $IMAGE_NAME
		docker push $IMAGE_NAME
		run_hook post_push
		echo "=>  Pushed image $IMAGE_NAME"
		if [ "$EXTERNAL_DOCKER" == "no" ] && [ "$MOUNTED_DOCKER_FOLDER" == "no" ]; then
			echo "=>  Cleaning up images"
			docker rmi -f $(docker images -q --no-trunc -a) > /dev/null 2>&1 || true
		fi
	fi
else
	echo "   Skipping push"
fi
