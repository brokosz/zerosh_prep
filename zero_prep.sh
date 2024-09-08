#!/bin/bash

# Function to display help and usage instructions
show_help() {
cat << EOF
Usage: ${0##*/} [OPTION] [DIRECTORY] [WORKSPACE]
Generate zero.sh configuration files from your current system settings and bootstrap the zero.sh repository.

Options:
  -h, --help           Display this help message and exit
  -p, --path           Specify a custom path for the output directory
                       (this will be used as the base directory for all files)
  -w, --workspace      Specify the workspace name (e.g., home, work, shared)
  -b, --bootstrap      Bootstrap the zero.sh repository as a Git submodule without running setup

This script performs the following steps:
  1. Detects the current shell environment and copies the appropriate shell configuration file.
  2. Generates a Brewfile with installed Homebrew packages.
  3. Captures macOS system defaults (for installed applications and built-in system preferences) and saves them in defaults.yaml.
  4. Copies the user's dotfiles and configuration files (e.g., .gitconfig, .config) to the symlinks directory.
  5. Optionally, pulls the latest zero.sh repository as a submodule, pins it to a specific version, and prepares it for use on a new system.

Examples:
  ${0##*/} -w home          Create a setup for the 'home' workspace.
  ${0##*/} -p /path/to/dir  Save configuration files to a custom directory.
  ${0##*/} -b               Bootstrap the zero.sh repository as a submodule.
EOF
}

# Detect the current shell environment
detect_shell() {
    SHELL_NAME=$(basename "$SHELL")

    case "$SHELL_NAME" in
        bash)
            echo "Detected bash shell."
            SHELL_RC_FILE="$HOME/.bashrc"
            ;;
        zsh)
            echo "Detected zsh shell."
            SHELL_RC_FILE="$HOME/.zshrc"
            ;;
        fish)
            echo "Detected fish shell."
            SHELL_RC_FILE="$HOME/.config/fish/config.fish"
            ;;
        *)
            echo "Unsupported shell: $SHELL_NAME"
            SHELL_RC_FILE=""
            ;;
    esac
}

# Bootstrap zero.sh repository as a submodule and pin to a specific version
bootstrap_zero_sh() {
    ZERO_REPO_URL="https://github.com/zero-sh/zero.sh"
    ZERO_REPO_DIR="$DOTFILES_DIR/zero"

    echo "Adding zero.sh as a submodule..."
    if [ ! -d "$ZERO_REPO_DIR" ]; then
        git submodule add "$ZERO_REPO_URL" "$ZERO_REPO_DIR"
    fi

    echo "Updating zero.sh submodule to the latest stable version..."
    git submodule update --init --remote "$ZERO_REPO_DIR"

    # Pin to the latest stable version (can be replaced with a specific tag or version)
    LATEST_VERSION=$(git -C "$ZERO_REPO_DIR" describe --tags `git rev-list --tags --max-count=1`)
    git -C "$ZERO_REPO_DIR" checkout "$LATEST_VERSION"
    echo "Pinned zero.sh to version: $LATEST_VERSION"

    # Commit the changes in the main repo
    git add "$ZERO_REPO_DIR"
    git commit -m "Added zero.sh submodule and pinned to version $LATEST_VERSION"

    echo "Zero.sh repository has been added as a submodule and pinned to $LATEST_VERSION."
    echo "On the new system, clone the repository with --recursive and run 'zero setup' to apply the configuration."
}

# Parse command-line arguments
WORKSPACE=""
DOTFILES_DIR=""
BOOTSTRAP=false
while :; do
    case $1 in
        -h|--help)
            show_help
            exit
            ;;
        -p|--path)
            if [ "$2" ]; then
                DOTFILES_DIR="$2"
                shift
            else
                echo 'ERROR: "--path" requires a non-empty option argument.'
                exit 1
            fi
            ;;
        -w|--workspace)
            if [ "$2" ]; then
                WORKSPACE="$2"
                shift
            else
                echo 'ERROR: "--workspace" requires a non-empty option argument.'
                exit 1
            fi
            ;;
        -b|--bootstrap)
            BOOTSTRAP=true
            ;;
        --) # End of all options
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)  # Default case: No more options
            break
    esac
    shift
done

# Ensure the custom directory is used, and create it if it doesn't exist
if [ -z "$DOTFILES_DIR" ]; then
    read -p "Enter the path to save the zero.sh config files (or press Enter to use default: ~/zero_prep): " INPUT_PATH
    DOTFILES_DIR=${INPUT_PATH:-"$HOME/zero_prep"}
fi

mkdir -p "$DOTFILES_DIR"

# If a workspace is specified, create a workspace subdirectory
if [ -n "$WORKSPACE" ]; then
    DOTFILES_DIR="$DOTFILES_DIR/workspaces/$WORKSPACE"
    echo "Creating workspace: $WORKSPACE"
fi

mkdir -p "$DOTFILES_DIR"
echo "Using directory: $DOTFILES_DIR"

# Detect the user's shell and set the appropriate configuration file
detect_shell

# Define other paths based on the provided or default dotfiles directory
BREWFILE="$DOTFILES_DIR/Brewfile"
DEFAULTS_YAML="$DOTFILES_DIR/defaults.yaml"
SYMLINKS_DIR="$DOTFILES_DIR/symlinks"
RUN_BEFORE_DIR="$DOTFILES_DIR/run/before"
RUN_AFTER_DIR="$DOTFILES_DIR/run/after"

# Create necessary directories
mkdir -p "$SYMLINKS_DIR/shell" "$SYMLINKS_DIR/git" "$SYMLINKS_DIR/config" "$RUN_BEFORE_DIR" "$RUN_AFTER_DIR"

# Step 1: Generate Brewfile
echo "Generating Brewfile..."
if command -v brew >/dev/null; then
  brew bundle dump --file="$BREWFILE" --force
else
  echo "Homebrew is not installed on this system."
fi

# Step 2: Generate defaults.yaml for installed applications and built-in system preferences
echo "Generating defaults.yaml from installed applications and system preferences..."
echo "---" > "$DEFAULTS_YAML"

builtin_system_prefs=(
    "com.apple.dock"
    "com.apple.finder"
    "com.apple.systempreferences"
    "com.apple.screensaver"
    "com.apple.menuextra.clock"
    "com.apple.screencapture"
)

for domain in "${builtin_system_prefs[@]}"; do
    echo "Processing system preference: $domain"
    echo "$domain:" >> "$DEFAULTS_YAML"
    for key in $(defaults read "$domain" 2>/dev/null | grep '=' | awk '{print $1}'); do
        value=$(defaults read "$domain" "$key" 2>/dev/null)
        echo "  $key: $value" >> "$DEFAULTS_YAML"
    done
done

# Step 3: Copy the correct shell configuration file to the symlinks directory
if [ -f "$SHELL_RC_FILE" ]; then
    echo "Copying shell configuration file ($SHELL_RC_FILE) to symlinks..."
    cp "$SHELL_RC_FILE" "$SYMLINKS_DIR/shell/$(basename "$SHELL_RC_FILE")"
else
    echo "No shell configuration file found for $SHELL_NAME."
fi

# Step 4: Copy dotfiles for other configurations (e.g., git)
echo "Copying dotfiles to symlinks..."
cp "$HOME/.gitconfig" "$SYMLINKS_DIR/git/.gitconfig"

# Step 5: Symlink the entire .config folder, excluding the custom path to prevent recursion
echo "Copying .config folder to symlinks..."
if [ -d "$HOME/.config" ]; then
    rsync -a --exclude "$DOTFILES_DIR" "$HOME/.config/" "$SYMLINKS_DIR/config/"
else
    echo ".config folder not found."
fi

# Step 6: Create example scripts for run/before and run/after
echo "Creating setup scripts..."

# Example script for before setup
cat <<'EOF' > "$RUN_BEFORE_DIR/01-before.sh"
#!/bin/bash
# Example script to run before setup
echo "Running pre-setup tasks..."
# Add your pre-setup commands here
EOF
chmod +x "$RUN_BEFORE_DIR/01-before.sh"

# Example script for after setup
cat <<'EOF' > "$RUN_AFTER_DIR/01-after.sh"
#!/bin/bash
# Example script to run after setup
echo "Running post-setup tasks..."
# Add your post-setup commands here
EOF
chmod +x "$RUN_AFTER_DIR/01-after.sh"

# Step 7: If the --bootstrap option is enabled, clone the zero.sh repo as a submodule and pin it
if [ "$BOOTSTRAP" = true ]; then
    bootstrap_zero_sh
fi

#
