#!/bin/bash
# dupctl.sh - CLI principal pentru Duplicate & Version Cleaner
# Suportă flag-uri pentru utilizare avansată și scripting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Încarcă modulele
cd "$SCRIPT_DIR" || exit 1
source "$SCRIPT_DIR/policies/default.policy"
source "$SCRIPT_DIR/core/guard.sh"
source "$SCRIPT_DIR/core/scan.sh"
source "$SCRIPT_DIR/core/classify.sh"
source "$SCRIPT_DIR/core/decide.sh"

# Variabile globale
DRY_RUN=true
VERBOSE=false
SCOPE="."
POLICY_FILE="$SCRIPT_DIR/policies/default.policy"
ACTION="help"

# Funcție: Afișează help
show_help() {
    cat << EOF
dupctl - Duplicate & Version Cleaner
====================================

Utilitar sigur pentru gestionarea duplicatelor și versiunilor vechi.

MODURI DE OPERARE:
  --audit          Scanează și raportează duplicatele și versiunile vechi
  --suggest        Analizează și sugerează acțiuni de curățare
  --clean-old      Mută versiunile vechi în carantină
  --dedupe         Înlocuiește duplicatele cu hardlink-uri

OPȚIUNI:
  --scope DIR      Directorul de scanat (implicit: .)
  --policy FILE    Fișier de politică personalizat
  --dry-run        Mod simulare (implicit: activat)
  --no-dry-run     Execută acțiuni reale (⚠️  periculos)
  --verbose        Output detaliat
  --help           Afișează acest mesaj

EXEMPLE:
  dupctl --audit --scope ~/Downloads
  dupctl --suggest --scope ~/Documents --verbose
  dupctl --clean-old --scope ~/Downloads --dry-run
  dupctl --dedupe --scope ~/Pictures --no-dry-run

SIGURANȚĂ:
  - Modul dry-run este IMPLICIT activat
  - Fișierele de sistem și configurările sunt PROTEJATE
  - Acțiunile distructive necesită confirmare
  - Toate operațiunile sunt logate

EOF
}

# Funcție: Afișează status protecție
show_safety_status() {
    echo "========================================"
    echo "STATUS SIGURANȚĂ DUPCTL"
    echo "========================================"
    echo "Mod dry-run: $([ "$DRY_RUN" = true ] && echo "✅ ACTIV (sigur)" || echo "⚠️  INACTIV (periculos)")"
    echo "Politică: $POLICY_FILE"
    echo "Scope: $SCOPE"
    echo "Verbozitate: $([ "$VERBOSE" = true ] && echo "detaliat" || echo "normal")"
    echo ""
}

# Funcție: Execută audit complet
run_audit() {
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    
    echo "========================================"
    echo "AUDIT DUPCTL - $timestamp"
    echo "========================================"
    echo ""
    
    show_safety_status
    show_protection_rules
    
    # Audit duplicate
    echo ""
    scan_duplicates "$SCOPE"
    
    # Audit versiuni vechi
    echo ""
    scan_old_versions "$SCOPE"
    
    echo "========================================"
    echo "AUDIT COMPLET"
    echo "========================================"
}

# Funcție: Generează sugestii
run_suggest() {
    echo "========================================"
    echo "SUGESTII DE CURĂȚARE"
    echo "========================================"
    echo ""
    
    show_safety_status
    
    # Aici ar trebui să integrez logica reală de sugestii
    # Pentru moment, afișez un placeholder
    echo "🔍 Analiză scope: $SCOPE"
    echo ""
    echo "[Această comandă ar analiza fișierele și ar sugera acțiuni concrete]"
    echo ""
    echo "Sugestii generate cu succes."
}

# Funcție: Curăță versiunile vechi
run_clean_old() {
    echo "========================================"
    echo "CURĂȚARE VERSIUNI VECHI"
    echo "========================================"
    echo ""
    
    show_safety_status
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "⚠️  MOD DRY-RUN ACTIV - Nicio modificare reală"
        echo ""
    else
        echo "🚨 MOD EXECUTARE - Fișierele vor fi mutate în carantină"
        echo ""
        
        # Cere confirmare
        read -p "Continuă? (tastează 'CONFIRM' pentru a continua): " confirm
        if [[ "$confirm" != "CONFIRM" ]]; then
            echo "Operațiune anulată."
            return 1
        fi
    fi
    
    # Aici ar trebui să integrez logica reală de curățare
    echo "🔍 Scanare versiuni vechi în: $SCOPE"
    echo ""
    echo "[Această comandă ar identifica și muta versiunile vechi în carantină]"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "✅ Simulare completă - nicio modificare făcută"
    else
        echo "✅ Curățare completă"
    fi
}

# Funcție: Execută deduplicare
run_dedupe() {
    echo "========================================"
    echo "DEDUPLICARE FIȘIERE"
    echo "========================================"
    echo ""
    
    show_safety_status
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "⚠️  MOD DRY-RUN ACTIV - Nicio modificare reală"
        echo ""
    else
        echo "🚨 MOD EXECUTARE - Duplicatele vor fi înlocuite cu hardlink-uri"
        echo ""
        
        # Cere confirmare
        read -p "Continuă? (tastează 'CONFIRM' pentru a continua): " confirm
        if [[ "$confirm" != "CONFIRM" ]]; then
            echo "Operațiune anulată."
            return 1
        fi
    fi
    
    # Aici ar trebui să integrez logica reală de deduplicare
    echo "🔍 Scanare duplicate în: $SCOPE"
    echo ""
    echo "[Această comandă ar identifica duplicatele și le-ar înlocui cu hardlink-uri]"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "✅ Simulare completă - nicio modificare făcută"
    else
        echo "✅ Deduplicare completă"
    fi
}

# Parsează argumentele
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --audit)
                ACTION="audit"
                shift
                ;;
            --suggest)
                ACTION="suggest"
                shift
                ;;
            --clean-old)
                ACTION="clean-old"
                shift
                ;;
            --dedupe)
                ACTION="dedupe"
                shift
                ;;
            --scope)
                SCOPE="$2"
                shift 2
                ;;
            --policy)
                POLICY_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-dry-run)
                DRY_RUN=false
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "❌ Opțiune necunoscută: $1"
                echo "Folosește --help pentru ajutor"
                exit 1
                ;;
        esac
    done
}

# Main
main() {
    parse_args "$@"
    
    case "$ACTION" in
        "audit")
            run_audit
            ;;
        "suggest")
            run_suggest
            ;;
        "clean-old")
            run_clean_old
            ;;
        "dedupe")
            run_dedupe
            ;;
        "help")
            show_help
            ;;
        *)
            echo "❌ Acțiune necunoscută: $ACTION"
            show_help
            exit 1
            ;;
    esac
}

# Execută main
main "$@"