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
# compiler specs
cc_specs = {
    "gcc": "%gcc",
    "clang": "%clang",
    "hipcc": "%gcc",
}

# mpi specs
mpi_specs = {"serial": "~mpi", "mpich": "+mpi^mpich", "openmpi": "+mpi^openmpi"}


class Job:
    def __init__(self, cc, mpi, stage):
        self.cc = cc
        self.mpi = mpi
        self.stage = stage

        # preset name: compiler?-mpi?-debug
        self.preset = f"{cc}-{'serial' if mpi=='serial' else 'mpi'}-debug"
        self.build_dir = f"build/{self.preset}"
        self.use_spec = f"antmoc {cc_specs[cc]} {mpi_specs[mpi]}"
        self.random_test = "ON" if self.mpi == "serial" else "OFF"  # no mpi

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

rm -rf {job.build_dir} &> /dev/null
cmake --preset {job.preset}
cmake --build {job.build_dir} -j$(nproc)
"""
)

if job.stage in ["run", "install"]:
    print(
        f"ctest --test-dir {job.build_dir} --output-on-failure {'--schedule-random' if job.random_test else ''}"
    )

if job.stage in ["install"]:
    print(f"cmake --install {job.build_dir} && ldd $(which antmoc)")
