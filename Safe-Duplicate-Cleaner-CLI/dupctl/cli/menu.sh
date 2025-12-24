#!/bin/bash
# menu.sh - Meniu CLI interactiv pentru dupctl
# Entry-point principal pentru utilizatorii umani

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Încarcă modulele necesare
cd "$SCRIPT_DIR" || exit 1
source "$SCRIPT_DIR/policies/default.policy"
source "$SCRIPT_DIR/core/guard.sh"

# Configurare meniu
MENU_TITLE="Duplicate & Version Cleaner"
MENU_VERSION="1.0.0"
DRY_RUN=true  # Implicit sigur

# Funcție: Curăță ecranul și afișează header
show_header() {
    clear
    echo "==========================================="
    echo "  $MENU_TITLE"
    echo "  Version: $MENU_VERSION"
    echo "==========================================="
    echo ""
}

# Funcție: Afișează statusul curent
show_status() {
    echo "Status:"
    echo "  Mod siguranță: $([ "$DRY_RUN" = true ] && echo "✅ DRY-RUN (sigur)" || echo "⚠️  EXECUTARE (real)")"
    echo "  Director curent: $(pwd)"
    echo ""
}

# Funcție: Meniu principal
show_main_menu() {
    show_header
    show_status
    
    echo "Meniu principal:"
    echo ""
    echo "  1) Scan & audit duplicates"
    echo "  2) Scan & audit old versions"
    echo "  3) Suggest cleanup actions"
    echo "  4) Clean old versions (safe scope)"
    echo "  5) Deduplicate identical files"
    echo "  6) Show last report"
    echo "  7) Configure policy"
    echo "  8) Exit"
    echo ""
    echo "  9) Show protection rules"
    echo ""
}

# Funcție: Citește opțiunea cu validare
read_option() {
    local choice
    read -p "Alege o opțiune (1-9): " choice
    
    case $choice in
        [1-9])
            return $choice
            ;;
        *)
            echo "Opțiune invalidă. Apasă ENTER pentru a continua..."
            read
            return 0
            ;;
    esac
}

# Funcție: Configurare scope de scanare
configure_scope() {
    show_header
    echo "=== CONFIGURARE SCOPE ==="
    echo ""
    echo "Scope-ul curent: ${SCOPE:-.}"
    echo ""
    echo "Opțiuni:"
    echo "  1) Folosește directorul curent ($(pwd))"
    echo "  2) Folosește ~/Downloads"
    echo "  3) Folosește ~/Documents"
    echo "  4) Folosește ~/Pictures"
    echo "  5) Specifică alt director"
    echo "  6) Înapoi la meniul principal"
    echo ""
    
    read -p "Alege o opțiune (1-6): " choice
    
    case $choice in
        1)
            SCOPE="."
            echo "Scope setat la: $SCOPE"
            ;;
        2)
            SCOPE="$HOME/Downloads"
            echo "Scope setat la: $SCOPE"
            ;;
        3)
            SCOPE="$HOME/Documents"
            echo "Scope setat la: $SCOPE"
            ;;
        4)
            SCOPE="$HOME/Pictures"
            echo "Scope setat la: $SCOPE"
            ;;
        5)
            read -p "Introdu calea directorului: " custom_path
            if [[ -d "$custom_path" ]]; then
                SCOPE="$custom_path"
                echo "Scope setat la: $SCOPE"
            else
                echo "❌ Directorul nu există: $custom_path"
            fi
            ;;
        6)
            return
            ;;
        *)
            echo "Opțiune invalidă"
            ;;
    esac
    
    echo ""
    read -p "Apasă ENTER pentru a continua..."
}

# Funcție: Meniu de configurare
show_config_menu() {
    while true; do
        show_header
        echo "=== CONFIGURARE ==="
        echo ""
        echo "Opțiuni de configurare:"
        echo ""
        echo "  1) Configurează scope de scanare"
        echo "  2) Toggle dry-run mode (acum: $([ "$DRY_RUN" = true ] && echo "activat" || echo "dezactivat"))"
        echo "  3) Afișează politica curentă"
        echo "  4) Afișează reguli de protecție"
        echo "  5) Înapoi la meniul principal"
        echo ""
        
        read -p "Alege o opțiune (1-5): " choice
        
        case $choice in
            1)
                configure_scope
                ;;
            2)
                DRY_RUN=$([ "$DRY_RUN" = true ] && echo false || echo true)
                echo "Dry-run mode: $([ "$DRY_RUN" = true ] && echo "activat" || echo "dezactivat")"
                read -p "Apasă ENTER pentru a continua..."
                ;;
            3)
                echo ""
                cat "$SCRIPT_DIR/policies/default.policy" | head -50
                echo ""
                read -p "Apasă ENTER pentru a continua..."
                ;;
            4)
                show_protection_rules
                read -p "Apasă ENTER pentru a continua..."
                ;;
            5)
                return
                ;;
            *)
                echo "Opțiune invalidă"
                read -p "Apasă ENTER pentru a continua..."
                ;;
        esac
    done
}

# Funcție: Confirmare acțiune periculoasă
confirm_dangerous_action() {
    local action="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "⚠️  MOD DRY-RUN ACTIV"
        echo "   Se va executa doar o simulare."
        echo ""
        read -p "Continuă cu simularea? (y/N): " confirm
        [[ "$confirm" == "y" || "$confirm" == "Y" ]]
    else
        echo "🚨 MOD EXECUTARE ACTIV"
        echo "   Această acțiune VA MODIFICA fișierele!"
        echo ""
        echo "Pentru a continua, tastează: CONFIRM EXECUTARE"
        read -p "> " confirm
        [[ "$confirm" == "CONFIRM EXECUTARE" ]]
    fi
}

# Funcție: Execută scanare duplicate
execute_scan_duplicates() {
    show_header
    echo "=== SCANARE DUPLICATE ==="
    echo ""
    
    # Configurează scope dacă nu este setat
    if [[ -z "${SCOPE:-}" ]]; then
        configure_scope
        [[ -z "${SCOPE:-}" ]] && return
    fi
    
    echo "Scope: $SCOPE"
    echo ""
    
    # Validează scope
    if ! validate_scan_scope "$SCOPE"; then
        echo ""
        read -p "Apasă ENTER pentru a continua..."
        return
    fi
    
    # Execută scanarea
    echo "🔍 Scanare în curs..."
    echo ""
    
    # Simulare scanare (în producție ar apela scan_duplicates din scan.sh)
    echo "[Aici s-ar executa scanarea reală a duplicatelor]"
    echo ""
    echo "Scanare completă."
    
    read -p "Apasă ENTER pentru a continua..."
}

# Funcție: Execută scanare versiuni vechi
execute_scan_versions() {
    show_header
    echo "=== SCANARE VERSIUNI VECHI ==="
    echo ""
    
    if [[ -z "${SCOPE:-}" ]]; then
        configure_scope
        [[ -z "${SCOPE:-}" ]] && return
    fi
    
    echo "Scope: $SCOPE"
    echo ""
    
    # Validează scope
    if ! validate_scan_scope "$SCOPE"; then
        echo ""
        read -p "Apasă ENTER pentru a continua..."
        return
    fi
    
    echo "🔍 Scanare versiuni vechi în curs..."
    echo ""
    
    # Simulare scanare
    echo "[Aici s-ar executa scanarea reală a versiunilor vechi]"
    echo ""
    echo "Scanare completă."
    
    read -p "Apasă ENTER pentru a continua..."
}

# Funcție: Sugerează acțiuni
execute_suggest() {
    show_header
    echo "=== SUGESTII DE CURĂȚARE ==="
    echo ""
    
    if [[ -z "${SCOPE:-}" ]]; then
        configure_scope
        [[ -z "${SCOPE:-}" ]] && return
    fi
    
    echo "Analiză scope: $SCOPE"
    echo ""
    echo "🔍 Generare sugestii..."
    echo ""
    
    # Simulare generare sugestii
    echo "[Aici s-ar genera sugestii concrete de curățare]"
    echo ""
    echo "Sugestii generate."
    
    read -p "Apasă ENTER pentru a continua..."
}

# Funcție: Curăță versiuni vechi
execute_clean_old() {
    show_header
    echo "=== CURĂȚARE VERSIUNI VECHI ==="
    echo ""
    
    if [[ -z "${SCOPE:-}" ]]; then
        configure_scope
        [[ -z "${SCOPE:-}" ]] && return
    fi
    
    echo "Scope: $SCOPE"
    echo ""
    
    # Cere confirmare
    if ! confirm_dangerous_action "curățare versiuni vechi"; then
        echo "Operațiune anulată."
        read -p "Apasă ENTER pentru a continua..."
        return
    fi
    
    echo ""
    echo "🔧 Executare curățare..."
    echo ""
    
    # Simulare curățare
    echo "[Aici s-ar executa mutarea versiunilor vechi în carantină]"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "✅ Simulare completă - nicio modificare reală"
    else
        echo "✅ Versiuni vechi mutate în carantină"
    fi
    
    read -p "Apasă ENTER pentru a continua..."
}

# Funcție: Deduplicare
execute_dedupe() {
    show_header
    echo "=== DEDUPLICARE FIȘIERE ==="
    echo ""
    
    if [[ -z "${SCOPE:-}" ]]; then
        configure_scope
        [[ -z "${SCOPE:-}" ]] && return
    fi
    
    echo "Scope: $SCOPE"
    echo ""
    
    # Cere confirmare
    if ! confirm_dangerous_action "deduplicare"; then
        echo "Operațiune anulată."
        read -p "Apasă ENTER pentru a continua..."
        return
    fi
    
    echo ""
    echo "🔧 Executare deduplicare..."
    echo ""
    
    # Simulare deduplicare
    echo "[Aici s-ar executa înlocuirea duplicatelor cu hardlink-uri]"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "✅ Simulare completă - nicio modificare reală"
    else
        echo "✅ Duplicatele au fost înlocuite cu hardlink-uri"
    fi
    
    read -p "Apasă ENTER pentru a continua..."
}

# Funcție: Afișează raport
show_report() {
    show_header
    echo "=== ULTIMUL RAPORT ==="
    echo ""
    
    local report_dir="$SCRIPT_DIR/reports"
    
    if [[ -d "$report_dir" ]]; then
        local latest_report
        latest_report="$(find "$report_dir" -name "*.txt" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
        
        if [[ -n "$latest_report" && -f "$latest_report" ]]; then
            echo "Raport: $latest_report"
            echo ""
            cat "$latest_report" | head -100
            echo ""
        else
            echo "Nu există rapoarte disponibile."
            echo ""
            echo "Execută o scanare pentru a genera un raport."
        fi
    else
        echo "Directorul de rapoarte nu există."
        echo ""
        echo "Execută o scanare pentru a crea rapoarte."
    fi
    
    read -p "Apasă ENTER pentru a continua..."
}

# Funcție principală
main() {
    while true; do
        show_main_menu
        read_option
        option=$?
        
        case $option in
            1)
                execute_scan_duplicates
                ;;
            2)
                execute_scan_versions
                ;;
            3)
                execute_suggest
                ;;
            4)
                execute_clean_old
                ;;
            5)
                execute_dedupe
                ;;
            6)
                show_report
                ;;
            7)
                show_config_menu
                ;;
            8)
                show_header
                echo "Mulțumesc pentru utilizarea dupctl!"
                echo ""
                exit 0
                ;;
            9)
                show_protection_rules
                read -p "Apasă ENTER pentru a continua..."
                ;;
            0)
                # Opțiune invalidă - read_option deja a afișat mesajul
                ;;
        esac
    done
}

# Verifică dacă scriptul este executat direct
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Verifică dependențe
    for cmd in find stat sha256sum; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "❌ Eroare: Comanda '$cmd' nu este disponibilă"
            exit 1
        fi
    done
    
    # Execută meniul principal
    main "$@"
fi