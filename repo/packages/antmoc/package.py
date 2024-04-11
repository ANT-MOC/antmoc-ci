from spack.package import *


class Antmoc(BundlePackage):
    """This bundle package is only for convenience."""

    homepage = "https://gitlab.com/HPCer/neutronics/ant-moc"

    maintainers = ['alephpiece']

    license("MIT")

    version('develop', preferred=True)
    version('0.1.15')
    version('0.1.14')

    variant('mpi', default=False, description='Enable MPI support')

    depends_on('cmake@3.16:', type='build')
    depends_on('mpi@3', when='+mpi', type=('build', 'link', 'run'))
    depends_on('cxxopts@3')
    depends_on('fmt@6 +shared', when='@:0.1.15')
    depends_on('fmt@8:10 +shared', when='@0.1.16:')
    depends_on('tinyxml2@7:10 +shared')
    depends_on('toml11@3.6:3.7')
    depends_on('hdf5@1.10:1.14 ~mpi+shared', when='~mpi')
    depends_on('hdf5@1.10:1.14 +mpi+shared', when='+mpi')
    depends_on('googletest@1.10.0: +gmock+pthreads+shared')
