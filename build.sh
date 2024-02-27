#!/bin/bash
# This script builds a "WineBuild.txz" file

# Get the local directory where the script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Create a temporary directory
TMPDIR=$(mktemp -d)
# Create the dist/ directory
DISTDIR="$TMPDIR/dist"
mkdir -p "$DISTDIR"

# Exit safely
# $1: The exit code
function cleanup {
    rm -rf "$TMPDIR"
    exit $1
}

# Log an info message
# $1: The message
function info {
    echo >&2 "Info: $1"
}

# Log a debug message
# $1: The message
function debug {
    echo >&2 "Debug: $1"
}

# Log an error message
# $1: The message
function error {
    echo >&2 "Error: $1"
}


# Required commands
function check_commands {
    local required_commands=(
        "curl"
        "jq"
        "ditto"
        "tar"
    )
    for command in "${required_commands[@]}"; do
        if ! command -v "$command" &> /dev/null; then
            error "$command is required"
            cleanup 1
        fi
    done
}

# Grab the latest release of a GitHub repository
# $1: The GitHub repository in the format "user/repo"
# $2: Version to grab
function get_release_data {
    local repo="$1"
    local url="https://api.github.com/repos/$repo/releases/$2"
    if ! release_data=$(curl -s "$url"); then
        error "Could not get the latest release data for $repo"
        cleanup 1
    fi
    # Return the release data
    echo "$release_data"
}

# Download a file from a URL
# $1: The URL
# $2: The output file
function download_file {
    local url="$1"
    local output="$2"
    if ! curl -s -L -o "$output" "$url"; then
        error "Could not download from $url"
        cleanup 1
    fi
}

# Get moltenvk download url
function get_moltenvk_download_url {
    local release_data=$(get_release_data "KhronosGroup/MoltenVK" "latest")
    local download_url=$(echo "$release_data" | jq -r ".assets[] | select(.name == \"MoltenVK-macos.tar\") | .browser_download_url")
    if [ -z "$download_url" ]; then
        error "Could not find a MoltenVK release"
        cleanup 1
    fi
    echo "$download_url"
}

# Create Wine
function create_wine {
    # Get the latest Wine release
    local release_data=$(get_release_data "Gcenx/macOS_Wine_builds" "latest")
    local tag_name="wine-devel-$(echo "$release_data" | jq -r ".tag_name")-osx64.tar.xz"
    local download_url=$(echo "$release_data" | jq -r --arg asset_name "$tag_name" ".assets[] | select(.name == \"$tag_name\") | .browser_download_url")
    if [ -z "$download_url" ]; then
        error "Could not find a Wine release"
        cleanup 1
    fi
    # Get the latest MoltenVK release
    local moltenvk_download_url=$(get_moltenvk_download_url)

    # Download and extract Wine
    info "Downloading Wine version $tag_name"
    download_file "$download_url" "$TMPDIR/wine-download.tar.xz"
    info "Extracting Wine"
    mkdir -p "$TMPDIR/wine"
    tar -C "$TMPDIR/wine" -xf "$TMPDIR/wine-download.tar.xz"
    mv "$TMPDIR/wine/Wine Devel.app/Contents/Resources/wine" "$DISTDIR/wine"
    # Download and extract MoltenVK
    info "Downloading MoltenVK"
    download_file "$moltenvk_download_url" "$TMPDIR/moltenvk-download.tar"
    info "Extracting MoltenVK"
    mkdir -p "$TMPDIR/MoltenVK"
    tar -C "$TMPDIR/MoltenVK" -xf "$TMPDIR/moltenvk-download.tar"
    rm "$DISTDIR/wine/lib/libMoltenVK.dylib"
    mv "$TMPDIR/MoltenVK/MoltenVK/MoltenVK/dylib/macOS/libMoltenVK.dylib" "$DISTDIR/wine/lib/libMoltenVK.dylib"
    # Remove the original download
    rm -f "$TMPDIR/wine-download.tar.xz"
    rm -rf "$TMPDIR/wine"
    rm -f "$TMPDIR/moltenvk-download.tar"
    rm -rf "$TMPDIR/MoltenVK"
    # Apply Apple GPTK patches with ditto
    info "Applying Apple GPTK patches"
    ditto "$DIR/lib/GPTK/redist/lib/" "$DISTDIR/Wine/lib/"
    # Done 
    info "Wine has been created"
}

# Create DXVK
function create_dxvk {
    # Get the latest DXVK release
    local release_data=$(get_release_data "Gcenx/DXVK-macOS" "latest")
    local tag_name=dxvk-macOS-async-$(echo "$release_data" | jq -r ".tag_name").tar.gz
    local download_url=$(echo "$release_data" | jq -r --arg asset_name "$tag_name" ".assets[] | select(.name == \"$tag_name\") | .browser_download_url")
    if [ -z "$download_url" ]; then
        error "Could not find a DXVK release"
        cleanup 1
    fi
    # Download and extract DXVK
    info "Downloading DXVK version $tag_name"
    download_file "$download_url" "$TMPDIR/dxvk-download.tar.gz"
    info "Extracting DXVK"
    mkdir -p "$DISTDIR/dxvk"
    tar -C "$DISTDIR/dxvk" --strip-components=1 -xzf "$TMPDIR/dxvk-download.tar.gz"
    # Remove the original download
    rm -f "$TMPDIR/dxvk-download.tar.gz"
    # Done 
    info "DXVK has been created"
}

# Create winetricks
function create_winetricks {
    # Make the winetricks directory
    mkdir -p "$DISTDIR/winetricks"
    # Get the latest winetricks release
    download_file "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" "$DISTDIR/winetricks/winetricks"
    chmod +x "$DISTDIR/winetricks/winetricks"
    # Get the verbs.txt file
    download_file "https://raw.githubusercontent.com/Winetricks/winetricks/master/files/verbs/all.txt" "$DISTDIR/winetricks/verbs.txt"
}

# Main
function main {
    info "Folder location: $DISTDIR"
    # Check for required commands
    check_commands
    # Create Wine
    create_wine
    # Create DXVK
    create_dxvk
    # Create winetricks
    create_winetricks
    # Create the tarball
    info "Creating the tarball"
    tar -cJf "$TMPDIR/build.txz" -C "$DISTDIR" .
    # Move the tarball to the current directory
    mv "$TMPDIR/build.txz" "$DIR/wine-build.txz"
    # Done
    info "wine-build.txz has been created"
    # Exit safely
    cleanup 0
}

main