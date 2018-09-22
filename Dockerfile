FROM ubuntu:16.04 AS builder

ENV BUILD_TAG 1.10.0

RUN apt update
RUN apt install -y --no-install-recommends \
  autoconf \
  automake \
  build-essential \
  ca-certificates \
  libboost-chrono-dev \
  libboost-filesystem-dev \
  libboost-program-options-dev \
  libboost-system-dev \
  libboost-thread-dev \
  libczmq-dev \
  libevent-dev \
  libssl-dev \
  libtool \
  pkg-config \
  wget

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


FROM ubuntu:16.04

RUN apt update \
  && apt install -y --no-install-recommends \
    libboost-chrono1.58.0 \
    libboost-filesystem1.58.0 \
    libboost-program-options1.58.0 \
    libboost-system1.58.0 \
    libboost-thread1.58.0 \
    libczmq-dev \
    libevent-dev \
    libssl-dev \
  && apt clean \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /dogecoin/src/dogecoind /dogecoin/src/dogecoin-cli /usr/local/bin/

RUN groupadd --gid 1000 dogecoind \
  && useradd --uid 1000 --gid dogecoind --shell /bin/bash --create-home dogecoind

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
