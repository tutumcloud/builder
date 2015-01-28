FROM tutum/dind:latest
MAINTAINER fernando@tutum.co

RUN apt-get update && apt-get install -y curl && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -L https://github.com/docker/fig/releases/download/1.0.1/fig-`uname -s`-`uname -m` > /usr/local/bin/fig && chmod +x /usr/local/bin/fig

ENV GIT_REPO https://github.com/tutumcloud/docker-hello-world.git
ENV GIT_TAG master
ENV DOCKERFILE_PATH /
ENV IMAGE_NAME tutum/hello-world:latest
ENV USERNAME tutum
ENV PASSWORD password
ENV EMAIL info@tutum.co

ADD build.sh /

CMD ["/build.sh"]