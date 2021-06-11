{ stdenv, lib, buildPythonPackage, fetchFromGitHub, autoreconfHook, pkg-config
, gfortran, mpi, blas, lapack, fftw, hdf5-full, swig, gsl, harminv, libctl
, libGDSII
# Python
, python, numpy, scipy, matplotlib, h5py, cython, autograd, mpi4py
} :

buildPythonPackage rec {
  pname = "meep";
  version = "1.18.0";

  src = fetchFromGitHub {
    owner = "NanoComp";
    repo = pname;
    rev = "v${version}";
    sha256= "08l4mczkh08dp90c4dlnyx6lsg093li0xqnnbh7q8k363cr8lx81";
  };

  nativeBuildInputs = [
    autoreconfHook
    gfortran
    pkg-config
    swig
    mpi
  ];

  buildInputs = [
    gsl
    blas
    lapack
    fftw
    hdf5-full
    harminv
    libctl
    libGDSII
  ];

  propagatedBuildInputs = [
    mpi
    numpy
    scipy
    matplotlib
    h5py
    cython
    autograd
    mpi4py
  ];

  propagatedUserEnvPkgs = [ mpi ];

  dontUseSetuptoolsBuild = true;
  dontUsePipInstall = true;
  dontUseSetuptoolsCheck = true;

  HDF5_MPI = "ON";
  PYTHON = "${python}/bin/${python.executable}";

  enableParallelBuilding = true;

  configureFlags = [
    "--without-libctl"
    "--enable-shared"
    "--with-mpi"
    "--with-openmp"
    "--enable-maintainer-mode"
  ];

  passthru = { inherit mpi; };

  meta = with lib; {
    description = "Free finite-difference time-domain (FDTD) software for electromagnetic simulations";
    homepage = "https://meep.readthedocs.io/en/latest/";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [ maintainers.sheepforce ];
  };
}
