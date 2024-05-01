#!/usr/bin/env bash

# Please make sure you are in the root directory of this git repo
MIRROR_DIR=$(pwd)/mirror
[ -d $MIRROR_DIR ] || mkdir $MIRROR_DIR

# Add a self-hosted repo
spack repo add repo/

# Copied from Dockerfile
GCC_SPEC="gcc"
CLANG_SPEC="clang"
MPICH_SPEC="mpich~fortran"
OPENMPI_SPEC="openmpi"

deps=(\
  "antmoc %$CLANG_SPEC +mpi ^$MPICH_SPEC" \
  "antmoc %$GCC_SPEC +mpi ^$MPICH_SPEC" \
  "antmoc %$GCC_SPEC +mpi ^$OPENMPI_SPEC")

for dep in "${deps[@]}"; do
  spack mirror create -D -d $MIRROR_DIR $dep
done
