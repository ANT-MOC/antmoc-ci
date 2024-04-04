#===============================================================================
# Stage 1: build packages
#===============================================================================
ARG SPACK_VERSION="0.21.2"
ARG SPACK_IMAGE="spack/ubuntu-focal"
FROM ${SPACK_IMAGE}:${SPACK_VERSION} AS builder
ARG UBUNTU_CODE
ENV UBUNTU_CODE=${UBUNTU_CODE:-"focal"}

#-------------------------------------------------------------------------------
# Set up environments
#-------------------------------------------------------------------------------
USER root
WORKDIR /tmp

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
#COPY mirror/ $MIRROR_DIR/

# update source list
COPY etc/apt/ /etc/apt/
RUN sed -i -e "s/focal/$UBUNTU_CODE/g" /etc/apt/sources.list

# set the arch for packages
ARG TARGET="x86_64"

# generate configurations
RUN (echo "config:" \
&&   echo "  install_tree:" \
&&   echo "    root: $INSTALL_DIR" \
&&   echo "  connect_timeout: 600") > $CONFIG_DIR/config.yaml

RUN (echo "mirrors:" \
&&   echo "  local: file://$MIRROR_DIR") > $CONFIG_DIR/mirrors.yaml

RUN (echo "repos:" \
&&   echo "  - $REPO_DIR") > $CONFIG_DIR/repos.yaml

RUN (echo "packages:" \
&&   echo "  all:" \
&&   echo "    target: [$TARGET]") > $CONFIG_DIR/packages.yaml

#-------------------------------------------------------------------------------
# Find or install compilers
#-------------------------------------------------------------------------------
# install LLVM and CMake
RUN apt-get update && apt-get install -y \
        llvm-10 \
        clang-10 \
        libomp-10-dev \
        cmake

# find external packages
RUN spack external find --scope system --not-buildable \
        gcc \
        llvm \
        autoconf \
        automake \
        cmake \
        gmake \
        libtool \
        perl

# find system gcc and clang
RUN spack compiler find; \
    spack config get compilers > $CONFIG_DIR/compilers.yaml; \
    spack compiler list

#-------------------------------------------------------------------------------
# Install dependencies for antmoc
#-------------------------------------------------------------------------------
# Compiler specs
ARG GCC_SPEC="gcc"
ARG CLANG_SPEC="clang"

# MPI specs
ARG MPICH_SPEC="mpich~fortran"
ARG OPENMPI_SPEC="openmpi"

RUN deps=("cmake %$GCC_SPEC" \
    "lcov@=2.0 %$GCC_SPEC" \
    "antmoc %$CLANG_SPEC ~mpi" \
    "antmoc %$CLANG_SPEC +mpi ^$MPICH_SPEC" \
    "antmoc %$GCC_SPEC ~mpi" \
    "antmoc %$GCC_SPEC +mpi ^$MPICH_SPEC" \
    "antmoc %$GCC_SPEC +mpi ^$OPENMPI_SPEC") \
    && for dep in "${deps[@]}"; do spack install --fail-fast -ny $dep; done
RUN spack gc -y && spack clean -a

# Check spack and dependency installation
RUN spack debug report && spack find -v


#===============================================================================
# Stage 2: build the runtime environment
#===============================================================================
ARG SPACK_IMAGE
ARG SPACK_VERSION
FROM ${SPACK_IMAGE}:${SPACK_VERSION}

LABEL maintainer="An Wang <wangan.cs@gmail.com>"

#-------------------------------------------------------------------------------
# Copy artifacts from stage 1 to stage 2
#-------------------------------------------------------------------------------
COPY --from=builder $CONFIG_DIR $CONFIG_DIR
COPY --from=builder $INSTALL_DIR $INSTALL_DIR
COPY --from=builder $REPO_DIR $REPO_DIR

#-------------------------------------------------------------------------------
# Install system packages
#-------------------------------------------------------------------------------
# install apt repositries
COPY etc/apt/ /etc/apt/

# install CMake, LLVM, and ROCm
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        cmake \
        clang-10 \
        llvm-10 \
        libomp-10-dev \
        kmod \
        openssh-server \
        sudo \
&&  rm -f /usr/bin/clang /usr/bin/clang++ \
&&  ln -s /usr/bin/clang-10 /usr/bin/clang \
&&  ln -s /usr/bin/clang++-10 /usr/bin/clang++ \
&&  rm -rf /var/lib/apt/lists/*

#-------------------------------------------------------------------------------
# Add a user
#-------------------------------------------------------------------------------
# set user name
ARG USER_NAME=hpcer

# create the first user
RUN set -e; \
    \
    if ! id -u $USER_NAME > /dev/null 2>&1; then \
        useradd -m $USER_NAME; \
        echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    fi

# transfer control to the default user
USER $USER_NAME
WORKDIR /home/$USER_NAME

# generate a script for Spack
RUN (echo "#!/usr/bin/env bash" \
&&   echo "export PATH=\$PATH:/opt/rocm/bin:/opt/rocm/rocprofiler/bin:/opt/rocm/opencl/bin" \
&&   echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/hip/lib:/opt/rocm/llvm/lib:/opt/rocm/opencl/lib" \
&&   echo "export INCLUDE=\$INCLUDE:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
&&   echo "export C_INCLUDE_PATH=\$C_INCLUDE_PATH:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
&&   echo "export CPLUS_INCLUDE_PATH=\$CPLUS_INCLUDE_PATH:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
&&   echo "export SPACK_ROOT=$SPACK_ROOT" \
&&   echo ". $SPACK_ROOT/share/spack/setup-env.sh" \
&&   echo "") > ~/setup-env.sh \
&&   chmod u+x ~/setup-env.sh

#-------------------------------------------------------------------------------
# Reset the entrypoint
#-------------------------------------------------------------------------------
ENTRYPOINT []
CMD ["/bin/bash"]


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
