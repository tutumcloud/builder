FROM tutum/dind:latest
MAINTAINER fernando@tutum.co

# Env vars to be set at runtime
ENV GIT_REPO https://github.com/tutumcloud/docker-hello-world.git
ENV IMAGE_NAME tutum/hello-world:latest
ENV USERNAME tutum
ENV PASSWORD password
ENV EMAIL info@tutum.co

ADD build.sh /

CMD ["/build.sh"]