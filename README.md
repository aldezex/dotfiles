# macOS Development Environment Setup

This repository contains a bash script for setting up a basic development environment on macOS. It automates the installation and updating of essential tools like Homebrew, Vim, Neovim, Fish shell, Fisher, and Starship prompt. Additionally, it configures Neovim and Fish with pre-defined settings.

## Prerequisites

- macOS operating system
- Command Line Tools for Xcode (Install by running `xcode-select --install` in the terminal)

## Getting Started

1. **Clone the Repository**: Clone this repository to your local machine to get started.

    ```bash
    git clone https://github.com/aldezex/dotfiles.git
    ```

2. **Navigate to the Script**: Change your directory to the location of the script.

    ```bash
    cd dotfiles 
    ```

3. **Make the Script Executable**: Before running the script, make sure it is executable.

    ```bash
    chmod +x setup_macos.sh
    ```

4. **Run the Script**: Execute the script to start the installation process.

    ```bash
    ./setup_macos.sh
    ```

## What the Script Does

- **Homebrew**: Checks for Homebrew. Installs or updates it if necessary.
- **Vim**: Checks for Vim. Installs or updates it using Homebrew.
- **Neovim**: Checks for Neovim. Installs or updates it using Homebrew.
- **Fish Shell**: Checks for Fish shell. Installs it using Homebrew if not found.
- **Fisher**: Checks for Fisher. Installs it using Homebrew if not found.
- **Starship**: Checks for the Starship prompt. Installs it using Homebrew if not found.
- **Configurations**: Moves Neovim and Fish configurations from the script directory to their respective configuration directories in `~/.config`.

## Notes

- The script is intended for macOS users and assumes Homebrew as the primary package manager.
- NVM and iTerm2 installation sections are commented out. Uncomment these sections if you wish to include their setup.
- The script copies Neovim and Fish configurations from specific directories. Ensure these directories contain the desired configuration files.

## Troubleshooting

If you encounter any issues while running the script, ensure you have the necessary permissions and your system is up to date. For specific tool-related issues, refer to the respective tool's documentation.

