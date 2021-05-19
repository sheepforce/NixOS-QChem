let
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/NixOS/nixpkgs";
    name = "nixpks-unstable";
    rev = "9775b39fd45a61c2a53aa6a90485fac8f87ce7c6";
    ref = "nixpkgs-unstable";
  };

in (import "${nixpkgs}" {}) // (import ./release.nix {
  inherit nixpkgs;
  config = {
    allowEnv = false;
    licMolpro = null;
    optAVX = true;
  };
  allowUnfree = true;

  preOverlays = [ (self: super: {
    openblas = super.openblas.override { dynamicArch = false; target = "HASWELL"; };
    openblasCompat = super.openblasCompat.override { dynamicArch = false; target = "HASWELL"; };
  })];

  postOverlays = [(self: super: {
    qchem = super.qchem // {
      qdng=null;
      mesa=null;
      gaussview=null;
      sharcV1=null;
      mctdh=null;
      mesa-qc=null;
      molpro12=null;
      molpro15=null;
      molpro18=null;
      molpro19=null;
      molpro-ext=null;
      blas = super.blas.override { blasProvider = super.mkl; };
      blas-i8 = super.qchem.blas-i8.override { blasProvider = super.mkl; isILP64 = true; };
      lapack = super.lapack.override {lapackProvider = super.mkl; };
      lapack-i8 = super.qchem.lapack-i8.override {lapackProvider = super.mkl; isILP64 = true; };
    };
  })];
})
