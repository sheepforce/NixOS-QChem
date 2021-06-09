{ stdenv, lib, fetchFromGitHub, autoreconfHook, gfortran, blas, lapack, fftw, hdf5-full
, pkg-config, mpi, python3, harminv, libctl, libGDSII
} :

stdenv.mkDerivation rec {
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
  ];

  buildInputs = [
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
    python3
  ];
  propagatedUserEnvPkgs = [ mpi ];

  configureFlags = [
    "--without-libctl"
    "--with-mpi"
    "--with-openmp"
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
