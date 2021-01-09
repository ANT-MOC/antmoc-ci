ANT-MOC CI
==========

[![Commit](https://images.microbadger.com/badges/commit/antmoc/antmoc-ci.svg)](https://github.com/antmoc-bot/antmoc-ci)
[![Version](https://images.microbadger.com/badges/version/antmoc/antmoc-ci.svg)](https://hub.docker.com/repository/docker/antmoc/antmoc-ci)
[![Docker Pulls](https://img.shields.io/docker/pulls/antmoc/antmoc-ci?color=informational)](https://hub.docker.com/repository/docker/antmoc/antmoc-ci)
[![Layers](https://images.microbadger.com/badges/image/antmoc/antmoc-ci.svg)](https://microbadger.com/images/antmoc/antmoc-ci)
[![Automated Build](https://img.shields.io/docker/automated/antmoc/antmoc-ci)](https://hub.docker.com/repository/docker/antmoc/antmoc-ci)

This project provides official ANT-MOC CI images starting from v0.1.15.

## Supported tags

- `latest`
- `0.1.15`

> Legacy images (before v0.1.15) could be found at
>
> - DockerHub: [leavesask/antmoc-ci](https://hub.docker.com/r/leavesask/antmoc-ci)
> - GitHub: [docker-antmoc-ci](https://github.com/alephpiece/docker-antmoc-ci)

## How to use

1. [Install docker engine](https://docs.docker.com/install/)

2. Pull the image
  ```bash
  docker pull antmoc/antmoc-ci:<tag>
  ```

3. Run the image interactively
  ```bash
  docker run -it --rm antmoc/antmoc-ci:<tag>
  ```

## How to build

The base image is [Spack](https://hub.docker.com/r/spack).

### make

It is highly recommended that you build the image with `make`.

```bash
# Build an image for code coverage
make

# Build and publish the image
make release
```

### docker build

As an alternative, you can build the image with `docker build` command.

```bash
docker build \
        --build-arg SPACK_IMAGE="spack/ubuntu-bionic" \
        --build-arg SPACK_VERSION="latest" \
        --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
        --build-arg VCS_REF=$(git rev-parse --short HEAD) \
        -t antmoc/antmoc-ci:latest .
```

