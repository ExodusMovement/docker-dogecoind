FROM alpine:3.8 AS builder

ENV BUILD_TAG 1.10.0

RUN apk add --no-cache \
    autoconf \
    automake \
    build-base \
    openssl-dev \
    libevent-dev \
    libtool \
    linux-headers \
    zeromq-dev

RUN wget -O- https://dl.bintray.com/boostorg/release/1.65.0/source/boost_1_65_0.tar.gz | tar xz
RUN cd /boost_1_65_0 \
  && ./bootstrap.sh --with-libraries=chrono,filesystem,program_options,system,thread \
  && ./b2 install link=shared -j$(nproc)

RUN wget -O- https://github.com/dogecoin/dogecoin/archive/v$BUILD_TAG.tar.gz | tar xz && mv /dogecoin-$BUILD_TAG /dogecoin
WORKDIR /dogecoin

RUN ./autogen.sh
RUN ./configure \
  --disable-shared \
  --disable-static \
  --disable-wallet \
  --disable-tests \
  --disable-bench \
  --enable-zmq \
  --with-utils \
  --without-libs \
  --without-gui
RUN make -j$(nproc)
RUN strip src/dogecoind src/dogecoin-cli


FROM alpine:3.8

RUN apk add --no-cache \
  openssl \
  libevent \
  zeromq

COPY --from=builder /usr/local/lib/libboost_* /usr/local/lib/
COPY --from=builder /dogecoin/src/dogecoind /dogecoin/src/dogecoin-cli /usr/local/bin/

RUN addgroup -g 1000 dogecoind \
  && adduser -u 1000 -G dogecoind -s /bin/sh -D dogecoind

USER dogecoind

# P2P & RPC
EXPOSE 22556 8332

ENV \
  DOGECOIND_DBCACHE=100 \
  DOGECOIND_PAR=0 \
  DOGECOIND_PORT=22556 \
  DOGECOIND_RPC_PORT=8332 \
  DOGECOIND_RPC_THREADS=4 \
  DOGECOIND_ARGUMENTS=""

CMD exec dogecoind \
  -dbcache=$DOGECOIND_DBCACHE \
  -par=$DOGECOIND_PAR \
  -port=$DOGECOIND_PORT \
  -rpcport=$DOGECOIND_RPC_PORT \
  -rpcthreads=$DOGECOIND_RPC_THREADS \
  $DOGECOIND_ARGUMENTS
