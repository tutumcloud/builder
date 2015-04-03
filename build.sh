#!/bin/bash
set -e

if [ -S /var/run/docker.sock ]; then
	echo "=> Detected unix socket at /var/run/docker.sock"
	docker version > /dev/null 2>&1 || (echo "   Failed to connect to docker daemon at /var/run/docker.sock" && exit 1)
else
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
		echo "   Cloning repo from $GIT_REPO in /app"
		git clone $GIT_REPO /app
		if [ $? -ne 0 ]; then
			echo "   ERROR: Error cloning $GIT_REPO"
			exit 1
		fi
		cd /app
		git checkout $GIT_TAG
	elif [ ! -z "$TGZ_URL" ]; then
		echo "   Downloading $TGZ_URL to /app"
		mkdir -p /app
		curl -sL $TGZ_URL | tar zx -C /app
		cd /app
	else
		echo "   ERROR: No application found in /app, and no \$GIT_REPO defined"
		exit 1
	fi
else
	echo "   Using existing app in /app"
	cd /app
fi
cd .${DOCKERFILE_PATH-/}

if [ ! -f Dockerfile ]; then
	echo "   WARNING: no Dockerfile detected! Created one using tutum/buildstep"
	echo "FROM tutum/buildstep" >> Dockerfile
fi

echo "=> Testing repo"
TEST_FILENAME=${TEST_FILENAME-docker-compose-test.yml}
if [ -f "./${TEST_FILENAME}" ]; then
	# Next command is to workaround the fact that docker-compose does not use .dockercfg to pull images
	# TODO: remove when fixed
	cat ./${TEST_FILENAME} | grep "image:" | awk '{print $2}' | xargs -n1 docker pull
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

if [ ! -z "$IMAGE_NAME" ]; then
	echo "=> Building image $IMAGE_NAME"
	docker build --rm --force-rm -t $IMAGE_NAME .
	if [ ! -z "$USERNAME" ] || [ ! -z "$DOCKERCFG" ] || [ -f /.dockercfg ]; then
		echo "=>  Pushing image $IMAGE_NAME"
		docker push $IMAGE_NAME
		docker rmi -f $(docker images -q --no-trunc -a) > /dev/null 2>&1
	fi
else
	echo "   WARNING: no \$IMAGE_NAME found - skipping build and push"
fi
