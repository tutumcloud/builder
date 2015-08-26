#!/bin/bash
set -e

IMAGE_NAME=${IMAGE_NAME:-$1}

print_msg() {
	echo -e "\e[1m${1}\e[0m"
}

run_hook() {
	HOOK=hooks/$1
	if [ -f "$HOOK" ]; then
		print_msg "=> Executing $HOOK hook"
		./$HOOK
		if [ $? -ne 0 ]; then
			print_msg "ERROR: $HOOK failed with exit code $?"
			exit 1
		fi
	fi
}

#
# Detect docker credentials for pulling private images and for pushing the built image
#
print_msg "=> Loading docker auth configuration"
if [ -f /.dockercfg ]; then
	print_msg "   Using existing configuration in /.dockercfg"
	ln -s /.dockercfg /root/.dockercfg
	mkdir -p /root/.docker && ln -s /.dockercfg /root/.docker/config.json
elif [ -d /.docker ]; then
	print_msg "   Using existing configuration in /.docker"
	ln -s /.docker /root/.docker
	ln -s /.docker/config.json /root/.dockercfg
elif [ ! -z "$DOCKERCFG" ]; then
	print_msg "   Detected configuration in \$DOCKERCFG"
	mkdir -p /root/.docker
	echo "$DOCKERCFG" > /root/.docker/config.json
	ln -s /root/.docker/config.json /root/.dockercfg
	unset DOCKERCFG
elif [ ! -z "$USERNAME" ] && [ ! -z "$PASSWORD" ]; then
	REGISTRY=$(echo $IMAGE_NAME | tr "/" "\n" | head -n1 | grep "\." || true)
	print_msg "   Logging into registry using $USERNAME"
	docker login -u $USERNAME -p $PASSWORD -e ${EMAIL-no-email@test.com} $REGISTRY
else
	print_msg "   WARNING: no \$USERNAME/\$PASSWORD or \$DOCKERCFG found - unable to load any credentials for pushing/pulling"
fi

#
# Clone the specified git repository or use the mounted code in /app
#
SOURCE=""
rm -fr /src && mkdir -p /src
print_msg "=> Detecting application"
if [ ! -d /app ]; then
	if [ ! -z "$GIT_REPO" ]; then
		print_msg "   Cloning repo from ${GIT_REPO##*@}"
		git clone --recursive $GIT_REPO /src
		if [ $? -ne 0 ]; then
			print_msg "   ERROR: Error cloning $GIT_REPO"
			exit 1
		fi
		cd /src
		git checkout $GIT_TAG
		export GIT_SHA1=$(git rev-parse HEAD)
		export GIT_MSG=$(git log --format=%B -n 1 $GIT_SHA1)
		print_msg "   Building commit ${GIT_SHA1}"
		SOURCE="Building ${GIT_REPO##*@}@${GIT_SHA1}"
		unset GIT_REPO
	elif [ ! -z "$TGZ_URL" ]; then
		print_msg "   Downloading $TGZ_URL"
		curl -sL $TGZ_URL | tar zx -C /src
		SOURCE="Building $TGZ_URL"
	else
		print_msg "   ERROR: No application found in /app, and no \$GIT_REPO defined"
		exit 1
	fi
	run_hook post_checkout
else
	SOURCE="Building mounted app in /app"
	print_msg "   $SOURCE"
	cp -r /app/. /src
fi
cd /src${DOCKERFILE_PATH:-/}
if [ -d "hooks" ]; then
	chmod +x hooks/*
fi
if [ ! -f Dockerfile ]; then
	print_msg "   WARNING: no Dockerfile detected! Created one using tutum/buildstep"
	echo "FROM tutum/buildstep" >> Dockerfile
fi


#
# (1/3) Build step
#
print_msg "=> Building repository"
START_DATE=$(date +"%s")
run_hook pre_build
if [ -f "hooks/build" ]; then
	run_hook build
else
	docker build --rm --force-rm -t this .
fi
run_hook post_build
END_DATE=$(date +"%s")
DATE_DIFF=$(($END_DATE-$START_DATE))
BUILD="Image built in $(($DATE_DIFF / 60)) minutes and $(($DATE_DIFF % 60)) seconds"

#
# (2/3) Test step
#
START_DATE=$(date +"%s")
run_hook pre_test
if [ -f "hooks/test" ]; then
	run_hook test
else
	TEST="No tests found"
	shopt -s nullglob
	for TEST_FILENAME in *{.test.yml,-test.yml}
	do
		print_msg "=> Executing tests in $TEST_FILENAME"
		IMAGES=$(cat ./${TEST_FILENAME} | grep -v "image: *this" | grep "image:" | awk '{print $2}')
		if [ ! -z "$IMAGES" ]; then
			echo $IMAGES | xargs -n1 docker pull
		fi

		PROJECT_NAME=$(echo $HOSTNAME | tr '[:upper:]' '[:lower:]' | sed s/\\.//g | sed s/-//g)
		docker-compose -f ${TEST_FILENAME} -p $PROJECT_NAME build

		if [ -z "$IMAGE_NAME" ]; then
			rm -f /root/.dockercfg
		fi

		docker-compose -f ${TEST_FILENAME} -p $PROJECT_NAME up -d sut
		docker logs -f ${PROJECT_NAME}_sut_1
		RET=$(docker wait ${PROJECT_NAME}_sut_1)
		docker-compose -f ${TEST_FILENAME} -p $PROJECT_NAME kill
		docker-compose -f ${TEST_FILENAME} -p $PROJECT_NAME rm --force -v
		if [ "$RET" != "0" ]; then
			print_msg "   Tests in $TEST_FILENAME FAILED: $RET"
			exit 1
		else
			print_msg "   Tests in $TEST_FILENAME PASSED"
			unset TEST
		fi
	done
fi
run_hook post_test
END_DATE=$(date +"%s")
DATE_DIFF=$(($END_DATE-$START_DATE))
TEST=${TEST:-"Tests passed in $(($DATE_DIFF / 60)) minutes and $(($DATE_DIFF % 60)) seconds"}

#
# (3/3) Push step
#
START_DATE=$(date +"%s")
if [ ! -z "$IMAGE_NAME" ]; then
	if [ ! -z "$USERNAME" ] || [ -f /root/.dockercfg ]; then
		print_msg "=> Pushing image $IMAGE_NAME"
		run_hook pre_push
		if [ -f "hooks/push" ]; then
			run_hook push
		else
			docker tag -f this $IMAGE_NAME
			docker push $IMAGE_NAME
			# docker push $IMAGE_NAME 2>&1 | tee /tmp/push-result || true
			# while cat /tmp/push-result | grep -q "is already in progress"; do
			#  	 docker push $IMAGE_NAME 2>&1 | tee /tmp/push-result || true
			# 	 sleep 1
			# done
			run_hook post_push
			print_msg "   Pushed image $IMAGE_NAME"
			if [ "$EXTERNAL_DOCKER" == "no" ] && [ "$MOUNTED_DOCKER_FOLDER" == "no" ]; then
				print_msg "   Cleaning up images"
				docker rmi -f $(docker images -q --no-trunc -a) > /dev/null 2>&1 || true
			fi
		fi
	fi
else
	PUSH="Skipping push"
	print_msg "   $PUSH"
fi
END_DATE=$(date +"%s")
DATE_DIFF=$(($END_DATE-$START_DATE))
PUSH=${PUSH:-"Image $IMAGE_NAME pushed in $(($DATE_DIFF / 60)) minutes and $(($DATE_DIFF % 60)) seconds"}

#
# Final summary
#
echo -e "\e[1m"
cat <<EOF

Build summary
=============

$DOCKER_USED
$SOURCE
$BUILD
$TEST
$PUSH

EOF
