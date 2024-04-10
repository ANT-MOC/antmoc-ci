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
[ -d \$WORKDIR ] && rm -rf \$WORKDIR && mkdir \$WORKDIR

# Always mount ANT-MOC to this directory in containers
# -v ./ant-moc:/opt/mnt/ant-moc
cp -r /opt/mnt/ant-moc/. \$WORKDIR/
cd \$WORKDIR

# Always mount scripts to this directory
# -v ./scripts:/opt/mnt/scripts
GENERATOR=/opt/mnt/scripts/generate-test.py

# Test cases
# declare -a TESTS=( \
#   "gcc serial run" "gcc mpich run" "gcc openmpi run" \
#   "clang serial run" "clang mpich run" \
#   "hipcc serial build" "hipcc mpich build" "hipcc openmpi build" )
declare -a TESTS=( \
  "gcc serial install" "gcc mpich install" "gcc openmpi install" \
  "clang serial install" "clang mpich install" )

# Run tests
for jobspec in "\${TESTS[@]}"; do
  bash << EOF1
  \$(python3 \${GENERATOR} --job "\${jobspec}")
EOF1
done

cd && rm -rf \$WORKDIR
EOF