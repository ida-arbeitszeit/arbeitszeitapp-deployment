{ arbeitszeitapp }:
{ config, lib, pkgs, ...}:
let
  cfg = config.services.arbeitszeitapp;
  user = "arbeitszeitapp";
  group = "arbeitszeitapp";
  stateDirectory = "/var/lib/arbeitszeit";
  dbname = "arbeitszeitapp";
in
{
  options.services.arbeitszeitapp = {
    enable = lib.mkEnableOption "arbeitszeitapp";
  };
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ arbeitszeitapp.overlay ];
    services.postgresql = {
      enable = true;
      ensureDatabases = [ dbname ];
      ensureUsers = [
        {
          name = user;
          ensurePermissions = {
            "DATABASE ${dbname}" = "ALL PRIVILEGES";
          };
        }
      ];
    };
    services.uwsgi = {
      enable = true;
      plugins = [ "python3" ];
      capabilities = [ "CAP_NET_BIND_SERVICE" ];
      instance = {
        type = "emperor";
        vassals.arbeitszeitapp = {
          env = [
            "ARBEITSZEIT_APP_CONFIGURATION=arbeitszeit_flask.development_settings"
            "ARBEITSZEIT_APP_SECRET_KEY_FILE=${stateDirectory}/secret_key"
            "ARBEITSZEIT_APP_DB_URI=postgresql:///${dbname}"
          ];
          chdir = pkgs.writeTextDir "wsgi.py"
            (builtins.readFile ../settings/wsgi.py);
          type = "normal";
          master = true;
          workers = 1;
          http = ":8000";
          cap = "net_bind_service";
          module = "wsgi:app";
          pythonPackages = self: [ self.arbeitszeitapp self.psycopg2 ];
          immediate-uid = user;
          immediate-gid = group;
        };
      };
    };
    systemd.tmpfiles.rules = [
      "d ${stateDirectory} 770 ${user} ${group}"
    ];  
    systemd.services.postgresql = {
        wantedBy = [ "uwsgi.service" ];
        before = [ "uwsgi.service" ];
    };
    users = {
      users.${user} = {
        isSystemUser = true;
        inherit group;
      };
      groups.${group} = {};
    };
  };
}
