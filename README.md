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
       nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
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
