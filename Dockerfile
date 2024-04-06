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
      rocthrust-dev \
      build-essential
# set up AMD clang and install CMake for spack
RUN <<EOF bash
set -ex
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cmake \
    openssh-server
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -f /usr/bin/clang /usr/bin/clang++ &> /dev/null
ln -s /opt/rocm-${ROCM_VERSION}/llvm/bin/clang /usr/bin/clang
ln -s /opt/rocm-${ROCM_VERSION}/llvm/bin/clang++ /usr/bin/clang++
EOF

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
RUN <<EOF bash
set -ex
mkdir -p $CONFIG_DIR
mkdir -p $INSTALL_DIR
mkdir -p $REPO_DIR
mkdir -p $MIRROR_DIR
EOF

# copy a self-hosted spack repo to the image
COPY repo/ $REPO_DIR/

# hold a local package mirror as needed
COPY mirror/ $MIRROR_DIR/

# set the arch for packages
ARG TARGET="x86_64"

# generate configurations
COPY <<EOF $CONFIG_DIR/config.yaml
config:
  install_tree:
    root: $INSTALL_DIR
  connect_timeout: 600
EOF

COPY <<EOF $CONFIG_DIR/packages.yaml
packages:
  all:
    target: [$TARGET]
EOF

RUN <<EOF bash
set -ex
spack mirror add --scope system local $MIRROR_DIR
spack repo add --scope system $REPO_DIR
EOF


#-------------------------------------------------------------------------------
# Find system compilers
#-------------------------------------------------------------------------------
# manually add AMD clang to compilers, 'CLANG_VERSION' is a placeholder
COPY <<EOF $CONFIG_DIR/compilers.yaml
compilers:
- compiler:
    spec: clang@=CLANG_VERSION
    paths:
      cc: /usr/bin/clang
      cxx: /usr/bin/clang++
      f77: /usr/bin/gfortran
      fc: /usr/bin/gfortran
    flags: {}
    operating_system: ubuntu22.04
    target: x86_64
    modules: []
    environment: {}
    extra_rpaths: []
EOF

# find gcc and external packages
RUN <<EOF bash
set -ex
# substitute clang version with the correct one
sed -i -e "s/CLANG_VERSION/$(clang --version | grep -Po '(?<=version )[^ ]+')/g" $CONFIG_DIR/compilers.yaml
# find gcc
spack compiler find --scope system
spack compiler list
# find external packages
spack external find --scope system --not-buildable \
    autoconf \
    automake \
    cmake \
    gmake \
    libtool \
    openssh \
    perl \
    python
EOF


#-------------------------------------------------------------------------------
# Install dependencies for antmoc
#-------------------------------------------------------------------------------
# MPI specs
ARG MPICH_SPEC="mpich@=4.1.2~fortran"
ARG OPENMPI_SPEC="openmpi@=4.1.6"

# To avoid the default --reuse option of spack 0.21,
# add %clang and %gcc for every MPI spec.
RUN <<EOF bash
set -ex
deps=(\
    "cmake %gcc" \
    "lcov@=2.0 %gcc" \
    "antmoc %clang ~mpi" \
    "antmoc %clang +mpi ^$MPICH_SPEC %clang" \
    "antmoc %gcc ~mpi" \
    "antmoc %gcc +mpi ^$MPICH_SPEC %gcc" \
    "antmoc %gcc +mpi ^$OPENMPI_SPEC %gcc")
for dep in "\${deps[@]}";
do
    spack install -j \$(nproc) --fail-fast -ny \$dep
done
spack gc -y && spack clean -a
spack debug report
spack find -v # Check spack and dependency installation
EOF

#-------------------------------------------------------------------------------
# Add a user
#-------------------------------------------------------------------------------
# set user name
ARG USER_NAME=hpcer

# create the first user
RUN <<EOF bash
set -ex
if ! id -u $USER_NAME &> /dev/null; then
    useradd -m $USER_NAME
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi
EOF

# transfer control to the default user
USER $USER_NAME
WORKDIR /home/$USER_NAME

# generate a script for Spack
RUN (echo "export SPACK_ROOT=$SPACK_ROOT" \
&&   echo ". $SPACK_ROOT/share/spack/setup-env.sh" \
# &&   echo "export PATH=\$PATH:/opt/rocm/bin:/opt/rocm/rocprofiler/bin:/opt/rocm/opencl/bin" \
# &&   echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/hip/lib:/opt/rocm/llvm/lib:/opt/rocm/opencl/lib" \
# &&   echo "export INCLUDE=\$INCLUDE:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
# &&   echo "export C_INCLUDE_PATH=\$C_INCLUDE_PATH:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
# &&   echo "export CPLUS_INCLUDE_PATH=\$CPLUS_INCLUDE_PATH:/opt/rocm/include:/opt/rocm/hip/include:/opt/rocm/llvm/include" \
&&   echo "") > ~/.bashrc

#-------------------------------------------------------------------------------
# Reset the entrypoint and CMD
#-------------------------------------------------------------------------------
ENTRYPOINT ["/bin/bash", "-l"]
CMD []

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
