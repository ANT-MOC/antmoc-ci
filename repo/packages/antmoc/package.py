from spack import *


class Antmoc(BundlePackage):
    """This bundle package is only for convenience."""

    homepage = ""

    maintainers = ['alephpiece']

    version('0.1.15')

    variant('mpi', default=False, description='Enable MPI support')

    depends_on('cmake@3.16:', type='build')
    depends_on('mpi@3.0:', when='+mpi', type=('build', 'link', 'run'))
    depends_on('cxxopts@master')
    depends_on('fmt@6.0.0:')
    depends_on('tinyxml2@7.0.0:')
    depends_on('toml11@3.6.0:')
    depends_on('hdf5@1.10.8~mpi', when='~mpi')
    depends_on('hdf5@1.10.8+mpi', when='+mpi')
    depends_on('blt')

