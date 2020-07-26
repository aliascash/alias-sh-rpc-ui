#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
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
    declare -A languageArray
    i=1 #Index counter for adding to array
    j=1 #Option menu value generator
    for currentLanguage in $(ls -1 include/ui_content_*.sh) ; do
        #Dynamic dialogs require an array that has a staggered structure
        #array[1]=1
        #array[2]=First_Menu_Option
        #array[3]=2
        #array[4]=Second_Menu_Option
        currentLanguage=${currentLanguage##*_}
        currentLanguage=${currentLanguage%%.*}
        languageArray[${i}]=${j}
        ((i++))
        languageArray[${i}]=${currentLanguage}
        ((i++))
        ((j++))
    done

    # Uncomment for debug
    #printf '%s\n' "${languageArray[@]}"
    #read -rsp "Press any key to continue..." -n1 key

    exec 3>&1
    CHOICE=$(dialog --backtitle "${TITLE_BACK}" \
                    --colors \
                    --no-shadow \
                    --title "${TITLE_LANGUAGE_SELECTION}" \
                    --menu "${TEXT_CHOOSE_LANGUAGE}" \
                    10 40 6 \
                    "${languageArray[@]}" \
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
