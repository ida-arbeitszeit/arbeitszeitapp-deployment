{
  description = "Implements a module for running arbeitszeitapp";
  inputs = {
    arbeitszeitapp.url =
      "github:arbeitszeit/arbeitszeitapp/seppeljordan/update-nix-dependencies";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, arbeitszeitapp }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems
        (system: f system (mkPkgs system));
      mkPkgs = system: import nixpkgs { inherit system; };
    in {
      nixosModules = {
        default = import modules/default.nix {
          overlay = arbeitszeitapp.overlays.default;
        };
      };
      devShells = forAllSystems (system: pkgs: {
        default =
          pkgs.mkShell { packages = [ pkgs.python3.pkgs.black pkgs.nixfmt ]; };
      });
      checks = forAllSystems (system: pkgs:
        let
          makeSimpleTest = name: testFile:
            pkgs.nixosTest {
              name = name;
              nodes.machine = { config, ... }: {
                imports = [ self.nixosModules.default ];
                nixpkgs.pkgs = pkgs;
                services.arbeitszeitapp.enable = true;
                services.arbeitszeitapp.hostName = "localhost";
                services.arbeitszeitapp.enableHttps = false;
                services.arbeitszeitapp.emailEncryptionType = null;
                services.arbeitszeitapp.emailConfigurationFile =
                  pkgs.writeText "mailconfig.json" (builtins.toJSON {
                    MAIL_SERVER = "mail.server.example";
                    MAIL_PORT = "465";
                    MAIL_USERNAME = "mail@mail.server.example";
                    MAIL_PASSWORD = "secret password";
                    MAIL_DEFAULT_SENDER = "sender@mail.server.example";
                  });
              };
              testScript = builtins.readFile testFile;
            };
        in {
          launchWebserver =
            makeSimpleTest "launchWebserver" tests/launchWebserver.py;
        });
    };
}
