FROM nginx:alpine

RUN set -ex && \
	apk add --no-cache bash \
    openssl \
    python3 \
    py3-pip \
    certbot \
    busybox-openrc \
    openrc

ARG AUTO_RENEW=1
ENV AUTO_RENEW=$AUTO_RENEW

COPY cronjob-renew.sh docker-entrypoint.sh /

RUN mkdir -p /nginx-config
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/bin/bash", "-c", "/docker-entrypoint.sh"]