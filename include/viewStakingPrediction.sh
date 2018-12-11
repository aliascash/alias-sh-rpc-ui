#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# Author: 2018 HLXEasy
#
# ============================================================================


# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $1 - start (optional - default "0")
#        $2 - if "true" stakes will be displayed (optional - default "true")
viewStakingPrediction() {
    local _start
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
    if [[ ${#transactions_global[@]} -eq 0 ]] && [[ ${_start} -ge ${COUNT_TRANS_VIEW} ]]; then
        viewAllTransactions "$(( ${_start} - ${COUNT_TRANS_VIEW} ))" \
                           "${_displayStakes}"
    fi
    local _page=$(( (${_start} / ${COUNT_TRANS_VIEW}) + 1 ))
    dialog --no-shadow \
        --begin 0 0 \
        --no-lines \
        --infobox "" "${currentTPutLines}" "${currentTPutCols}" \
        \
        --and-widget \
        --colors \
        --extra-button \
        --help-button \
        --title "${TITLE_VIEW_TRANSACTIONS} ${_page}" \
        --ok-label "${_prevButton}" \
        --extra-label "${_nextButton}" \
        --help-label "${_mainMenuButton}" \
        --cancel-label "${_displayStakesButton}" \
        --default-button 'extra' \
        --yesno "$(makeOutputTransactions $(( ${SIZE_X_TRANS_VIEW} - 4 )))" "${SIZE_Y_TRANS_VIEW}" "${SIZE_X_TRANS_VIEW}"
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_ESC})
            refreshMainMenu_DATA;;
        ${DIALOG_OK})
            if [[ ${_start} -ge ${COUNT_TRANS_VIEW} ]]; then
                viewAllTransactions $(( ${_start} - ${COUNT_TRANS_VIEW} )) \
                                   "${_displayStakes}"
            else
                viewAllTransactions "0" \
                                    "${_displayStakes}"
            fi;;
        ${DIALOG_EXTRA})
            viewAllTransactions $(( ${_start} + ${COUNT_TRANS_VIEW} )) \
                               "${_displayStakes}";;
        ${DIALOG_CANCEL})
            if [[ "${_displayStakes}" = "true" ]]; then
            viewAllTransactions "0" \
                                "false"
            else
            viewAllTransactions "0" \
                                "true"
            fi;;
        ${DIALOG_HELP})
            refreshMainMenu_DATA;;
    esac
    errorHandling "${ERROR_TRANS_FATAL}" \
                  1
}
