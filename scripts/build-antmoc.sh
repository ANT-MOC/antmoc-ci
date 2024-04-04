#!/usr/bin/env bash
sudo -Hi -u root bash << EOF
source /home/hpcer/setup-env.sh
spack uninstall -fy fmt%gcc
spack install -ny googletest@=1.10.0+gmock %gcc
spack install -ny fmt@=8.0.0 %gcc
EOF
sudo -Hi -u hpcer bash << EOF
set -e
whoami

# Always mount ANT-MOC to this directory in containers
# -v ./ant-moc:/home/hpcer/ant-moc
cd \$HOME/ant-moc/

# Setup environment
source ~/setup-env.sh
spack debug report

# Setup variables
C_COMPILER="gcc"
CXX_COMPILER="g++"
BUILD_TYPE="Release"
BUILD_SHARED_LIBS="ON"
ENABLE_MPI="OFF"
ENABLE_HIP="OFF"
ENABLE_TESTS="ON"
CTEST_RANDOM="ON"
USE_SPECS="antmoc %gcc ~mpi"

# Build ANT-MOC
spack load cmake%gcc \
cxxopts%gcc \
fmt@=8.0.0%gcc \
tinyxml2%gcc \
toml11%gcc \
hdf5~mpi%gcc \
googletest%gcc
spack find --loaded

#cmake -S . -B build \
#  -DCMAKE_C_COMPILER=\$C_COMPILER \
#  -DCMAKE_CXX_COMPILER=\$CXX_COMPILER \
#  -DCMAKE_BUILD_TYPE=\$BUILD_TYPE \
#  -DBUILD_SHARED_LIBS:BOOL=\$BUILD_SHARED_LIBS \
#  -DENABLE_TESTS:BOOL=\$ENABLE_TESTS \
#  -DENABLE_MPI:BOOL=\$ENABLE_MPI \
#  -DENABLE_HIP:BOOL=\$ENABLE_HIP
#
#cmake --build build -j
#
#ARGS="--output-on-failure"
#if [ "\$CTEST_RANDOM" == "ON" ]; then ARGS="\$ARGS --schedule-random"; fi
#cd build/
#ctest \$ARGS

EOF
