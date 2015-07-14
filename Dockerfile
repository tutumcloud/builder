FROM jpetazzo/dind:latest
MAINTAINER support@tutum.co

# Store github.com SSH fingerprint
RUN mkdir -p ~/.ssh && ssh-keyscan -H github.com | tee -a ~/.ssh/known_hosts

ADD https://github.com/docker/compose/releases/download/1.2.0/docker-compose-linux-x86_64 /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose


ADD version_list /
ADD build.sh /
ENTRYPOINT ["/build.sh"]
