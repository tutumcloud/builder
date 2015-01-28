#!/bin/bash
set -e
export PORT=2375
export DOCKER_HOST=tcp://127.0.0.1:2375

echo "=> Starting docker"
wrapdocker > /dev/null 2>&1 &

echo "=> Cloning repo"
git clone $GIT_REPO /app
cd /app
git checkout $GIT_TAG
cd .$DOCKERFILE_PATH

echo "=> Testing repo"
if [ -f "./fig-test.yml" ]; then
	fig -f fig-test.yml -p app up sut
	RET=$(docker wait app_sut_1)
	if [ "$RET" != "0" ]; then
		echo "   Tests FAILED: $RET"
		exit 1
	else
		echo "   Tests PASSED"
	fi
else
	echo "   No tests found (have you created a fig-test.yml file?). Skipping..."
fi

echo "=> Building"
docker build --rm --force-rm -t $IMAGE_NAME .

REGISTRY=$(echo $IMAGE_NAME | tr "/" "\n" | head -n1 | grep "\." || true)
echo "=> Logging into registry"
docker login -u $USERNAME -p $PASSWORD -e $EMAIL $REGISTRY

echo "=> Pushing image"
docker push $IMAGE_NAME
docker rmi -f $(docker images -q --no-trunc -a) > /dev/null 2>&1