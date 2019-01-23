#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# Author: 2019 HLXEasy
#
# ============================================================================


# ============================================================================
# Goal:
updateBinaries() {
    dialog --backtitle "${TITLE_BACK}" \
        --title "${TITLE_UPDATE_BINARIES}" \
        --yesno "\n${TEXT_QUESTION_DO_UPDATE}" 7 40

    # Get exit status
    # 0 means user hit [yes] button.
    # 1 means user hit [no] button.
    # 255 means user hit [Esc] key.
    exit_status=$?
    case ${exit_status} in
        0)
            reset
            info "Stopping spectrecoind"
            sudo systemctl stop spectrecoind
            echo ''
            info "Downloading and starting update script"
            sudo bash <(curl -s https://raw.githubusercontent.com/spectrecoin/installer/simpleUpdater/linux/updateSpectrecoin.sh)
            info "Update finished, press return to restart spectrecoind"
            read a
            ;;
        *)
            dialog --backtitle "${TITLE_BACK}" \
                --title "${TITLE_UPDATE_BINARIES}" \
                --msgbox "\n${TEXT_UPDATE_CANCELED}" 6 20
            ;;
    esac
    refreshMainMenu_DATA
}
