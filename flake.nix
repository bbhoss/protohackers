{
  description = "Development environment";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (nixpkgs.lib) optional;
        pkgs = import nixpkgs { inherit system; };
        beamPackages = pkgs.beam.packagesWith pkgs.beam.interpreters.erlangR25;

        elixir = beamPackages.elixir_1_14;
        locales = if pkgs.stdenv.hostPlatform.libc == "glibc" then
          pkgs.glibcLocales.override {
            allLocales = false; # Only en-US utf8
          }
        else
          pkgs.locale;
      in {
        devShell = pkgs.mkShell {
          buildInputs = [ elixir locales pkgs.wireshark ]
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin
            (with pkgs.darwin.apple_sdk.frameworks; [ Cocoa CoreServices ]);
        };
      });
}
