IMAGE=antmoc/antmoc-ci:0.1.16-alpha

slim build --target $IMAGE \
  --mount $(pwd)/ant-moc:/home/hpcer/ant-moc \
  --mount $(pwd)/scripts:/home/hpcer/scripts \
  --http-probe=false \
  --show-clogs \
  --include-path /opt/spack \
  --include-path /etc/spack \
  --include-path /opt/software \
  --include-path /opt/repo \
  --entrypoint /bin/bash \
  --exec-file ./scripts/build-antmoc.sh
