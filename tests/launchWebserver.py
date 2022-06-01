machine.wait_for_unit("multi-user.target")
machine.wait_for_unit("nginx.service")
machine.wait_for_unit("uwsgi.service")
machine.wait_for_open_port(80)
# The first connection takes a long time since it must build font
# cache and run db migrations
assert "Arbeitszeit" in machine.succeed("curl -vLf localhost/")
assert "Arbeitszeit" in machine.succeed("curl -vLf localhost/member/login")
machine.succeed("curl -vLf localhost/static/main.js")
machine.succeed("sudo -u arbeitszeitapp arbeitszeitapp-manage db upgrade")

# Check if service still works after restarting
machine.succeed("systemctl restart uwsgi.service")
machine.wait_for_unit("uwsgi.service")
assert "Arbeitszeit" in machine.succeed("curl -vLf localhost/")

# Check if payout job workds
machine.succeed("systemctl start arbeitszeitapp-payout.service")
