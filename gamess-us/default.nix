{ stdenv, lib, makeWrapper, fetchFromGitLab, requireFile, gfortran, writeTextFile, cmake, perl,
  tcsh, mpi, blas, hostname, openssh, gnused
}:
assert
  lib.asserts.assertMsg
  (builtins.elem blas.passthru.implementation [ "mkl" "openblas" ])
  "The BLAS providers can be either MKL or OpenBLAS.";

assert
  lib.asserts.assertMsg
  (!blas.isILP64)
  "A 32 bit integer implementation of BLAS is required.";

let
  blasImplementation = blas.passthru.implementation;
  blasProvider = blas.passthru.provider;

  version = "2020R2";
  gfortranVersion = lib.versions.majorMinor gfortran.version;
  libxcSource = fetchFromGitLab {
    owner = "libxc";
    repo = "libxc";
    rev = "5.0.0";
    sha256 = "0jdc51dih3v8c41kxdkn3lkcfrjb8qwx36a09ryzik148ra1043p";
  };

  /*
  1.    Starting -> <return>
  2.    Select the target architecture (arbitrary 64 bit linux, also PowerPC)-> linux64
  3.    Select location of the gamess directory. Choose source location for the moment -> <return>
  4.    Select gamess build directory. Build directly here -> <return>
  5.    Give a version string -> ${gammesVersion}
  6.    Select the Fortran compiler -> gfortran
  7.    Give the version of gfortran (first two digits only) -> ${lib.versions.majorMinor gfortran.version}
  8.    Continue to math setup -> <return>
  9.    Select the BLAS library to use. -> ${blasImplementation}
  10.   Give the path to the blas library -> ${blasProvider}
  10A.  If MKL was selected, the nix directory structure confuses Gamess for a moment. Long story
        short: directly say proceed in a next line -> "${blasProvider}\nproceed"
  11.  Compile source code activator -> <return>
  12.  Done with source code activator, go to network stuff -> <return>
  13.  Select parallelisation type -> mpi
  14.  Select OpenMPI -> ${openmpi.pname}
  15.  Give the location of the MPI installation. -> ${mpi}
  16.  Build external LibXC -> yes
  17.  Skip reminder for LibXC download -> <return>
  18.  Enables CC active space methods -> yes
  19.  Enable LIBCCHEM -> no
  20.  Enable OpenMP support -> yes
  */
  configAnswers = writeTextFile {
    name = "GAMESS-US_Config_Answers.txt";
    text = ''

      linux64


      ${version}
      gfortran
      ${lib.versions.majorMinor gfortran.version}

      ${blasImplementation}
      ${blasProvider}
      ${if blasImplementation == "mkl" then "${blasProvider}\n12-so" else "${blasProvider}/lib"}


      mpi
      ${mpi.pname}
      ${mpi}
      yes

      no
      no
      no
    '';
  };

in
  stdenv.mkDerivation rec {
    pname = "gamess-us";
    inherit version;

    nativeBuildInputs = [
      makeWrapper
      cmake
      perl
      hostname
      gnused
    ];

    buildInputs = [
      gfortran
      blas
    ];

    propagatedBuildInputs = [
      tcsh
      mpi
    ];

    src = requireFile rec {
      name = "gamess-current.tar.gz";
      sha256 = "5eb9242751159b6de244055e1bbb5987e052f913d47ce5eb8a4c6d262361cdc3";
      url = "https://www.msg.chem.iastate.edu/gamess/download.html";
    };

    # cmake must present to build libxc but should not trigger the actual configuration phase.
    dontUseCmakeConfigure = true;
    enableParallelBuilding = false;

    # Initialise the LibXC source code.
    postUnpack = ''
      mkdir -p $sourceRoot/libxc
      cp -r ${libxcSource}/* $sourceRoot/libxc/.
    '';

    patches = [
      ./patches/rungms.patch
      ./patches/AuxDataPath.patch
    ];

    /*
    Environment variable required by GAMESS to set correct MPI version in rungms script. Replaced at
    build time.
    */
    mpiname = mpi.pname;
    mpiroot = builtins.toString mpi;

    # Change all scripts to use tcsh instead of csh
    postPatch = ''
      # Patch the shebangs of all scripts
      cScripts="comp compall config gms-files.csh lked runall rungms rungms-dev ddi/compddi"
      for s in $cScripts; do
        substituteInPlace $s \
          --replace "/bin/csh" "/bin/tcsh" \
          --replace "/usr/bin/env csh" "/bin/tcsh"
        patchShebangs $s
      done
      patchShebangs tools

      # Increase the maximum numbers of CPUs per node and maximum number of Nodes to a more reasonable
      # value for DDI
      substituteInPlace ddi/compddi \
        --replace "set MAXCPUS=32" "set MAXCPUS=256"

      # Prepare the rungms script
      # Replace references to @version@ and @out@
      substituteAllInPlace rungms

      # Make config accept dynamic OpenBLAS
      substituteInPlace config \
        --replace "libopenblas.a" "libopenblas.so"

      # Help the compiler to find DFT modules.
      substituteInPlace comp \
        --replace "         set EXTRAOPT=\" \"" "         set EXTRAOPT=\"-I$(pwd)/gamess/libxc/build/include\""
    '';

    configurePhase = ''
      ./config < ${configAnswers}
    '';

    # The LibXC step is the only one that works in parallel, but it also takes a lot of time.
    buildPhase = ''
      make ddi -j 1
      make libxc -j $NIX_BUILD_CORES
      make modules -j 1
      make gamess -j 1
    '';

    # buildFlags = [ "ddi" "libxc" "modules" "gamess" ];


    # Of course also the installation is quite custom ... Take care of the installation.
    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/share $out/share/gamess

      # Copy the interesting scripts and executables
      cp gamess.${version}.x rungms $out/bin/.

      # Copy the file definitons stuff to share
      cp gms-files.csh $out/share/gamess

      # Copy auxdata, which contains parameters and basis sets
      cp -r auxdata $out/share/gamess/.

      # Copy the test files
      cp -r tests $out/share/gamess/.

      runHook postInstall
    '';

    binSearchPath = lib.strings.makeSearchPath "bin" [ openssh mpi tcsh hostname ];
    /*
    Patch the entry point to fit this systems needs for running an actual calculation.
    */
    postFixup = ''
       wrapProgram $out/bin/rungms \
         --set-default SCRATCH "/tmp" \
         --prefix PATH : ${binSearchPath}
    '';

    hardeningDisable = [ "format" ];

    meta = with lib; {
      description = "GAMESS is a program for ab initio molecular quantum chemistry.";
      homepage = "https://www.msg.chem.iastate.edu/gamess/index.html";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  }
