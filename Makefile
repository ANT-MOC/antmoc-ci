#===============================================================================
# Default User Options
#===============================================================================

# Build-time arguments
UBUNTU_CODE    ?= jammy
SPACK_VERSION  ?= 0.21.2
SPACK_IMAGE     = spack/ubuntu-$(UBUNTU_CODE)
ROCM_VERSION   ?= 5.4.6
AMDGPU_VERSION ?= 5.4.6

# Target
TARGET ?= x86_64

# Image name
DOCKER_IMAGE ?= antmoc/antmoc-ci
DOCKER_TAG   := 0.1.16-alpha

#===============================================================================
# Variables and objects
#===============================================================================

OCI_CREATED=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
OCI_SOURCE=$(shell git config --get remote.origin.url)

# Get the latest commit
GIT_COMMIT = $(strip $(shell git rev-parse --short HEAD))

#===============================================================================
# Targets to Build
#===============================================================================

.PHONY : build push output build_full push_full output_full

default: build
release: build push output
release_full: build_full push_full output_full

build:
	# Build Docker image
	docker build \
                 --build-arg UBUNTU_CODE=$(UBUNTU_CODE) \
                 --build-arg SPACK_VERSION=$(SPACK_VERSION) \
                 --build-arg SPACK_IMAGE=$(SPACK_IMAGE) \
                 --build-arg TARGET=$(TARGET) \
                 --build-arg OCI_CREATED=$(OCI_CREATED) \
                 --build-arg OCI_SOURCE=$(OCI_SOURCE) \
                 --build-arg OCI_REVISION=$(GIT_COMMIT) \
                 -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

push:
	# Tag image as latest
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_IMAGE):latest

	# Push to DockerHub
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)
	docker push $(DOCKER_IMAGE):latest

output:
	@echo Docker Image: $(DOCKER_IMAGE):$(DOCKER_TAG)

build_full:
	# Build Docker image with ROCm
	docker build \
                 --build-arg UBUNTU_CODE=$(UBUNTU_CODE) \
                 --build-arg SPACK_VERSION=$(SPACK_VERSION) \
                 --build-arg SPACK_IMAGE=$(SPACK_IMAGE) \
                 --build-arg TARGET=$(TARGET) \
                 --build-arg OCI_CREATED=$(OCI_CREATED) \
                 --build-arg OCI_SOURCE=$(OCI_SOURCE) \
                 --build-arg OCI_REVISION=$(GIT_COMMIT) \
								 -f ./Dockerfile-full \
                 -t $(DOCKER_IMAGE):$(DOCKER_TAG)-full .

push_full:
	# Push to DockerHub
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)-full

output_full:
	@echo Docker Image: $(DOCKER_IMAGE):$(DOCKER_TAG)-full
