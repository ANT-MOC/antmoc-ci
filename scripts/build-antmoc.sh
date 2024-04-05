#!/usr/bin/env bash
# For slim toolkit 1.40.11

sudo -Hi -u root bash << EOF
rm -f /usr/bin/clang /usr/bin/clang++
ln -s /usr/bin/clang-14 /usr/bin/clang
ln -s /usr/bin/clang++-14 /usr/bin/clang++
EOF

sudo -Hi -u hpcer bash << EOF
# Compilers in tuple (C compiler, C++ compiler, spack spec)
set -e
whoami

# Always mount ANT-MOC to this directory in containers
# -v ./ant-moc:/home/hpcer/ant-moc
cd \$HOME/ant-moc/

# Setup environment
source \$HOME/setup-env.sh
spack debug report

# Run tests
declare -A CCs=(
  ["gcc"]="gcc g++ %gcc" \
  ["clang"]="clang clang++ %clang" \
  ["hipcc"]="hipcc hipcc %gcc")

# MPI specs
declare -A MPIs=( \
  ["serial"]="~mpi" \
  ["mpich"]="+mpi^mpich" \
  ["openmpi"]="+mpi^openmpi")

for cc_id in "\${!CCs[@]}"; do
  declare -a cc=(\${CCs[\$cc_id]})
  for mpi in "\${!MPIs[@]}"; do
    C_COMPILER="\${cc[0]}"
    CXX_COMPILER="\${cc[1]}"
    USE_SPECS="antmoc \${cc[2]} \${MPIs[\$mpi]}"
    BUILD_TYPE=Release
    BUILD_SHARED_LIBS=ON
    ENABLE_TESTS=ON

    # Enable MPI or not
    if [ \$mpi == "serial" ]; then
      ENABLE_MPI=OFF
      CTEST_RANDOM=ON
    else
      ENABLE_MPI=ON
      CTEST_RANDOM=OFF
    fi

    # Enable HIP or not
    if [ \${cc[0]} == "hipcc" ]; then
      ENABLE_HIP=ON
    else
      ENABLE_HIP=OFF
    fi

    # Load dependencies
    spack load cmake%gcc \$USE_SPECS
    spack find --loaded

    rm -rf build/ &> /dev/null

    # Build ANT-MOC
    cmake -S . -B build \
      -DCMAKE_C_COMPILER=\$C_COMPILER \
      -DCMAKE_CXX_COMPILER=\$CXX_COMPILER \
      -DCMAKE_BUILD_TYPE=\$BUILD_TYPE \
      -DBUILD_SHARED_LIBS:BOOL=\$BUILD_SHARED_LIBS \
      -DENABLE_TESTS:BOOL=\$ENABLE_TESTS \
      -DENABLE_MPI:BOOL=\$ENABLE_MPI \
      -DENABLE_HIP:BOOL=\$ENABLE_HIP

    cmake --build build -j\$(nproc)

    if [ ! \${cc[0]} == "hipcc" ]; then
      ARGS="--output-on-failure"
      if [ "\$CTEST_RANDOM" == "ON" ]; then ARGS="\$ARGS --schedule-random"; fi
      cd build/
      # Exclude broken tests
      # FIXME: these tests are broken on Ubuntu jammy but work on Ubuntu focal
      ctest \$ARGS -E unit_test_initialize*
    fi
  done
done
EOF