FROM ubuntu:20.04

ARG GOSS_VERSION='v0.3.10'

WORKDIR /code

ADD --chown=root:root https://github.com/aelsabbahy/goss/releases/download/${GOSS_VERSION}/goss-linux-amd64 /bin/goss

RUN apt-get update \
    && apt-get -y install python3-pip python3 git ansible \
    && chmod 755 /bin/goss
