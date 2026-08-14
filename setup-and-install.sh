#!/usr/bin/env bash
#
# setup-and-install.sh — takes a machine from nothing to fully configured, and
# on every run after that reconciles it back to what this repo says.
#
# It is a reconciler, not an installer: each run compares the machine against
# the desired state below and only touches what differs. Running it twice in a
# row does nothing the second time.
#
# Run with no arguments it asks which of three things you want:
#
#   1  install     packages + symlinks + config, the full reconcile
#   2  update      everything install does, plus upgrading what is installed
#   3  uninstall   undo it: remove the symlinks, the generated files and,
#                  after a second confirmation, the packages themselves
#
#   ./setup-and-install.sh                 ask which mode
#   ./setup-and-install.sh --install       mode 1, no menu
#   ./setup-and-install.sh --update        mode 2, no menu
#   ./setup-and-install.sh --uninstall     mode 3, no menu
#
#   ./setup-and-install.sh --dry-run       report every difference, change nothing
#   ./setup-and-install.sh --links-only    symlinks only, no packages, no nvim
#   ./setup-and-install.sh --no-deps       skip package installation
#   ./setup-and-install.sh --no-nvim       skip the nvim clone and plugin sync
#   ./setup-and-install.sh --prune         also uninstall packages not in the Brewfile
#   ./setup-and-install.sh --yes           non-interactive: repo wins every conflict
#   ./setup-and-install.sh --adopt         non-interactive: the machine wins, and
#                                          its version is copied back into the repo
#
# Without a terminal there is nobody to answer the menu, so a mode flag is
# required: it refuses to guess rather than silently installing.
#
# What it reconciles:
#   1. A package manager (Homebrew), plus the base packages Linux needs first.
#   2. zsh installed and set as the login shell.
#   3. Everything in the Brewfile.
#   4. The symlinks in LINKS below — including REMOVING links this repo used to
#      create and no longer does, tracked through a state file.
#   5. Claude Code accounts, if you want more than one on this machine.
#   6. The nvim config repo, cloned and with its plugins synced.
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

# The same config, mirrored into a secondary Claude Code account directory.
# source (relative to the repo) -> destination (relative to the account dir)
CLAUDE_ACCOUNT_LINKS=(
    "claude_CLAUDE.md:CLAUDE.md"
    "claude_statusline.sh:statusline.sh"
    "claude_hook_herdr-agent-state.sh:hooks/herdr-agent-state.sh"
    "claude_hook_session-cleanup.sh:hooks/session-cleanup.sh"
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
ACCOUNTS_STATE="$STATE_DIR/claude-accounts"
ACCOUNTS_FILE="$HOME/.config/dotfiles/claude-accounts.zsh"

MODE=""
DRY_RUN=false
DO_DEPS=true
DO_NVIM=true
DO_PRUNE=false
DO_UPGRADE=false
CONFLICT_POLICY=ask       # ask | repo | local

for arg in "$@"; do
    case "$arg" in
        --install)    MODE=install ;;
        --update)     MODE=update ;;
        --uninstall)  MODE=uninstall ;;
        --dry-run)    DRY_RUN=true ;;
        --links-only) DO_DEPS=false; DO_NVIM=false ;;
        --no-deps)    DO_DEPS=false ;;
        --no-nvim)    DO_NVIM=false ;;
        --prune)      DO_PRUNE=true ;;
        --yes)        CONFLICT_POLICY=repo ;;
        --adopt)      CONFLICT_POLICY=local ;;
        -h|--help)
            awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"
            exit 0 ;;
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
interactive() { [ -t 0 ] && [ -r /dev/tty ]; }

# ---------------------------------------------------------------------------
# Mode
# ---------------------------------------------------------------------------
choose_mode() {
    [ -n "$MODE" ] && return 0

    if ! interactive; then
        err "no terminal to ask which mode to run."
        err "pass one of --install, --update or --uninstall."
        exit 2
    fi

    while true; do
        printf '\n%s\n' "${B}What do you want to do?${RST}"
        printf '  [1] install     packages, symlinks and config\n'
        printf '  [2] update      all of the above, plus upgrading what is installed\n'
        printf '  [3] uninstall   undo it and clean up what it left behind\n'
        printf '  [q] quit\n'
        printf '  > '
        read -r reply </dev/tty
        case "$reply" in
            1) MODE=install;   return 0 ;;
            2) MODE=update;    return 0 ;;
            3) MODE=uninstall; return 0 ;;
            q|Q) say "nothing done"; exit 0 ;;
            *) info "  1, 2, 3 or q" ;;
        esac
    done
}

choose_mode
[ "$MODE" = update ] && DO_UPGRADE=true

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
say "  mode:      $MODE"
[ "$MODE" = uninstall ] || say "  conflicts: $CONFLICT_POLICY"
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
    # Download first, run second. The usual one-liner, bash -c "$(curl ...)",
    # hides a failed download: the substitution collapses to the empty string,
    # bash runs nothing and exits 0, and the only trace left is curl's own
    # error further up the output.
    local url=https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    local installer
    if ! installer=$(curl -fsSL "$url") || [ -z "$installer" ]; then
        err "  could not download the Homebrew installer from $url"
        return 1
    fi
    NONINTERACTIVE=1 /bin/bash -c "$installer" || return 1

    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        [ -x "$candidate" ] && eval "$("$candidate" shellenv)" && break
    done
    have brew
}

step_package_manager() {
    $DO_DEPS || return 0
    head_ "Package manager"
    [ "$OS" = linux ] && ensure_apt_base
    ensure_brew || err "  could not set up Homebrew; package steps will be skipped"
}

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

step_shell() {
    $DO_DEPS || return 0
    head_ "Shell"
    ensure_zsh_login_shell
}

# ---------------------------------------------------------------------------
# 3. Brewfile
# ---------------------------------------------------------------------------
step_packages() {
    $DO_DEPS && have brew || return 0
    head_ "Packages"

    if [ ! -f "$DOTFILES/Brewfile" ]; then
        warn "  no Brewfile in the repo, skipping"
        return 0
    fi

    if $DRY_RUN; then
        brew bundle check --file "$DOTFILES/Brewfile" --verbose 2>&1 | sed 's/^/  /'
        return 0
    fi

    if brew bundle check --file "$DOTFILES/Brewfile" >/dev/null 2>&1; then
        ok "  every Brewfile package already installed"
    else
        brew bundle --file "$DOTFILES/Brewfile" 2>&1 | sed 's/^/  /'
    fi

    if $DO_PRUNE; then
        say ""
        say "  packages installed but not listed in the Brewfile:"
        brew bundle cleanup --file "$DOTFILES/Brewfile" 2>&1 | sed 's/^/    /'
        if interactive; then
            printf '  uninstall them? [y/N] '
            read -r reply </dev/tty
            case "$reply" in
                [yY]) brew bundle cleanup --force --file "$DOTFILES/Brewfile" 2>&1 | sed 's/^/    /' ;;
                *)    info "    left alone" ;;
            esac
        else
            info "    --prune needs a terminal to confirm; nothing removed"
        fi
    fi
}

# Update mode only: move what is installed forward, rather than just making
# sure it is present.
step_upgrade() {
    $DO_UPGRADE && $DO_DEPS && have brew || return 0
    head_ "Upgrades"
    if $DRY_RUN; then
        info "  would run: brew update && brew upgrade && brew cleanup"
        brew outdated 2>/dev/null | sed 's/^/  outdated: /'
        return 0
    fi
    brew update 2>&1 | sed 's/^/  /'
    brew upgrade 2>&1 | sed 's/^/  /'
    brew cleanup 2>&1 | sed 's/^/  /'
    ok "  packages upgraded"
}

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

declare -a current_dests=()

step_links() {
    head_ "Config files"

    local entry rel src dest target kind
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
}

# --- Prune: links this repo used to create and no longer does ---------------
# The state file is what makes this safe. Without it there is no way to tell a
# link we created last month from one the user made themselves.
step_stale_links() {
    head_ "Stale links"

    if [ ! -f "$STATE_FILE" ]; then
        info "  no previous state recorded; nothing to prune"
        return 0
    fi

    local stale=0 old_rel old_dest d still_wanted
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
    return 0
}

record_links_state() {
    $DRY_RUN && return 0
    mkdir -p "$STATE_DIR"
    printf '%s\n' "${current_dests[@]}" > "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# 5. Claude Code accounts
# ---------------------------------------------------------------------------
# Claude Code keeps one account per config directory: CLAUDE_CONFIG_DIR decides
# where its .claude.json lives, and that file holds the OAuth session, so two
# directories are two logins. Everything worth sharing — CLAUDE.md, the hooks,
# the statusline, plugins and skills — is symlinked, so the accounts differ only
# in identity, history and projects.
#
# This is per-machine, not per-repo: the alias names are recorded in the state
# directory and the aliases themselves are generated into a file that zshrc
# sources if it exists. The repo stays the same on every machine.

accounts_state_get() {
    local key="$1"
    [ -f "$ACCOUNTS_STATE" ] || return 1
    sed -n "s/^$key=//p" "$ACCOUNTS_STATE" | head -1
}

# claude-dez -> ~/.claude-dez, work -> ~/.claude-work. The first alias is always
# the primary account, ~/.claude, which already exists and is already logged in.
account_dir_for() {
    local name="$1"
    case "$name" in
        claude-*) printf '%s\n' "$HOME/.claude-${name#claude-}" ;;
        *)        printf '%s\n' "$HOME/.claude-$name" ;;
    esac
}

valid_alias_name() {
    case "$1" in
        claude) return 1 ;;                      # would shadow the real command
        [A-Za-z]*[!A-Za-z0-9_-]*) return 1 ;;
        [A-Za-z]*) return 0 ;;
        *) return 1 ;;
    esac
}

# Mirror the shared config into a secondary account directory.
#
# settings.json is COPIED, never symlinked: Claude Code rewrites that file in
# place when you change the model or the theme, which replaces a symlink with a
# regular file. The hooks and statusline it only ever reads, so those stay
# links. Paths inside the copy are repointed at the account's own directory.
provision_account_dir() {
    local dir="$1" base entry src dest
    base="$(basename "$dir")"

    run mkdir -p "$dir/hooks"

    for entry in "${CLAUDE_ACCOUNT_LINKS[@]}"; do
        src="$DOTFILES/${entry%%:*}"
        dest="$dir/${entry##*:}"
        [ -e "$src" ] || { err "    ! ${entry%%:*} missing from the repo"; continue; }
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            continue
        fi
        link_atomically "$src" "$dest"
        ok "    + $base/${entry##*:}"
    done

    # Shared with the primary account so a second copy of the plugin cache does
    # not land on disk; a directory symlink survives the files rewritten inside.
    local shared
    for shared in plugins skills; do
        [ -e "$HOME/.claude/$shared" ] || continue
        if [ -L "$dir/$shared" ] && [ "$(readlink "$dir/$shared")" = "$HOME/.claude/$shared" ]; then
            continue
        fi
        link_atomically "$HOME/.claude/$shared" "$dir/$shared"
        ok "    + $base/$shared -> ~/.claude/$shared"
    done

    # Written only when it would actually differ: this is a reconciler, and a
    # file rewritten on every run is churn, not reconciliation.
    if [ -f "$DOTFILES/claude_settings.json" ]; then
        local want
        want="$(sed "s|/\.claude/|/$base/|g" "$DOTFILES/claude_settings.json")"
        if [ -f "$dir/settings.json" ] && [ "$want" = "$(cat "$dir/settings.json")" ]; then
            :
        elif $DRY_RUN; then
            info "    would write $base/settings.json from the repo"
        else
            printf '%s\n' "$want" > "$dir/settings.json.tmp.$$" \
                && mv -f "$dir/settings.json.tmp.$$" "$dir/settings.json" \
                && ok "    ~ $base/settings.json"
        fi
    fi
}

write_accounts_file() {
    local primary="$1" secondary="$2" secondary_dir="$3" want

    # $HOME rather than the expanded path, so the file says the same thing on
    # every machine and reads like something a human would have written.
    want="$(cat <<EOF
# Generated by setup-and-install.sh — do not edit, your changes will be lost.
#
# One Claude Code account per config directory. Plain \`claude\` keeps using
# ~/.claude so the IDE extension and anything scripted are unaffected.
alias $primary='CLAUDE_CONFIG_DIR="\$HOME/.claude" claude'
alias $secondary='CLAUDE_CONFIG_DIR="\$HOME/$(basename "$secondary_dir")" claude'
EOF
)"

    if [ -f "$ACCOUNTS_FILE" ] && [ "$want" = "$(cat "$ACCOUNTS_FILE")" ]; then
        return 0
    fi
    if $DRY_RUN; then
        info "  would write ${ACCOUNTS_FILE/#$HOME/~}"
        return 0
    fi

    mkdir -p "$(dirname "$ACCOUNTS_FILE")"
    printf '%s\n' "$want" > "$ACCOUNTS_FILE"
    ok "  ~ ${ACCOUNTS_FILE/#$HOME/~}"
}

step_claude_accounts() {
    head_ "Claude Code accounts"

    local enabled primary secondary secondary_dir reply

    enabled="$(accounts_state_get enabled)" || enabled=""

    if [ "$enabled" = no ]; then
        info "  declined on a previous run; delete $ACCOUNTS_STATE to be asked again"
        return 0
    fi

    if [ -z "$enabled" ]; then
        if ! interactive; then
            info "  no terminal to ask; skipped (run interactively to set it up)"
            return 0
        fi
        say "  Claude Code can run several accounts on one machine, one per config"
        say "  directory, reached through a shell alias each. Plain \`claude\` keeps"
        say "  working as it does now."
        printf '  set that up? [y/N] '
        read -r reply </dev/tty
        case "$reply" in
            [yY]*) enabled=yes ;;
            *)
                if ! $DRY_RUN; then
                    mkdir -p "$STATE_DIR"
                    printf 'enabled=no\n' > "$ACCOUNTS_STATE"
                fi
                info "  skipped, and recorded so it does not ask again"
                return 0 ;;
        esac
    fi

    primary="$(accounts_state_get primary)"   || primary=""
    secondary="$(accounts_state_get secondary)" || secondary=""

    # Names are asked once and reused on every later run.
    if [ -z "$primary" ] || [ -z "$secondary" ]; then
        if ! interactive; then
            warn "  enabled but no alias names recorded, and no terminal to ask"
            return 0
        fi
        while true; do
            printf '  alias for the current account (~/.claude) [claude-main]: '
            read -r primary </dev/tty
            [ -n "$primary" ] || primary=claude-main
            valid_alias_name "$primary" && break
            info "    letters, digits, - and _; must start with a letter; not \"claude\""
        done
        while true; do
            printf '  alias for the second account [claude-alt]: '
            read -r secondary </dev/tty
            [ -n "$secondary" ] || secondary=claude-alt
            if [ "$secondary" = "$primary" ]; then
                info "    it has to differ from $primary"
                continue
            fi
            valid_alias_name "$secondary" && break
            info "    letters, digits, - and _; must start with a letter; not \"claude\""
        done
    fi

    secondary_dir="$(account_dir_for "$secondary")"

    printf '  %-16s -> %s\n' "$primary" "~/.claude"
    printf '  %-16s -> %s\n' "$secondary" "${secondary_dir/#$HOME/~}"

    provision_account_dir "$secondary_dir"
    write_accounts_file "$primary" "$secondary" "$secondary_dir"

    if ! $DRY_RUN; then
        mkdir -p "$STATE_DIR"
        printf 'enabled=yes\nprimary=%s\nsecondary=%s\nsecondary_dir=%s\n' \
            "$primary" "$secondary" "$secondary_dir" > "$ACCOUNTS_STATE"
    fi

    if [ ! -f "$secondary_dir/.claude.json" ]; then
        info "  $secondary has no session yet: run it and log in with /login"
    fi
}

# ---------------------------------------------------------------------------
# 6. nvim
# ---------------------------------------------------------------------------
step_nvim() {
    $DO_NVIM || return 0
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
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
# Deliberately narrow: it only removes what this repo can prove it created —
# symlinks recorded in the state file that still point here, the generated
# aliases file, and the account directory whose name is in the state file. The
# primary ~/.claude is never touched; it is your main account, not a residue.

confirm_word() {
    local word="$1" prompt="$2" typed
    if $DRY_RUN; then
        info "  dry run: would ask you to type $word"
        return 0
    fi
    if ! interactive; then
        err "  uninstalling needs a terminal to confirm"
        return 1
    fi
    printf '%s\n' "$prompt"
    printf '  type %s to continue: ' "$word"
    read -r typed </dev/tty
    [ "$typed" = "$word" ] || { info "  not confirmed, nothing removed"; return 1; }
}

uninstall_links() {
    head_ "Symlinks"

    if [ ! -f "$STATE_FILE" ]; then
        info "  no state file; nothing this repo can prove it created"
        return 0
    fi

    local rel dest gone=0
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        dest="$HOME/$rel"
        [ -L "$dest" ] || continue
        case "$(readlink "$dest")" in
            "$DOTFILES"/*)
                run rm -f "$dest"
                warn "  - $rel"
                gone=$((gone + 1)) ;;
            *)
                info "  . $rel points outside the repo, left alone" ;;
        esac
    done < "$STATE_FILE"
    [ "$gone" -eq 0 ] && ok "  no repo symlinks left to remove"
    return 0
}

uninstall_claude_accounts() {
    head_ "Claude Code accounts"

    local dir size
    dir="$(accounts_state_get secondary_dir)" || dir=""

    if [ -e "$ACCOUNTS_FILE" ]; then
        run rm -f "$ACCOUNTS_FILE"
        warn "  - ${ACCOUNTS_FILE/#$HOME/~}"
    fi

    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        info "  no secondary account directory recorded"
    else
        size="$(du -sh "$dir" 2>/dev/null | cut -f1)"
        warn "  ${dir/#$HOME/~} holds this account's sessions and history (${size:-unknown})"
        if confirm_word DELETE "  it is not recoverable from the repo."; then
            backup "$dir" "$(basename "$dir")"
            run rm -rf "$dir"
            warn "  - ${dir/#$HOME/~}  (backed up under $BACKUP_DIR)"
        else
            info "  kept"
        fi
    fi

    [ -e "$ACCOUNTS_STATE" ] && run rm -f "$ACCOUNTS_STATE"
    info "  ~/.claude left alone: it is your main account, not a residue"
    return 0
}

uninstall_nvim() {
    head_ "Neovim config"

    if [ ! -d "$NVIM_DIR" ]; then
        info "  nothing at $NVIM_DIR"
        return 0
    fi
    if [ ! -d "$NVIM_DIR/.git" ]; then
        warn "  $NVIM_DIR is not a git clone; left alone"
        return 0
    fi
    if [ -n "$(git -C "$NVIM_DIR" status --porcelain 2>/dev/null)" ]; then
        warn "  uncommitted changes in $NVIM_DIR; left alone"
        git -C "$NVIM_DIR" status --short 2>/dev/null | sed 's/^/    /'
        return 0
    fi
    # Commits that exist only here would be lost with the directory.
    if git -C "$NVIM_DIR" rev-parse '@{u}' >/dev/null 2>&1; then
        if [ -n "$(git -C "$NVIM_DIR" log --oneline '@{u}..' 2>/dev/null)" ]; then
            warn "  commits in $NVIM_DIR that are not on the remote; left alone"
            git -C "$NVIM_DIR" log --oneline '@{u}..' 2>/dev/null | sed 's/^/    /'
            return 0
        fi
    else
        warn "  no upstream configured for $NVIM_DIR; cannot prove it is pushed, left alone"
        return 0
    fi

    run rm -rf "$NVIM_DIR"
    warn "  - ${NVIM_DIR/#$HOME/~}  (clean, and everything is on the remote)"
}

uninstall_packages() {
    head_ "Packages"

    have brew || { info "  no brew on this machine"; return 0; }
    if [ ! -f "$DOTFILES/Brewfile" ]; then
        info "  no Brewfile in the repo"
        return 0
    fi

    local formulae=() casks=() name
    while IFS= read -r name; do
        [ -n "$name" ] && formulae+=("$name")
    done < <(sed -n 's/^ *brew  *"\([^"]*\)".*/\1/p' "$DOTFILES/Brewfile")
    while IFS= read -r name; do
        [ -n "$name" ] && casks+=("$name")
    done < <(sed -n 's/^ *cask  *"\([^"]*\)".*/\1/p' "$DOTFILES/Brewfile")

    if [ ${#formulae[@]} -eq 0 ] && [ ${#casks[@]} -eq 0 ]; then
        info "  nothing listed in the Brewfile"
        return 0
    fi

    say "  the Brewfile lists ${#formulae[@]} formulae and ${#casks[@]} casks:"
    # Under `set -u` an empty array is an unbound variable, and this Brewfile
    # has no casks at all, so both expansions need the guard.
    [ ${#formulae[@]} -gt 0 ] && printf '    %s\n' "${formulae[@]}"
    [ ${#casks[@]} -gt 0 ]    && printf '    %s\n' "${casks[@]}"
    warn "  these are tools you also use outside dotfiles."

    # A different word from the one that got us here, on purpose: this is the
    # step that reaches outside the repo, and it should not fall to muscle
    # memory from the previous prompt.
    confirm_word PACKAGES "  removing them affects the whole machine, not just this repo." || return 0

    # Casks first: a cask can depend on a formula, never the other way round.
    # Anything another package still needs will refuse to go, which is the
    # outcome we want — report it instead of forcing.
    local failed=()
    for name in ${casks[@]+"${casks[@]}"}; do
        if $DRY_RUN; then
            info "    would uninstall cask $name"
        elif ! brew uninstall --cask "$name" >/dev/null 2>&1; then
            failed+=("cask $name")
        fi
    done
    for name in ${formulae[@]+"${formulae[@]}"}; do
        if $DRY_RUN; then
            info "    would uninstall formula $name"
        elif ! brew uninstall --formula "$name" >/dev/null 2>&1; then
            failed+=("formula $name")
        fi
    done

    if [ ${#failed[@]} -gt 0 ]; then
        warn "  still installed, something else depends on them:"
        printf '    %s\n' "${failed[@]}"
    else
        $DRY_RUN || ok "  Brewfile packages removed"
    fi
}

# Directories this repo created on the way in and that are now empty. rmdir,
# never rm -rf: if anything else ended up in one of them it stays, and the
# failure is the point rather than an error to suppress.
prune_empty_dirs() {
    head_ "Empty directories"

    local dirs=() d entry rel
    for entry in "${LINKS[@]}"; do
        rel="${entry##*:}"
        d="$(dirname "$HOME/$rel")"
        [ "$d" = "$HOME" ] && continue
        dirs+=("$d")
    done
    dirs+=("$(dirname "$ACCOUNTS_FILE")")
    dirs+=("$STATE_DIR" "$(dirname "$STATE_DIR")")

    # Deepest first, so a parent emptied by its children can go in the same pass.
    local pruned=0
    while IFS= read -r d; do
        [ -d "$d" ] || continue
        case "$d" in "$HOME"|"$HOME"/) continue ;; esac
        if $DRY_RUN; then
            [ -z "$(ls -A "$d" 2>/dev/null)" ] && { info "  would remove empty ${d/#$HOME/~}"; pruned=$((pruned + 1)); }
        elif rmdir "$d" 2>/dev/null; then
            warn "  - ${d/#$HOME/~}"
            pruned=$((pruned + 1))
        fi
    done < <(printf '%s\n' "${dirs[@]}" | awk '{print gsub(/\//,"/"), $0}' | sort -rn | cut -d' ' -f2-)

    [ "$pruned" -eq 0 ] && ok "  none left empty"
    return 0
}

uninstall_state() {
    head_ "State"
    if [ -d "$STATE_DIR" ]; then
        run rm -rf "$STATE_DIR"
        warn "  - ${STATE_DIR/#$HOME/~}"
    else
        info "  no state directory"
    fi
    say ""
    info "  the repo itself and ~/.dotfiles-backup were not touched."
    info "  your login shell is still zsh; change it back with chsh if you want."
}

do_uninstall() {
    head_ "Uninstall"
    say "  this removes the symlinks this repo created, the generated Claude"
    say "  aliases, the nvim clone and — after a separate confirmation — the"
    say "  Brewfile packages."
    confirm_word UNINSTALL "" || exit 0

    uninstall_links
    uninstall_claude_accounts
    uninstall_nvim
    uninstall_packages
    uninstall_state
    prune_empty_dirs

    head_ "Done"
    [ -d "$BACKUP_DIR" ] && say "  backup: $BACKUP_DIR"
    $DRY_RUN && info "  dry run: nothing above was actually changed"
    exit 0
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
[ "$MODE" = uninstall ] && do_uninstall

step_package_manager
step_shell
step_packages
step_upgrade
step_links
step_stale_links
record_links_state
step_claude_accounts
step_nvim

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
    say "    ./setup-and-install.sh --install --yes      repo wins"
    say "    ./setup-and-install.sh --install --adopt    this machine wins, copied into the repo"
    exit 1
fi

$DRY_RUN && { say ""; info "  dry run: nothing above was actually changed"; }
exit 0
