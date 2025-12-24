# dupctl - Duplicate & Version Cleaner

> **Utilitar CLI sigur pentru gestionarea duplicatelor și versiunilor vechi pe sisteme Linux**

##  Scop

dupctl este un tool defensiv, auditabil și conservator, proiectat pentru a:
- Detecteze fișiere duplicate exacte
- Identifice versiuni vechi ale fișierelor
- Sugereze acțiuni de curățare
- Execute operațiuni sigure (mutare în carantină, hardlink replacement)

##  Filozofie de Securitate

### **Fail-Closed Design**
Tool-ul refuză să opereze pe fișiere critice prin design, nu prin opțiuni.

### **Deny-by-Default**
- Toate fișierele de sistem sunt interzise
- Toate configurările sunt interzise
- Toate fișierele de cod sursă sunt interzise
- Doar directoarele user-data sunt permise implicit

### **Auditabilitate**
Fiecare operațiune este explicabilă:
- De ce un fișier este considerat duplicat/versiune veche
- Ce regulă de protecție a fost aplicată
- De ce o acțiune este permisă sau blocată

## Structură

```
dupctl/
├── README.md                  # Acest fișier
├── cli/
│   ├── menu.sh               # Meniu interactiv (entry point principal)
│   └── dupctl.sh             # CLI cu flag-uri (pentru scripting)
├── core/
│   ├── guard.sh              # Sistem de protecție defensiv
│   ├── scan.sh               # Scanare duplicate și versiuni
│   ├── classify.sh           # Clasificare fișiere
│   └── decide.sh             # Motor de decizii
├── policies/
│   ├── default.policy        # Politica implicită
│   └── protected.paths       # Directoare interzise
├── quarantine/               # Director pentru carantină
├── reports/                  # Rapoarte generate
└── docs/
    └── design.md             # Documentație tehnică
```

##  Instalare

```bash
# Clonează sau descarcă tool-ul
cd dupctl

# Asigură permisiuni de execuție
chmod +x cli/menu.sh cli/dupctl.sh

# Execută meniul principal
./cli/menu.sh
```

##  Utilizare

### Meniu Interactiv (Recomandat)

```bash
./cli/menu.sh
```

Acesta pornește meniul principal cu opțiuni clare și protecție maximă.

### CLI Flags (Pentru Scripting)

```bash
# Audit complet
./cli/dupctl.sh --audit --scope ~/Downloads

# Sugestii de curățare
./cli/dupctl.sh --suggest --scope ~/Documents --verbose

# Curățare versiuni vechi (simulare)
./cli/dupctl.sh --clean-old --scope ~/Downloads --dry-run

# Deduplicare reală (⚠️ periculos)
./cli/dupctl.sh --dedupe --scope ~/Pictures --no-dry-run
```

##  Reguli de Protecție

### Directoare Interzise (Absolut)
```
/bin /sbin /lib /lib64 /usr /etc /boot
/proc /sys /run /var/lib
```

### Extensii Interzise
```
.conf .cfg .ini .yaml .yml .json .toml
.service .env
.c .cpp .h .py .js .ts .go .rs .java .sh
```

### Dotfiles Critice Interzise
```
~/.ssh/* ~/.gitconfig ~/.bashrc ~/.zshrc
```

##  Funcționalități

### 1. Detectare Duplicate
- Grupare după mărime
- Hash parțial pentru fișiere mari
- Hash complet pentru confirmare
- Comparare eficientă

### 2. Detectare Versiuni Vechi
- Sufixe clasice: `.old`, `.bak`, `(1)`, `_v1`
- Pattern-uri regex configurabile
- Comparare timestamp
- Analiza conținutului

### 3. Clasificare Inteligentă
- Duplicate exacte
- Versiuni vechi confirmate
- Similare (doar raportate)

### 4. Decizii Bazate pe Politici
- Preferă fișierele mai noi
- Preferă locațiile user-data
- Exclude implicit configurațiile

### 5. Acțiuni Sigure
- `dry-run` IMPLICIT
- Mutare în carantină (NU ștergere)
- Hardlink replacement doar în zone sigure

##  Configurare

Politica implicită este în `policies/default.policy`. Poți crea politici personalizate:

```bash
# Copiază politica implicită
cp policies/default.policy policies/my.policy

# Modifică după necesități
$EDITOR policies/my.policy

# Folosește politica personalizată
./cli/dupctl.sh --policy policies/my.policy --audit
```

##  Explicabilitate

Fiecare fișier procesat are explicații:

```
 /home/user/Downloads/file.pdf
   Clasificare: DUPLICAT_EXACT
   Motiv: Hash identic (sha256: a1b2c3d4...)
   Decizie: Păstrează /home/user/Documents/file.pdf (mai nou)
   Acțiune: Mută în carantină /home/user/Downloads/file.pdf
```

##  Testare

Tool-ul include protecții multiple:

```bash
# Verifică dacă un path este protejat
./core/guard.sh check /etc/passwd
# Output: 🔒 PROTEJAT: CONFIG_DIR:/etc

# Validează un scope
./core/guard.sh scope /usr
# Output: ❌ EROARE: Directorul '/usr' este PROTEJAT

# Afișează toate regulile
./core/guard.sh rules
```

##  Raportare

Toate operațiunile generează rapoarte în `reports/`:
- Timestamp complet
- Scope scanat
- Politică aplicată
- Rezultate detaliate
- Decizii luate