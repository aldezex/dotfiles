#!/usr/bin/env bash
#
# setup-and-install.sh — takes a machine from nothing to fully configured, and
# on every run after that reconciles it back to what this repo says.
#
# It is a reconciler, not an installer: each run compares the machine against
# the desired state below and only touches what differs. Running it twice in a
# row does nothing the second time.
#
#   ./setup-and-install.sh                 full run
#   ./setup-and-install.sh --dry-run       report every difference, change nothing
#   ./setup-and-install.sh --links-only    symlinks only, no packages, no nvim
#   ./setup-and-install.sh --no-deps       skip package installation
#   ./setup-and-install.sh --no-nvim       skip the nvim clone and plugin sync
#   ./setup-and-install.sh --prune         also uninstall packages not in the Brewfile
#   ./setup-and-install.sh --yes           non-interactive: repo wins every conflict
#   ./setup-and-install.sh --adopt         non-interactive: the machine wins, and
#                                          its version is copied back into the repo
#
# What it reconciles:
#   1. A package manager (Homebrew), plus the base packages Linux needs first.
#   2. zsh installed and set as the login shell.
#   3. Everything in the Brewfile.
#   4. The symlinks in LINKS below — including REMOVING links this repo used to
#      create and no longer does, tracked through a state file.
#   5. The nvim config repo, cloned and with its plugins synced.
#
# On a conflict — something already at a destination that is not our symlink —
# it stops and asks, showing the diff. Nothing is ever overwritten without a
# backup under ~/.dotfiles-backup/<date>/.

set -uo pipefail

# ---------------------------------------------------------------------------
# Desired state
# ---------------------------------------------------------------------------
# source (relative to the repo) -> destination (relative to $HOME)
LINKS=(
    "zshrc:.zshrc"
    "zprofile:.zprofile"
    "gitconfig:.gitconfig"
    "githelpers:.githelpers"
    "gitignore_global:.config/git/ignore"
    "starship.toml:.config/starship.toml"
    "ghostty.config:.config/ghostty/config"
    "herdr.toml:.config/herdr/config.toml"
    "herdr-hotkeys-cheatsheet.md:.config/herdr/hotkeys-cheatsheet.md"
    "claude_settings.json:.claude/settings.json"
    "claude_statusline.sh:.claude/statusline.sh"
    "claude_hook_herdr-agent-state.sh:.claude/hooks/herdr-agent-state.sh"
    "claude_CLAUDE.md:.claude/CLAUDE.md"
    "claude_hook_session-cleanup.sh:.claude/hooks/session-cleanup.sh"
)

NVIM_REPO="https://github.com/aldezex/nvim.git"
NVIM_DIR="$HOME/.config/nvim"

# The only packages that come from apt. Everything else — every tool the
# configs actually call — comes from the Brewfile, so both machines run the same
# versions from the same manifest.
#
# The first five are Homebrew's own documented prerequisites: it cannot be
# installed, let alone build anything, without them.
#
# zsh is the deliberate exception. It is the login shell, and a login shell
# belongs to the system: it has to exist before Homebrew's PATH is set up, it
# has to work under sudo and PAM, and if it lived under /home/linuxbrew a broken
# brew prefix would mean not being able to log in at all.
APT_BASE=(build-essential procps curl file git zsh)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
STATE_FILE="$STATE_DIR/linked"

DRY_RUN=false
DO_DEPS=true
DO_NVIM=true
DO_PRUNE=false
CONFLICT_POLICY=ask       # ask | repo | local

for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY_RUN=true ;;
        --links-only) DO_DEPS=false; DO_NVIM=false ;;
        --no-deps)    DO_DEPS=false ;;
        --no-nvim)    DO_NVIM=false ;;
        --prune)      DO_PRUNE=true ;;
        --yes)        CONFLICT_POLICY=repo ;;
        --adopt)      CONFLICT_POLICY=local ;;
        -h|--help)    sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

# Not a terminal and no policy chosen: never guess, report and move on.
[ -t 0 ] || [ "$CONFLICT_POLICY" != "ask" ] || CONFLICT_POLICY=report

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    B=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RED=$'\033[31m'; RST=$'\033[0m'
else
    B=; DIM=; GRN=; YLW=; RED=; RST=
fi

n_linked=0; n_ok=0; n_removed=0; n_adopted=0; n_conflict=0
CONFLICTS=()

say()  { printf '%s\n' "$*"; }
info() { printf '%s\n' "${DIM}$*${RST}"; }
ok()   { printf '%s\n' "${GRN}$*${RST}"; }
warn() { printf '%s\n' "${YLW}$*${RST}"; }
err()  { printf '%s\n' "${RED}$*${RST}" >&2; }
head_() { printf '\n%s\n' "${B}$*${RST}"; }
run()  { $DRY_RUN || "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------
OS=unknown; IS_WSL=false
case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)
        OS=linux
        grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null && IS_WSL=true
        ;;
esac

head_ "Environment"
say "  os:        $OS$($IS_WSL && printf ' (WSL)')"
say "  repo:      $DOTFILES"
say "  conflicts: $CONFLICT_POLICY"
$DRY_RUN && warn "  dry run: nothing will be changed"

# ---------------------------------------------------------------------------
# 1. Package manager
# ---------------------------------------------------------------------------
ensure_apt_base() {
    have apt-get || return 0
    local missing=()
    local p
    for p in "${APT_BASE[@]}"; do
        dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        ok "  apt base packages already installed"
        return 0
    fi
    say "  installing via apt: ${missing[*]}"
    if ! have sudo; then
        err "  sudo not available; install manually: apt install ${missing[*]}"
        return 1
    fi
    run sudo apt-get update -qq
    run sudo apt-get install -y "${missing[@]}"
}

ensure_brew() {
    # Pick up an existing install that is not on PATH yet.
    local candidate
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        [ -x "$candidate" ] && eval "$("$candidate" shellenv)" && break
    done

    if have brew; then
        ok "  homebrew present ($(command -v brew))"
        return 0
    fi

    # On Linux this lands in /home/linuxbrew/.linuxbrew and needs sudo once.
    # zshrc and zprofile both find it there on their own afterwards.
    warn "  homebrew missing, installing"
    if $DRY_RUN; then
        say "  would run the official Homebrew installer"
        return 0
    fi
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/brew/HEAD/install.sh)" || return 1

    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        [ -x "$candidate" ] && eval "$("$candidate" shellenv)" && break
    done
    have brew
}

if $DO_DEPS; then
    head_ "Package manager"
    [ "$OS" = linux ] && ensure_apt_base
    ensure_brew || err "  could not set up Homebrew; package steps will be skipped"
fi

# ---------------------------------------------------------------------------
# 2. zsh as the login shell
# ---------------------------------------------------------------------------
ensure_zsh_login_shell() {
    have zsh || { warn "  zsh not installed yet, skipping shell change"; return 0; }

    local zsh_path current
    zsh_path=$(command -v zsh)
    current=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
    [ -n "$current" ] || current="${SHELL:-}"

    if [ "$current" = "$zsh_path" ]; then
        ok "  login shell is already $zsh_path"
        return 0
    fi

    # chsh refuses any shell missing from /etc/shells. The apt package registers
    # itself; a Homebrew zsh does not.
    if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
        say "  registering $zsh_path in /etc/shells"
        if have sudo; then
            $DRY_RUN || printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        else
            err "  cannot write /etc/shells without sudo; add $zsh_path by hand"
            return 1
        fi
    fi

    say "  setting the login shell to $zsh_path (was ${current:-unset})"
    run chsh -s "$zsh_path" || {
        err "  chsh failed; run it by hand: chsh -s $zsh_path"
        return 1
    }
    $IS_WSL && info "  on WSL: close every session for the new shell to take effect"
}

if $DO_DEPS; then
    head_ "Shell"
    ensure_zsh_login_shell
fi

# ---------------------------------------------------------------------------
# 3. Brewfile
# ---------------------------------------------------------------------------
if $DO_DEPS && have brew; then
    head_ "Packages"
    if [ ! -f "$DOTFILES/Brewfile" ]; then
        warn "  no Brewfile in the repo, skipping"
    elif $DRY_RUN; then
        brew bundle check --file "$DOTFILES/Brewfile" --verbose 2>&1 | sed 's/^/  /'
    else
        if brew bundle check --file "$DOTFILES/Brewfile" >/dev/null 2>&1; then
            ok "  every Brewfile package already installed"
        else
            brew bundle --file "$DOTFILES/Brewfile" 2>&1 | sed 's/^/  /'
        fi

        if $DO_PRUNE; then
            say ""
            say "  packages installed but not listed in the Brewfile:"
            brew bundle cleanup --file "$DOTFILES/Brewfile" 2>&1 | sed 's/^/    /'
            if [ -t 0 ]; then
                printf '  uninstall them? [y/N] '
                read -r reply
                case "$reply" in
                    [yY]) brew bundle cleanup --force --file "$DOTFILES/Brewfile" 2>&1 | sed 's/^/    /' ;;
                    *)    info "    left alone" ;;
                esac
            else
                info "    --prune needs a terminal to confirm; nothing removed"
            fi
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 4. Symlinks
# ---------------------------------------------------------------------------
# Atomic: link to a temporary name, then rename over the destination. `mv -f`
# on a symlink is a rename(2) — either the old one is there or the new one is,
# never neither.
link_atomically() {
    local src="$1" dest="$2" tmp
    run mkdir -p "$(dirname "$dest")"
    $DRY_RUN && return 0
    tmp="$dest.dotfiles-tmp.$$"
    ln -s "$src" "$tmp" && mv -f "$tmp" "$dest"
}

backup() {
    local dest="$1" rel="$2"
    run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    run cp -R "$dest" "$BACKUP_DIR/$rel"
}

show_diff() {
    local src="$1" dest="$2"
    if diff -u --label "repo: ${src#$DOTFILES/}" --label "machine: $dest" \
            "$src" "$dest" 2>/dev/null | head -40; then
        info "    (identical content, only not a symlink)"
    fi
}

# Something is at the destination that is not our symlink. Ask what to do.
resolve_conflict() {
    local src="$1" dest="$2" rel="$3" kind="$4"

    case "$CONFLICT_POLICY" in
        repo)
            backup "$dest" "$rel"
            run rm -rf "$dest"
            link_atomically "$src" "$dest"
            warn "  ~ $rel  ($kind, backed up, repo version linked)"
            n_linked=$((n_linked + 1))
            return 0 ;;
        local)
            $DRY_RUN || cp -R "$dest" "$src"
            backup "$dest" "$rel"
            run rm -rf "$dest"
            link_atomically "$src" "$dest"
            warn "  ~ $rel  ($kind, machine version adopted into the repo)"
            n_adopted=$((n_adopted + 1))
            return 0 ;;
        report)
            CONFLICTS+=("$rel  ($kind)")
            warn "  ! $rel  ($kind) — left untouched"
            n_conflict=$((n_conflict + 1))
            return 0 ;;
    esac

    # Interactive
    while true; do
        printf '\n%s\n' "${YLW}  conflict: ~/$rel is $kind${RST}"
        printf '  [r] use the repo version (yours is backed up)\n'
        printf '  [l] keep this machine and copy it back into the repo\n'
        printf '  [d] show the diff\n'
        printf '  [s] skip for now\n'
        printf '  > '
        read -r choice </dev/tty
        case "$choice" in
            r|R)
                backup "$dest" "$rel"
                run rm -rf "$dest"
                link_atomically "$src" "$dest"
                ok "    repo version linked"
                n_linked=$((n_linked + 1)); return 0 ;;
            l|L)
                $DRY_RUN || cp -R "$dest" "$src"
                backup "$dest" "$rel"
                run rm -rf "$dest"
                link_atomically "$src" "$dest"
                ok "    adopted into the repo — it will show up in git status"
                n_adopted=$((n_adopted + 1)); return 0 ;;
            d|D) show_diff "$src" "$dest" ;;
            s|S)
                CONFLICTS+=("$rel  ($kind)")
                info "    skipped"
                n_conflict=$((n_conflict + 1)); return 0 ;;
            *) info "    r, l, d or s" ;;
        esac
    done
}

head_ "Config files"

declare -a current_dests=()

for entry in "${LINKS[@]}"; do
    rel="${entry##*:}"
    src="$DOTFILES/${entry%%:*}"
    dest="$HOME/$rel"
    current_dests+=("$rel")

    if [ ! -e "$src" ]; then
        err "  ! ${entry%%:*} listed in LINKS but missing from the repo"
        continue
    fi

    # Already correct.
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        n_ok=$((n_ok + 1))
        continue
    fi

    # Nothing there: just link it.
    if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
        link_atomically "$src" "$dest"
        ok "  + $rel"
        n_linked=$((n_linked + 1))
        continue
    fi

    # Something else is there.
    if [ -L "$dest" ]; then
        target=$(readlink "$dest")
        case "$target" in
            "$DOTFILES"/*) kind="a symlink to $(basename "$target") in this repo" ;;
            *)             kind="a symlink to $target" ;;
        esac
    elif [ -d "$dest" ]; then
        kind="a real directory"
    else
        kind="a real file"
    fi
    resolve_conflict "$src" "$dest" "$rel" "$kind"
done

# --- Prune: links this repo used to create and no longer does ---------------
# The state file is what makes this safe. Without it there is no way to tell a
# link we created last month from one the user made themselves.
head_ "Stale links"

if [ -f "$STATE_FILE" ]; then
    stale=0
    while IFS= read -r old_rel; do
        [ -n "$old_rel" ] || continue

        still_wanted=false
        for d in "${current_dests[@]}"; do
            [ "$d" = "$old_rel" ] && { still_wanted=true; break; }
        done
        $still_wanted && continue

        old_dest="$HOME/$old_rel"
        [ -L "$old_dest" ] || continue

        # Only ever remove a symlink that still points into this repo.
        case "$(readlink "$old_dest")" in
            "$DOTFILES"/*)
                run rm -f "$old_dest"
                warn "  - $old_rel  (no longer managed by this repo)"
                n_removed=$((n_removed + 1))
                stale=$((stale + 1)) ;;
            *)
                info "  . $old_rel points elsewhere now, left alone" ;;
        esac
    done < "$STATE_FILE"
    [ "$stale" -eq 0 ] && ok "  nothing stale"
else
    info "  no previous state recorded; nothing to prune"
fi

if ! $DRY_RUN; then
    mkdir -p "$STATE_DIR"
    printf '%s\n' "${current_dests[@]}" > "$STATE_FILE"
fi

# ---------------------------------------------------------------------------
# 5. nvim
# ---------------------------------------------------------------------------
if $DO_NVIM; then
    head_ "Neovim config"

    if [ ! -e "$NVIM_DIR" ]; then
        say "  cloning $NVIM_REPO"
        run git clone --quiet "$NVIM_REPO" "$NVIM_DIR"
    elif [ -d "$NVIM_DIR/.git" ]; then
        if [ -n "$(git -C "$NVIM_DIR" status --porcelain 2>/dev/null)" ]; then
            warn "  local changes in $NVIM_DIR, not pulling"
            git -C "$NVIM_DIR" status --short 2>/dev/null | sed 's/^/    /'
        else
            say "  updating $NVIM_DIR"
            run git -C "$NVIM_DIR" pull --quiet --ff-only || warn "  pull failed, left as is"
        fi
    else
        warn "  $NVIM_DIR exists but is not a git clone, left alone"
    fi

    # The command straight out of that repo's README.
    if have nvim && [ -e "$NVIM_DIR/init.lua" ]; then
        say "  syncing plugins"
        if $DRY_RUN; then
            info "    would run: nvim --headless +\"Lazy! sync\" +qa"
        else
            nvim --headless +"Lazy! sync" +qa 2>&1 | grep -iE "error|E[0-9]+:" | sed 's/^/    /'
            ok "  plugins synced"
        fi
    elif ! have nvim; then
        warn "  nvim not installed, skipping the plugin sync"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
head_ "Summary"
say "  linked:     $n_linked"
say "  adopted:    $n_adopted"
say "  unchanged:  $n_ok"
say "  removed:    $n_removed"
say "  conflicts:  $n_conflict"

[ -d "$BACKUP_DIR" ] && say "  backup:     $BACKUP_DIR"

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    head_ "Unresolved"
    for c in "${CONFLICTS[@]}"; do say "  $c"; done
    say ""
    say "  rerun and pick per file, or force one side:"
    say "    ./setup-and-install.sh --yes      repo wins"
    say "    ./setup-and-install.sh --adopt    this machine wins, copied into the repo"
    exit 1
fi

$DRY_RUN && { say ""; info "  dry run: nothing above was actually changed"; }
exit 0
