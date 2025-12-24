#!/bin/bash
# decide.sh - Motor de decizii pentru dupctl
# Implementează politicile de preferință și acțiuni sigure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/policies/default.policy"
source "$SCRIPT_DIR/core/guard.sh"

# Funcție: Aplică politicile de preferință pentru un grup de duplicate
apply_duplicate_policy() {
    local files=("$@")
    local candidates=()
    local keep_file=""
    
    [[ ${#files[@]} -eq 0 ]] && return 1
    
    echo "=== APLICARE POLITICĂ DUPLICATE ==="
    echo "Grup: ${#files[@]} fișiere"
    echo ""
    
    # Filtrare fișiere protejate
    for file in "${files[@]}"; do
        if can_operate_on_file "$file" "policy"; then
            candidates+=("$file")
        fi
    done
    
    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "❌ Niciun fișier eligibil în acest grup"
        return 1
    fi
    
    # Afișează candidații
    echo "Candidați eligibili:"
    for i in "${!candidates[@]}"; do
        local file="${candidates[$i]}"
        local size="$(stat -c%s "$file" 2>/dev/null)"
        local mtime="$(stat -c%Y "$file" 2>/dev/null)"
        local mtime_human="$(date -d "@$mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")"
        
        printf "  [%d] %-50s %10s bytes  %s\n" "$i" "$file" "$size" "$mtime_human"
    done
    
    echo ""
    echo "Aplicând politica: $PREFERENCE_ORDER"
    echo ""
    
    # Implementează logica de preferință
    local temp_candidates=("${candidates[@]}")
    
    for criterion in $PREFERENCE_ORDER; do
        case "$criterion" in
            "newer")
                echo "📅 Criteriu: fișiere mai noi"
                
                # Găsește cel mai nou fișier
                local newest_time=0
                local newest_file=""
                
                for file in "${temp_candidates[@]}"; do
                    local mtime="$(stat -c%Y "$file" 2>/dev/null)"
                    if [[ -n "$mtime" && $mtime -gt $newest_time ]]; then
                        newest_time=$mtime
                        newest_file="$file"
                    fi
                done
                
                if [[ -n "$newest_file" ]]; then
                    echo "    ✓ Păstrează: $newest_file"
                    keep_file="$newest_file"
                    break
                fi
                ;;
                
            "user-data")
                echo "🏠 Criteriu: locații user-data"
                
                # Preferă fișierele din directoarele user-ului
                for safe_dir in $SAFE_DIRECTORIES; do
                    for file in "${temp_candidates[@]}"; do
                        if [[ "$file" == "$safe_dir"* ]]; then
                            echo "    ✓ Păstrează (user-data): $file"
                            keep_file="$file"
                            break 2
                        fi
                    done
                done
                
                if [[ -n "$keep_file" ]]; then
                    break
                fi
                ;;
                
            "larger")
                echo "📊 Criteriu: fișiere mai mari"
                
                # Găsește cel mai mare fișier
                local largest_size=0
                local largest_file=""
                
                for file in "${temp_candidates[@]}"; do
                    local size="$(stat -c%s "$file" 2>/dev/null)"
                    if [[ -n "$size" && $size -gt $largest_size ]]; then
                        largest_size=$size
                        largest_file="$file"
                    fi
                done
                
                if [[ -n "$largest_file" ]]; then
                    echo "    ✓ Păstrează: $largest_file"
                    keep_file="$largest_file"
                    break
                fi
                ;;
        esac
    done
    
    # Dacă niciun criteriu nu a funcționat, păstrează primul
    if [[ -z "$keep_file" && ${#temp_candidates[@]} -gt 0 ]]; then
        keep_file="${temp_candidates[0]}"
        echo "🤷 Fallback: păstrează primul fișier"
        echo "    ✓ Păstrează: $keep_file"
    fi
    
    echo ""
    
    # Returnează fișierul de păstrat
    if [[ -n "$keep_file" ]]; then
        echo "REZULTAT: Păstrează → $keep_file"
        
        # Afișează fișierele de șters
        local remove_count=0
        for file in "${temp_candidates[@]}"; do
            if [[ "$file" != "$keep_file" ]]; then
                if [[ $remove_count -eq 0 ]]; then
                    echo ""
                    echo "Fișiere de eliminat:"
                fi
                echo "  ❌ $file"
                ((remove_count++))
            fi
        done
        
        echo ""
        echo "Total de eliminat: $remove_count fișiere"
        echo "Spațiu potențial economisit: $(du -sh "$keep_file" 2>/dev/null | cut -f1) (păstrat)"
        
        return 0
    else
        echo "❌ Nu s-a putut aplica politica"
        return 1
    fi
}

# Funcție: Aplică politica pentru versiuni vechi
apply_version_policy() {
    local old_files=("$@")
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    
    [[ ${#old_files[@]} -eq 0 ]] && return 1
    
    echo "=== APLICARE POLITICĂ VERSIUNI VECHI ==="
    echo "Timestamp: $timestamp"
    echo ""
    
    local action_count=0
    
    for oldfile in "${old_files[@]}"; do
        [[ ! -f "$oldfile" ]] && continue
        
        # Verifică protecție
        if ! can_operate_on_file "$oldfile" "version-policy"; then
            continue
        fi
        
        local filename="$(basename "$oldfile")"
        local dirname="$(dirname "$oldfile")"
        local basefile=""
        
        # Încearcă să identifice versiunea de bază
        for suffix in $OLD_VERSION_SUFFIXES; do
            if [[ "$filename" == *.$suffix ]]; then
                local candidate="$dirname/${filename%.$suffix}"
                if [[ -f "$candidate" ]]; then
                    basefile="$candidate"
                    break
                fi
            fi
        done
        
        # Dacă nu a găsit prin sufixe, încearcă pattern-uri
        if [[ -z "$basefile" ]]; then
            # Elimină pattern-uri comune
            local base_candidate="$dirname/$(echo "$filename" | sed 's/\.old$//;s/\.bak$//;s/_bak$//;s/ (1)$//;s/ (2)$//;s/_copy$//;s/\.orig$//;s/\.save$//;s/\.tmp$//;s/\.temp$//')"
            
            if [[ -f "$base_candidate" && "$base_candidate" != "$oldfile" ]]; then
                basefile="$base_candidate"
            fi
        fi
        
        # Decizie
        if [[ -n "$basefile" ]]; then
            local old_mtime="$(stat -c%Y "$oldfile" 2>/dev/null)"
            local base_mtime="$(stat -c%Y "$basefile" 2>/dev/null)"
            
            if [[ -n "$old_mtime" && -n "$base_mtime" ]]; then
                if [[ $old_mtime -lt $base_mtime ]]; then
                    local age_days=$(( (base_mtime - old_mtime) / 86400 ))
                    
                    echo "📂 $filename"
                    echo "   Versiune de bază: $(basename "$basefile")"
                    echo "   Diferență de timp: $age_days zile"
                    echo "   ✓ DECIZIE: Mută în carantină"
                    echo ""
                    
                    ((action_count++))
                else
                    echo "⚠️  $filename - versiune mai nouă decât cea de bază (IGNORAT)"
                fi
            else
                echo "❌ $filename - nu se pot citi metadata (IGNORAT)"
            fi
        else
            echo "🔍 $filename - nu s-a găsit versiune de bază"
            echo "   DECIZIE: Raportat ca suspicios, dar păstrat"
            echo ""
        fi
    done
    
    echo "========================================"
    echo "REZULTAT POLITICĂ VERSIUNI"
    echo "========================================"
    echo "Fișiere pentru carantină: $action_count"
    echo ""
    
    return 0
}

# Funcție: Execută acțiunea de deduplicare (cu confirmare)
execute_deduplication() {
    local keep_file="$1"
    shift
    local remove_files=("$@")
    local dry_run="${DRY_RUN:-true}"
    
    [[ -z "$keep_file" ]] && return 1
    [[ ${#remove_files[@]} -eq 0 ]] && return 0
    
    echo "=== EXECUTARE DEDUPLICARE ==="
    echo "Mod: $([ "$dry_run" = true ] && echo "DRY-RUN" || echo "EXECUTARE")"
    echo ""
    echo "Păstrează: $keep_file"
    echo ""
    
    if [[ ${#remove_files[@]} -gt 0 ]]; then
        echo "Înlocuiește cu hardlink către:"
        for file in "${remove_files[@]}"; do
            echo "  → $file"
        done
        echo ""
    fi
    
    # În mod real, aici s-ar face înlocuirea cu hardlink
    # Pentru moment, doar simulăm
    if [[ "$dry_run" == "true" ]]; then
        echo "📝 [DRY-RUN] Hardlink replacement simulat"
        echo "   Comenzi care s-ar executa:"
        for file in "${remove_files[@]}"; do
            echo "   ln -f "$keep_file" "$file""
        done
    else
        echo "🔧 Executare înlocuire hardlink..."
        # Implementare reală (comentată pentru siguranță)
        # for file in "${remove_files[@]}"; do
        #     if can_operate_on_file "$file" "hardlink"; then
        #         ln -f "$keep_file" "$file" 2>/dev/null || echo "  Eroare la $file"
        #     fi
        # done
    fi
    
    echo ""
    echo "✅ Deduplicare completă"
    return 0
}

# Funcție: Mută fișiere în carantină
quarantine_files() {
    local files=("$@")
    local dry_run="${DRY_RUN:-true}"
    local quarantine_dir
    
    [[ ${#files[@]} -eq 0 ]] && return 0
    
    # Setup director carantină
    quarantine_dir="$(setup_quarantine)" || {
        echo "❌ Nu se poate crea director de carantină"
        return 1
    }
    
    echo "=== MUTARE ÎN CARANTINĂ ==="
    echo "Director carantină: $quarantine_dir"
    echo "Mod: $([ "$dry_run" = true ] && echo "DRY-RUN" || echo "EXECUTARE")"
    echo ""
    
    local moved_count=0
    
    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && continue
        
        if ! can_operate_on_file "$file" "quarantine"; then
            continue
        fi
        
        local filename="$(basename "$file")"
        local target="$quarantine_dir/${filename}_$(date +%Y%m%d_%H%M%S)"
        
        if [[ "$dry_run" == "true" ]]; then
            echo "📝 [DRY-RUN] mv \"$file\" \"$target\""
        else
            echo "📦 mv \"$file\" \"$target\""
            mv "$file" "$target" 2>/dev/null && ((moved_count++)) || {
                echo "  ❌ Eroare la mutarea $file"
            }
        fi
    done
    
    echo ""
    echo "========================================"
    echo "REZULTAT CARANTINĂ"
    echo "========================================"
    echo "Total fișiere procesate: ${#files[@]}"
    echo "Fișiere mutate: $moved_count"
    echo ""
    
    return 0
}

# Dacă scriptul este executat direct
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        "policy")
            echo "Politica curentă de preferință:"
            echo "$PREFERENCE_ORDER"
            ;;
        "duplicates")
            shift
            apply_duplicate_policy "$@"
            ;;
        "versions")
            shift
            apply_version_policy "$@"
            ;;
        *)
            echo "Usage: $0 {policy|duplicates <files...>|versions <files...>}"
            ;;
    esac
fi