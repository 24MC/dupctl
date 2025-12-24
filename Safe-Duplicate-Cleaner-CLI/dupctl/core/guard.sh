#!/bin/bash
# guard.sh - Sistem de protecție defensiv pentru dupctl
# Implementează regulile hard de siguranță - DENY-BY-DEFAULT

# Calea către directorul dupctl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Încarcă politicile
source "$SCRIPT_DIR/policies/default.policy"

# Funcție: Verifică dacă un path este protejat
is_path_protected() {
    local path="$1"
    local abs_path
    
    # Obține calea absolută
    abs_path="$(realpath -m "$path" 2>/dev/null || echo "$path")"
    
    # Verifică directoare de sistem interzise
    while IFS='#' read -r protected_path comment; do
        protected_path="$(echo "$protected_path" | xargs)"
        [[ -z "$protected_path" || "$protected_path" =~ ^[[:space:]]*# ]] && continue
        
        if [[ "$abs_path" == "$protected_path"* ]] || [[ "$abs_path" == "$protected_path" ]]; then
            echo "SYSTEM_DIR:$protected_path"
            return 0
        fi
    done < "$SCRIPT_DIR/policies/protected.paths"
    
    # Verifică extensii interzite
    local filename="$(basename "$path")"
    local extension="${filename##*.}"
    
    if [[ "$filename" != "$extension" ]]; then
        for banned_ext in $BANNED_EXTENSIONS; do
            if [[ "$extension" == "$banned_ext" ]]; then
                echo "BANNED_EXT:$extension"
                return 0
            fi
        done
    fi
    
    # Verifică fișiere dotfile critice
    for banned_dot in $BANNED_DOTFILES; do
        if [[ "$filename" == "$banned_dot" ]]; then
            echo "BANNED_DOTFILE:$filename"
            return 0
        fi
    done
    
    # Verifică directoare /etc
    if [[ "$abs_path" == "/etc"* ]] || [[ "$abs_path" == "/usr/etc"* ]] || [[ "$abs_path" == "/opt/etc"* ]]; then
        echo "CONFIG_DIR:/etc"
        return 0
    fi
    
    return 1
}

# Funcție: Validează scope-ul de scanare
validate_scan_scope() {
    local scope="${1:-.}"
    local errors=0
    
    echo "=== VALIDARE SCOPE: $scope ==="
    
    # Dacă scope-ul este un director
    if [[ -d "$scope" ]]; then
        local protection
        protection="$(is_path_protected "$scope")"
        if [[ -n "$protection" ]]; then
            echo "❌ EROARE: Directorul '$scope' este PROTEJAT ($protection)"
            echo "   Nu se poate scana un director de sistem sau de configurare."
            return 1
        fi
        
        # Verifică subdirectoare
        find "$scope" -type d 2>/dev/null | while read -r dir; do
            protection="$(is_path_protected "$dir")"
            if [[ -n "$protection" ]]; then
                echo "⚠️  AVERTISMENT: Subdirector protejat detectat: $dir ($protection)"
                echo "   Acest subdirectory va fi IGNORAT din scanare."
                ((errors++))
            fi
        done
    fi
    
    # Dacă scope-ul este un fișier
    if [[ -f "$scope" ]]; then
        local protection
        protection="$(is_path_protected "$scope")"
        if [[ -n "$protection" ]]; then
            echo "❌ EROARE: Fișierul '$scope' este PROTEJAT ($protection)"
            return 1
        fi
    fi
    
    echo "✅ Scope-ul este sigur pentru scanare"
    return 0
}

# Funcție: Afișează regulile de protecție
show_protection_rules() {
    echo ""
    echo "==========================================="
    echo " REGULI DE PROTECȚIE DUPCTL"
    echo "==========================================="
    echo ""
    echo "🔒 DIRECTOARE INTERZISE:"
    while IFS='#' read -r path comment; do
        path="$(echo "$path" | xargs)"
        [[ -z "$path" || "$path" =~ ^[[:space:]]*# ]] && continue
        printf "  %-20s %s\n" "$path" "# $comment"
    done < "$SCRIPT_DIR/policies/protected.paths"
    
    echo ""
    echo "📝 EXTENSII INTERZISE:"
    for ext in $BANNED_EXTENSIONS; do
        echo "  .$ext"
    done
    
    echo ""
    echo "🔧 DOTFILES INTERZISE:"
    for dot in $BANNED_DOTFILES; do
        echo "  $dot"
    done
    
    echo ""
    echo "📂 ADDITIONAL PROTECTED:"
    echo "  /etc/* (toate fișierele de configurare sistem)"
    echo "  /usr/etc/*"
    echo "  /opt/etc/*"
    echo ""
    echo "==========================================="
}

# Funcție: Verifică dacă putem opera pe un fișier
can_operate_on_file() {
    local file="$1"
    local operation="$2"
    local protection
    
    protection="$(is_path_protected "$file")"
    if [[ -n "$protection" ]]; then
        echo "❌ OPERAȚIUNE BLOCATĂ: $operation pe '$file'"
        echo "   Motiv: $protection"
        return 1
    fi
    
    return 0
}

# Funcție: Creează director de carantină sigur
setup_quarantine() {
    local quarantine_dir="${1:-$QUARANTINE_DIR}"
    
    # Verifică dacă directorul de carantină este în loc sigur
    if [[ ! "$quarantine_dir" =~ ^/tmp ]]; then
        echo "❌ Directorul de carantină trebuie să fie în /tmp pentru siguranță"
        return 1
    fi
    
    mkdir -p "$quarantine_dir" || {
        echo "❌ Nu se poate crea directorul de carantină: $quarantine_dir"
        return 1
    }
    
    echo "$quarantine_dir"
    return 0
}

# Dacă scriptul este executat direct
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        "rules")
            show_protection_rules
            ;;
        "check")
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 check <path>"
                exit 1
            fi
            result="$(is_path_protected "$2")"
            if [[ -n "$result" ]]; then
                echo "🔒 PROTEJAT: $result"
                exit 1
            else
                echo "✅ SIGUR: Nu este protejat"
                exit 0
            fi
            ;;
        "scope")
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 scope <directory>"
                exit 1
            fi
            validate_scan_scope "$2"
            ;;
        *)
            echo "Usage: $0 {rules|check <path>|scope <directory>}"
            echo ""
            echo "Comenzi:"
            echo "  rules          - Afișează toate regulile de protecție"
            echo "  check <path>   - Verifică dacă un path este protejat"
            echo "  scope <dir>    - Validează un scope de scanare"
            ;;
    esac
fi