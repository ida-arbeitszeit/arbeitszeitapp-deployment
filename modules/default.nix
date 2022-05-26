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
    import json
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
    with open("${cfg.emailConfigurationFile}") as handle:
        mail_config = json.load(handle)
    MAIL_BACKEND = "flask_mail"
    MAIL_SERVER = mail_config["MAIL_SERVER"]
    MAIL_PORT = mail_config["MAIL_PORT"]
    MAIL_USERNAME = mail_config["MAIL_USERNAME"]
    MAIL_PASSWORD = mail_config["MAIL_PASSWORD"]
    MAIL_DEFAULT_SENDER = mail_config["MAIL_DEFAULT_SENDER"]
    SERVER_NAME = "${cfg.hostName}";
  '';
  manageCommand = pkgs.writeShellApplication {
    name = "arbeitszeitapp-manage";
    runtimeInputs = [
      (pkgs.python3.withPackages (p: [ p.arbeitszeitapp p.psycopg2 p.flask ]))
    ];
    text = ''
      cd ${stateDirectory}
      FLASK_APP=arbeitszeit_flask.wsgi:app \
          ARBEITSZEITAPP_CONFIGURATION_PATH=${configFile} \
          flask "$@"
    '';
  };
in
{
  options.services.arbeitszeitapp = {
    enable = lib.mkEnableOption "arbeitszeitapp";
    emailConfigurationFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a json file containing the mail configuration in the
        following format:

        {
          "MAIL_SERVER": "mail.server.example",
          "MAIL_PORT": "465",
          "MAIL_USERNAME": "username@mail.server.example",
          "MAIL_PASSWORD": "my secret mail password",
          "MAIL_DEFAULT_SENDER": "sender.address@mail.server.example"
        }
      '';
    };
    hostName = lib.mkOption {
      type = lib.types.str;
      description = ''
        Hostname where the server can be reached.
      '';
      example = "my.server.example";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      manageCommand
    ];
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
