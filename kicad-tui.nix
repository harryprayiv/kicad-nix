{ pkgs }:

let
  kicadTui = pkgs.writeShellApplication {
    name = "kicad-tui";
    runtimeInputs = with pkgs; [
      kicad
      dialog
      jq
      ncurses
      gum
      fzf
      bat
      tree
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      PROJECT_DIR="''${KICAD_PROJECT_DIR:-$(pwd)}"
      
      show_main_menu() {
        choice=$(gum choose \
          "New Project" \
          "Open Project" \
          "Project Operations" \
          "Schematic Tools" \
          "PCB Tools" \
          "Library Manager" \
          "Manufacturing Export" \
          "Settings" \
          "Exit")
        
        case "$choice" in
          "New Project") new_project ;;
          "Open Project") open_project ;;
          "Project Operations") project_operations ;;
          "Schematic Tools") schematic_tools ;;
          "PCB Tools") pcb_tools ;;
          "Library Manager") library_manager ;;
          "Manufacturing Export") manufacturing_export ;;
          "Settings") settings_menu ;;
          "Exit") exit 0 ;;
          *) show_main_menu ;;
        esac
      }
      
      new_project() {
        name=$(gum input --placeholder "Enter project name")
        if [ -z "$name" ]; then
          show_main_menu
          return
        fi
        
        location=$(gum input --placeholder "Enter project location" --value "$PROJECT_DIR")
        
        project_path="$location/$name"
        mkdir -p "$project_path"/{hardware,libraries,documentation,output}
        mkdir -p "$project_path/libraries"/{symbols,footprints,3dmodels}
        
        cat > "$project_path/hardware/$name.kicad_pro" <<'EOF'
      {
        "board": {
          "design_settings": {
            "defaults": {
              "board_outline_line_width": 0.15,
              "copper_line_width": 0.2,
              "copper_text_size_h": 1.5,
              "copper_text_size_v": 1.5
            }
          }
        },
        "schematic": {
          "drawing": {
            "default_line_thickness": 6.0,
            "default_text_size": 50.0,
            "field_names": [],
            "pin_symbol_size": 25.0,
            "text_offset_ratio": 0.3
          }
        },
        "libraries": {
          "pinned_footprint_libs": [],
          "pinned_symbol_libs": []
        },
        "meta": {
          "filename": "PROJECT_NAME.kicad_pro",
          "version": 1
        }
      }
      EOF
        sed -i "s/PROJECT_NAME/$name/g" "$project_path/hardware/$name.kicad_pro"
        
        cat > "$project_path/hardware/$name.kicad_sch" <<EOF
      (kicad_sch (version 20230121) (generator eeschema)
        (uuid $(uuidgen | tr '[:upper:]' '[:lower:]'))
        (paper "A4")
        (lib_symbols)
        (symbol_instances)
      )
      EOF
        
        cat > "$project_path/hardware/$name.kicad_pcb" <<'EOF'
      (kicad_pcb (version 20221018) (generator pcbnew)
        (general
          (thickness 1.6)
        )
        (paper "A4")
        (layers
          (0 "F.Cu" signal)
          (31 "B.Cu" signal)
          (32 "B.Adhes" user "B.Adhesive")
          (33 "F.Adhes" user "F.Adhesive")
          (34 "B.Paste" user)
          (35 "F.Paste" user)
          (36 "B.SilkS" user "B.Silkscreen")
          (37 "F.SilkS" user "F.Silkscreen")
          (38 "B.Mask" user)
          (39 "F.Mask" user)
          (44 "Edge.Cuts" user)
          (45 "Margin" user)
          (46 "B.CrtYd" user "B.Courtyard")
          (47 "F.CrtYd" user "F.Courtyard")
        )
        (setup
          (pad_to_mask_clearance 0)
          (pcbplotparams
            (layerselection 0x00010fc_ffffffff)
          )
        )
      )
      EOF
        
        gum style --foreground 212 "Project created at: $project_path"
        sleep 2
        
        export KICAD_CURRENT_PROJECT="$project_path/hardware/$name"
        project_operations
      }
      
      open_project() {
        # shellcheck disable=SC2016
        project_file=$(find "$PROJECT_DIR" -name "*.kicad_pro" 2>/dev/null | fzf --preview 'tree -L 2 $(dirname {})' || true)
        
        if [ -n "$project_file" ]; then
          export KICAD_CURRENT_PROJECT="''${project_file%.kicad_pro}"
          gum style --foreground 212 "Opened: $(basename "$KICAD_CURRENT_PROJECT")"
          sleep 1
          project_operations
        else
          show_main_menu
        fi
      }
      
      project_operations() {
        if [ -z "''${KICAD_CURRENT_PROJECT:-}" ]; then
          gum style --foreground 196 "No project selected"
          sleep 2
          show_main_menu
          return
        fi
        
        choice=$(gum choose \
          "Project Status" \
          "Run ERC" \
          "Run DRC" \
          "Update Libraries" \
          "Archive Project" \
          "Back")
        
        case "$choice" in
          "Project Status") show_project_status ;;
          "Run ERC") run_erc ;;
          "Run DRC") run_drc ;;
          "Update Libraries") update_libraries ;;
          "Archive Project") archive_project ;;
          "Back") show_main_menu ;;
          *) project_operations ;;
        esac
      }
      
      schematic_tools() {
        if [ -z "''${KICAD_CURRENT_PROJECT:-}" ]; then
          gum style --foreground 196 "No project selected"
          sleep 2
          show_main_menu
          return
        fi
        
        choice=$(gum choose \
          "Export PDF" \
          "Export SVG" \
          "Export BOM" \
          "Export Netlist" \
          "Upgrade Format" \
          "Back")
        
        case "$choice" in
          "Export PDF") export_schematic_pdf ;;
          "Export SVG") export_schematic_svg ;;
          "Export BOM") export_bom ;;
          "Export Netlist") export_netlist ;;
          "Upgrade Format") upgrade_schematic ;;
          "Back") project_operations ;;
          *) schematic_tools ;;
        esac
      }
      
      pcb_tools() {
        if [ -z "''${KICAD_CURRENT_PROJECT:-}" ]; then
          gum style --foreground 196 "No project selected"
          sleep 2
          show_main_menu
          return
        fi
        
        choice=$(gum choose \
          "Export Gerbers" \
          "Export Pick Place" \
          "Export Drill Files" \
          "Export 3D STEP" \
          "Export PDF" \
          "Export SVG" \
          "Back")
        
        case "$choice" in
          "Export Gerbers") export_gerbers ;;
          "Export Pick Place") export_pick_place ;;
          "Export Drill Files") export_drill ;;
          "Export 3D STEP") export_3d ;;
          "Export PDF") export_pcb_pdf ;;
          "Export SVG") export_pcb_svg ;;
          "Back") project_operations ;;
          *) pcb_tools ;;
        esac
      }
      
      manufacturing_export() {
        if [ -z "''${KICAD_CURRENT_PROJECT:-}" ]; then
          gum style --foreground 196 "No project selected"
          sleep 2
          show_main_menu
          return
        fi
        
        choice=$(gum choose \
          "Complete Fab Package" \
          "JLCPCB Export" \
          "PCBWay Export" \
          "OSHPark Export" \
          "Assembly Files" \
          "Back")
        
        case "$choice" in
          "Complete Fab Package") export_complete_fab ;;
          "JLCPCB Export") export_jlcpcb ;;
          "PCBWay Export") export_pcbway ;;
          "OSHPark Export") export_oshpark ;;
          "Assembly Files") export_assembly ;;
          "Back") show_main_menu ;;
          *) manufacturing_export ;;
        esac
      }
      
      library_manager() {
        choice=$(gum choose \
          "Install Library" \
          "Update Libraries" \
          "Export Library" \
          "Manage Symbols" \
          "Manage Footprints" \
          "Manage 3D Models" \
          "Back")
        
        case "$choice" in
          "Install Library") install_library ;;
          "Update Libraries") update_all_libraries ;;
          "Export Library") export_library ;;
          "Manage Symbols") manage_symbols ;;
          "Manage Footprints") manage_footprints ;;
          "Manage 3D Models") manage_3d_models ;;
          "Back") show_main_menu ;;
          *) library_manager ;;
        esac
      }
      
      run_erc() {
        local sch_file="$KICAD_CURRENT_PROJECT.kicad_sch"
        if [ ! -f "$sch_file" ]; then
          gum style --foreground 196 "Schematic file not found"
          sleep 2
          project_operations
          return
        fi
        
        gum spin --spinner dot --title "Running ERC..." -- \
          kicad-cli sch erc --severity-all -o "$KICAD_CURRENT_PROJECT.erc" "$sch_file"
        
        if [ -f "$KICAD_CURRENT_PROJECT.erc" ]; then
          gum pager < "$KICAD_CURRENT_PROJECT.erc"
        fi
        
        project_operations
      }
      
      run_drc() {
        local pcb_file="$KICAD_CURRENT_PROJECT.kicad_pcb"
        if [ ! -f "$pcb_file" ]; then
          gum style --foreground 196 "PCB file not found"
          sleep 2
          project_operations
          return
        fi
        
        gum spin --spinner dot --title "Running DRC..." -- \
          kicad-cli pcb drc --severity-all -o "$KICAD_CURRENT_PROJECT.drc" "$pcb_file"
        
        if [ -f "$KICAD_CURRENT_PROJECT.drc" ]; then
          gum pager < "$KICAD_CURRENT_PROJECT.drc"
        fi
        
        project_operations
      }
      
      export_gerbers() {
        local pcb_file="$KICAD_CURRENT_PROJECT.kicad_pcb"
        local output_dir
        output_dir="$(dirname "$KICAD_CURRENT_PROJECT")/output/gerbers"
        
        mkdir -p "$output_dir"
        
        gum spin --spinner dot --title "Exporting Gerbers..." -- \
          kicad-cli pcb export gerbers --output "$output_dir" "$pcb_file"
        
        gum style --foreground 212 "Gerbers exported to: $output_dir"
        sleep 2
        pcb_tools
      }
      
      export_complete_fab() {
        local pcb_file="$KICAD_CURRENT_PROJECT.kicad_pcb"
        local project_name
        local output_base
        local fab_dir
        
        project_name=$(basename "$KICAD_CURRENT_PROJECT")
        output_base="$(dirname "$KICAD_CURRENT_PROJECT")/output"
        fab_dir="$output_base/fab_package_$(date +%Y%m%d_%H%M%S)"
        
        mkdir -p "$fab_dir"/{gerbers,assembly,3d}
        
        gum spin --spinner dot --title "Exporting Gerbers..." -- \
          kicad-cli pcb export gerbers --output "$fab_dir/gerbers" "$pcb_file"
        
        gum spin --spinner dot --title "Exporting Drill files..." -- \
          kicad-cli pcb export drill --output "$fab_dir/gerbers" "$pcb_file"
        
        gum spin --spinner dot --title "Exporting Pick and Place..." -- \
          kicad-cli pcb export pos --output "$fab_dir/assembly/$project_name.pos" "$pcb_file"
        
        local sch_file="$KICAD_CURRENT_PROJECT.kicad_sch"
        if [ -f "$sch_file" ]; then
          gum spin --spinner dot --title "Exporting BOM..." -- \
            kicad-cli sch export bom --output "$fab_dir/assembly/$project_name.csv" "$sch_file"
        fi
        
        gum spin --spinner dot --title "Exporting 3D STEP..." -- \
          kicad-cli pcb export step --output "$fab_dir/3d/$project_name.step" "$pcb_file"
        
        cat > "$fab_dir/README.txt" <<EOF
      Fabrication Package: $project_name
      Generated: $(date)
      
      Contents:
      - gerbers/    : Gerber files and drill files
      - assembly/   : Pick and Place and BOM files
      - 3d/         : 3D STEP model
      
      Board specifications:
      - Layers: 2
      - Thickness: 1.6mm
      - Surface finish: HASL
      - Solder mask: Green
      - Silkscreen: White
      EOF
        
        cd "$output_base"
        zip -r "$(basename "$fab_dir").zip" "$(basename "$fab_dir")"
        
        gum style --foreground 212 "Complete fab package: $fab_dir.zip"
        sleep 3
        manufacturing_export
      }
      
      show_project_status() {
        local project_name
        local project_dir
        local file_count
        
        project_name=$(basename "$KICAD_CURRENT_PROJECT")
        project_dir=$(dirname "$KICAD_CURRENT_PROJECT")
        file_count=$(find "$project_dir" -maxdepth 1 -name "$(basename "$KICAD_CURRENT_PROJECT").*" -type f | wc -l)
        
        gum style \
          --foreground 212 \
          --border-foreground 212 \
          --border double \
          --align center \
          --width 50 \
          --margin "1 2" \
          --padding "1 2" \
          "Project: $project_name" \
          "" \
          "Location: $project_dir" \
          "" \
          "Files:" \
          "$file_count project files" \
          "" \
          "$(tree -L 2 "$project_dir" 2>/dev/null | tail -n 1)"
        
        gum input --placeholder "Press Enter to continue"
        project_operations
      }
      
      clear
      gum style \
        --foreground 212 \
        --border-foreground 212 \
        --border double \
        --align center \
        --width 50 \
        --margin "1 2" \
        --padding "1 2" \
        "KiCad TUI Manager" \
        "Version 1.0.0"
      
      sleep 1
      show_main_menu
    '';
  };
  
  kicadBatch = pkgs.writeShellScriptBin "kicad-batch" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    PROJECT="$1"
    COMMAND="$2"
    shift 2
    
    case "$COMMAND" in
      gerbers)
        kicad-cli pcb export gerbers -o ./output/gerbers "$PROJECT.kicad_pcb"
        ;;
      pdf)
        kicad-cli sch export pdf -o "$PROJECT.pdf" "$PROJECT.kicad_sch"
        kicad-cli pcb export pdf -o "$PROJECT-pcb.pdf" "$PROJECT.kicad_pcb"
        ;;
      bom)
        kicad-cli sch export bom -o "$PROJECT-bom.csv" "$PROJECT.kicad_sch"
        ;;
      *)
        echo "Unknown command: $COMMAND"
        exit 1
        ;;
    esac
  '';

in {
  inherit kicadTui kicadBatch;
}