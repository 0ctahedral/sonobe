# we are creating a set that is the output of this flake?
{
  # specify other flakes/derivations as input
  inputs = {
    # need nixpkgs for mkShell (and what else?)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # need utils for making system specification easier
    flake-utils.url = "github:numtide/flake-utils";
    # zig overlay for getting zig master binary
    zig-overlay = {
      # git url of the overlay
      url = "github:mitchellh/zig-overlay";
      # make sure that we use the same nixpkgs and flake-utils that we already have here
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };
  # destructure the inputs |
  #                        v
  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # get current system zig
        zig = zig-overlay.packages.${system}.master;
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      # use the inherited system so that we don't have to type out nixpkgs.blah.blah.blah
      with pkgs;
      {
        # create the dev shell that now has the correct version of zig in it
        devShells.default = mkShell {
          buildInputs = [ zig ];
        };
      }
    );
}
