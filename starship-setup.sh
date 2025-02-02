#!/bin/bash

###############################################################################
#
# Starship (Star Fox 64 PC) Installation and Configuration Script
# @author SilentException
# @since 2024-12-29
#
# This script automates the process of downloading, verifying, and installing
# the Starship game/port for Linux. It was made with the Steam Deck in mind but
# should work on most Linux distributions. It provides a user-friendly setup
# experience with detailed instructions and prompts for manual steps where
# required.
#
# Functionality:
# 1. Prompts the user to specify an installation directory
#    (default: ~/Games/StarFox64PC).
# 2. Depending on the installation directory state, it executes the initial
#    installation of the game and all required files, or it updates an existing
#    installation to the latest version.
# 3. Prompts the user with links to download necessary binaries and O2R files
#    from the latest GitHub action artifacts.
# 4. Ensures ROM files are placed and verified with their SHA-1 checksum.
# 5. Clones or updates the Starship repository to provide necessary
#    configuration files.
# 6. Executes Torch to generate the required O2R file from the verified ROM.
# 7. Provides step-by-step instructions for adding the game to Steam and
#    configuring Steam Input for an optimal experience on the Steam Deck.
#
# Requirements:
# - git (for cloning the source repository).
# - jq (for processing JSON responses from GitHub's API).
# - wget (for downloading Torch binaries).
# - curl (for fetching data from the GitHub API).
# - unzip (for extracting downloaded artifacts).
#
# Usage:
# - Download the script and make it executable (chmod +x script_name.sh).
# - Run the script in a terminal and follow the prompts to finish installation.
# - Ensure required dependencies are installed before running the script.
#
# Version History:
# - 0.1 Initial public version (2024-12-29)
# - 0.2 Updated script to align with recent Starship repository / actions
#       changes(o2r, new files in release)
# 
###############################################################################

# define colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NC="\033[0m" # no color

# define paths and variables
WORKING_DIRECTORY="$(realpath "$(dirname "$0")")"
GAME_DIR_DEFAULT="$HOME/Games/StarFox64PC"
GAME_DIR="$WORKING_DIRECTORY"

DOWNLOAD_ARCH="x86_64"
DOWNLOAD_BRANCH="main"
GAME_ROM_Z64_EXPECTED_SHA1="09f0d105f476b00efa5303a3ebc42e60a7753b7a"

# prompt for installation directory
echo -e "${YELLOW}Please specify the installation directory. Press Enter to use the default: \"${NC}${CYAN}$GAME_DIR_DEFAULT${NC}${YELLOW}\".${NC}"
read -p "Installation Directory [$GAME_DIR_DEFAULT]: " USER_INPUT_GAME_DIR

# use default if no input is provided
if [ -z "$USER_INPUT_GAME_DIR" ]; then
    GAME_DIR="$GAME_DIR_DEFAULT"
else
    GAME_DIR="$USER_INPUT_GAME_DIR"
fi

# ensure GAME_DIR
mkdir -p "$GAME_DIR"
if [ $? -ne 0 ] || [ ! -d "$GAME_DIR" ]; then
    echo -e "${RED}Error: failed to create or access the installation directory:${NC} \"${CYAN}$GAME_DIR${NC}\"."
    #read -p "Press Enter to exit..."
    exit 1
fi

# inform the user of the chosen installation directory
echo -e "${GREEN}Installation directory set to:${NC} \"${CYAN}$GAME_DIR${NC}\"."

# now we can define more paths and variables - depending on GAME_DIR
GAME_BINARY_FILE="$GAME_DIR/starship.AppImage"
GAME_GAMECONTROLLERDB_FILE="$GAME_DIR/gamecontrollerdb.txt"
GAME_VERSION_FILE="$GAME_DIR/VERSION"
GAME_OTR_FILE_OLD="$GAME_DIR/starship.otr"
GAME_O2R_FILE="$GAME_DIR/starship.o2r"
GAME_ROM_OTR_FILE_OLD="$GAME_DIR/sf64.otr"
GAME_ROM_O2R_FILE="$GAME_DIR/sf64.o2r"
GAME_ROM_DIR="$GAME_DIR/rom"
GAME_GENERATEOTR_DIR_OLD="$GAME_DIR/generate-otr"
GAME_GENERATEO2R_DIR="$GAME_DIR/generate-o2r"
GAME_GENERATEO2R_ROM_O2R_FILE="$GAME_GENERATEO2R_DIR/sf64.o2r"
GAME_SOURCES_DIR="$GAME_DIR/sources"
GAME_SOURCES_CONFIG_FILE="$GAME_SOURCES_DIR/config.yml"
GAME_SOURCES_ASSETS_DIR="$GAME_SOURCES_DIR/assets"
GAME_SOURCES_INCLUDE_DIR="$GAME_SOURCES_DIR/include"
TEMP_DIR="$GAME_DIR/downloads"
TEMP_BINARY_DOWNLOAD_FILE="$TEMP_DIR/Starship-linux.zip"
TEMP_O2R_DOWNLOAD_FILE="$TEMP_DIR/starship.o2r.zip"
TEMP_BINARY_FILE="$TEMP_DIR/starship.appimage"
TEMP_GAMECONTROLLERDB_FILE="$TEMP_DIR/gamecontrollerdb.txt"
TEMP_O2R_FILE="$TEMP_DIR/starship.o2r"
TEMP_DIR_CONFIG_FILE="$TEMP_DIR/config.yml"
TEMP_DIR_ASSETS_DIR="$TEMP_DIR/assets"

PERFORMING_UPDATE=0
# are we installing or updating...?
if [ ! -f "$GAME_BINARY_FILE" ]; then
    echo -e "${YELLOW}First time installation...${NC}"
else
    echo -e "${YELLOW}Updating existing installation...${NC}"
    PERFORMING_UPDATE=1
fi

# fetch HarbourMasters/Starship action runs
STARSHIP_ACTIONRUNS_URL="https://api.github.com/repos/HarbourMasters/Starship/actions/runs?branch=$DOWNLOAD_BRANCH&per_page=15"
STARSHIP_ACTIONRUNS_JSON=$(curl -s "$STARSHIP_ACTIONRUNS_URL")

# get action event - event must be === "push" or  !== "pull_request"
STARSHIP_ACTIONRUN_EVENT=$(echo "$STARSHIP_ACTIONRUNS_JSON" | jq -r '[.workflow_runs[] | select(.status == "completed") | select(.conclusion == "success")][0] | "\(.event)"')

STARSHIP_VERSION=""
if [ ! -z "$STARSHIP_ACTIONRUN_EVENT" ] && [ "$STARSHIP_ACTIONRUN_EVENT" != "pull_request" ]; then
    STARSHIP_VERSION=$(echo "$STARSHIP_ACTIONRUNS_JSON" | jq -r "[.workflow_runs[] | select(.status == \"completed\") | select(.conclusion == \"success\")][0] | \"starship-${DOWNLOAD_ARCH}-linux-\\(.created_at|fromdate|strflocaltime(\"%Y-%m-%d\"))-${DOWNLOAD_BRANCH}-\\(.run_number)-\\(.head_sha[:7])\"")
else
    echo -e "${RED}Error: latest action run type is not supported (${STARSHIP_ACTIONRUN_EVENT}). Please check and try again later.${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi

if [ -z "$STARSHIP_VERSION" ]; then
    echo -e "${RED}Error: unable to get the latest version.${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi

if [ $PERFORMING_UPDATE -eq 1 ] && [ -e "$GAME_VERSION_FILE" ] && [ "$STARSHIP_VERSION" == "$(cat "$GAME_VERSION_FILE")" ]; then
    echo -e "${GREEN}The latest version is already installed. Nothing to do.${NC}"
    #read -p "Press Enter to exit..."
    exit 0
fi

# fetch action run artifacts
STARSHIP_ACTIONRUN_HTML_URL=$(echo "$STARSHIP_ACTIONRUNS_JSON" | jq -r '[.workflow_runs[] | select(.status == "completed") | select(.conclusion == "success")][0] | "\(.html_url)"')
if [ -z "$STARSHIP_ACTIONRUN_HTML_URL" ]; then
    echo -e "${RED}Error: unable to get action run HTML link.${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi

STARSHIP_ACTIONRUN_ARTIFACTS_URL=$(echo "$STARSHIP_ACTIONRUNS_JSON" | jq -r '[.workflow_runs[] | select(.status == "completed") | select(.conclusion == "success")][0] | "\(.artifacts_url)"')
STARSHIP_ACTIONRUN_ARTIFACTS_JSON=$(curl -s "$STARSHIP_ACTIONRUN_ARTIFACTS_URL")

STARSHIP_ACTIONRUN_ARTIFACT_LINUX_ID=$(echo "$STARSHIP_ACTIONRUN_ARTIFACTS_JSON" | jq -r '.artifacts[] | select(.name == "Starship-linux") | .id')
if [ -z "$STARSHIP_ACTIONRUN_ARTIFACT_LINUX_ID" ]; then
    echo -e "${RED}Error: unable to get Linux binary artifact download ID.${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi

STARSHIP_ACTIONRUN_ARTIFACT_O2R_ID=$(echo "$STARSHIP_ACTIONRUN_ARTIFACTS_JSON" | jq -r '.artifacts[] | select(.name == "starship.o2r") | .id')
if [ -z "$STARSHIP_ACTIONRUN_ARTIFACT_O2R_ID" ]; then
    echo -e "${RED}Error: unable to get O2R artifact download ID.${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi

STARSHIP_ACTIONRUN_ARTIFACT_LINUX_DOWNLOAD_URL="$STARSHIP_ACTIONRUN_HTML_URL/artifacts/$STARSHIP_ACTIONRUN_ARTIFACT_LINUX_ID"
#wget -nv "$STARSHIP_ACTIONRUN_ARTIFACT_LINUX_DOWNLOAD_URL" -O "$TEMP_BINARY_DOWNLOAD_FILE"
#if [ ! -f "$TEMP_BINARY_DOWNLOAD_FILE" ]; then
#    echo -e "${RED}Error: download failed, please check $TEMP_BINARY_DOWNLOAD_FILE${NC}"
#    #read -p "Press Enter to exit..."
#    exit 1
#fi

STARSHIP_ACTIONRUN_ARTIFACT_O2R_DOWNLOAD_URL="$STARSHIP_ACTIONRUN_HTML_URL/artifacts/$STARSHIP_ACTIONRUN_ARTIFACT_O2R_ID"
#wget -nv "$STARSHIP_ACTIONRUN_ARTIFACT_O2R_DOWNLOAD_URL" -O "$TEMP_O2R_DOWNLOAD_FILE"
#if [ ! -f "$TEMP_O2R_DOWNLOAD_FILE" ]; then
#    echo -e "${RED}Error: download failed, please check $TEMP_O2R_DOWNLOAD_FILE${NC}"
#    #read -p "Press Enter to exit..."
#    exit 1
#fi

# prompt user for manual downloads
echo -e "${BLUE}GitHub authentication is required to download artifacts directly.${NC}"
echo -e "${YELLOW}Please manually download the following files and place them in the \"${TEMP_DIR}\" folder.${NC}"
echo -e "Linux binary artifact: ${CYAN}$STARSHIP_ACTIONRUN_ARTIFACT_LINUX_DOWNLOAD_URL${NC}"
echo -e "O2R artifact: ${CYAN}$STARSHIP_ACTIONRUN_ARTIFACT_O2R_DOWNLOAD_URL${NC}"

mkdir -p "$TEMP_DIR"
rm -v "$TEMP_BINARY_DOWNLOAD_FILE" 2>/dev/null
rm -v "$TEMP_O2R_DOWNLOAD_FILE" 2>/dev/null
while true; do
    # check if Linux binary artifact is downloaded
    if [ ! -f "$TEMP_BINARY_DOWNLOAD_FILE" ]; then
        echo -e "${RED}Linux binary artifact not found at \"${NC}${CYAN}$TEMP_BINARY_DOWNLOAD_FILE${NC}${RED}\".${NC}"
        echo -e "Please download it from: ${CYAN}$STARSHIP_ACTIONRUN_ARTIFACT_LINUX_DOWNLOAD_URL${NC}"
    fi
    # check if O2R artifact is downloaded
    if [ ! -f "$TEMP_O2R_DOWNLOAD_FILE" ]; then
        echo -e "${RED}O2R artifact not found at \"${NC}${CYAN}$TEMP_O2R_DOWNLOAD_FILE${NC}${RED}\".${NC}"
        echo -e "Please download it from: ${CYAN}$STARSHIP_ACTIONRUN_ARTIFACT_O2R_DOWNLOAD_URL${NC}"
    fi
    # check if both files are present
    if [ -f "$TEMP_BINARY_DOWNLOAD_FILE" ] && [ -f "$TEMP_O2R_DOWNLOAD_FILE" ]; then
        echo -e "${GREEN}Both files have been downloaded successfully.${NC}"
        break
    fi
    # prompt the user for confirmation or exit
    read -p "Press Enter after placing the required files to appropriate folder, or type 'c'/'x' to exit: " USER_INPUT
    if [[ "$USER_INPUT" =~ ^[cCxX]$ ]]; then
        echo -e "${RED}Operation canceled by the user.${NC}"
        #read -p "Press Enter to exit..."
        exit 1
    fi
done

# unzip and process downloaded files
if [ ! -f "$TEMP_BINARY_DOWNLOAD_FILE" ] ; then
    echo -e "${RED}Linux binary artifact not found at \"$TEMP_BINARY_DOWNLOAD_FILE\".${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi
unzip -u -o -q "$TEMP_BINARY_DOWNLOAD_FILE" -d "$TEMP_DIR"
if [ ! -f "$TEMP_BINARY_FILE" ]; then
    echo -e "${RED}Game binary not found at \"$TEMP_BINARY_FILE\".${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi
rm -v "$TEMP_BINARY_DOWNLOAD_FILE"
mv -v "$TEMP_BINARY_FILE" "$GAME_BINARY_FILE" && chmod +x "$GAME_BINARY_FILE"
mv -v "$TEMP_GAMECONTROLLERDB_FILE" "$GAME_GAMECONTROLLERDB_FILE"
if [ ! -f "$TEMP_O2R_DOWNLOAD_FILE" ]; then
    echo -e "${RED}O2R artifact not found at \"$TEMP_O2R_DOWNLOAD_FILE\".${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi
unzip -u -o -q "$TEMP_O2R_DOWNLOAD_FILE" -d "$TEMP_DIR" && mv -v "$TEMP_O2R_FILE" "$GAME_O2R_FILE" && rm -v "$TEMP_O2R_DOWNLOAD_FILE"
rm -fv "$GAME_OTR_FILE_OLD" # remove old starship.otr file

echo -e "${GREEN}Download was successful.${NC}"

echo "Generating O2R from ROM file..."

# ROM handling
mkdir -p "$GAME_ROM_DIR"
while true; do
    GAME_ROM_Z64_FILE=$(ls "$GAME_ROM_DIR"/*.z64 2>/dev/null | head -n 1)
    if [ -z "$GAME_ROM_Z64_FILE" ]; then
        echo -e "${YELLOW}No .z64 files found in \"$GAME_ROM_DIR\".${NC}"
        echo -e "Please place the ROM file in \"${CYAN}$GAME_ROM_DIR${NC}\"."
        read -p "Press Enter to continue, or type 'c'/'x' to exit: " USER_INPUT
        if [[ "$USER_INPUT" =~ ^[cCxX]$ ]]; then
            echo -e "${RED}Operation canceled by the user.${NC}"
            #read -p "Press Enter to exit..."
            exit 1
        fi
        continue
    fi
    GAME_ROM_Z64_SHA1=$(sha1sum "$GAME_ROM_Z64_FILE" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
    if [ "$GAME_ROM_Z64_SHA1" != "$GAME_ROM_Z64_EXPECTED_SHA1" ]; then
        echo -e "${RED}ROM file SHA-1 does not match the expected value.${NC}"
        echo -e "${YELLOW}Expected: $GAME_ROM_Z64_EXPECTED_SHA1${NC}"
        echo -e "${RED}Found: $GAME_ROM_Z64_SHA1${NC}"
        read -p "Replace the file and try again, or type 'c'/'x' to exit: " USER_INPUT
        if [[ "$USER_INPUT" =~ ^[cCxX]$ ]]; then
            echo -e "${RED}Operation canceled by the user.${NC}"
            #read -p "Press Enter to exit..."
            exit 1
        fi
        continue
    fi
    echo -e "${GREEN}ROM file verified successfully. SHA-1 matches.${NC}"
    break
done

# Starship GitHub sources (not used any longer)
if [[ -d "$GAME_SOURCES_DIR" ]]; then
    echo -e "The folder \"${CYAN}$GAME_SOURCES_DIR${NC}\" is no longer used or needed."
    read -p "Would you like to delete it? (y/n): " USER_INPUT
    if [[ "$USER_INPUT" =~ ^[yY]$ ]]; then
        rm -rf "$GAME_SOURCES_DIR"
        echo -e "${YELLOW}Folder \"${CYAN}$GAME_SOURCES_DIR${NC}\" has been deleted.${NC}"
    else
        echo -e "${YELLOW}Folder \"${CYAN}$GAME_SOURCES_DIR${NC}\" was not deleted.${NC}"
    fi
fi
# mkdir -p "$GAME_SOURCES_DIR"
# if [ -d "$GAME_SOURCES_DIR/.git" ]; then
#     echo -e "${YELLOW}Repository already exists. Ensuring it's up-to-date...${NC}"
#     (
#         cd "$GAME_SOURCES_DIR" || { echo -e "${RED}Failed to change directory to $GAME_SOURCES_DIR${NC}"; exit 1; }
#         git fetch origin
#         git reset --hard origin/${DOWNLOAD_BRANCH}
#         echo -e "${GREEN}Repository reset to the latest commit.${NC}"
#     )
# else
#     echo -e "${BLUE}Cloning repository...${NC}"
#     git clone https://github.com/HarbourMasters/Starship.git "$GAME_SOURCES_DIR"
#     echo -e "${GREEN}Cloned GitHub repository to $GAME_SOURCES_DIR.${NC}"
# fi

# torch - generate O2R
rm -rfv "$GAME_GENERATEOTR_DIR_OLD" # remove old generate-otr directory
mkdir -p "$GAME_GENERATEO2R_DIR"
GAME_GENERATEO2R_ROM_Z64_FILE="$GAME_GENERATEO2R_DIR/$(basename "$GAME_ROM_Z64_FILE")"

# copy the verified ROM file to the generate-o2r directory
cp -v "$GAME_ROM_Z64_FILE" "$GAME_GENERATEO2R_ROM_Z64_FILE"

# download the latest torch binary
wget -nv https://github.com/HarbourMasters/Torch/releases/latest/download/torch -O "$GAME_GENERATEO2R_DIR/torch-latest"
chmod +x "$GAME_GENERATEO2R_DIR/torch-latest"
echo -e "${GREEN}Downloaded latest TORCH to $GAME_GENERATEO2R_DIR/torch-latest.${NC}"

# copy configuration, assets and include files required for torch
if [ -f "$TEMP_DIR_CONFIG_FILE" ]; then
    rm -rfv "$GAME_GENERATEO2R_DIR/config.yml"
    mv "$TEMP_DIR_CONFIG_FILE" "$GAME_GENERATEO2R_DIR"
    echo -e "${GREEN}Moved \"config.yml\" to $GAME_GENERATEO2R_DIR.${NC}"
else
    echo -e "${RED}Error: $TEMP_DIR_CONFIG_FILE not found!${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi
if [ -d "$TEMP_DIR_ASSETS_DIR" ]; then
    rm -rfv "$GAME_GENERATEO2R_DIR/assets"
    mv "$TEMP_DIR_ASSETS_DIR" "$GAME_GENERATEO2R_DIR"
    echo -e "${GREEN}Moved \"assets\" folder to $GAME_GENERATEO2R_DIR.${NC}"
else
    echo -e "${RED}Error: $TEMP_DIR_ASSETS_DIR not found!${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi
rm -rfv "$GAME_GENERATEO2R_DIR/include"
# if [ -d "$GAME_SOURCES_INCLUDE_DIR" ]; then
#     rm -rfv "$GAME_GENERATEO2R_DIR/include"
#     cp -r "$GAME_SOURCES_INCLUDE_DIR" "$GAME_GENERATEO2R_DIR"
#     echo -e "${GREEN}Copied \"include\" folder to $GAME_GENERATEO2R_DIR.${NC}"
# else
#     echo -e "${RED}Error: $GAME_SOURCES_INCLUDE_DIR not found!${NC}"
#     #read -p "Press Enter to exit..."
#     exit 1
# fi

# execute torch to generate O2R file
echo -e "${YELLOW}Executing \"${NC}${CYAN}$GAME_GENERATEO2R_DIR/torch-latest o2r $GAME_GENERATEO2R_ROM_Z64_FILE${NC}${YELLOW}\" to generate ROM O2R...${NC}"
(
    cd "$GAME_GENERATEO2R_DIR" || { echo -e "${RED}Error: Failed to change directory to $GAME_GENERATEO2R_DIR${NC}"; exit 1; }
    ./torch-latest o2r "$GAME_GENERATEO2R_ROM_Z64_FILE" >/dev/null
)
if [ $? -ne 0 ]; then
    rm -rfv "$GAME_GENERATEO2R_ROM_Z64_FILE"
    echo -e "${RED}Error: torch-latest failed to execute.${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi

# check if torch successfully generated O2R file
if [ -f "$GAME_GENERATEO2R_ROM_O2R_FILE" ]; then
    echo -e "${GREEN}torch-latest executed successfully. Copying generated O2R...${NC}"
    mv -v "$GAME_GENERATEO2R_ROM_O2R_FILE" "$GAME_ROM_O2R_FILE"
    rm -rfv "$GAME_GENERATEO2R_ROM_Z64_FILE"
    rm -rfv "$GAME_ROM_OTR_FILE_OLD" # remove old sf64.otr file
else
    rm -rfv "$GAME_GENERATEO2R_ROM_Z64_FILE"
    echo -e "${RED}Error: torch failed to generate O2R file.${NC}"
    #read -p "Press Enter to exit..."
    exit 1
fi

# save the current starship version
echo "$STARSHIP_VERSION" > "$GAME_VERSION_FILE"

# done
echo -e "${GREEN}Everything done.${NC}"

# final Instructions
echo -e "${CYAN}Installation complete!${NC}"

echo -e "\n${YELLOW}Follow these steps to set up and run the game from Steam:${NC}"
echo -e "\n1. Add \"${CYAN}$GAME_BINARY_FILE${NC}\" to ${CYAN}Steam${NC}."
echo -e "   - Use the ${CYAN}SteamGridDB Decky plugin${NC} to set the artwork, or set it manually."
echo -e "\n2. In ${CYAN}Steam Input${NC} for the newly added game, set the layout to:"
echo -e "   \"${BLUE}Gamepad with Mouse Trackpad${NC}\"."
echo -e "   - Edit the layout and set the ${CYAN}right trackpad click${NC} to ${CYAN}left mouse click${NC}."
echo -e "\n3. Configure additional buttons in the layout (optional):"
echo -e "   - Assign \"${CYAN}Select/View${NC}\" to keyboard key ${CYAN}F1${NC} using a ${CYAN}long press activation${NC}."
echo -e "   - Alternatively, use one of the rear buttons for the ${CYAN}F1 key${NC}."
echo -e "   - Assign ${CYAN}F11${NC} to a back key for full-screen mode toggle."
echo -e "\n4. Run the game for the first time to configure the graphic settings:"
echo -e "   - Use the ${CYAN}F1${NC} action button (configured earlier) to open the ${CYAN}Enhancements Menu${NC}."
echo -e "   - In the ${CYAN}Graphics${NC} section:"
echo -e "     - Set ${CYAN}FPS${NC} to ${CYAN}30${NC} (Linux build currently crashes with higher FPS)."
echo -e "     - Set ${CYAN}MSAA${NC} to ${CYAN}2x${NC} or ${CYAN}4x${NC}."
echo -e "   - In ${CYAN}Graphics/Resolution Editor${NC}:"
echo -e "     - Enable ${CYAN}Advanced settings${NC}."
echo -e "     - Enable ${CYAN}Set fixed vertical resolution${NC} and set it to ${CYAN}800${NC}."
echo -e "     - Set ${CYAN}Force aspect ratio${NC} to ${CYAN}16:10 (8:5)${NC}."
echo -e "\n${GREEN}You're all set! Enjoy the game!${NC}"
