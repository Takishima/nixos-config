# my.alerts.healthchecksIo, and what my.autoUpgrade reports through it.
# `monitor` stands in for healthchecks.io, at the URL of the fixture's secret.
{
  self,
  fixtureSecrets,
  lib,
  pkgs,
  ...
}:
let
  # Appends each ping to /var/lib/pings as its path, then its body.
  server = pkgs.writers.writePython3 "pings" { } ''
    import http.server


    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            body = self.rfile.read(int(self.headers["Content-Length"]))
            with open("/var/lib/pings", "ab") as log:
                log.write(b"PING " + self.path.encode() + b"\n")
                log.write(body + b"\n")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")


    http.server.HTTPServer(("", 8000), Handler).serve_forever()
  '';
in
{
  name = "healthchecks-io";

  nodes = {
    monitor = {
      networking.firewall.allowedTCPPorts = [ 8000 ];
      systemd.services.pings = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = server;
      };
    };

    machine = {
      imports = [
        self.nixosModules.alerts
        self.nixosModules.auto-upgrade
      ];

      my = {
        secrets = fixtureSecrets;
        alerts.healthchecksIo = {
          enable = true;
          units = [ "job" ];
          heartbeat = [ "job" ];
        };
        autoUpgrade = {
          enable = true;
          checks.healthy = "true";
        };
      };

      systemd.services.job = {
        serviceConfig.Type = "oneshot";
        script = ''
          echo "the job says hello"
          test -e /run/job-works
        '';
      };
    };

    # As a freshly installed host: no sops file yet. Only evaluated.
    fresh = {
      imports = [ self.nixosModules.alerts ];
      my = {
        secrets.file = null;
        alerts.healthchecksIo.enable = true;
      };
    };
  };

  testScript =
    { nodes, ... }:
    assert lib.assertMsg (
      nodes.fresh.my.alerts.healthchecksIo.ping == null
      && lib.any (lib.hasInfix "my.alerts.healthchecksIo") nodes.fresh.warnings
    ) "without its sops key, my.alerts.healthchecksIo must report nothing and say so";
    ''
      monitor.start()
      machine.start()
      monitor.wait_for_unit("pings.service")
      monitor.wait_for_open_port(8000)
      machine.wait_for_unit("multi-user.target")

      def pinged(*lines):
          for line in lines:
              monitor.wait_until_succeeds(f"grep -qxF '{line}' /var/lib/pings")
          print(monitor.succeed("cat /var/lib/pings"))
          monitor.succeed("rm /var/lib/pings")

      with subtest("a failure is reported, with the unit's log"):
          machine.fail("systemctl start job.service")
          pinged("PING /ping/snakeoil/fail", "job.service failed", "the job says hello")

      with subtest("a success is the heartbeat"):
          machine.succeed("touch /run/job-works", "systemctl start job.service")
          pinged("PING /ping/snakeoil", "job.service succeeded")

      with subtest("only root pings"):
          status, out = machine.execute("su nobody -s /bin/sh -c '${nodes.machine.my.alerts.healthchecksIo.ping} /fail intruder' 2>&1 </dev/null")
          assert status != 0 and "Permission denied" in out, out

      with subtest("a rollback that rebooted is reported once the machine is back"):
          machine.succeed("echo 'check failed: sshd' > /var/lib/nixos-upgrade/report")
          machine.succeed("systemctl start nixos-upgrade-report.service")
          pinged("PING /ping/snakeoil/fail", "an upgrade was rolled back", "check failed: sshd")
          machine.fail("test -e /var/lib/nixos-upgrade/report")
    '';
}
