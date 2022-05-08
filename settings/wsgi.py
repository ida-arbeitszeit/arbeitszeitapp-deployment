import arbeitszeit_flask
from arbeitszeit_flask import development_settings
from os import path


class ApplicationFactory:
    def __init__(self):
        pass

    def make_app(self):
        return arbeitszeit_flask.create_app(
            config=development_settings.__dict__,
            # template_folder=self.get_templates_folder(),
        )

    def get_templates_folder(self):
        template_folder = path.join(
            path.dirname(arbeitszeit_flask.__file__),
            "templates",
        )
        assert path.isdir(
            template_folder
        ), f"Template folder `{template_folder}` is not a directory"
        return template_folder


app = ApplicationFactory().make_app()
