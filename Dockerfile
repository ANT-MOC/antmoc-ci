#===============================================================================
# Stage 1: build packages
#===============================================================================
ARG SPACK_IMAGE="spack/ubuntu-bionic"
ARG SPACK_VERSION="v0.17.1"
FROM ${SPACK_IMAGE}:${SPACK_VERSION} AS builder

#-------------------------------------------------------------------------------
# Set up environments
#-------------------------------------------------------------------------------
USER root
WORKDIR /tmp

# set Spack paths which should be shared between docker stages
ARG SPACK_ROOT=/opt/spack
ARG CONFIG_DIR=/etc/spack
ARG INSTALL_DIR=/opt/software
ARG MIRROR_DIR=/opt/mirror
ARG REPO_DIR=/opt/repo

# create directories for Spack
RUN set -e; \
    mkdir -p $CONFIG_DIR; \
    mkdir -p $INSTALL_DIR; \
    mkdir -p $MIRROR_DIR

# copy files from the context to the image
COPY etc/apt/ /etc/apt/
#COPY mirror/ $MIRROR_DIR/
COPY repo/ $REPO_DIR/

# set the arch for packages
ARG TARGET="x86_64"

# generate configurations
RUN (echo "config:" \
&&   echo "  install_tree:" \
&&   echo "    root: $INSTALL_DIR" \
&&   echo "  connect_timeout: 0") > $CONFIG_DIR/config.yaml

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
# install apt repositries
RUN apt-get update && apt-get install -y \
        apt-transport-https \
        ca-certificates \
        gnupg \
        software-properties-common \
        wget \
&&  wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
    gpg --dearmor - | \
    tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null \
&&  apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main'

# install LLVM and CMake
RUN apt-get update && apt-get install -y \
        llvm-9 \
        clang-9 \
        libomp-9-dev \
        cmake

# find external packages
RUN spack external find --scope system --not-buildable \
        gcc \
        llvm \
        autoconf \
        automake \
        cmake \
        libtool \
        perl

# find system gcc and clang
RUN spack compiler find; \
    spack config get compilers > $CONFIG_DIR/compilers.yaml; \
    spack compilers

#-------------------------------------------------------------------------------
# Install dependencies for antmoc
#-------------------------------------------------------------------------------
# Compiler specs
ARG GCC_SPEC="gcc"
ARG CLANG_SPEC="clang"

# MPI specs
ARG MPICH_SPEC="mpich~fortran"
ARG OPENMPI_SPEC="openmpi"

RUN spack mirror create -D -d $MIRROR_DIR cmake %$GCC_SPEC \
&&  spack install --fail-fast -ny --reuse cmake %$GCC_SPEC
RUN spack mirror create -D -d $MIRROR_DIR lcov@1.14 %$GCC_SPEC \
&&  spack install --fail-fast -ny --reuse lcov@1.14 %$GCC_SPEC
RUN spack mirror create -D -d $MIRROR_DIR antmoc %$CLANG_SPEC ~mpi \
&&  spack install --fail-fast -ny --reuse antmoc %$CLANG_SPEC ~mpi
RUN spack mirror create -D -d $MIRROR_DIR antmoc %$CLANG_SPEC +mpi ^$MPICH_SPEC \
&&  spack install --fail-fast -ny --reuse antmoc %$CLANG_SPEC +mpi ^$MPICH_SPEC
RUN spack mirror create -D -d $MIRROR_DIR antmoc %$GCC_SPEC ~mpi \
&&  spack install --fail-fast -ny --reuse antmoc %$GCC_SPEC ~mpi
RUN spack mirror create -D -d $MIRROR_DIR antmoc %$GCC_SPEC +mpi ^$MPICH_SPEC \
&&  spack install --fail-fast -ny --reuse antmoc %$GCC_SPEC +mpi ^$MPICH_SPEC
RUN spack mirror create -D -d $MIRROR_DIR antmoc %$GCC_SPEC +mpi ^$OPENMPI_SPEC \
&&  spack install --fail-fast -ny --reuse antmoc %$GCC_SPEC +mpi ^$OPENMPI_SPEC
RUN spack gc -y && spack clean -a


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
ARG CONFIG_DIR=/etc/spack
ARG INSTALL_DIR=/opt/software
ARG REPO_DIR=/opt/repo

COPY --from=builder $CONFIG_DIR $CONFIG_DIR
COPY --from=builder $INSTALL_DIR $INSTALL_DIR
COPY --from=builder $REPO_DIR $REPO_DIR

#-------------------------------------------------------------------------------
# Install system packages
#-------------------------------------------------------------------------------
# install apt repositries
COPY etc/apt/ /etc/apt/
RUN apt-get update && apt-get install -y \
        apt-transport-https \
        ca-certificates \
        gnupg \
        software-properties-common \
        wget \
&&  wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
    gpg --dearmor - | \
    tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null \
&&  apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main' \
    \
&&  wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | \
    apt-key add - \
&&  echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ xenial main' | \
    tee /etc/apt/sources.list.d/rocm.list

# install CMake, LLVM, and ROCm
RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        clang-9 \
        llvm-9 \
        libomp-9-dev \
        kmod \
        openssh-server \
        sudo \
        rocm-dev \
        rocthrust \
&&  rm -f /usr/bin/clang /usr/bin/clang++ \
&&  ln -s /usr/bin/clang-9 /usr/bin/clang \
&&  ln -s /usr/bin/clang++-9 /usr/bin/clang++ \
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
