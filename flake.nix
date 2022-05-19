{
  description = "A very basic flake";
  inputs = { arbeitszeitapp.url = "github:arbeitszeit/arbeitszeitapp"; };

  outputs = { self, nixpkgs, arbeitszeitapp, flake-utils }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems
        (system: f system (mkPkgs system));
      mkPkgs = system: import nixpkgs { inherit system; };
    in {
      nixosModules = {
        default = { config, ... }: {
          nixpkgs.overlays = [ arbeitszeitapp.overlay ];
          imports = [ modules/default.nix ];
        };
      };
      devShell = forAllSystems (system: pkgs:
        pkgs.mkShell {
          packages = [ pkgs.python3Packages.black pkgs.nixfmt ];
        });
      checks = forAllSystems (system: pkgs: {
        launchWebserver = pkgs.nixosTest {
          machine = { config, ... }: {
            imports = [ self.nixosModules.default ];
            services.arbeitszeitapp.enable = true;
          };
          testScript = builtins.readFile tests/launchWebserver.py;
        };
      });
    };
}
