FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    ca-certificates \
    ccache \
    lcov \
    perl \
    pkg-config \
    dpkg-dev \
    binutils \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    python3 \
  && rm -rf /var/lib/apt/lists/*

# ccache (persist via volume mount from host if desired)
ENV CCACHE_DIR=/ccache
RUN mkdir -p /ccache && chmod 777 /ccache
ENV PATH="/usr/lib/ccache:${PATH}"

WORKDIR /workspace
CMD ["/bin/bash"]