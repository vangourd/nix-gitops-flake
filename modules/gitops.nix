{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.gitops;
  script = pkgs.gitops-sync;
in
{
  options.services.gitops = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable GitOps synchronization";
    };

    repository = mkOption {
      type = types.str;
      description = "URL of the upstream Git repository";
    };

    ref = mkOption {
      type = types.str;
      default = "main";
      description = "Branch or tag to deploy";
    };

    frequency = mkOption {
      type = types.str;
      default = "15m";
      description = "Run interval for the sync timer";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.gitops-sync = {
      description = "GitOps sync service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${script}/bin/gitops-sync '${cfg.repository}' '${cfg.ref}' '';
      };
    };

    systemd.timers.gitops-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnUnitActiveSec = cfg.frequency;
    };
  };
}
