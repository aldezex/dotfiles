# dotfiles

zsh, git, Neovim, Ghostty, herdr and Claude Code. macOS, Linux and WSL.

```sh
git clone https://github.com/aldezex/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup-and-install.sh --dry-run   # report every difference, change nothing
./setup-and-install.sh
```

One script does everything: Homebrew, zsh as the login shell, the `Brewfile`,
the symlinks, and the Neovim config from [aldezex/nvim](https://github.com/aldezex/nvim).

It reconciles rather than installs. Every run compares the machine against this
repo and touches only what differs, including removing links it used to create
and no longer does. Run it twice and the second run does nothing.

When something is already at a destination and it is not our symlink, it shows
the diff and asks: take the repo's version, or keep the machine's and copy it
back here ready to commit. Nothing is overwritten without a backup in
`~/.dotfiles-backup/`.

`./setup-and-install.sh --help` for the flags.

Because these are symlinks, editing `~/.zshrc` is editing this repo.

## Windows

Work inside WSL, which is just another Linux box here. Install from the WSL
shell against the WSL `$HOME` — not from PowerShell, not over `/mnt/c`.
