docker-builder
==============

An image that builds a git repository and pushes the resulting image to any public or private registry, all within a container.


# Usage

Run the following docker command:

	docker run --rm --privileged -e GIT_REPO=$GIT_REPO -e IMAGE_NAME=$IMAGE_NAME -e USERNAME=$USERNAME -e PASSWORD=$PASSWORD -e EMAIL=$EMAIL tutum/docker-builder

Where:

* `$GIT_REPO` is the git repository to clone and build, i.e. `https://github.com/tutumcloud/docker-hello-world.git`
* `$IMAGE_NAME` is the name of the image to create with an optional tag, i.e. `tutum/hello-world:latest`
* `$USERNAME` is the username to use to log into the registry using `docker login`
* `$PASSWORD` is the password to use to log into the registry using `docker login`
* `$EMAIL` is the email to use to log into the registry using `docker login`
