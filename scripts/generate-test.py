#!/usr/bin/env python3
# -------------------------------------------------------------------------------
# Preparing
#
# This script depends on Spack to validate specs. Jobs will be generated only
# for valid specs.
# -------------------------------------------------------------------------------
import sys, getopt

# parse command line arguments
opts, args = getopt.getopt(sys.argv[1:], "h", ["job="])

for name, value in opts:
    if name == "--job":
        job_spec = value

# -------------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------------
# tuples for (CXX compiler, compiler specs)
cc_specs = {
    "gcc": ("g++", "%gcc"),
    "clang": ("clang++", "%clang"),
    "hipcc": ("hipcc", "%gcc"),
}

# mpi specs
mpi_specs = {"serial": "~mpi", "mpich": "+mpi^mpich", "openmpi": "+mpi^openmpi"}


def on_off(bool_value):
    return "ON" if bool_value else "OFF"


class Job:
    def __init__(self, compiler, mpi, stage):
        self.cc = compiler
        self.cxx = cc_specs[compiler][0]
        self.cc_spec = cc_specs[compiler][1]
        self.mpi = mpi
        self.mpi_spec = mpi_specs[mpi]
        self.stage = stage

        self.use_mpi = self.mpi != "serial"
        self.use_hip = self.cc == "hipcc"
        self.random_test = self.mpi == "serial"  # if no mpi
        self.use_spec = f"antmoc {self.cc_spec} {self.mpi_spec}"

    def __str__(self):
        return f"({self.cc}, {self.mpi}, <={self.stage})"

    def __repr__(self):
        return self.__str__()


# -------------------------------------------------------------------------------
# Generating
# -------------------------------------------------------------------------------
job_spec = job_spec.split()
job = Job(job_spec[0], job_spec[1], job_spec[2])

print(
    f"""set -e
spack unload --all
spack load cmake%gcc {job.use_spec}
spack find --loaded

rm -rf build/ &> /dev/null

cmake -S . -B build \\
    -DCMAKE_C_COMPILER={job.cc} \\
    -DCMAKE_CXX_COMPILER={job.cxx} \\
    -DCMAKE_BUILD_TYPE=Release \\
    -DBUILD_SHARED_LIBS:BOOL=ON \\
    -DENABLE_ALL_WARNINGS=OFF \\
    -DENABLE_TESTS:BOOL=ON \\
    -DENABLE_MPI:BOOL={job.use_mpi} \\
    -DENABLE_HIP:BOOL={job.use_hip}

cmake --build build -j$(nproc)
"""
)

if job.stage in ["run", "install"]:
    print(f"ctest --test-dir build --output-on-failure {'--schedule-random' if job.random_test else ''}")