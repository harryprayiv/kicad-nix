{
  description = "KiCad Project Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Import the TUI module if you want it
        kicadTools = import ./kicad-tui.nix { inherit pkgs; };
        
        # Your custom libraries
        customLibraries = ./libraries;
        
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            kicad
            
            # Optional: include TUI tools
            kicadTools.kicadTui
            kicadTools.kicadBatch
            
            # Basic utilities
            git
            python3
            zip
            unzip
          ];
          
          shellHook = ''
            echo "KiCad Development Environment"
            echo ""
            echo "Commands available:"
            echo "  kicad        - Launch KiCad GUI"
            echo "  kicad-cli    - KiCad command line interface"
            echo "  kicad-tui    - Text user interface (if enabled)"
            echo "  kicad-batch  - Batch processing tool (if enabled)"
            
            export KICAD_PROJECT_DIR="$(pwd)"
            export KICAD9_SYMBOL_DIR="$(pwd)/libraries/symbols"
            export KICAD9_FOOTPRINT_DIR="$(pwd)/libraries/footprints"
            export KICAD9_3DMODEL_DIR="$(pwd)/libraries/3dmodels"
            
            mkdir -p libraries/{symbols,footprints,3dmodels}
            mkdir -p projects
          '';
        };
        
        # Minimal shell without TUI
        devShells.minimal = pkgs.mkShell {
          buildInputs = with pkgs; [
            kicad
            git
          ];
          
          shellHook = ''
            echo "KiCad Minimal Environment"
            export KICAD_PROJECT_DIR="$(pwd)"
          '';
        };
      });
}