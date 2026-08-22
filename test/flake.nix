{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations.testuser = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ../modules/chillpill-shell.nix
        {
          home.username = "testuser";
          home.homeDirectory = "/home/testuser";
          home.stateVersion = "26.05";

          programs.chillpillshell = {
            enable = true;
            settings = {
              clockFormat = "HH:mm";
              weatherLocation = "London";
            };
          };
        }
      ];
    };
  };
}
