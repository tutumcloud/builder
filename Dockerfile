FROM ubuntu:trusty
MAINTAINER support@tutum.co

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -yq iptables apt-transport-https ca-certificates ssh git

# Docker-in-docker setup
ENV DOCKER_BUCKET=get.docker.com DOCKER_VERSION=1.8.2 DOCKER_SHA256=97a3f5924b0b831a310efa8bf0a4c91956cd6387c4a8667d27e2b2dd3da67e4d DIND_COMMIT=b8bed8832b77a478360ae946a69dab5e922b194e
ADD https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind /usr/local/bin/dind
ADD https://${DOCKER_BUCKET}/builds/Linux/x86_64/docker-$DOCKER_VERSION /usr/local/bin/docker
RUN echo "${DOCKER_SHA256}  /usr/local/bin/docker" | sha256sum -c - \
	&& chmod +x /usr/local/bin/docker && chmod +x /usr/local/bin/dind
VOLUME /var/lib/docker
# End docker-in-docker setup

# Store github.com SSH fingerprint
RUN mkdir -p ~/.ssh && ssh-keyscan -H github.com | tee -a ~/.ssh/known_hosts

ADD https://github.com/docker/compose/releases/download/1.3.3/docker-compose-linux-x86_64 /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

ENV GIT_CLONE_OPTS="--recursive"

ADD version_list /
ADD *.sh /
ENTRYPOINT ["/usr/local/bin/dind", "/run.sh"]
