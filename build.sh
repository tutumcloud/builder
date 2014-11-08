#!/bin/bash
set -e
export PORT=2375
export DOCKER_HOST=tcp://127.0.0.1:2375

echo "=> Starting docker"
wrapdocker > /dev/null 2>&1 &

echo "=> Cloning repo"
git clone $GIT_REPO /app
cd /app

echo "=> Building"
docker build --rm --force-rm -t $IMAGE_NAME .

REGISTRY=$(echo $IMAGE_NAME | tr "/" "\n" | head -n1 | grep "\." || true)
echo "=> Logging into registry"
docker login -u $USERNAME -p $PASSWORD -e $EMAIL $REGISTRY

echo "=> Pushing image"
docker push $IMAGE_NAME
docker rmi -f $(docker images -q --no-trunc -a) > /dev/null 2>&1