{ arbeitszeitapp }:
{ config, lib, pkgs, ...}:
let
  package = pkgs.python3.pkgs.arbeitszeitapp;
  cfg = config.services.arbeitszeitapp;
  user = "arbeitszeitapp";
  group = "arbeitszeitapp";
  stateDirectory = "/var/lib/arbeitszeitapp";
  databaseUri = "postgresql:///${dbname}";
  dbname = "arbeitszeitapp";
  configFile = pkgs.writeText "arbeitszeitapp.cfg" ''
    import secrets
    try:
        with open("${stateDirectory}/secret_key") as handle:
            SECRET_KEY = handle.read()
    except FileNotFoundError:
        SECRET_KEY = secrets.token_hex(50)
        with open("${stateDirectory}/secret_key", "w") as handle:
            handle.write(SECRET_KEY)
    try:
        with open("${stateDirectory}/password_salt") as handle:
            SECURITY_PASSWORD_SALT = handle.read()
    except FileNotFoundError:
        SECURITY_PASSWORD_SALT = secrets.token_hex(50)
        with open("${stateDirectory}/secret_key", "w") as handle:
            handle.write(SECURITY_PASSWORD_SALT)
    SQLALCHEMY_DATABASE_URI = "${databaseUri}"
    FORCE_HTTPS = False
  '';
  preStart = pkgs.writeShellApplication {
    name = "arbeitszeitapp-manage";
    runtimeInputs = [
      (pkgs.python3.withPackages (p: with p; [ arbeitszeitapp psycopg2 flask ]))
    ];
    text = ''
      FLASK_APP=arbeitszeitapp SQLALCHEMY_DATABASE_URI=${databaseUri} flask "$@"
    '';
  };
in
{
  options.services.arbeitszeitapp = {
    enable = lib.mkEnableOption "arbeitszeitapp";
  };
  config = lib.mkIf cfg.enable {
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
            "ARBEITSZEITAPP_CONFIGURATION_PATH=${configFile}"
            "MPLCONFIGDIR=${stateDirectory}"
          ];
          type = "normal";
          enable-threads = true;
          master = true;
          workers = 1;
          http = ":8000";
          cap = "net_bind_service";
          module = "arbeitszeit_flask.wsgi:app";
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
        home = stateDirectory;
        inherit group;
      };
      groups.${group} = {};
    };
  };
}
