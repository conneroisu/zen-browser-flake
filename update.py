from typing import Any
import requests
import json
import subprocess


def get_latest_release() -> Any:
    """Fetch the latest release information from GitHub."""
    url = "https://api.github.com/repos/zen-browser/desktop/releases/latest"
    response = requests.get(url)
    response.raise_for_status()
    return response.json()


def download_and_hash(url: str):
    """Download a file and calculate its SHA256 hash using nix-prefetch-url."""
    try:
        print(f"\nHashing URL: {url}")
        print("-" * 80)

        cmd = []
        if "dmg" in url:
            cmd = ["nix-prefetch-url", url]
        else:
            cmd = ["nix-prefetch-url", "--type", "sha256", "--unpack", url]

        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        hash_value = result.stdout.strip()

        print(f"Status: Success")
        print(f"Hash value: {hash_value}")
        print("-" * 80)

        return f"sha256:{hash_value}"
    except subprocess.CalledProcessError as e:
        error_msg = f"Failed to fetch and hash URL: {e.stderr}"
        print(f"Status: Failed")
        print(f"Error message: {error_msg}")
        print("-" * 80)
        raise Exception(error_msg)


def main():
    try:
        # Get latest release info
        release = get_latest_release()
        version = release["tag_name"]
        print(f"Latest version: {version}")

        # Platform mapping
        platforms = {
            "x86_64-linux": {"pattern": "zen.linux-x86_64.tar.xz"},
            "aarch64-linux": {"pattern": "zen.linux-aarch64.tar.xz"},
            "aarch64-darwin": {"pattern": "zen.macos-universal.dmg"},
            "x86_64-darwin": {"pattern": "zen.macos-universal.dmg"},
        }

        # Build version data structure
        version_data = {
            "version": version,
            "platforms": {}
        }

        # Calculate hashes for each platform
        for platform, info in platforms.items():
            pattern = info["pattern"]
            asset = next((a for a in release["assets"] if pattern in a["name"]), None)

            if not asset:
                print(f"Warning: No matching asset found for {platform}")
                continue

            print(f"Calculating hash for {platform}...")
            hash_value = download_and_hash(asset["browser_download_url"])
            
            version_data["platforms"][platform] = {
                "url": asset["browser_download_url"],
                "sha256": hash_value
            }

        # Write version.json
        with open("version.json", "w") as f:
            json.dump(version_data, f, indent=2)

        print("\nversion.json has been updated successfully!")
        print(f"New version: {version}")

    except requests.exceptions.RequestException as e:
        print(f"Error fetching data from GitHub: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    main()
