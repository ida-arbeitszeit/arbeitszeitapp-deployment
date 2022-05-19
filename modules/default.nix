{ arbeitszeitapp }:
{ config, lib, pkgs, ...}:
let
  cfg = config.services.arbeitszeitapp;
in
{
  options.services.arbeitszeitapp = {
    enable = lib.mkEnableOption "arbeitszeitapp";
  };
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ arbeitszeitapp.overlay ];
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
            (builtins.readFile ../settings/wsgi.py);
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
}
