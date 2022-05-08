machine.wait_for_unit("multi-user.target")
machine.wait_for_unit("uwsgi.service")
machine.wait_for_open_port(8000)
assert "Arbeitszeit" in machine.succeed("curl -v 127.0.0.1:8000")
