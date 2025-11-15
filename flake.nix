{
  description = "KiCad project with custom libraries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        customLibraries = ./libraries;
        
        kicadCustomLibs = pkgs.stdenv.mkDerivation {
          name = "kicad-custom-libraries";
          src = customLibraries;
          
          installPhase = ''
            mkdir -p $out/share/kicad
            cp -r footprints $out/share/kicad/ || true
            cp -r symbols $out/share/kicad/ || true
            cp -r 3dmodels $out/share/kicad/ || true
            cp -r template $out/share/kicad/ || true
          '';
        };

        kicadWithLibs = pkgs.symlinkJoin {
          name = "kicad-with-custom-libs";
          paths = [ pkgs.kicad ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/kicad \
              --set KICAD9_USER_FOOTPRINT_DIR "${kicadCustomLibs}/share/kicad/footprints" \
              --set KICAD9_USER_SYMBOL_DIR "${kicadCustomLibs}/share/kicad/symbols" \
              --set KICAD9_USER_3DMODEL_DIR "${kicadCustomLibs}/share/kicad/3dmodels" \
              --set KICAD9_USER_TEMPLATE_DIR "${kicadCustomLibs}/share/kicad/template" \
              --set KICAD_USER_DATA_DIR "$HOME/.local/share/kicad/9.0" \
              --set KICAD_CONFIG_HOME "$HOME/.config/kicad/9.0"
              
            for tool in pcbnew eeschema gerbview pcb_calculator pl_editor bitmap2component; do
              if [ -e $out/bin/$tool ]; then
                wrapProgram $out/bin/$tool \
                  --set KICAD9_USER_FOOTPRINT_DIR "${kicadCustomLibs}/share/kicad/footprints" \
                  --set KICAD9_USER_SYMBOL_DIR "${kicadCustomLibs}/share/kicad/symbols" \
                  --set KICAD9_USER_3DMODEL_DIR "${kicadCustomLibs}/share/kicad/3dmodels"
              fi
            done
          '';
        };
        
        initScript = pkgs.writeShellScriptBin "kicad-init" ''
          #!/usr/bin/env bash
          set -euo pipefail
          
          PROJECT_DIR="''${1:-.}"
          
          echo "Initializing KiCad project structure in $PROJECT_DIR..."
          
          mkdir -p "$PROJECT_DIR/libraries/footprints"
          mkdir -p "$PROJECT_DIR/libraries/symbols"
          mkdir -p "$PROJECT_DIR/libraries/3dmodels"
          mkdir -p "$PROJECT_DIR/libraries/template"
          
          mkdir -p "$HOME/.local/share/kicad/9.0"
          mkdir -p "$HOME/.config/kicad/9.0"
          
          if [ ! -e "$HOME/.local/share/kicad/9.0/custom_footprints" ]; then
            ln -sf "$PROJECT_DIR/libraries/footprints" "$HOME/.local/share/kicad/9.0/custom_footprints"
          fi
          if [ ! -e "$HOME/.local/share/kicad/9.0/custom_symbols" ]; then
            ln -sf "$PROJECT_DIR/libraries/symbols" "$HOME/.local/share/kicad/9.0/custom_symbols"
          fi
          
          echo "KiCad project structure initialized!"
          echo "Custom libraries will be in: $PROJECT_DIR/libraries/"
        '';
        
        kicadDevScript = pkgs.writeShellScriptBin "kicad-dev" ''
          #!/usr/bin/env bash
          echo "KiCad Development Environment"
          echo "============================="
          echo "Custom libraries loaded from: ./libraries/"
          echo ""
          echo "Available commands:"
          echo "  kicad         - Launch KiCad with custom libraries"
          echo "  kicad-init    - Initialize project structure"
          echo "  pcbnew        - PCB designer"
          echo "  eeschema      - Schematic editor"
          echo ""
          exec kicad "$@"
        '';

      in
      {
        packages = {
          default = kicadWithLibs;
          kicad = kicadWithLibs;
          init = initScript;
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            kicadWithLibs
            initScript
            kicadDevScript
            git
            python3
            ngspice
            freecad
          ];
          
          shellHook = ''
            echo "KiCad development environment loaded"
            echo "Run 'kicad-init' to set up project structure"
            echo "Run 'kicad-dev' to launch KiCad with custom libraries"
            
            export KICAD_PROJECT_DIR="$(pwd)"
            export KICAD9_USER_FOOTPRINT_DIR="$KICAD_PROJECT_DIR/libraries/footprints"
            export KICAD9_USER_SYMBOL_DIR="$KICAD_PROJECT_DIR/libraries/symbols"
            export KICAD9_USER_3DMODEL_DIR="$KICAD_PROJECT_DIR/libraries/3dmodels"
            
            mkdir -p "$HOME/.local/share/kicad/9.0"
            mkdir -p "$HOME/.config/kicad/9.0"
          '';
        };
      });
}