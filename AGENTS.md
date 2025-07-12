# AGENTS.md

Agent guidance for zen-browser-flake repository.

## Commands

```bash
# Build/Test
nix build .#default                    # Build package
nix build .#packages.x86_64-linux.default  # Build specific platform
nix run .                              # Run Zen Browser
python update.py                       # Update to latest version

# Lint/Format
statix check                           # Lint Nix code
nixpkgs-fmt flake.nix                  # Format with nixpkgs-fmt
alejandra flake.nix                    # Format with alejandra

# Development
nix develop                            # Enter dev shell
nix flake update                       # Update flake.lock
```

## Project Structure

- **flake.nix**: Main package definition with multi-platform support
- **update.py**: Automated version updater using GitHub API
- **version.json**: Version/hash data for all platforms (x86_64/aarch64 Linux/macOS)
- **zen.desktop**: Desktop integration file for Linux
- **pyproject.toml**: Python dependencies (requests for GitHub API)

## Code Style

- **Nix**: Use 2-space indentation, prefer `let...in` for complex expressions
- **Python**: Follow PEP 8, use type hints, descriptive function names
- **Imports**: Group stdlib, third-party, local imports separately
- **Error Handling**: Use proper exception handling with descriptive messages
- **Naming**: Use snake_case for Python, camelCase for Nix attributes
- **Platforms**: Support x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin

## Special Notes

- 1Password integration requires adding `.zen-wrapped` to `/etc/1password/custom_allowed_browsers`
- Linux builds use extensive library patching via `patchelf` and `wrapProgram`
- macOS builds extract DMG files and install .app bundles
- Version updates modify both version.json and require hash recalculation