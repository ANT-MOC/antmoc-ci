ARG SPACK_VERSION="0.21.2"
ARG SPACK_IMAGE="spack/ubuntu-jammy"
FROM ${SPACK_IMAGE}:${SPACK_VERSION} AS builder
ARG UBUNTU_CODE
ENV UBUNTU_CODE=${UBUNTU_CODE:-"jammy"}

LABEL maintainer="An Wang <wangan.cs@gmail.com>"

USER root
WORKDIR /tmp

#-------------------------------------------------------------------------------
# Install system compilers and libraries
#-------------------------------------------------------------------------------
# Register the ROCM package repository, and install rocm-dev package
ARG ROCM_VERSION=5.4.6
ARG AMDGPU_VERSION=5.4.6

# install LLVM and CMake for spack, and
# install ROCm HIP, see https://github.com/ROCm/ROCm-docker/blob/master/dev/Dockerfile-ubuntu-22.04
COPY etc/apt/ /etc/apt/
ARG APT_PREF="Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600"
RUN sed -i -e "s/jammy/$UBUNTU_CODE/g" /etc/apt/sources.list \
      && echo -e "$APT_PREF" | tee /etc/apt/preferences.d/rocm-pin-600 \
      && apt-get update \
      && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl libnuma-dev gnupg \
      && curl -sL https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add - \
      && printf "deb [arch=amd64] https://repo.radeon.com/rocm/apt/$ROCM_VERSION/ $UBUNTU_CODE main" | tee /etc/apt/sources.list.d/rocm.list \
      && printf "deb [arch=amd64] https://repo.radeon.com/amdgpu/$AMDGPU_VERSION/ubuntu $UBUNTU_CODE main" | tee /etc/apt/sources.list.d/amdgpu.list \
      && apt-get update \
      && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      sudo \
      libelf1 \
      kmod \
      file \
      python3 \
      python3-pip \
      rocm-dev \
      build-essential \
      llvm-14 clang-14 libomp-14-dev cmake openssh-server && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/*

#-------------------------------------------------------------------------------
# Set up spack
#-------------------------------------------------------------------------------
# set Spack paths which should be shared between docker stages
ENV SPACK_ROOT=/opt/spack
ENV CONFIG_DIR=/etc/spack
ENV INSTALL_DIR=/opt/software
ENV MIRROR_DIR=/opt/mirror
ENV REPO_DIR=/opt/repo

# create directories for Spack
RUN set -e; \
    mkdir -p $CONFIG_DIR; \
    mkdir -p $INSTALL_DIR; \
    mkdir -p $REPO_DIR; \
    mkdir -p $MIRROR_DIR

# copy a self-hosted spack repo to the image
COPY repo/ $REPO_DIR/

# hold a local package mirror as needed
COPY mirror/ $MIRROR_DIR/

# set the arch for packages
ARG TARGET="x86_64"

# generate configurations
RUN (echo "config:" \
    &&   echo "  install_tree:" \
    &&   echo "    root: $INSTALL_DIR" \
    &&   echo "  connect_timeout: 600") > $CONFIG_DIR/config.yaml \
    && (echo "mirrors:" \
        &&   echo "  local: file://$MIRROR_DIR") > $CONFIG_DIR/mirrors.yaml \
    && (echo "repos:" \
        &&   echo "  - $REPO_DIR") > $CONFIG_DIR/repos.yaml \
    && (echo "packages:" \
        &&   echo "  all:" \
        &&   echo "    target: [$TARGET]") > $CONFIG_DIR/packages.yaml

#-------------------------------------------------------------------------------
# Find system compilers
#-------------------------------------------------------------------------------
# find external packages and system compilers
RUN spack compiler find \
    && spack config get compilers > $CONFIG_DIR/compilers.yaml \
    && spack compiler list \
    && spack external find --scope system --not-buildable \
    gcc \
    llvm \
    autoconf \
    automake \
    cmake \
    gmake \
    libtool \
    perl

#-------------------------------------------------------------------------------
# Install dependencies for antmoc
#-------------------------------------------------------------------------------
# Compiler specs
ARG GCC_SPEC="gcc"
ARG CLANG_SPEC="clang"

# MPI specs
ARG MPICH_SPEC="mpich~fortran"
ARG OPENMPI_SPEC="openmpi"

RUN deps=(\
    "cmake %$GCC_SPEC" \
    "lcov@=2.0 %$GCC_SPEC" \
    "antmoc %$CLANG_SPEC ~mpi" \
    "antmoc %$CLANG_SPEC +mpi ^$MPICH_SPEC" \
    "antmoc %$GCC_SPEC ~mpi" \
    "antmoc %$GCC_SPEC +mpi ^$MPICH_SPEC" \
    "antmoc %$GCC_SPEC +mpi ^$OPENMPI_SPEC") \
    && for dep in "${deps[@]}"; do spack install -j $(nproc) --fail-fast -ny $dep; done \
    && spack gc -y && spack clean -a \
    && spack debug report && spack find -v # Check spack and dependency installation


#-------------------------------------------------------------------------------
# Add a user
#-------------------------------------------------------------------------------
# set user name
ARG USER_NAME=hpcer

# create the first user
RUN set -e; \
    \
    if ! id -u $USER_NAME &> /dev/null; then \
        useradd -m $USER_NAME; \
        echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    fi

# transfer control to the default user
USER $USER_NAME
WORKDIR /home/$USER_NAME

# generate a script for Spack
RUN (echo "#!/usr/bin/env bash" \
# &&   echo "export PATH=\$PATH:/opt/rocm/bin:/opt/rocm/rocprofiler/bin:/opt/rocm/opencl/bin" \
# &&   echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/hip/lib:/opt/rocm/llvm/lib:/opt/rocm/opencl/lib" \
# &&   echo "export INCLUDE=\$INCLUDE:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
# &&   echo "export C_INCLUDE_PATH=\$C_INCLUDE_PATH:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
# &&   echo "export CPLUS_INCLUDE_PATH=\$CPLUS_INCLUDE_PATH:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
&&   echo "export SPACK_ROOT=$SPACK_ROOT" \
&&   echo ". $SPACK_ROOT/share/spack/setup-env.sh" \
&&   echo "") > ~/setup-env.sh \
&&   chmod u+x ~/setup-env.sh

#-------------------------------------------------------------------------------
# Reset the entrypoint, add CMD
#-------------------------------------------------------------------------------
ENTRYPOINT ["/bin/bash"]
CMD ["interactive-shell"]

#-----------------------------------------------------------------------
# Build-time metadata as defined at http://label-schema.org
#-----------------------------------------------------------------------
ARG BUILD_DATE
ARG VCS_REF
ARG VCS_URL
LABEL org.label-schema.build-date=${BUILD_DATE} \
      org.label-schema.name="ANT-MOC CI image" \
      org.label-schema.description="Provides tools for ANT-MOC CI" \
      org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.vcs-url=${VCS_URL} \
      org.label-schema.schema-version="0.1"
