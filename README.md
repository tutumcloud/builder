tutum/builder
====================

A docker image that builds, tests and pushes docker images from code repositories.


# Usage

## Build from local folder

Run the following docker command in the folder that you want to build and push:

	docker run --rm -it --privileged -v $(pwd):/app -v $HOME/.dockercfg:/.dockercfg:r -e IMAGE_NAME=$IMAGE_NAME tutum/builder

Where:

* `$IMAGE_NAME` is the name of the image to create with an optional tag, i.e. `tutum/hello-world:latest`


## Build from Git repository

Run the following docker command:

	docker run --rm -it --privileged -e GIT_REPO=$GIT_REPO -e IMAGE_NAME=$IMAGE_NAME -e USERNAME=$USERNAME -e PASSWORD=$PASSWORD -e EMAIL=$EMAIL tutum/builder

Where:

* `$GIT_REPO` is the git repository to clone and build, i.e. `https://github.com/tutumcloud/quickstart-python.git`
* `$GIT_TAG` is the tag/branch/commit to checkout after clone, i.e. `master`
* `$DOCKERFILE_PATH` is the relative path to the root of the repository where the `Dockerfile` is present, i.e. `/`
* `$IMAGE_NAME` is the name of the image to create with an optional tag, i.e. `tutum/quickstart-python:latest`
* `$USERNAME` is the username to use to log into the registry using `docker login`
* `$PASSWORD` is the password to use to log into the registry using `docker login`
* `$EMAIL` is the email to use to log into the registry using `docker login`


# Testing

If you want to test your app before building, create a `fig-test.yml` file in your repository root with a service called `sut` which will be run for testing. You can specify another file name in `$FIGTEST_FILENAME` if required. If that container exits successfully (exit code 0), the build will continue; otherwise, the build will fail and the image won't be built nor pushed.

Example `fig-test.yml` file for a Django app that depends on a Redis cache:

	sut:
	  build: .
	  links:
	    - redis
	  command: python manage.py test
	redis:
	  image: tutum/redis
	  environment:
	    - REDIS_PASS=password


# Notes

## Caching images for faster builds

If you want to cache the images used for building and testing, run the following:

	docker run --name builder_cache tutum/builder true

And then run your builds as above appending `--volumes-from builder_cache` to them to reuse already downloaded image layers.

## Adding credentials via .dockercfg

If your tests depend on private images, you can pass their credentials either by mounting your local `.dockercfg` file inside the container appending `-v $HOME/.dockercfg:/.dockercfg:r`, or by providing the contents of this file via an environment variable called `$DOCKERCFG`: `-e DOCKERCFG=$(cat $HOME/.dockercfg)`
	
