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
      nixosModules = { default = import modules/default.nix; };
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
                nixpkgs.overlays = [ arbeitszeitapp.overlays.default ];
                services.arbeitszeitapp.enable = true;
                services.arbeitszeitapp.hostName = "localhost";
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
        in { launchWebserver = makeSimpleTest tests/launchWebserver.py; });
    };
}
