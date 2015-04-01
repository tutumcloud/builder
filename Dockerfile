FROM jpetazzo/dind:latest
MAINTAINER fernando@tutum.co

RUN apt-get update && apt-get install -y curl && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -L https://github.com/docker/compose/releases/download/1.1.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

ADD build.sh /

CMD ["/build.sh"]