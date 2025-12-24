# Design Document - dupctl

> **Arhitectura și deciziile de design pentru Duplicate & Version Cleaner**

## 🏗️ Arhitectura Generală

dupctl este proiectat pe principiul **modularității defensive** cu separare clară între:
- **Interfață utilizator** (meniu CLI + CLI flags)
- **Logica de business** (scanare, clasificare, decizii)
- **Protecții** (guard system)
- **Politici** (configurabile)

## 🔄 Flow-ul Meniului

### 1. Pornire și Inițializare
```
User → ./cli/menu.sh
     ↓
[Verificare dependențe]
[Încărcare module]
[Afișare header + status]
```

### 2. Navigare Meniu Principal
```
Meniu Principal
├── 1) Scan & audit duplicates
│   └── [Configure scope] → [Validare scope] → [Executare scanare]
│
├── 2) Scan & audit old versions
│   └── [Configure scope] → [Validare scope] → [Executare scanare]
│
├── 3) Suggest cleanup actions
│   └── [Analiză scope] → [Generare sugestii] → [Afișare recomandări]
│
├── 4) Clean old versions (safe scope)
│   └── [Confirmare] → [Scanare] → [Mutare carantină]
│
├── 5) Deduplicate identical files
│   └── [Confirmare] → [Scanare] → [Hardlink replacement]
│
├── 6) Show last report
│   └── [Căutare rapoarte] → [Afișare conținut]
│
├── 7) Configure policy
│   └── [Submeniu config] → [Scope|Dry-run|Politici|Protecții]
│
└── 8) Exit
```

### 3. Flow de Confirmare pentru Acțiuni Distructive

```
Acțiune Distructivă (clean-old, dedupe)
↓
[Verificare dry-run mode]
├─ DRY-RUN = true:
│  └─ ⚠️  "MOD DRY-RUN ACTIV - Simulare? (y/N)"
│
└─ DRY-RUN = false:
   └─ 🚨 "MOD EXECUTARE - tastează 'CONFIRM EXECUTARE'"
       ↓
   [Verificare input]
   ├─ Corect → Continuă
   └─ Greșit → Anulează
```

## 🛡️ Sistemul de Protecție (Guard)

### Flow de Validare

```
Input Path
↓
[Realpath absolut]
↓
┌─────────────────────────────────────────────────────────┐
│                    VERIFICĂRI                           │
├─────────────────────────────────────────────────────────┤
│ 1. Este în protected.paths?                            │
│    → /bin, /sbin, /lib, /usr, /etc, etc.              │
├─────────────────────────────────────────────────────────┤
│ 2. Are extensie interzisă?                            │
│    → .conf, .py, .sh, .json, etc.                     │
├─────────────────────────────────────────────────────────┤
│ 3. Este dotfile critic?                               │
│    → .ssh, .gitconfig, .bashrc, etc.                  │
├─────────────────────────────────────────────────────────┤
│ 4. Este în /etc/* ?                                   │
├─────────────────────────────────────────────────────────┤
│ Dacă ORICARE = DA → Returnează cod protecție          │
│ Dacă TOATE = NU → Returnează OK (sigur)               │
└─────────────────────────────────────────────────────────┘
```

### Coduri de Protecție

| Cod | Descriere | Exemplu |
|-----|-----------|---------|
| `SYSTEM_DIR:/bin` | Director de sistem | `/bin`, `/usr/bin` |
| `CONFIG_DIR:/etc` | Director de configurare | `/etc/passwd` |
| `BANNED_EXT:py` | Extensie interzisă | `script.py` |
| `BANNED_DOTFILE:.ssh` | Dotfile critic | `~/.ssh/id_rsa` |

## 📊 Logica de Decizie

### Politica de Preferință

```
PREFERENCE_ORDER="newer user-data larger"
```

**Interpretare:**
1. **newer**: Preferă fișierele cu timestamp mai recent
2. **user-data**: Preferă fișierele din ~/Downloads, ~/Documents, etc.
3. **larger**: Preferă fișierele mai mari (pentru versiuni)

### Algoritm Decizie Duplicate

```python
def decide_duplicate(group_files):
    candidates = filter_protected_files(group_files)
    
    for criterion in PREFERENCE_ORDER:
        if criterion == "newer":
            keep = find_newest(candidates)
            if keep: break
            
        elif criterion == "user-data":
            keep = find_in_user_dirs(candidates)
            if keep: break
            
        elif criterion == "larger":
            keep = find_largest(candidates)
            if keep: break
    
    # Fallback
    if not keep:
        keep = candidates[0]
    
    return keep, [f for f in candidates if f != keep]
```

## 🔍 Logica de Scanare

### Scanare Duplicate

```
1. Find toate fișierele din scope
   ↓
2. Filtrare protecții (guard.sh)
   ↓
3. Grupare după mărime
   ↓
4. Pentru grupuri > 1 fișier:
   ├─ Dacă mărime > MAX_SIZE_FULL_HASH:
   │  └─ Hash parțial (primul MB)
   └─ Altfel:
      └─ Hash complet
   ↓
5. Grupare după hash
   ↓
6. Returnează grupurile cu hash identic
```

### Scanare Versiuni Vechi

```
1. Find toate fișierele din scope
   ↓
2. Filtrare protecții
   ↓
3. Match după sufixe:
   ├─ .old, .bak, .backup, etc.
   └─ Pattern-uri regex din politică
   ↓
4. Verifică existența versiunii de bază
   ↓
5. Compară timestamp-uri
   ↓
6. Returnează versiunile confirmate ca vechi
```

## 🗂️ Formate de Date

### Format Raport

```
========================================
RAPORT DUPCTL - 20251225_025630
========================================
Data: Wed Dec 25 02:56:30 UTC 2025
Scope: /home/user/Downloads
Politică: ./policies/default.policy

=== DUPLICATE EXACTE ===
Grup 1: 3 fișiere identice
Hash: a1b2c3d4e5f6789012345678901234567890abcd...
----------------------------------------
  [0] /home/user/Downloads/document.pdf
      1048576 bytes  2025-12-24 14:30:00
  [1] /home/user/Downloads/document (1).pdf
      1048576 bytes  2025-12-24 14:25:00
  [2] /home/user/Documents/old/document.pdf
      1048576 bytes  2025-12-23 10:15:00

DECIZIE: Păstrează [0] (cel mai nou)
ACȚIUNE: Mută [1], [2] în carantină

=== VERSIUNI VECHI ===
📄 /home/user/Downloads/report.bak
   Versiune de bază: report.pdf
   Diferență de timp: 15 zile
   ✓ Confirmat: versiune veche
```

## ⚙️ Configurare Politici

### Format Politică

```bash
# ===== REGULI DE PROTECȚIE =====
BANNED_EXTENSIONS="conf cfg ini yaml yml json toml ..."
BANNED_DOTFILES=".ssh .gitconfig .bashrc .zshrc ..."

# ===== SCOPE SIGUR =====
SAFE_DIRECTORIES="$HOME/Downloads $HOME/Documents ..."

# ===== POLITICI VERSIUNI =====
OLD_VERSION_SUFFIXES="old bak backup copy ..."
OLD_VERSION_PATTERNS="\.old$ Old file
                      _bak$ Backup file"

# ===== POLITICI DUPLICATE =====
MIN_FILE_SIZE=1
MAX_SIZE_FULL_HASH=100

# ===== DECIZII =====
PREFERENCE_ORDER="newer user-data larger"
QUARANTINE_DIR="/tmp/dupctl_quarantine"
```

## 🔄 Flow de Acțiuni

### 1. Deduplicare

```
[Scanare duplicate]
   ↓
[Clasificare grupuri]
   ↓
[Aplicare politică preferință]
   ↓
[Confirmare utilizator]
   ↓
[Hardlink replacement]
   ↓
[Raportare rezultate]
```

### 2. Curățare Versiuni Vechi

```
[Scanare versiuni vechi]
   ↓
[Verificare versiuni de bază]
   ↓
[Confirmare utilizator]
   ↓
[Mutare în carantină]
   ↓
[Raportare rezultate]
```

## 🧪 Scenarii de Testare

### Scenariu 1: Încercare Acces Director Sistem

```bash
$ ./cli/dupctl.sh --audit --scope /etc

Output:
=== VALIDARE SCOPE: /etc ===
❌ EROARE: Directorul '/etc' este PROTEJAT (CONFIG_DIR:/etc)
   Nu se poate scana un director de sistem sau de configurare.
```

### Scenariu 2: Încercare Ștergere Fișier Config

```bash
$ ./cli/dupctl.sh --clean-old --scope ~/.ssh/config

Output:
❌ OPERAȚIUNE BLOCATĂ: clean-old pe '/home/user/.ssh/config'
   Motiv: BANNED_DOTFILE:config
```

### Scenariu 3: Operare Sigură în Downloads

```bash
$ ./cli/menu.sh
→ Alege 1) Scan & audit duplicates
→ Scope: ~/Downloads
→ Validare scope: ✅ SIGUR
→ Scanare completă cu rezultate
```

## 🔧 Extensibilitate

### Adăugare Criteriu Decizie

```bash
# În decide.sh
elif [[ "$criterion" == "custom" ]]; then
    # Implementare logică custom
    keep=$(apply_custom_logic "${temp_candidates[@]}")
```

### Adăugare Pattern Versiune Vechi

```bash
# În default.policy
OLD_VERSION_PATTERNS="...\n_v[0-9]+_[0-9]+$ Version with underscore"
```

### Adăugare Extensie Interzisă

```bash
# În default.policy
BANNED_EXTENSIONS="... dockerfile makefile"
```

## 📈 Performanță

### Optimizări Implementate

1. **Hash parțial pentru fișiere mari**
   - Fișiere > 100MB: hash doar primul MB
   - Reduce timp de procesare cu ~80%

2. **Grupare după mărime întâi**
   - Doar fișiere cu mărime identică sunt comparate
   - Elimină 99% din comparații inutile

3. **Caching hash-uri**
   - Hash-urile calculate sunt memorate temporar
   - Evită recalcularea pentru același fișier

## 🎯 Decizii de Design

### De ce nu ștergem direct?
- **Siguranță**: Mutarea în carantină permite recuperare
- **Audit**: Păstrăm dovara operațiunii
- **Rollback**: Se poate reveni la starea anterioară

### De ce meniu interactiv?
- **Transparență**: Utilizatorul vede exact ce se întâmplă
- **Confirmare**: Acțiunile distructive necesită confirmare explicită
- **Debugging**: Ușor de identificat problemele

### De ce Bash și nu Python/Go?
- **Disponibilitate**: Bash este prezent pe TOATE sistemele Linux
- **Simplitate**: Nu necesită dependențe externe
- **Transparență**: Cod ușor de auditat de către sysadmini

## 📚 Referințe

- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide)
- [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.pdf)
- [Defensive Programming](https://en.wikipedia.org/wiki/Defensive_programming)

---

**Notă**: Acest document reprezintă arhitectura conceptuală. Implementarea completă necesită integrarea modulelor descrise.