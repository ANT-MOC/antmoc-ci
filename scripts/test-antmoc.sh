# For slim toolkit 1.40.11
sudo -Hi bash -i << EOF
set -e
whoami
env

# Setup environment
. ~/setup-env.sh
spack debug report
spack find -v antmoc

WORKDIR=/tmp/ant-moc
[ -d \$WORKDIR ] && rm -rf \$WORKDIR
mkdir \$WORKDIR

# Always mount ANT-MOC to this directory in containers
# -v ./ant-moc:/opt/mnt/ant-moc
cp -r /opt/mnt/ant-moc/. \$WORKDIR/
cd \$WORKDIR

# Compilers in tuple (C compiler, C++ compiler, spack spec)
declare -A COMPILERS=( \
  ["gcc"]="gcc g++ %gcc" \
  ["clang"]="clang clang++ %clang" \
  ["hipcc"]="hipcc hipcc %gcc")

# MPI specs
declare -A MPIS=( \
  ["serial"]="~mpi" \
  ["mpich"]="+mpi^mpich" \
  ["openmpi"]="+mpi^openmpi")

# Test cases
# declare -a TESTS=( \
#   "gcc serial run" "gcc mpich run" "gcc openmpi run" \
#   "clang serial run" "clang mpich run" \
#   "hipcc serial build" "hipcc mpich build" "hipcc openmpi build" )
declare -a TESTS=( \
  "gcc serial run" "gcc mpich run" "gcc openmpi run" \
  "clang serial run" "clang mpich run" )

# Run tests
for s in "\${TESTS[@]}"; do
  cd \$WORKDIR

  declare -a test=(\${s[@]})
  declare -a cc=(\${COMPILERS[\${test[0]}]})
  mpi=\${test[1]}
  stage=\${test[2]}

  echo "\${cc[@]} \$mpi \$stage"

  C_COMPILER="\${cc[0]}"
  CXX_COMPILER="\${cc[1]}"
  USE_SPECS="antmoc \${cc[2]} \${MPIS[\$mpi]}"
  BUILD_TYPE=Release
  BUILD_SHARED_LIBS=ON
  ENABLE_ALL_WARNINGS=OFF

  # Enable tests
  if [ \$stage == "run" ]; then
    ENABLE_TESTS=ON
  else
    ENABLE_TESTS=OFF
  fi

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
  spack unload --all
  spack load cmake%gcc \$USE_SPECS
  spack find --loaded

  rm -rf build/ &> /dev/null

  # Build ANT-MOC
  cmake -S . -B build \
    -DCMAKE_C_COMPILER=\$C_COMPILER \
    -DCMAKE_CXX_COMPILER=\$CXX_COMPILER \
    -DCMAKE_BUILD_TYPE=\$BUILD_TYPE \
    -DBUILD_SHARED_LIBS:BOOL=\$BUILD_SHARED_LIBS \
    -DENABLE_ALL_WARNINGS=\$ENABLE_ALL_WARNINGS \
    -DENABLE_TESTS:BOOL=\$ENABLE_TESTS \
    -DENABLE_MPI:BOOL=\$ENABLE_MPI \
    -DENABLE_HIP:BOOL=\$ENABLE_HIP

  echo -e "Building ANT-MOC..."
  cmake --build build -j\$(nproc)

  if [ \$stage == "run" ]; then
    ARGS="--output-on-failure"
    if [ "\$CTEST_RANDOM" == "ON" ]; then ARGS="\$ARGS --schedule-random"; fi
    cd build/
    ctest \$ARGS
  fi
done

cd
rm -rf \$WORKDIR
EOF