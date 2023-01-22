{
  description = "Implements a module for running arbeitszeitapp";
  inputs = {
    arbeitszeitapp.url = "github:arbeitszeit/arbeitszeitapp";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
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
          makeTestWithProfiling = name: testFile:
            pkgs.nixosTest {
              name = name;
              nodes.machine = { config, ... }: {
                virtualisation.memorySize = 2048;
                virtualisation.diskSize = 1024;
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
                services.arbeitszeitapp.profilingEnabled = true;
                services.arbeitszeitapp.profilingCredentialsFile =
                  pkgs.writeText "profiling.json" (builtins.toJSON {
                    PROFILING_AUTH_USER = "testuser";
                    PROFILING_AUTH_PASSWORD = "testpassword";
                  });
              };
              testScript = builtins.readFile testFile;
            };
        in {
          launchWebserver =
            makeSimpleTest "launchWebserver" tests/launchWebserver.py;
          launchWebserverWithProfiling =
            makeTestWithProfiling "launchWebserverWithProfiling"
            tests/launchWebserver.py;
          testProfiling =
            makeTestWithProfiling "testProfiling" tests/testProfiling.py;
        });
    };
}
