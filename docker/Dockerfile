FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    build-essential \
    git \
    ca-certificates \
    wget \
    curl \
    ccache \
    lcov \
    pkg-config \
    dpkg-dev \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    python3 \
    && rm -rf /var/lib/apt/lists/*

ENV CCACHE_DIR=/ccache
RUN mkdir -p /ccache && chmod 777 /ccache
ENV PATH="/usr/lib/ccache:${PATH}"

WORKDIR /workspace

CMD ["/bin/bash"]