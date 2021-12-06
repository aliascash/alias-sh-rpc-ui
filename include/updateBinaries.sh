#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# Author: 2019 HLXEasy
#
# ============================================================================

choosenVersionFile=/tmp/choosenVersion-$$.txt

# ----------------------------------------------------------------------------
# Current aarch64 Raspberry Pi OS has ID=debian on /etc/os-release
# So check if we're really on a Raspi or not
handleRaspiAarch64() {
    if [ "$(uname -m)" = aarch64 ] ; then
        archiveName="RaspberryPi-Buster"
    fi
}

determineDistribution() {
    # ----------------------------------------------------------------------------
    # Determining current operating system (distribution)
    if [[ -e /etc/os-release ]] ; then
        . /etc/os-release
    else
        echo "File /etc/os-release not found, not updating anything"
        exit 1
    fi

    archiveName=''
    case ${ID} in
        "debian")
            case ${VERSION_ID} in
                "9")
                    archiveName='Debian-Stretch'
                    handleRaspiAarch64
                    ;;
                "10")
                    archiveName='Debian-Buster'
                    handleRaspiAarch64
                    ;;
                *)
                    case ${PRETTY_NAME} in
                        *"bullseye"*)
                            archiveName='Debian-Buster'
                            handleRaspiAarch64
                            ;;
                        *)
                            cat /etc/os-release
                            exit 1
                            ;;
                    esac
                    ;;
            esac
            ;;
        "ubuntu")
            usedDistro="ubuntu"
            case ${VERSION_CODENAME} in
                "bionic"|"cosmic")
                    archiveName='Ubuntu-18-04'
                    ;;
                "focal")
                    archiveName='Ubuntu-20-04'
                    ;;
                *)
                    echo "Unsupported operating system ID=${ID}, VERSION_ID=${VERSION_CODENAME}"
                    exit
                    ;;
            esac
            ;;
        "centos")
            usedDistro="CentOS"
            ;;
        "fedora")
            usedDistro="Fedora"
            ;;
        "opensuse-leap")
            usedDistro="OpenSUSE-Tumbleweed"
            ;;
        "raspbian")
            usedDistro="raspberry"
            case ${VERSION_ID} in
                "9")
                    archiveName='RaspberryPi-Stretch'
                    ;;
                "10")
                    archiveName='RaspberryPi-Buster'
                    ;;
                *)
                    case ${PRETTY_NAME} in
                        *"bullseye"*)
                            archiveName='RaspberryPi-Buster'
                            ;;
                        *)
                            cat /etc/os-release
                            exit 1
                            ;;
                    esac
                    ;;
            esac
            ;;
        *)
            echo "Unsupported operating system ${ID}, VERSION_ID=${VERSION_ID}"
            exit
            ;;
    esac
}

# ============================================================================
# Goal: Just a simple info box to show the update was canceled
updateCanceled(){
    dialog \
        --backtitle "${TITLE_BACK}" \
        --no-shadow \
        --title "${TITLE_UPDATE_BINARIES}" \
        --msgbox "\n${TEXT_UPDATE_CANCELED}" 9 40
}

# ============================================================================
# Goal: Update Aliaswallet binaries
# - Clear the screen
# - Stop Aliaswallet daemon using sudo
# - Download the main installation script using curl and excute it
performUpdate(){
    reset
    info "Stopping aliaswalletd"
    sudo systemctl stop aliaswalletd
    echo ''
    if [[ -n "${choosenVersion}" ]] ; then
        info "Updating to version ${choosenVersion}"
    fi
    info "Downloading and starting update script"
    curl ${cacertParam} -L -s https://raw.githubusercontent.com/aliascash/installer/master/linux/updateAliaswallet.sh | sudo bash -s "${choosenVersion}"
    info "Update finished, press return to restart aliaswalletd"
    read a
}

# ============================================================================
# Goal: Update Aliaswallet binaries
# - Determine list of available versions
# - Open dialog window with radio list of these versions
# - Loop here if nothing was selected
# - Put selected version into ${choosenVersion}
# - Start update
chooseVersionToInstall() {
    local showReleaseVersions=$1
    local negateResult=''

    determineDistribution

    if ${showReleaseVersions} ; then
        negateResult='| not'
    fi
    rm -f ${choosenVersionFile}

    # Exactly three parameters are required per entry on the dialog radiolist.
    # Result of curl-jq-query are three lines per release like this example:
    #
    # Alias-4.4.0-f1d56b63-Debian-Buster.tgz
    # 2021-08-25T20:56:13Z
    # Bot
    #
    # - From the 1st field the version is extracted
    # - From the 2nd field the date is extracted
    # - 3rd field is just a dummy to fill the 3rd argument for each
    #   parameter tripple of the dialog radiolist
    dialog \
        --backtitle "${TITLE_BACK}" \
        --colors \
        --no-shadow \
        --title "${TITLE_AVAILABLE_VERSIONS}" \
        --radiolist "\n${TEXT_UPDATE_CHOOSE_VERSION_HINT}" 17 50 10 \
            $(while read currentEntry ; do 
                case ${currentEntry} in
                    Bot|User)
                        # Dummy output as empty first column
                        echo "Bot"
                        ;;
                    Alias*)
                        # Output version
                        currentEntry=${currentEntry#*-}
                        echo ${currentEntry%%-*}
                        ;;
                    *)
                        # Output date
                        echo ${currentEntry%%T*}
                        ;;
                esac
            done < <(curl ${cacertParam} -L -s https://api.github.com/repos/aliascash/alias-wallet/releases |
                        jq -r ".[].assets[] | select(.name | contains(\"${archiveName}\")) | select(.name | contains(\"tgz\")) | select(.name | contains(\"Build\") ${negateResult}) | .name, .updated_at, .uploader.type")
                    ) 2>${choosenVersionFile}
    if [[ $? = ${DIALOG_OK} ]] ; then
        if [[ -f ${choosenVersionFile} ]] ; then
            choosenVersion=$(cat ${choosenVersionFile})
            rm -f ${choosenVersionFile}
            if [[ -z "${choosenVersion}" ]] ; then
                chooseVersionToInstall
            else
                performUpdate
            fi
        else
            chooseVersionToInstall
        fi
    else
        updateCanceled
    fi
}

# ============================================================================
# Goal: Main update dialog
# - Ask how to update:
# -- Update to latest release
# -- Or choose version to install
# - Start update
updateBinaries() {
    dialog \
        --backtitle "${TITLE_BACK}" \
        --colors \
        --no-shadow \
        --title "${TITLE_UPDATE_BINARIES}" \
        --ok-label "${BUTTON_LABEL_UPDATE_TO_LATEST_RELEASE}" \
        --cancel-label "${BUTTON_LABEL_UPDATE_CHOOSE_VERSION}" \
        --extra-button --extra-label "${BUTTON_LABEL_MAIN_MENU}" \
        --default-button "extra" \
        --yesno "\n${TEXT_QUESTION_DO_UPDATE}" 8 64

    # Get exit status
    # 0 means user hit [yes] button.
    # 1 means user hit [no] button.
    # 255 means user hit [Esc] key.
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_EXTRA})
            updateCanceled
            ;;
        ${DIALOG_CANCEL})
            chooseVersionToInstall false
            ;;
        ${DIALOG_OK})
            chooseVersionToInstall true
            ;;
    esac
    refreshMainMenu_DATA
}
