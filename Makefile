#===============================================================================
# Default User Options
#===============================================================================

# Build-time arguments
UBUNTU_CODE   ?= "focal"
SPACK_VERSION ?= "0.21.2"
SPACK_IMAGE    = "spack/ubuntu-$(UBUNTU_CODE)"

# Target
TARGET ?= "x86_64"

# Image name
DOCKER_IMAGE ?= antmoc/antmoc-ci
DOCKER_TAG   := 0.1.16-a

# Default user
USER_NAME ?= hpcer

#===============================================================================
# Variables and objects
#===============================================================================

BUILD_DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_URL=$(shell git config --get remote.origin.url)

# Get the latest commit
GIT_COMMIT = $(strip $(shell git rev-parse --short HEAD))

#===============================================================================
# Targets to Build
#===============================================================================

.PHONY : docker_build docker_push output

default: build
build: docker_build output
release: docker_build docker_push output

docker_build:
	# Build Docker image
	docker build \
                 --build-arg UBUNTU_CODE=$(UBUNTU_CODE) \
                 --build-arg SPACK_VERSION=$(SPACK_VERSION) \
                 --build-arg SPACK_IMAGE=$(SPACK_IMAGE) \
                 --build-arg TARGET=$(TARGET) \
                 --build-arg BUILD_DATE=$(BUILD_DATE) \
                 --build-arg VCS_URL=$(VCS_URL) \
                 --build-arg VCS_REF=$(GIT_COMMIT) \
                 -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

docker_push:
	# Tag image as latest
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_IMAGE):latest

	# Push to DockerHub
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)
	docker push $(DOCKER_IMAGE):latest

output:
	@echo Docker Image: $(DOCKER_IMAGE):$(DOCKER_TAG)
