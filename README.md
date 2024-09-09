# Zero.sh Bootstrap & Configuration Prep

This repository contains scripts to bootstrap the [zero.sh](https://github.com/zero-sh/zero.sh.git) system setup and prepare all necessary configuration files, ensuring a smooth setup process on a new system.

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Step-by-Step Instructions](#step-by-step-instructions)
  - [Bootstrapping the Zero.sh Repository](#bootstrapping-the-zerosh-repository)
- [Directory Structure](#directory-structure)
- [Next Steps](#next-steps)
- [Contributing](#contributing)
- [License](#license)

## Overview
This repository allows you to:
- Capture system defaults and configuration files from an existing macOS system.
- Prepare these files for easy use with **zero.sh** on a new system.
- Bootstrap the **zero.sh** repository without running the setup, so that the new system can be configured in a seamless manner.

## Features
- Automatically generates:
  - `Brewfile` with your Homebrew packages.
  - `defaults.yaml` containing your macOS system preferences for installed apps and core macOS settings.
  - Symlinked configuration files (e.g., `.bashrc`, `.zshrc`, `.gitconfig`, etc.), including shell profiles like `.bash_profile` or `.zprofile`.
  - Scripts to run before and after the setup.
- Pulls the latest **zero.sh** repository.
- Prepares the system for an easy, repeatable installation on a new machine.

## Requirements
- macOS system with:
  - **Homebrew** installed.
  - **Git** installed.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/yourrepo.git
   cd yourrepo
   ```

2. Make sure the main script is executable:
   ```bash
   chmod +x zero_prep.sh
   ```

## Usage

### Step-by-Step Instructions
1. Run the `zero_prep.sh` script to prepare your system configuration:
   ```bash
   ./zero_prep.sh --path ~/path/to/store/prepped/config --workspace my_workspace
   ```

   - **`--path`**: The location where the configuration files and repository will be stored.
   - **`--workspace`**: Optional. You can specify a workspace to organize your config files (e.g., `home`, `work`).

2. If you want to bootstrap the **zero.sh** repository for future setup, use the `--bootstrap` flag:
   ```bash
   ./zero_prep.sh --path ~/path/to/store/prepped/config --bootstrap
   ```

### Bootstrapping the Zero.sh Repository
Running the script with the `--bootstrap` option will pull the latest version of the **zero.sh** repository and prepare it for use on a new system. **Note:** The script will not run the **zero.sh** setup on your current machine; it will only clone the repository for future use.

Once you are on your new system, run the following to apply the setup:
```bash
caffeinate -i ~/.dotfiles/zero/setup
```

This will prevent the machine from going to sleep while **zero.sh** runs.

## Directory Structure
The script generates the following structure:

```
~/path/to/store/prepped/config
├── Brewfile
├── defaults.yaml
├── run/
│   ├── before/
│   └── after/
├── symlinks/
│   ├── bash/
│   ├── zsh/
│   ├── fish/
│   └── git/
└── zero/  (cloned zero.sh repository)
```

- **Brewfile**: Lists all Homebrew packages for easy installation.
- **defaults.yaml**: Contains macOS system preferences for installed apps and system settings.
- **symlinks/**: Contains symlinked configuration files for each shell and other configurations (e.g., git).
- **run/**: Contains scripts that run before and after the setup.
- **zero/**: Contains the cloned **zero.sh** repository.

## Next Steps
1. Review the generated files in the configured directory.
2. Move the generated files to `~/.dotfiles`:
   ```bash
   mv ~/path/to/store/prepped/config ~/.dotfiles
   ```

3. Optionally, upload the `~/.dotfiles` directory to a Git repository for future use:
   ```bash
   cd ~/.dotfiles
   git init
   git remote add origin <your-repo-url>
   git add .
   git commit -m "Initial dotfiles commit"
   git push -u origin master
   ```

4. On a new machine:
   - Clone the repository:
     ```bash
     git clone https://github.com/<your-username>/<your-repo>.git ~/.dotfiles --recursive
     ```
   - Run zero.sh setup with `caffeinate`:
     ```bash
     caffeinate -i ~/.dotfiles/zero/setup
     ```

## Contributing
I welcome contributions! Please fork the repository and submit a pull request with your changes.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
