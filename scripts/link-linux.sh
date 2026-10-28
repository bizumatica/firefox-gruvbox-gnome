#!/usr/bin/env bash
# link-linux.sh: liga o perfil do Firefox a este repositório (Linux; macOS não testado).
#
#   <perfil>/chrome   ->  <repo>              (pasta inteira, via link simbólico)
#   <perfil>/user.js  ->  <repo>/profile/user.js
#
# Opcional (--import-private): COPIA cert9.db, permissions.sqlite e prefs.js de uma
# pasta PRIVADA, fora do repositório, para o perfil. Esses arquivos nunca devem ir
# para o GitHub. Eles são copiados (não ligados) porque o Firefox os reescreve.
#
# Uso:
#   ./scripts/link-linux.sh [opções]
#
# Opções:
#   --profile CAMINHO      pasta do perfil (padrão: detecta pelo profiles.ini)
#   --private-dir CAMINHO  pasta privada com os 3 arquivos (padrão: ~/.firefox-privado)
#   --import-private       copia cert9.db, permissions.sqlite e prefs.js para o perfil
#   --skip-userjs          não liga o user.js (útil se cada máquina usa um perfil de RAM)
#   --undo                 remove os links e restaura os backups mais recentes
#   --dry-run              só mostra o que faria
#   --force                ignora a checagem de "Firefox aberto" (não recomendado)
#   -h, --help             esta ajuda
#
# Variáveis de ambiente equivalentes: PROFILE_DIR, PRIVATE_DIR.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_DIR="${PROFILE_DIR:-}"
PRIVATE_DIR="${PRIVATE_DIR:-$HOME/.firefox-privado}"
DO_IMPORT=0; DO_UNDO=0; DRY=0; FORCE=0; SKIP_USERJS=0
TS="$(date +%Y%m%d-%H%M%S)"
PRIVATE_FILES=(cert9.db permissions.sqlite prefs.js)
PRIV=""

log()  { printf '• %s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }
die()  { printf 'ERRO: %s\n' "$*" >&2; exit 1; }
usage(){ sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

run() {
  if (( DRY )); then
    printf '[dry-run]'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

while (( $# )); do
  case "$1" in
    --profile)        PROFILE_DIR="${2:?falta o caminho}"; shift 2 ;;
    --private-dir)    PRIVATE_DIR="${2:?falta o caminho}"; shift 2 ;;
    --import-private) DO_IMPORT=1; shift ;;
    --skip-userjs)    SKIP_USERJS=1; shift ;;
    --undo)           DO_UNDO=1; shift ;;
    --dry-run)        DRY=1; shift ;;
    --force)          FORCE=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    *) die "opção desconhecida: $1 (use --help)" ;;
  esac
done

# --- detecção do perfil padrão ------------------------------------------------
find_profile() {
  local bases=(
    "$HOME/.config/mozilla/firefox"
    "$HOME/.mozilla/firefox"
    "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    "$HOME/snap/firefox/common/.mozilla/firefox"
    "$HOME/Library/Application Support/Firefox"
  )
  local base ini rel res isrel path
  for base in "${bases[@]}"; do
    ini="$base/profiles.ini"
    [[ -f "$ini" ]] || continue
    # 1) perfil padrão da instalação: [Install...] Default=Profiles/xxxx
    rel="$(awk -F= '/^\[/{s=($0 ~ /^\[Install/)} s && $1=="Default"{print $2; exit}' "$ini")"
    if [[ -n "$rel" ]]; then printf '%s/%s\n' "$base" "$rel"; return 0; fi
    # 2) perfil marcado Default=1: [ProfileN]
    res="$(awk -F= '
      /^\[/ { if (sec ~ /^Profile/ && def==1 && path!="") { print rel "|" path; done=1; exit }
              sec=substr($0,2,length($0)-2); path=""; rel=1; def=0; next }
      $1=="Path"       { path=$2 }
      $1=="IsRelative" { rel=$2 }
      $1=="Default"    { def=$2 }
      END { if (!done && sec ~ /^Profile/ && def==1 && path!="") print rel "|" path }
    ' "$ini")"
    if [[ -n "$res" ]]; then
      isrel="${res%%|*}"; path="${res#*|}"
      if [[ "$isrel" == "1" ]]; then printf '%s/%s\n' "$base" "$path"; else printf '%s\n' "$path"; fi
      return 0
    fi
  done
  return 1
}

firefox_running() {
  pgrep -x firefox >/dev/null 2>&1 || pgrep -x firefox-bin >/dev/null 2>&1 \
    || pgrep -x firefox-esr >/dev/null 2>&1 || [[ -L "$PROFILE_DIR/lock" ]]
}

# --- operações ----------------------------------------------------------------
latest_backup() { ls -1d "$1".bak.* 2>/dev/null | sort | tail -n 1 || true; }

link_item() {  # link_item <alvo> <link>
  local target="$1" link="$2"
  if [[ -L "$link" ]]; then
    if [[ "$(readlink "$link")" == "$target" ]]; then
      log "ok: $link já aponta para $target"; return 0
    fi
    run rm "$link"                       # remove só o atalho antigo
  elif [[ -e "$link" ]]; then
    run mv "$link" "$link.bak.$TS"
    log "backup: $link.bak.$TS"
  fi
  run ln -s "$target" "$link"
  log "link: $link -> $target"
}

unlink_item() {  # unlink_item <link>
  local link="$1" bak
  if [[ -L "$link" ]]; then
    run rm "$link"; log "removido o link: $link"
  else
    log "nada a desfazer em: $link (não é link)"; return 0
  fi
  bak="$(latest_backup "$link")"
  if [[ -n "$bak" ]]; then run mv "$bak" "$link"; log "restaurado: $bak -> $link"; fi
}

ensure_submodule() {
  if [[ ! -d "$REPO_DIR/firefox-gnome-theme/theme" ]]; then
    if command -v git >/dev/null 2>&1 && [[ -d "$REPO_DIR/.git" || -f "$REPO_DIR/.git" ]]; then
      log "submódulo do tema ausente ou vazio: baixando"
      run git -C "$REPO_DIR" submodule update --init
    else
      warn "firefox-gnome-theme está vazio e não achei o git para baixá-lo"
    fi
  fi
}

check_private() {  # valida ANTES de alterar qualquer coisa
  [[ -d "$PRIVATE_DIR" ]] || die "pasta privada não existe: $PRIVATE_DIR"
  PRIV="$(cd "$PRIVATE_DIR" && pwd)"
  case "$PRIV/" in
    "$REPO_DIR"/*) die "a pasta privada não pode ficar dentro do repositório ($PRIV)" ;;
  esac
}

import_private() {
  local priv="$PRIV" f src dst sfx had
  for f in "${PRIVATE_FILES[@]}"; do
    src="$priv/$f"; dst="$PROFILE_DIR/$f"
    if [[ ! -f "$src" ]]; then log "pulado (não encontrado): $src"; continue; fi
    had=0
    for sfx in "" "-wal" "-shm"; do          # bancos SQLite podem ter -wal/-shm
      if [[ -e "$dst$sfx" ]]; then run mv "$dst$sfx" "$dst$sfx.bak.$TS"; [[ -z "$sfx" ]] && had=1; fi
    done
    run cp -p "$src" "$dst"
    run chmod 600 "$dst"
    if (( had )); then log "importado: $f (backup do anterior: $f.bak.$TS)"; else log "importado: $f"; fi
  done
  warn "prefs.js substitui TODAS as preferências do perfil e guarda os IDs das extensões:"
  warn "em um perfil já usado, extensões podem perder dados locais. Prefira o user.js para preferências."
}

# --- execução -----------------------------------------------------------------
[[ -n "$PROFILE_DIR" ]] || PROFILE_DIR="$(find_profile)" \
  || die "não achei o perfil. Informe com --profile CAMINHO (veja about:support)."
[[ -d "$PROFILE_DIR" ]] || die "pasta do perfil não existe: $PROFILE_DIR"
PROFILE_DIR="$(cd "$PROFILE_DIR" && pwd)"

log "repositório: $REPO_DIR"
log "perfil:      $PROFILE_DIR"
(( DRY )) && log "modo dry-run: nada será alterado"

if firefox_running && (( ! FORCE )); then
  die "o Firefox parece estar aberto. Feche-o por completo (ou use --force)."
fi

if (( DO_UNDO )); then
  unlink_item "$PROFILE_DIR/chrome"
  unlink_item "$PROFILE_DIR/user.js"
  log "pronto. Os arquivos importados (cert9.db etc.) não são desfeitos: restaure os .bak.* à mão."
  exit 0
fi

if (( DO_IMPORT )); then check_private; fi
ensure_submodule
link_item "$REPO_DIR" "$PROFILE_DIR/chrome"
if (( ! SKIP_USERJS )); then
  if [[ -f "$REPO_DIR/profile/user.js" ]]; then
    link_item "$REPO_DIR/profile/user.js" "$PROFILE_DIR/user.js"
  else
    warn "profile/user.js não existe no repositório; pulando"
  fi
fi
if (( DO_IMPORT )); then import_private; fi

log "concluído. Abra o Firefox. Para desfazer: $0 --undo"
