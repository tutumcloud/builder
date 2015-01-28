tutum/builder
=============

A docker image that builds, tests and pushes docker images from code repositories.


# Usage

## Build from local folder

Run the following docker command:

	docker run --rm -it --privileged -v $(pwd):/app -e IMAGE_NAME=$IMAGE_NAME -e USERNAME=$USERNAME -e PASSWORD=$PASSWORD -e EMAIL=$EMAIL tutum/docker-builder

Where:

* `$(pwd)` is the path to your application repository (defaults to current path)
* `$IMAGE_NAME` is the name of the image to create with an optional tag, i.e. `tutum/hello-world:latest`
* `$USERNAME` is the username to use to log into the registry using `docker login`
* `$PASSWORD` is the password to use to log into the registry using `docker login`
* `$EMAIL` is the email to use to log into the registry using `docker login`


## Build from Git repository

Run the following docker command:

	docker run --rm -it --privileged -e GIT_REPO=$GIT_REPO -e IMAGE_NAME=$IMAGE_NAME -e USERNAME=$USERNAME -e PASSWORD=$PASSWORD -e EMAIL=$EMAIL tutum/docker-builder

Where:

* `$GIT_REPO` is the git repository to clone and build, i.e. `https://github.com/tutumcloud/quickstart-python.git`
* `$GIT_TAG` is the tag/branch/commit to checkout after clone, i.e. `master`
* `$DOCKERFILE_PATH` is the relative path to the root of the repository where the `Dockerfile` is present, i.e. `/`
* `$IMAGE_NAME` is the name of the image to create with an optional tag, i.e. `tutum/hello-world:latest`
* `$USERNAME` is the username to use to log into the registry using `docker login`
* `$PASSWORD` is the password to use to log into the registry using `docker login`
* `$EMAIL` is the email to use to log into the registry using `docker login`


# Testing

If you want to test your app before building, create a `fig-test.yml` file in your repository root with a service called `sut` which will be run for testing. If that container exits successfully (exit code 0), the build will continue; otherwise, the build will fail and the image won't be built nor pushed.

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

	docker run --name builder_cache tutum/docker-builder true

And then run your builds as above appending `--volumes-from builder_cache` to them to reuse already downloaded image layers.

## Adding credentials to pull private images

If your tests depend on private images, you can pass their credentials either by mounting your local `.dockercfg` file inside the container appending `-v $HOME/.dockercfg:/.dockercfg:r`, or by providing the contents of this file via an environment variable called `$DOCKERCFG`: `-e DOCKERCFG=$(cat $HOME/.dockercfg)`
	
