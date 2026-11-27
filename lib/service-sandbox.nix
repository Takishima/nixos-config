# systemd serviceConfig that takes from a service what few services need.
let
  isolated = {
    LockPersonality = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    RestrictNamespaces = true;
    RestrictRealtime = true;
    SystemCallArchitectures = "native";
  };

  unprivileged = isolated // {
    CapabilityBoundingSet = "";
    MemoryDenyWriteExecute = true;
    ProcSubset = "pid";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
  };
in
{
  inherit isolated unprivileged;

  internetClient = unprivileged // {
    PrivateDevices = true;
    PrivateUsers = true;
    # AF_UNIX reaches nscd, which resolves names.
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
  };
}
