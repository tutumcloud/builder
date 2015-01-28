FROM tutum/dind:latest
MAINTAINER fernando@tutum.co

RUN apt-get update && apt-get install -y curl && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -L https://github.com/docker/fig/releases/download/1.0.1/fig-`uname -s`-`uname -m` > /usr/local/bin/fig && chmod +x /usr/local/bin/fig

ADD build.sh /

CMD ["/build.sh"]