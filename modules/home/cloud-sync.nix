{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.cloudSync;
  onedriveDir = "${config.xdg.configHome}/onedrive/accounts";

  # OneDriveGUI keeps state in this file, so it is seeded, not linked.
  guiProfiles = pkgs.writeText "onedrive-gui-profiles" (
    lib.generators.toINI { } (
      lib.mapAttrs (name: account: {
        config_file = "${onedriveDir}/${name}/config";
        auto_sync = "True";
        account_type = account.type;
        free_space = "";
      }) cfg.onedrive.accounts
    )
  );
in
{
  options.my.cloudSync = {
    onedrive = {
      enable = lib.mkEnableOption "OneDrive, synced by the onedrive client under OneDriveGUI";

      accounts = lib.mkOption {
        default = { };
        description = "OneDriveGUI profiles, by name. Each needs one login in the GUI.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [
                  "Personal"
                  "Business"
                  "SharePoint"
                ];
                default = "Personal";
              };
              settings = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                example = {
                  sync_dir = "~/OneDrive";
                };
                description = "The client's `config` file, see onedrive(1).";
              };
              syncList = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [ "!/Imports" ];
                description = "Lines of `sync_list`. A change needs a resync from the GUI.";
              };
            };
          }
        );
      };
    };

    synologyDrive.enable = lib.mkEnableOption "the Synology Drive client";
    rclone.enable = lib.mkEnableOption "rclone; its remotes hold session tokens and stay in ~/.config/rclone";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.onedrive.enable {
      home.packages = [
        pkgs.onedrive
        pkgs.onedrivegui
      ];

      xdg.configFile = lib.concatMapAttrs (
        name: account:
        {
          "onedrive/accounts/${name}/config".text = lib.concatLines (
            lib.mapAttrsToList (key: value: "${key} = \"${value}\"") account.settings
          );
        }
        // lib.optionalAttrs (account.syncList != [ ]) {
          "onedrive/accounts/${name}/sync_list".text = lib.concatLines account.syncList;
        }
      ) cfg.onedrive.accounts;

      home.activation.onedriveGuiProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -e "${config.xdg.configHome}/onedrive-gui/profiles" ]; then
          run install -Dm644 ${guiProfiles} "${config.xdg.configHome}/onedrive-gui/profiles"
        fi
      '';

      systemd.user.services.onedrivegui = {
        Unit = {
          Description = "OneDriveGUI";
          After = [ config.wayland.systemd.target ];
          PartOf = [ config.wayland.systemd.target ];
        };
        Service = {
          ExecStart = lib.getExe pkgs.onedrivegui;
          Restart = "on-failure";
        };
        Install.WantedBy = [ config.wayland.systemd.target ];
      };
    })

    (lib.mkIf cfg.synologyDrive.enable { home.packages = [ pkgs.synology-drive-client ]; })
    (lib.mkIf cfg.rclone.enable { home.packages = [ pkgs.rclone ]; })
  ];
}
