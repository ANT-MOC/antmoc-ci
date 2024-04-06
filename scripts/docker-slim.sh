# See https://github.com/slimtoolkit/slim

IMAGE=${1:-"antmoc/antmoc-ci:0.1.16-alpha"}

# /opt is the largest directory
slim build --target $IMAGE \
  --mount $(pwd)/ant-moc:/opt/mnt/ant-moc \
  --http-probe=false \
  --show-clogs \
  --include-path /root \
  --include-path /home \
  --include-path /usr \
  --include-path /etc \
  --include-path /opt/spack \
  --include-path /opt/software \
  --include-path /opt/repo \
  --entrypoint /bin/bash \
  --exec-file ./scripts/build-antmoc.sh
