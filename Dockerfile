FROM jpetazzo/dind:latest
MAINTAINER support@tutum.co

# Store github.com SSH fingerprint
RUN mkdir -p ~/.ssh && ssh-keyscan -H github.com | tee -a ~/.ssh/known_hosts

ADD https://github.com/docker/compose/releases/download/1.3.3/docker-compose-linux-x86_64 /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

ENV GIT_CLONE_OPTS="--recursive"

ADD version_list /
ADD *.sh /
ENTRYPOINT ["/run.sh"]
