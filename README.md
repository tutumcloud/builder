docker-builder
==============

An image that builds a git repository and pushes the resulting image to any public or private registry, all within a container.


# Usage

Run the following docker command:

	docker run --rm --privileged -e GIT_REPO=$GIT_REPO -e GIT_TAG=$GIT_TAG -e IMAGE_NAME=$IMAGE_NAME -e USERNAME=$USERNAME -e PASSWORD=$PASSWORD -e EMAIL=$EMAIL tutum/docker-builder

Where:

* `$GIT_REPO` is the git repository to clone and build, i.e. `https://github.com/tutumcloud/quickstart-python.git`
* `$GIT_TAG` is the tag/branch/commit to checkout after clone, i.e. `master`
* `$DOCKERFILE_PATH` is the relative path to the root of the repository where the `Dockerfile` is present, i.e. `/`
* `$IMAGE_NAME` is the name of the image to create with an optional tag, i.e. `tutum/hello-world:latest`
* `$USERNAME` is the username to use to log into the registry using `docker login`
* `$PASSWORD` is the password to use to log into the registry using `docker login`
* `$EMAIL` is the email to use to log into the registry using `docker login`


# Testing

If you want to test your app before building, create a `fig-test.yml` file in your repository root with a service called `sut` which will be run for testing. If that container exits successfully (exit code 0), the build will continue; otherwise, the build will fail and exit.

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
