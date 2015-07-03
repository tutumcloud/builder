FROM jpetazzo/dind:latest
MAINTAINER support@tutum.co

ADD https://github.com/docker/compose/releases/download/1.2.0/docker-compose-linux-x86_64 /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

ADD version_list /
ADD build.sh /
ENTRYPOINT ["/build.sh"]
