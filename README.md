# Starship (Star Fox 64 PC) Installation and Configuration Script

This repository contains a Bash script to automate the installation and configuration of the Starship (Star Fox 64 game PC port) on Linux. While it is specifically designed for the Steam Deck, it should work on most Linux distributions.

The script provides a user-friendly setup experience with detailed instructions and prompts for manual steps when necessary.

## Functionality

* Prompts the user to specify an installation directory (default: ~/Games/StarFox64PC).
* Detects whether it needs to execute the initial installation or update an existing installation.
* Provides links to manually download necessary binaries and OTR files from the latest GitHub action artifacts.
* Prompts the user to place a ROM file in the correct location and ensures/verifies the ROM file using SHA-1 checksum.
* Clones or updates the Starship repository to provide latest necessary configuration files.
* Executes Torch to generate the required OTR file from the provided ROM.
* Offers step-by-step instructions for adding the game to Steam and configuring Steam Input for optimal gameplay, especially on the Steam Deck.

## Requirements

The following tools are required to use the script:
* git: For cloning the source repository.
* jq: For processing JSON responses from GitHub's API.
* wget: For downloading Torch binaries.
* curl: For fetching data from the GitHub API.
* unzip: For extracting downloaded artifacts.

Ensure these dependencies are installed before running the script.

## Usage

* Clone this repository to your system.
  ```bash
  git clone https://github.com/SilentException/starship-setup-linux.git
  cd starship-setup-linux
  ```
* Make the script executable.
  ```bash
  chmod +x starship-setup.sh
  ```
* Run the script.
  ```bash
  ./starship-setup.sh
  ```
* Follow the prompts to complete the installation or update.

## Version History

* 0.1: Initial public version (2024-12-29)
* 0.2: Updated script to align with recent Starship repository / actions changes(o2r, new files in release)

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to fork the repository and submit a pull request.

## License

Licensed under MIT License.
