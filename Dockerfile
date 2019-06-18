FROM node:10.15.3-alpine as builder

ENV NODE_ENV=production \
    VERDACCIO_BUILD_REGISTRY=https://registry.npmjs.org

RUN apk --no-cache add openssl ca-certificates wget && \
    apk --no-cache add g++ gcc libgcc libstdc++ linux-headers make python && \
    wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-2.25-r0.apk && \
    apk add glibc-2.25-r0.apk

WORKDIR /opt/verdaccio-build
COPY . .

RUN yarn config set registry $VERDACCIO_BUILD_REGISTRY && \
    yarn install --production=false --no-lockfile && \
    yarn lint && \
    yarn code:docker-build && \
    yarn cache clean && \
    yarn install --production=true --no-lockfile



FROM node:10.15.3-alpine
LABEL maintainer="https://github.com/verdaccio/verdaccio"

ENV VERDACCIO_APPDIR=/opt/verdaccio \
    VERDACCIO_PORT=4873 \
    VERDACCIO_PROTOCOL=http
ENV PATH=$VERDACCIO_APPDIR/docker-bin:$PATH \
    HOME=$VERDACCIO_APPDIR

WORKDIR $VERDACCIO_APPDIR

RUN apk --no-cache add openssl dumb-init

RUN mkdir -p /verdaccio/storage /verdaccio/plugins /verdaccio/conf

COPY --from=builder /opt/verdaccio-build .

ADD conf/docker.yaml /verdaccio/conf/config.yaml

RUN chmod -R +x $VERDACCIO_APPDIR/bin $VERDACCIO_APPDIR/docker-bin

EXPOSE $VERDACCIO_PORT

VOLUME /verdaccio/storage

ENTRYPOINT ["uid_entrypoint"]

CMD $VERDACCIO_APPDIR/bin/verdaccio --config /verdaccio/conf/config.yaml --listen $VERDACCIO_PROTOCOL://0.0.0.0:$VERDACCIO_PORT
