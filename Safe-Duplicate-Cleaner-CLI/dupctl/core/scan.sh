#!/bin/bash
# scan.sh - Sistem de scanare pentru duplicate și versiuni
# Implementează scanare sigură cu protecție defensivă

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/policies/default.policy"
source "$SCRIPT_DIR/core/guard.sh"

# Global vars
SCAN_RESULTS="/tmp/dupctl_scan_$$.tmp"
HASH_CACHE="/tmp/dupctl_hash_$$.tmp"

# Cleanup la exit
trap "rm -f $SCAN_RESULTS $HASH_CACHE" EXIT

# Funcție: Scanează după fișiere duplicate
scan_duplicates() {
    local scope="${1:-.}"
    local min_size="${2:-$MIN_FILE_SIZE}"
    
    echo "=== SCANARE DUPLICATE ==="
    echo "Scope: $scope"
    echo "Mărime minimă: $min_size bytes"
    echo ""
    
    # Validează scope-ul
    if ! validate_scan_scope "$scope"; then
        echo "❌ Scanare anulată: scope invalid"
        return 1
    fi
    
    # Găsește toate fișierele din scope
    local file_count=0
    local duplicate_groups=0
    
    # Array asociativ pentru grupare după mărime
    declare -A size_groups
    
    while IFS= read -r -d '' file; do
        # Verifică protecție
        if ! can_operate_on_file "$file" "scan"; then
            continue
        fi
        
        # Obține mărimea
        local size
        size="$(stat -c%s "$file" 2>/dev/null)" || continue
        
        # Filtrare după mărime minimă
        if [[ $size -lt $min_size ]]; then
            continue
        fi
        
        # Grupare după mărime
        if [[ -n "${size_groups[$size]}" ]]; then
            size_groups[$size]="${size_groups[$size]}|$file"
        else
            size_groups[$size]="$file"
        fi
        
        ((file_count++))
        
        # Progress indicator
        if [[ $((file_count % 50)) -eq 0 ]]; then
            echo -n "."
        fi
        
    done < <(find "$scope" -type f -print0 2>/dev/null)
    
    echo ""
    echo "Fișiere scanate: $file_count"
    echo ""
    
    # Procesează grupurile cu aceeași mărime
    echo "=== GRUPURI CU ACEEAȘI MĂRIME ==="
    
    for size in "${!size_groups[@]}"; do
        local files="${size_groups[$size]}"
        local count="$(echo "$files" | tr '|' '\n' | wc -l)"
        
        if [[ $count -gt 1 ]]; then
            echo ""
            echo "Grup $((++duplicate_groups)): $count fișiere, mărime $size bytes"
            echo "----------------------------------------"
            
            # Calculează hash pentru fiecare fișier din grup
            declare -A hash_groups
            
            echo "$files" | tr '|' '\n' | while read -r filepath; do
                [[ -z "$filepath" ]] && continue
                
                local hash
                # Pentru fișiere mari, folosește hash parțial întâi
                if [[ $size -gt $((MAX_SIZE_FULL_HASH * 1024 * 1024)) ]] && [[ $MAX_SIZE_FULL_HASH -gt 0 ]]; then
                    hash="$(head -c 1048576 "$filepath" | sha256sum | cut -d' ' -f1)"
                    echo "  📄 $filepath (hash parțial)"
                else
                    hash="$(sha256sum "$filepath" 2>/dev/null | cut -d' ' -f1)"
                    echo "  📄 $filepath (hash complet)"
                fi
                
                if [[ -n "$hash" ]]; then
                    if [[ -n "${hash_groups[$hash]}" ]]; then
                        hash_groups[$hash]="${hash_groups[$hash]}|$filepath"
                    else
                        hash_groups[$hash]="$filepath"
                    fi
                fi
            done
            
            # Afișează duplicatele exacte
            for hash in "${!hash_groups[@]}"; do
                local same_hash_files="${hash_groups[$hash]}"
                local same_count="$(echo "$same_hash_files" | tr '|' '\n' | wc -l)"
                
                if [[ $same_count -gt 1 ]]; then
                    echo "    🔍 DUPLICATE EXACTE (hash: ${hash:0:16}...)"
                    echo "$same_hash_files" | tr '|' '\n' | sed 's/^/      /'
                    echo "    ---"
                fi
            done
        fi
    done
    
    echo ""
    echo "========================================"
    echo "REZULTAT SCANARE DUPLICATE"
    echo "========================================"
    echo "Total fișiere scanate: $file_count"
    echo "Grupuri cu mărime similară: $duplicate_groups"
    echo ""
}

# Funcție: Scanează după versiuni vechi
scan_old_versions() {
    local scope="${1:-.}"
    
    echo "=== SCANARE VERSIUNI VECHI ==="
    echo "Scope: $scope"
    echo ""
    
    # Validează scope-ul
    if ! validate_scan_scope "$scope"; then
        echo "❌ Scanare anulată: scope invalid"
        return 1
    fi
    
    local old_version_count=0
    
    # Caută fișiere cu sufixe de versiuni vechi
    echo "--- Căutare după sufixe clasice ---"
    
    for suffix in $OLD_VERSION_SUFFIXES; do
        echo ""
        echo "Pattern: *.$suffix"
        
        find "$scope" -type f -name "*.$suffix" 2>/dev/null | while read -r oldfile; do
            if can_operate_on_file "$oldfile" "scan"; then
                local basefile="${oldfile%.$suffix}"
                
                if [[ -f "$basefile" ]]; then
                    echo "  🔍 VERSIUNE VECHE: $oldfile"
                    echo "     Versiune de bază: $basefile"
                    
                    # Compară timpții
                    local old_time="$(stat -c%Y "$oldfile" 2>/dev/null)"
                    local base_time="$(stat -c%Y "$basefile" 2>/dev/null)"
                    
                    if [[ -n "$old_time" && -n "$base_time" ]]; then
                        if [[ $old_time -lt $base_time ]]; then
                            echo "     ✓ Confirmat: mai vechi cu $(( (base_time - old_time) / 60 )) minute"
                        else
                            echo "     ⚠️  Atenție: de fapt este mai nou"
                        fi
                    fi
                    
                    ((old_version_count++))
                fi
            fi
        done
    done
    
    # Caută după pattern-uri regex
    echo ""
    echo "--- Căutare după pattern-uri regex ---"
    
    echo "$OLD_VERSION_PATTERNS" | while read -r pattern description; do
        [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
        
        echo ""
        echo "Pattern: $pattern ($description)"
        
        find "$scope" -type f -regextype posix-extended -regex ".*$pattern" 2>/dev/null | while read -r oldfile; do
            if can_operate_on_file "$oldfile" "scan"; then
                echo "  🔍 VERSIUNE VECHE: $oldfile"
                ((old_version_count++))
            fi
        done
    done
    
    echo ""
    echo "========================================"
    echo "REZULTAT SCANARE VERSIUNI VECHI"
    echo "========================================"
    echo "Total versiuni vechi detectate: $old_version_count"
    echo ""
}

# Dacă scriptul este executat direct
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        "duplicates")
            scan_duplicates "${2:-.}"
            ;;
        "versions")
            scan_old_versions "${2:-.}"
            ;;
        *)
            echo "Usage: $0 {duplicates|versions} [scope]"
            echo ""
            echo "Comenzi:"
            echo "  duplicates [scope]  - Scanează după fișiere duplicate"
            echo "  versions [scope]    - Scanează după versiuni vechi"
            echo ""
            echo "Exemple:"
            echo "  $0 duplicates ~/Downloads"
            echo "  $0 versions ~/Documents"
            ;;
    esac
fi