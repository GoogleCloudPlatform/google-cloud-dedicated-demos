
{
  description = "A flake that loads some packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:

    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        dev = with pkgs; [
          just
          kubeconform
          kubectl
          kustomize
          pipx
          pre-commit
          shfmt
          terraform
          tflint
        ];

      in
      rec {
        devShells = {
          default = pkgs.mkShell {
            packages = dev;
          };
        };
      }
    );
}
