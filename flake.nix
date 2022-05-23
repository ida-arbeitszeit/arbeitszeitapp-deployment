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
        default = import modules/default.nix { inherit arbeitszeitapp; };
      };
      devShell = forAllSystems (system: pkgs:
        pkgs.mkShell {
          packages = [ pkgs.python3Packages.black pkgs.nixfmt ];
        });
      checks = forAllSystems (system: pkgs:
        let
          makeSimpleTest = testFile:
            pkgs.nixosTest {
              machine = { config, ... }: {
                imports = [ self.nixosModules.default ];
                services.arbeitszeitapp.enable = true;
              };
              testScript = builtins.readFile testFile;
            };
        in {
          launchWebserver = makeSimpleTest tests/launchWebserver.py;
          canAccessMemberLogin = makeSimpleTest tests/canGetLoginForm.py;
        });
    };
}
