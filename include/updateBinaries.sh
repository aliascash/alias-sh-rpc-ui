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
    rm -f ${choosenVersionFile}
    # Exactly three parameters are required per entry on the dialog radiolist.
    # Result of curl-grep-cut-cut are three lines per release like this example:
    #
    # Build144
    # 2019-03-31T15
    # https
    #
    # - From the 2nd field only the first 10 chars where used
    # - 3rd field is just a dummy to fill the 3rd argument for each
    #   parameter tripple of the dialog radiolist
    # - "v*" is searched to break the for loop at this point, as here
    #   the old, unsupported Aliaswallet versions begin.
    dialog \
        --backtitle "${TITLE_BACK}" \
        --colors \
        --no-shadow \
        --title "${TITLE_AVAILABLE_VERSIONS}" \
        --radiolist "\n${TEXT_UPDATE_CHOOSE_VERSION_HINT}" 17 50 10 \
            $(for i in $(curl ${cacertParam} -L -s https://api.github.com/repos/aliascash/alias/releases |
                            grep -e tag_name -e published_at -e tarball_url |
                            cut -d: -f2 |
                            cut -d '"' -f2) ; do
                if [[ ${i} == v* ]] ; then break ; fi
                echo "${i:0:10}" ;
            done ) 2>${choosenVersionFile}
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
            chooseVersionToInstall
            ;;
        ${DIALOG_OK})
            performUpdate
            ;;
    esac
    refreshMainMenu_DATA
}
