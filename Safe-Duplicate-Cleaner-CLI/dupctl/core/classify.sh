#!/bin/bash
# classify.sh - Clasifică fișierele detectate în categorii
# Creează rapoarte structurate pentru decizii

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/policies/default.policy"
source "$SCRIPT_DIR/core/guard.sh"

# Funcție: Clasifică un set de fișiere ca duplicate
classify_duplicates() {
    local files=("$@")
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    
    [[ ${#files[@]} -eq 0 ]] && return 1
    
    echo "=== CLASIFICARE DUPLICATE ==="
    echo "Timestamp: $timestamp"
    echo "Fișiere analizate: ${#files[@]}"
    echo ""
    
    # Grupare după hash
    declare -A hash_groups
    declare -A file_info
    
    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && continue
        
        # Verifică protecție
        if ! can_operate_on_file "$file" "classify"; then
            continue
        fi
        
        local hash="$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)"
        local size="$(stat -c%s "$file" 2>/dev/null)"
        local mtime="$(stat -c%Y "$file" 2>/dev/null)"
        
        if [[ -n "$hash" ]]; then
            file_info["$file"]="$hash|$size|$mtime"
            
            if [[ -n "${hash_groups[$hash]}" ]]; then
                hash_groups[$hash]="${hash_groups[$hash]}|$file"
            else
                hash_groups[$hash]="$file"
            fi
        fi
    done
    
    # Identifică grupurile de duplicate exacte
    local duplicate_groups=0
    local total_duplicates=0
    
    for hash in "${!hash_groups[@]}"; do
        local group_files="${hash_groups[$hash]}"
        local count="$(echo "$group_files" | tr '|' '\n' | wc -l)"
        
        if [[ $count -gt 1 ]]; then
            ((duplicate_groups++))
            total_duplicates=$((total_duplicates + count))
            
            echo "Grup $duplicate_groups: $count fișiere identice"
            echo "Hash: ${hash:0:32}..."
            echo "----------------------------------------"
            
            # Afișează fișierele cu metadata
            echo "$group_files" | tr '|' '\n' | while read -r filepath; do
                [[ -z "$filepath" ]] && continue
                
                local info="${file_info[$filepath]}"
                IFS='|' read -r f_hash f_size f_mtime <<< "$info"
                
                local mtime_human
                mtime_human="$(date -d "@$f_mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")"
                
                printf "  📄 %-60s %10s bytes  %s\n" "$filepath" "$f_size" "$mtime_human"
            done
            
            echo ""
        fi
    done
    
    echo "========================================"
    echo "REZULTAT CLASIFICARE"
    echo "========================================"
    echo "Grupuri duplicate: $duplicate_groups"
    echo "Total fișiere duplicate: $total_duplicates"
    echo ""
    
    return 0
}

# Funcție: Clasifică versiuni vechi
classify_old_versions() {
    local files=("$@")
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    
    [[ ${#files[@]} -eq 0 ]] && return 1
    
    echo "=== CLASIFICARE VERSIUNI VECHI ==="
    echo "Timestamp: $timestamp"
    echo "Fișiere analizate: ${#files[@]}"
    echo ""
    
    local old_count=0
    local backup_count=0
    local temp_count=0
    
    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && continue
        
        # Verifică protecție
        if ! can_operate_on_file "$file" "classify"; then
            continue
        fi
        
        local filename="$(basename "$file")"
        local dirname="$(dirname "$file")"
        local size="$(stat -c%s "$file" 2>/dev/null)"
        local mtime="$(stat -c%Y "$file" 2>/dev/null)"
        local mtime_human="$(date -d "@$mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")"
        
        local classification=""
        local reason=""
        
        # Clasificare după sufixe
        for suffix in $OLD_VERSION_SUFFIXES; do
            if [[ "$filename" == *.$suffix ]]; then
                classification="OLD_VERSION"
                reason="Sufix .$suffix"
                ((old_count++))
                break
            fi
        done
        
        # Clasificare după pattern-uri
        if [[ -z "$classification" ]]; then
            echo "$OLD_VERSION_PATTERNS" | while read -r pattern description; do
                [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
                
                if [[ "$filename" =~ $pattern ]]; then
                    classification="PATTERN_MATCH"
                    reason="Pattern: $description"
                    ((backup_count++))
                    break
                fi
            done
        fi
        
        # Afișează clasificarea
        if [[ -n "$classification" ]]; then
            printf "📄 %-60s\n" "$file"
            printf "   Clasificare: %-20s %s\n" "$classification" "$reason"
            printf "   Mărime: %s bytes | Modificat: %s\n" "$size" "$mtime_human"
            
            # Caută versiune de bază
            local basefile=""
            case "$classification" in
                "OLD_VERSION")
                    basefile="${file%.*}"
                    ;;
                "PATTERN_MATCH")
                    # Încearcă să găsească fișierul de bază prin eliminarea pattern-ului
                    basefile="$dirname/$(echo "$filename" | sed 's/\.old$//;s/\.bak$//;s/_bak$//;s/ (1)$//;s/ (2)$//;s/_copy$//')"
                    ;;
            esac
            
            if [[ -n "$basefile" && -f "$basefile" ]]; then
                local base_mtime="$(stat -c%Y "$basefile" 2>/dev/null)"
                if [[ -n "$base_mtime" && $mtime -lt $base_mtime ]]; then
                    local age_diff=$(( (base_mtime - mtime) / 86400 ))
                    printf "   ✓ Versiune de bază: %s (cu %d zile mai nou)\n" "$basefile" "$age_diff"
                fi
            fi
            
            echo ""
        fi
    done
    
    echo "========================================"
    echo "REZULTAT CLASIFICARE VERSIUNI"
    echo "========================================"
    echo "Versiuni vechi (sufixe): $old_count"
    echo "Fișiere backup (pattern-uri): $backup_count"
    echo "Total clasificate: $((old_count + backup_count))"
    echo ""
}

# Funcție: Generează raport de clasificare
generate_classification_report() {
    local scope="${1:-.}"
    local report_file="$SCRIPT_DIR/reports/classification_$(date +%Y%m%d_%H%M%S).txt"
    
    mkdir -p "$SCRIPT_DIR/reports"
    
    {
        echo "========================================"
        echo "RAPORT DE CLASIFICARE DUPCTL"
        echo "========================================"
        echo "Data: $(date)"
        echo "Scope: $scope"
        echo "Politică: $SCRIPT_DIR/policies/default.policy"
        echo ""
        
        # Aici ar putea fi integrate rezultatele din scanare
        echo "[Acest raport ar conține rezultatele complete ale clasificării]"
        echo ""
        
    } > "$report_file"
    
    echo "Raport salvat: $report_file"
}

# Dacă scriptul este executat direct
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        "duplicates")
            shift
            classify_duplicates "$@"
            ;;
        "versions")
            shift
            classify_old_versions "$@"
            ;;
        "report")
            generate_classification_report "${2:-.}"
            ;;
        *)
            echo "Usage: $0 {duplicates|versions|report} [args...]"
            echo ""
            echo "Comenzi:"
            echo "  duplicates <files...>  - Clasifică fișierele ca duplicate"
            echo "  versions <files...>    - Clasifică fișierele ca versiuni vechi"
            echo "  report [scope]         - Generează raport de clasificare"
            ;;
    esac
fi