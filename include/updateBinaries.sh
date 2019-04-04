#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# Author: 2019 HLXEasy
#
# ============================================================================


chooseVersionToInstall() {
    dialog \
        --backtitle "${TITLE_BACK}" \
        --colors \
        --no-shadow \
        --title title \
        --radiolist Text 23 50 10 $(for i in $(curl -L -s https://api.github.com/repos/spectrecoin/spectre/releases | grep -e tag_name -e published_at -e tarball_url | cut -d: -f2 | cut -d '"' -f2) ; do echo "${i:0:10}" ; done ) 2>/tmp/choice.txt
}

# ============================================================================
# Goal:
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
        --yesno "${TEXT_QUESTION_DO_UPDATE}" 9 40

    # Get exit status
    # 0 means user hit [yes] button.
    # 1 means user hit [no] button.
    # 255 means user hit [Esc] key.
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_EXTRA})
            dialog \
                --backtitle "${TITLE_BACK}" \
                --title "${TITLE_UPDATE_BINARIES}" \
                --msgbox "\n${TEXT_UPDATE_CANCELED}" 9 40
            ;;
        ${DIALOG_CANCEL})
            chooseVersionToInstall
            ;;
        ${DIALOG_OK})
            reset
            info "Stopping spectrecoind"
            sudo systemctl stop spectrecoind
            echo ''
            info "Downloading and starting update script"
            curl -L -s https://raw.githubusercontent.com/spectrecoin/installer/master/linux/updateSpectrecoin.sh | sudo bash -s
            info "Update finished, press return to restart spectrecoind"
            read a
            ;;
    esac
    refreshMainMenu_DATA
}
