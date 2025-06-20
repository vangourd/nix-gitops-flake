# nix-gitops-flake

This repository contains a small **Rust-based GitOps agent** and example
configuration. The agent periodically pulls a Nix flake from an upstream
repository and applies it to your system. A key feature is local secrets
management using `age-nix`, so you can keep encrypted files under version
control without relying on an external provider. The example is intended for a
single machine but can be extended to work with `sops-nix` and Vault for more
complex deployments.

## Using age-nix

1. **Generate a key pair**
   Run `age-keygen -o /etc/ssh/age.key` on the target machine. The command
   prints the public key which you will use to encrypt your secrets.

2. **Add age-nix to your flake**
   Include the `age-nix` and `sops-nix` modules and enable them in your
   configuration:

   ```nix
   {
     inputs = {
       age-nix.url = "github:Mic92/age.nix";
       sops-nix.url = "github:Mic92/sops-nix";
       nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
     };

     outputs = { self, nixpkgs, age-nix, sops-nix, ... }:
       let
         system = "x86_64-linux";
         pkgs = import nixpkgs { inherit system; };
       in
       {
         nixosConfigurations.myhost = pkgs.nixosSystem {
           system = system;
           modules = [
             age-nix.nixosModules.default
             sops-nix.nixosModules.sops
             ./modules/gitops.nix
           ];
         };
       };
   }
   ```

3. **Reference the key**
   Configure age-nix and sops-nix to read the private key generated above:

   ```nix
   { config, ... }:
   {
     age.identityPaths = [ "/etc/ssh/age.key" ];
     sops.age.keyFile = "/etc/ssh/age.key";
   }
   ```

4. **Encrypt your secrets**
   Use `sops` with the printed public key:

   ```bash
   sops --age <public-key> secrets.yaml
   ```

   Commit the resulting `secrets.yaml` file to your repository. When your
   GitOps service runs, `age-nix` provides the private key so `sops` can
   decrypt the file locally and apply the secrets.

With this setup your system has local control over secret decryption while
keeping the encrypted data in version control.

### Using Vault as a secrets provider

`sops-nix` can pull decryption keys from Vault. Configure the Vault
connection and authentication method and `sops` will fetch the key at
runtime:

```nix
{ config, ... }:
{
  sops.vault = {
    enable = true;
    address = "https://vault.example.com";
    tokenFile = "/etc/vault-token"; # or use approle parameters
  };
}
```

The token file or approle credentials must be available on the machine so the
GitOps service can decrypt secrets when it runs.

## GitOps service module

This flake also exposes a helper script and a NixOS module so you can
install a service that regularly pulls an upstream repository and applies
its flake.

1. **Add the flake as an input**

   ```nix
   inputs.gitops.url = "github:yourname/nix-gitops-flake";
   ```

2. **Enable the module**

   ```nix
   {
     imports = [ inputs.gitops.nixosModules.gitops ];

     services.gitops = {
       enable = true;
       repository = "https://github.com/myorg/infra.git";
       ref = "main";            # or a tag
       frequency = "30m";       # how often to check for changes
     };
   }
   ```

The module installs a `systemd` timer and service called `gitops-sync`.
It runs the bundled `gitops-sync` script which clones the repository and
executes `nixos-rebuild` with the checked-out flake. Secrets managed
with `sops-nix`, `age-nix`, or Vault become available during the rebuild
so sensitive data stays encrypted in your repo.

You can also install the helper script directly using:

```bash
nix profile install github:yourname/nix-gitops-flake#gitops-sync
```

This makes it easy to experiment locally or run the sync manually.

### Installing via overlay

The flake provides an overlay so you can access the package through
`nixpkgs` without using `nix profile`:

```nix
{
  inputs.gitops.url = "github:yourname/nix-gitops-flake";

  outputs = { self, nixpkgs, gitops, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ gitops.overlays.default ]; };
    in
    {
      packages.x86_64-linux.gitops-sync = pkgs.gitops-sync;
    };
}
```

This overlay can later be submitted to `nixpkgs` so the package becomes
available as `pkgs.gitops-sync` for all users.
