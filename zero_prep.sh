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
  -b, --bootstrap      Bootstrap the zero.sh repository without running setup

This script performs the following steps:
  1. Detects the current shell environment and copies the appropriate shell configuration file.
  2. Generates a Brewfile with installed Homebrew packages.
  3. Captures macOS system defaults (for installed applications and built-in system preferences) and saves them in defaults.yaml.
  4. Copies the user's dotfiles and configuration files (e.g., .gitconfig, .config) to the symlinks directory.
  5. Optionally, pulls the latest zero.sh repository for use on a new system.

Examples:
  ${0##*/} -w home          Create a setup for the 'home' workspace.
  ${0##*/} -p /path/to/store/prepped/config  Save configuration files to a custom directory.
  ${0##*/} -b               Bootstrap the zero.sh repository without running setup.
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

# Get list of installed applications, including from ~/Applications
get_installed_apps() {
    echo "Getting list of installed applications..."
    find /Applications /System/Applications ~/Applications -maxdepth 1 -name "*.app" | sed 's#.*/##' | sed 's/.app$//'
}

# Built-in macOS system preferences to always capture
builtin_system_prefs=(
    "com.apple.dock"
    "com.apple.finder"
    "com.apple.systempreferences"
    "com.apple.screensaver"
    "com.apple.menuextra.clock"
    "com.apple.screencapture"
    "com.apple.preference"   # System Preferences pane
)

# Capture defaults only for installed applications and built-in system preferences
generate_defaults() {
    echo "Generating defaults.yaml for installed applications and system preferences..."
    echo "---" > "$DEFAULTS_YAML"

    installed_apps=$(get_installed_apps)

    # Capture system defaults for built-in macOS preferences
    for domain in "${builtin_system_prefs[@]}"; do
        echo "Processing built-in system preference: $domain"
        echo "$domain:" >> "$DEFAULTS_YAML"
        for key in $(defaults read "$domain" 2>/dev/null | grep '=' | awk '{print $1}'); do
            value=$(defaults read "$domain" "$key" 2>/dev/null)
            echo "  $key: $value" >> "$DEFAULTS_YAML"
        done
    done

    # Capture system defaults for installed applications, including those from ~/Applications
    for domain in $(defaults domains | sed 's/, /\n/g'); do
        app_name=$(echo "$domain" | awk -F'.' '{print $NF}')
        if [[ "$installed_apps" =~ "$app_name" ]]; then
            echo "Processing domain: $domain for installed app: $app_name"
            echo "$domain:" >> "$DEFAULTS_YAML"
            for key in $(defaults read "$domain" 2>/dev/null | grep '=' | awk '{print $1}'); do
                value=$(defaults read "$domain" "$key" 2>/dev/null)
                echo "  $key: $value" >> "$DEFAULTS_YAML"
            done
        fi
    done
}

# Bootstrap zero.sh repository without running setup
bootstrap_zero_sh() {
    ZERO_REPO_URL="https://github.com/zero-sh/zero.sh"
    ZERO_REPO_DIR="$DOTFILES_DIR/zero"

    echo "Cloning the zero.sh repository..."
    if [ ! -d "$ZERO_REPO_DIR" ]; then
        git clone "$ZERO_REPO_URL" "$ZERO_REPO_DIR"
    else
        echo "Zero.sh repository already exists, pulling latest changes..."
        git -C "$ZERO_REPO_DIR" pull
    fi

    echo "Zero.sh repository has been prepared for use on the new system."
    echo "On the new system, run 'zero setup' to apply the configuration."
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
    read -p "Enter the path to save the zero.sh config files (or press Enter to use default: ~/.dotfiles): " INPUT_PATH
    DOTFILES_DIR=${INPUT_PATH:-"$HOME/.dotfiles"}
fi

mkdir -p "$DOTFILES_DIR"

# Ensure workspace is created inside the workspaces directory under .dotfiles
WORKSPACE_DIR="$DOTFILES_DIR/workspaces/$WORKSPACE"
mkdir -p "$WORKSPACE_DIR"

# Now use WORKSPACE_DIR for storing all config-related files (Brewfile, run, symlinks, etc.)
BREWFILE="$WORKSPACE_DIR/Brewfile"
DEFAULTS_YAML="$WORKSPACE_DIR/defaults.yaml"
SYMLINKS_DIR="$WORKSPACE_DIR/symlinks"
RUN_BEFORE_DIR="$WORKSPACE_DIR/run/before"
RUN_AFTER_DIR="$WORKSPACE_DIR/run/after"

# Create necessary directories only if they don't exist
mkdir -p "$SYMLINKS_DIR/shell" "$SYMLINKS_DIR/git" "$SYMLINKS_DIR/config" "$RUN_BEFORE_DIR" "$RUN_AFTER_DIR"

# Step 1: Generate Brewfile
echo "Generating Brewfile..."
if command -v brew >/dev/null; then
  if [ -f "$BREWFILE" ]; then
    echo "Brewfile already exists. Skipping generation."
  else
    brew bundle dump --file="$BREWFILE" --force
  fi
else
  echo "Homebrew is not installed on this system."
fi

# Step 2: Generate defaults.yaml for installed applications and built-in system preferences
generate_defaults

# Step 3: Copy the correct shell configuration file to the symlinks directory
if [ -f "$SHELL_RC_FILE" ]; then
    if [ ! -f "$SYMLINKS_DIR/shell/$(basename "$SHELL_RC_FILE")" ]; then
        echo "Copying shell configuration file ($SHELL_RC_FILE) to symlinks..."
        cp "$SHELL_RC_FILE" "$SYMLINKS_DIR/shell/$(basename "$SHELL_RC_FILE")"
    else
        echo "Shell configuration file already exists in symlinks. Skipping copy."
    fi
else
    echo "No shell configuration file found for $SHELL_NAME."
fi

# Step 4: Copy dotfiles for other configurations (e.g., git)
if [ -f "$HOME/.gitconfig" ]; then
    if [ ! -f "$SYMLINKS_DIR/git/.gitconfig" ]; then
        echo "Copying .gitconfig to symlinks..."
        cp "$HOME/.gitconfig" "$SYMLINKS_DIR/git/.gitconfig"
    else
        echo ".gitconfig already exists in symlinks. Skipping copy."
    fi
else
    echo ".gitconfig not found."
fi

# Step 5: Symlink the entire .config folder, excluding the custom path to prevent recursion
if [ -d "$HOME/.config" ]; then
    if [ ! -d "$SYMLINKS_DIR/config" ]; then
        echo "Copying .config folder to symlinks..."
        rsync -a --exclude "$DOTFILES_DIR" "$HOME/.config/" "$SYMLINKS_DIR/config/"
    else
        echo ".config folder already exists in symlinks. Skipping copy."
    fi
else
    echo ".config folder not found."
fi

# Step 6: Create example scripts for run/before and run/after
echo "Creating setup scripts..."

# Example script for before setup
if [ ! -f "$RUN_BEFORE_DIR/01-before.sh" ]; then
    cat <<'EOF' > "$RUN_BEFORE_DIR/01-before.sh"
#!/bin/bash
# Example script to run before setup
echo "Running pre-setup tasks..."
# Add your pre-setup commands here
EOF
    chmod +x "$RUN_BEFORE_DIR/01-before.sh"
else
    echo "Pre-setup script already exists. Skipping creation."
fi

# Example script for after setup
if [ ! -f "$RUN_AFTER_DIR/01-after.sh" ]; then
    cat <<'EOF' > "$RUN_AFTER_DIR/01-after.sh"
#!/bin/bash
# Example script to run after setup
echo "Running post-setup tasks..."
# Add your post-setup commands here
EOF
    chmod +x "$RUN_AFTER_DIR/01-after.sh"
else
    echo "Post-setup script already exists. Skipping creation."
fi

# Step 7: If the --bootstrap option is enabled, clone the zero.sh repo as a submodule and prepare it
if [ "$BOOTSTRAP" = true ]; then
    bootstrap_zero_sh
fi

echo "Setup completed. Configuration files have been generated in $WORKSPACE_DIR."
