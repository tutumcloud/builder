tutum/builder
=============

A docker image that builds, tests and pushes docker images from code repositories.


# Usage

## Build from local folder

Run the following docker command in the folder that you want to build and push:

	docker run --rm -it --privileged -v $(pwd):/app -v $HOME/.dockercfg:/.dockercfg:r tutum/builder $IMAGE_NAME

Where:

* `$IMAGE_NAME` (optional) is the name of the image to build and push with an optional tag, i.e. `tutum/hello-world:latest`. If not specified, it will be built and tested, but not pushed. It can also be passed in as an environment variable `-e IMAGE_NAME=$IMAGE_NAME`.

This will use the `~/.dockercfg` file which should be prepopulated with credentials by using `docker login <registry>` in the host. Alternatively, you can use `$USERNAME`, `$PASSWORD` and `$EMAIL` as described below.


## Build from Git repository

Run the following docker command:

	docker run --rm -it --privileged -e GIT_REPO=$GIT_REPO -e USERNAME=$USERNAME -e PASSWORD=$PASSWORD -e EMAIL=$EMAIL -e DOCKERFILE_PATH=$DOCKERFILE_PATH tutum/builder $IMAGE_NAME

Where:

* `$GIT_REPO` is the git repository to clone and build, i.e. `https://github.com/tutumcloud/quickstart-python.git`
* `$GIT_TAG` (optional, defaults to `master`) is the tag/branch/commit to checkout after clone, i.e. `master`
* `$DOCKERFILE_PATH` (optional, defaults to `/`) is the relative path to the root of the repository where the `Dockerfile` is present, i.e. `/`
* `$IMAGE_NAME` is the name of the image to create with an optional tag, i.e. `tutum/quickstart-python:latest`
* `$USERNAME` is the username to use to log into the registry using `docker login`
* `$PASSWORD` is the password to use to log into the registry using `docker login`
* `$EMAIL` (optional) is the email to use to log into the registry using `docker login`


## Build from compressed tarball

Run the following docker command:

	docker run --rm -it --privileged -e TGZ_URL=$TGZ_URL -e DOCKERFILE_PATH=$DOCKERFILE_PATH -e USERNAME=$USERNAME -e PASSWORD=$PASSWORD -e EMAIL=$EMAIL tutum/builder $IMAGE_NAME

Where:

* `$TGZ_URL` is the URL to the compressed tarball (.tgz) to download and build, i.e. `https://github.com/tutumcloud/docker-hello-world/archive/v1.0.tar.gz`
* `$DOCKERFILE_PATH` (optional, defaults to `/`) is the relative path to the root of the tarball where the `Dockerfile` is present, i.e. `/docker-hello-world-1.0`
* `$IMAGE_NAME` is the name of the image to create with an optional tag, i.e. `tutum/hello-world:latest`
* `$USERNAME` is the username to use to log into the registry using `docker login`
* `$PASSWORD` is the password to use to log into the registry using `docker login`
* `$EMAIL` (optional) is the email to use to log into the registry using `docker login`


# Testing

If you want to test your app before building, create a `docker-compose.test.yml` file in your repository root with a service called `sut` which will be run for testing. You can specify another file name in `$TEST_FILENAME` if required. If that container exits successfully (exit code 0), the build will continue; otherwise, the build will fail and the image won't be built nor pushed.

Example `docker-compose.test.yml` file for a Django app that depends on a Redis cache:

	sut:
	  build: .
	  links:
	    - redis
	  command: python manage.py test
	redis:
	  image: tutum/redis
	  environment:
	    - REDIS_PASS=password

To speed up testing, you can replace `build: .` in your `sut` service with `image: this`, which is the name of the image that is built just before running the tests. This way you can avoid building the same image twice.


# Hooks

There is the possibility to run scripts before and after some of the build steps to set up your application as required. The following hooks are available (in this order):

* `hooks/post_checkout` (does not run if mounting `/app`)
* `hooks/pre_build`
* `hooks/post_build`
* `hooks/pre_test`
* `hooks/post_test`
* `hooks/pre_push`
* `hooks/post_push`

Create a file in your repository in a folder called `hooks` with those names and the builder will execute them before and after each step.

# Environment Variables

The following environment variables are available for testing, when executing the docker-compose.test.yml file; and during the execution of Hooks.

* GIT_BRANCH which contains the name of the branch that is currently being tested
* GIT_TAG which contains the branch/tag/commit being tested
* GIT_SHA1 which contains the commmit hash of the tag being tested
* IMAGE_NAME which contains the name of the docker repository being built (not defined for automated tests triggered outside of an automated build)


# Notes

## Caching images for faster builds

If you want to cache the images used for building and testing, run the following:

	docker run --name builder_cache tutum/builder true

And then run your builds as above appending `--volumes-from builder_cache` to them to reuse already downloaded image layers.

## Adding credentials via .dockercfg

If your tests depend on private images, you can pass their credentials either by mounting your local `.dockercfg` file inside the container appending `-v $HOME/.dockercfg:/.dockercfg:r`, or by providing the contents of this file via an environment variable called `$DOCKERCFG`: `-e DOCKERCFG=$(cat $HOME/.dockercfg)`

## Using the host docker daemon instead of docker-in-docker

If you want to use the host docker daemon instead of letting the container run its own, mount the host's docker unix socket inside the container by appending `-v /var/run/docker.sock:/var/run/docker.sock:rw` to the `docker run` command.
