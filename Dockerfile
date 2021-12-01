ARG dpdk_version=20.11.3
ARG pktgen_version=20.11.3

FROM ubuntu:20.04 as build
ARG dpdk_version
ARG pktgen_version

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential python3-pip liblua5.3-dev \
  cmake wget libnuma-dev pciutils libpcap-dev libelf-dev linux-headers-generic \
  && pip3 install meson ninja pyelftools
#  cmake wget libnuma-dev pciutils libpcap-dev libelf-dev linux-headers-`uname -r` \

ENV DPDK_VER=$dpdk_version
ENV PKTGEN_VER=$pktgen_version
ENV RTE_SDK=/opt/dpdk-stable-$DPDK_VER
RUN echo DPDK_VER=${DPDK_VER}
RUN echo PKTGEN_VER=${PKTGEN_VER}

WORKDIR /opt

# downloading and unpacking DPDK
RUN wget -q https://fast.dpdk.org/rel/dpdk-$DPDK_VER.tar.xz && tar xf dpdk-$DPDK_VER.tar.xz

# build & install DPDK ...
RUN cd $RTE_SDK \
   && meson build \
   && ninja -C build \
   && ninja -C build install \
   && cp -r build/lib /usr/local/

# patch to make pktgen compile on arm. Got tip from
# https://medium.com/codex/nvidia-mellanox-bluefield-2-smartnic-dpdk-rig-for-dive-part-ii-change-mode-of-operation-a994f0f0e543
RUN sed -i 's/#  error Platform.*//' /usr/local/include/rte_spinlock.h
RUN sed -i 's/#  error Platform.*//' /usr/local/include/rte_atomic_32.h

# downlaod and unpack pktgen
RUN wget -q https://git.dpdk.org/apps/pktgen-dpdk/snapshot/pktgen-dpdk-pktgen-$PKTGEN_VER.tar.gz \
   && tar xf pktgen-dpdk-pktgen-$PKTGEN_VER.tar.gz

# building pktgen
RUN cd pktgen-dpdk-pktgen-$PKTGEN_VER \
      && tools/pktgen-build.sh clean \
      && tools/pktgen-build.sh buildlua \
      && cp -r usr/local /usr/ \
      && mkdir -p /usr/local/share/lua/5.3/ \
      && cp Pktgen.lua /usr/local/share/lua/5.3/

#####################################################
FROM ubuntu:20.04
ARG dpdk_version
ENV DPDK_VER=$dpdk_version

COPY --from=build /usr/local /usr/local/

RUN apt-get update \
  && apt-get -y --no-install-recommends install liblua5.3 libnuma-dev pciutils libpcap-dev python3 iproute2 \
  && ldconfig
