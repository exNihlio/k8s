FROM ubuntu:20.04

WORKDIR /root

RUN apt-get update \
    && apt-get -y install python3 git ansible \
    && mkdir -p /root/vars

COPY * /root/

COPY ./vars /root/vars/