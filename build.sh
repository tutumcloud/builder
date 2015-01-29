#!/bin/bash
set -e
export PORT=2375
export DOCKER_HOST=tcp://127.0.0.1:2375

echo "=> Starting docker"
wrapdocker > /dev/null 2>&1 &
sleep 2

echo "=> Checking docker daemon"
docker version > /dev/null 2>&1 || (echo "   Failed to start docker (did you use --privileged when running this container?)" && exit 1)

echo "=> Loading docker auth configuration"
if [ -f /.dockercfg ]; then
	echo "   Using existing configuration in /.dockercfg"
elif [ ! -z "$DOCKERCFG" ]; then
	echo "   Detected configuration in \$DOCKERCFG"
	echo $DOCKERCFG > /.dockercfg
elif [ ! -z "$USERNAME" ] && [ ! -z "$PASSWORD" ]; then
	REGISTRY=$(echo $IMAGE_NAME | tr "/" "\n" | head -n1 | grep "\." || true)
	echo "   Logging into registry using $USERNAME"
	docker login -u $USERNAME -p $PASSWORD -e ${EMAIL-no-email@test.com} $REGISTRY
else
	echo "   WARNING: no \$USERNAME/\$PASSWORD or \$DOCKERCFG found - unable to load any credentials for pusing/pulling"
fi

echo "=> Detecting application"
if [ ! -d /app ]; then
	if [ ! -z "$GIT_REPO" ]; then
		echo "   Cloning repo from $GIT_REPO"
		git clone $GIT_REPO /app
		cd /app
		git checkout $GIT_TAG
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
FIGTEST_FILENAME=${FIGTEST_FILENAME-fig-test.yml}
if [ -f "./${FIGTEST_FILENAME}" ]; then
	fig -f ${FIGTEST_FILENAME} -p app up sut
	RET=$(docker wait app_sut_1)
	if [ "$RET" != "0" ]; then
		echo "   Tests FAILED: $RET"
		exit 1
	else
		echo "   Tests PASSED"
	fi
else
	echo "   No tests found - skipping (have you created a ${FIGTEST_FILENAME} file?)"
fi

echo "=> Building and pushing image"
if [ ! -z "$IMAGE_NAME" ]; then
	docker build --rm --force-rm -t $IMAGE_NAME .

	echo "   Pushing image $IMAGE_NAME"
	docker push $IMAGE_NAME
	docker rmi -f $(docker images -q --no-trunc -a) > /dev/null 2>&1
else
	echo "   WARNING: no \$IMAGE_NAME found - skipping build and push"
fi
