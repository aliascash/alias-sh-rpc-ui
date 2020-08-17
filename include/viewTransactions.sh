#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# Author: 2018 dave#0773@discord
#
# ============================================================================


# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $1 - start (optional - default "0")
#        $2 - if "true" stakes will be displayed (optional - default "true")
viewAllTransactions() {
    unset transactions
    declare -A transactions

    local _start
    local _focus='help'
    if [[ -z "$1" ]]; then
        _start="0"
    else
        _start="$1"
    fi
    local _displayStakes
    if [[ -z "$2" ]] || [[ "$2" = "true" ]]; then
        _displayStakes="true"
        _displayStakesButton="${BUTTON_LABEL_HIDE_STAKES}"
    else
        _displayStakes="false"
        _displayStakesButton="${BUTTON_LABEL_SHOW_STAKES}"
    fi
    if [[ -n "$3" ]] ; then
        _focus="${3}"
    fi
    _prevButton="${BUTTON_LABEL_PREVIOUS}"
    _nextButton="${BUTTON_LABEL_NEXT}"
    _mainMenuButton="${BUTTON_LABEL_MAIN_MENU}"
    calculateLayout
    if [[ ${SIZE_X_TRANS} == 0 ]]; then
        # shorten buttons
        _displayStakesButton=$(echo ${_displayStakesButton} | sed 's/\(.\{4\}\).*/\1/')
        _prevButton=$(echo ${_prevButton} | sed 's/\(.\{4\}\).*/\1/')
        _nextButton=$(echo ${_nextButton} | sed 's/\(.\{4\}\).*/\1/')
        _mainMenuButton=$(echo ${_mainMenuButton} | sed 's/\(.\{4\}\).*/\1/')
     fi
    if [[ "${_displayStakes}" = "true" ]]; then
        executeCURL "listtransactions" \
                    '"*",'"${COUNT_TRANS_VIEW},${_start}"',"1"'
    else
        executeCURL "listtransactions" \
                    '"*",'"${COUNT_TRANS_VIEW},${_start}"',"0"'
    fi
    getTransactions
    local _page=$(( (${_start} / ${COUNT_TRANS_VIEW}) + 1 ))

    if [[ ${_start} -le 0 ]] ; then
        # Disable "Previous" button on first page
        previousButton=""
        buttonTypeOK="yes"
        buttonTypeCancel="no"
    else
        previousButton="--extra-button --extra-label ${_prevButton}"
        buttonTypeOK="ok"
        buttonTypeCancel="cancel"
    fi
    if [[ ${currentAmountOfTransactions} -le 0 ]] ; then
        # Disable "Next" button if there are no more transactions
        nextButton=""
        _focus="extra"
    else
        nextButton="--help-button --help-label ${_nextButton}"
    fi

    dialog --no-shadow \
        --begin 0 0 \
        --no-lines \
        --infobox "" "${currentTPutLines}" "${currentTPutCols}" \
        \
        --and-widget \
        --colors \
        --title "${TITLE_VIEW_TRANSACTIONS} ${_page}" \
        --${buttonTypeOK}-label "${_mainMenuButton}" \
        --${buttonTypeCancel}-label "${_displayStakesButton}" \
        ${previousButton} \
        ${nextButton} \
        --default-button "${_focus}" \
        --yesno "$(makeOutputTransactions $(( ${SIZE_X_TRANS_VIEW} - 4 )))" "${SIZE_Y_TRANS_VIEW}" "${SIZE_X_TRANS_VIEW}"
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_ESC})
            refreshMainMenu_DATA;;
        ${DIALOG_EXTRA})
            if [[ ${_start} -ge ${COUNT_TRANS_VIEW} ]]; then
                viewAllTransactions $(( ${_start} - ${COUNT_TRANS_VIEW} )) "${_displayStakes}" "extra"
            else
                viewAllTransactions "0" "${_displayStakes}" "extra"
            fi;;
        ${DIALOG_HELP})
            viewAllTransactions $(( ${_start} + ${COUNT_TRANS_VIEW} )) "${_displayStakes}" "help";;
        ${DIALOG_CANCEL})
            if [[ "${_displayStakes}" = "true" ]]; then
                viewAllTransactions "0" "false" "help"
            else
                viewAllTransactions "0" "true" "help"
            fi;;
        ${DIALOG_OK})
            refreshMainMenu_DATA;;
    esac
    errorHandling "${ERROR_TRANS_FATAL}" 1
}
