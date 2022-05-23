import arbeitszeit_flask
from arbeitszeit_flask import development_settings
from os import path
from os import environ
import secrets


class ApplicationFactory:
    def __init__(self):
        pass

    def make_app(self):
        return arbeitszeit_flask.create_app(config=self.get_configuration())

    def get_configuration(self):
        configuration = development_settings.__dict__
        configuration["SECRET_KEY"] = self.get_secret_key()
        configuration["SQLALCHEMY_DATABASE_URI"] = self.get_db_uri()
        return configuration

    def get_db_uri(self):
        uri = environ.get("ARBEITSZEIT_APP_DB_URI")
        assert uri
        return uri

    def get_secret_key(self):
        key_file = environ.get("ARBEITSZEIT_APP_SECRET_KEY_FILE")
        try:
            with open(key_file) as handle:
                return handle.read().strip()
        except FileNotFoundError:
            secret_key = secrets.token_hex(40)
            with open(key_file, "w") as handle:
                handle.write(secret_key)
            return secret_key


app = ApplicationFactory().make_app()
