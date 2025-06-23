# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Nix Flake that packages the Zen Browser (a privacy-focused web browser) for NixOS and other Nix-based systems. The flake downloads pre-built binaries from GitHub releases and properly packages them for multiple platforms (Linux and macOS on both x86_64 and ARM64).

## Common Commands

### Development

```bash
# Enter development shell with required tools
nix develop

# Update to the latest Zen Browser version
python update.py

# Format Nix code
nixpkgs-fmt flake.nix
# or
alejandra flake.nix

# Lint/check Nix code
statix check

# Build the package
nix build .#default

# Run Zen Browser directly
nix run .
```

### Testing Changes

```bash
# Build and test locally before committing
nix build .#default --rebuild

# Test on specific platform
nix build .#packages.x86_64-linux.default
nix build .#packages.aarch64-darwin.default
```

## Architecture

### Core Components

1. **flake.nix** - Main configuration file that:
   - Defines package builds for all supported platforms
   - Handles platform-specific binary downloads and extraction
   - Patches ELF binaries on Linux with required libraries
   - Wraps the browser with proper environment variables

2. **update.py** - Automated update script that:
   - Fetches latest release info from GitHub API
   - Downloads binaries and calculates SHA256 hashes
   - Updates version and hash values in flake.nix
   - Handles different archive formats (tar.xz for Linux, DMG for macOS)

### Platform-Specific Handling

The flake uses different strategies per platform:

**Linux (x86_64/aarch64)**:
- Downloads tar.xz archives
- Uses `patchelf` to fix binary interpreter and RPATH
- Wraps executable with required library paths
- Includes extensive list of runtime dependencies

**macOS (x86_64/aarch64)**:
- Downloads DMG files
- Extracts .app bundle using undmg
- Creates simple wrapper script

### Key Design Decisions

1. **Binary Distribution**: Downloads pre-built binaries rather than building from source
2. **Automated Updates**: Python script ensures easy version bumps
3. **Comprehensive Patching**: Extensive library patching ensures compatibility on NixOS
4. **Multi-platform Support**: Single flake supports 4 platform combinations

## Important Considerations

- The `version.json` file appears to be unused but may be intended for future version tracking
- When updating, ensure all platform hashes are updated correctly
- The flake uses `autoPatchelfHook` for Linux builds to automatically handle most library dependencies
- 1Password integration requires manual configuration as documented in README.md
- The desktop file (`zen.desktop`) is automatically installed on Linux for proper desktop integration