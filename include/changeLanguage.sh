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


# ============================================================================
# Goal:
changeLanguage() {
    i=1 #Index counter
    exec 3>&1
    # The for loop on the dialog parameters produces separate words and so
    # separate arguments for dialog. That's expected behviour, so ShellCheck
    # warning SC2046 must be disabled.
    # shellcheck disable=SC2046
    CHOICE=$(dialog --backtitle "${TITLE_BACK}" \
                    --colors \
                    --no-shadow \
                    --title "${TITLE_LANGUAGE_SELECTION}" \
                    --menu "${TEXT_CHOOSE_LANGUAGE}" \
                    15 40 11 \
                    $(for currentLanguage in include/ui_content_*.sh ; do
                            currentLanguage=${currentLanguage##*_}
                            echo "${currentLanguage%%.*}" ${i}
                            ((i++))
                        done) \
                    2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    # Get exit status
    # 0 means user hit [yes] button.
    # 1 means user hit [no] button.
    # 255 means user hit [Esc] key.
    case ${exit_status} in
        0)
#            entryPositionInList=$(echo "${CHOICE}*2" | bc -l)
#            UI_LANGUAGE=${languageArray[${entryPositionInList}]}
            UI_LANGUAGE=${CHOICE}
            updateSettings
            . include/ui_content_${UI_LANGUAGE}.sh
            ;;
        *)
            dialog --backtitle "${TITLE_BACK}" \
                --title "${TITLE_LANGUAGE_SELECTION}" \
                --msgbox "\n${TEXT_CHOOSE_LANGUAGE_CANCELED}" 6 40
            ;;
    esac
    refreshMainMenu_DATA
}
