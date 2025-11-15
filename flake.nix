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
            
            # Point to KiCad 9's SYSTEM libraries using passthru
            export KICAD9_SYMBOL_DIR="${pkgs.kicad.libraries.symbols}/share/kicad/symbols"
            export KICAD9_FOOTPRINT_DIR="${pkgs.kicad.libraries.footprints}/share/kicad/footprints"
            export KICAD9_3DMODEL_DIR="${pkgs.kicad.libraries.packages3d}/share/kicad/3dmodels"
            export KICAD9_TEMPLATE_DIR="${pkgs.kicad.libraries.templates}/share/kicad/template"
            
            # User libraries for YOUR custom symbols/footprints
            export KICAD_USER_SYMBOL_DIR="$(pwd)/libraries/symbols"
            export KICAD_USER_FOOTPRINT_DIR="$(pwd)/libraries/footprints"
            export KICAD_USER_3DMODEL_DIR="$(pwd)/libraries/3dmodels"
            
            # Create directories for user libraries only
            mkdir -p libraries/{symbols,footprints,3dmodels}
            mkdir -p projects
            
            echo ""
            echo "System symbol libraries: ${pkgs.kicad.libraries.symbols}/share/kicad/symbols"
            echo "System footprint libraries: ${pkgs.kicad.libraries.footprints}/share/kicad/footprints"
            echo "User libraries: $(pwd)/libraries/"
          '';
        };
      });
}