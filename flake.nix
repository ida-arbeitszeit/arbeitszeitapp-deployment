{
  description = "A very basic flake";
  inputs = {
    arbeitszeitapp.url = "github:arbeitszeit/arbeitszeitapp";
  };

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
            services.uwsgi = {
              enable = true;
              plugins = [ "python3" ];
              capabilities = [ "CAP_NET_BIND_SERVICE" ];
              instance = {
                type = "emperor";
                vassals.arbeitszeitapp = {
                  env = [
                    "ARBEITSZEIT_APP_CONFIGURATION=arbeitszeit_flask.development_settings"
                  ];
                  chdir = pkgs.writeTextDir "wsgi.py"
                    (builtins.readFile settings/wsgi.py);
                  type = "normal";
                  master = true;
                  workers = 1;
                  http = ":8000";
                  cap = "net_bind_service";
                  module = "wsgi:app";
                  pythonPackages = self: [ self.arbeitszeitapp ];
                };
              };
            };
          };
          testScript = builtins.readFile tests/launchWebserver.py;
        };
      });
    };
}
