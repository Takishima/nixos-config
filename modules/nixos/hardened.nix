{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.hardened;
  rootPassword = "password_hash/root";
  inherit (config.my.secrets) has;
  hasRootPassword = has rootPassword;

  # Whether fail2ban leaves an address alone: one of the home network, but not
  # a VPN client, whose /24 may be inside that range.
  users = config.users.users;
  hasKey = name: users.${name}.openssh.authorizedKeys.keys != [ ];
  withoutKey = lib.filter (name: !(users ? ${name} && hasKey name)) cfg.sshUsers;
  withoutPassword = lib.filter (name: users.${name}.isNormalUser && !has "password_hash/${name}") (
    lib.attrNames users
  );
  trusted = lib.subtractLists [ "root" ] config.nix.settings.trusted-users;

  # No password is what a sops file that cannot be decrypted leaves root with.
  rootHasPassword = pkgs.writeShellApplication {
    name = "root-has-password";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.getent
    ];
    text = ''
      case $(getent shadow root | cut -d: -f2) in
        '$'*) ;;
        *) exit 1 ;;
      esac
    '';
  };

  vpn = config.my.wireguard;
  isHome = pkgs.writeShellScript "fail2ban-is-home" (
    lib.concatLines (
      [ "case $1 in" ]
      ++ lib.optional vpn.enable "  ${lib.removeSuffix ".0/24" vpn.subnet}.*) exit 1 ;;"
      ++ map (pattern: "  ${pattern}) exit 0 ;;") cfg.neverBan
      ++ [
        "  *) exit 1 ;;"
        "esac"
      ]
    )
  );
in
{
  imports = [
    ./auto-upgrade.nix
    ./nix.nix
    ./secrets.nix
    ./ssh-server.nix
    ./wireguard.nix
  ];

  options.my.hardened = {
    enable = lib.mkEnableOption ''
      a tighter setup for a server reachable from the internet: SSH for a few
      users, no sudo and root by `su` with `password_hash/root` from the sops
      file, users only as declared, fail2ban, a stricter firewall and kernel'';

    sshUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Who may log in over SSH.";
    };

    neverBan = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [ "192.168.1.*" ];
      description = ''
        Addresses fail2ban never bans, as shell patterns: the home network.
        Clients of `my.wireguard` are banned all the same.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hasRootPassword;
        message = ''
          my.hardened: the sops file has no ${rootPassword}. Nobody may use sudo,
          so without it nobody could become root.
        '';
      }
      {
        assertion = config.my.sshServer.enable && cfg.sshUsers != [ ] && withoutKey == [ ];
        message = ''
          my.hardened: nobody could log in. my.sshServer has to be on, and
          every one of sshUsers a user with a key in openssh.authorizedKeys.keys.
          Without one: ${toString withoutKey}
        '';
      }
      {
        assertion = withoutPassword == [ ];
        message = ''
          my.hardened: no password_hash/<user> in the sops file for
          ${toString withoutPassword}, who would get the initial password.
        '';
      }
      {
        assertion = trusted == [ ] && !config.my.nix.workstation;
        message = ''
          my.hardened: a trusted Nix user is root without a password, and so
          is a flake whose nixConfig is accepted unasked. Drop
          nix.settings.trusted-users (${toString trusted}) and my.nix.workstation.
        '';
      }
    ];

    # Only what this configuration declares: no account or password set by hand
    # survives a switch. Passwords change in the sops file.
    users.mutableUsers = false;

    # Root is reached with `su` and its own password, from a user's SSH session:
    # a stolen SSH key alone is not root. Keep the users out of wheel: sudo is
    # gone.
    security.sudo.enable = false;
    sops.secrets.${rootPassword} = lib.mkIf hasRootPassword { neededForUsers = true; };
    users.users.root.hashedPasswordFile =
      lib.mkIf hasRootPassword
        config.sops.secrets.${rootPassword}.path;

    nix.settings.allowed-users = [ "root" ] ++ cfg.sshUsers;

    my.autoUpgrade.checks = lib.mkIf hasRootPassword {
      root-password = lib.getExe rootHasPassword;
    };

    services = {
      openssh = {
        settings.AllowUsers = cfg.sshUsers;
        # Only the keys in the configuration log in, not ~/.ssh/authorized_keys.
        authorizedKeysInHomedir = false;
        # Only the key that is kept outside the machine, so a rebuilt
        # machine is the same host to its clients.
        hostKeys = [
          {
            type = "ed25519";
            path = "/etc/ssh/ssh_host_ed25519_key";
          }
        ];
      };

      # Two failures within 15 minutes ban for an hour, and each further ban
      # doubles, up to a week. The home network is spared.
      fail2ban = {
        enable = true;
        maxretry = 2;
        bantime = "1h";
        jails.DEFAULT.settings = {
          findtime = "15m";
          ignorecommand = "${isHome} <ip>";
        };
        bantime-increment = {
          enable = true;
          maxtime = "1w";
        };
      };
    };

    networking.firewall = {
      logRefusedConnections = true;
      # Drop a packet whose reply would leave by another interface.
      checkReversePath = "strict";
    };

    boot.kernel.sysctl = {
      # Kernel logs and addresses are root's.
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_harden" = 2;
      "kernel.yama.ptrace_scope" = 1;

      # No rerouting on a stranger's say-so.
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.default.accept_source_route" = 0;
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    };
  };
}
