#!/bin/bash

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $1 - start (optional - default "0")
#        $2 - if "true" stakes will be displayed (optional - default "true")
makeWalletInfoOutput() {
    local _textWidth
    if [[ -z "$1" ]]; then
        _textWidth="${TEXTWIDTH_INFO}"
    else
        _textWidth="$1"
    fi
    if [[ ${TEXTHIGHT_INFO} -ge 13 ]] ; then
        echo "${TEXT_HEADLINE_WALLET_INFO}\n"
    fi
    local _balance=$(echo "scale=8 ; ${info_global[${WALLET_BALANCE_XSPEC}]}+${info_global[${WALLET_STAKE}]}" | bc)
    if [[ ${_balance} == '.'* ]]; then
        _balance="0"${_balance}
    fi
    echo $(fillLine "${TEXT_BALANCE} ${TEXT_CURRENCY}:-_-${_balance}" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_BALANCE} ${TEXT_CURRENCY_2}:-_-\Z6${info_global[${WALLET_BALANCE_SPECTRE}]}\Zn" \
                    "${_textWidth}")"\n"
    #
    if [[ ${TEXTHIGHT_INFO} -ge 13 ]] ; then
        echo "\n${TEXT_HEADLINE_STAKING_INFO}\n"
    elif [[ ${TEXTHIGHT_INFO} -ge 10 ]] ; then
        echo "\n"
    fi
    echo $(fillLine "${TEXT_WALLET_STATE}: ${info_global[${WALLET_UNLOCKED_UNTIL}]}-_-${TEXT_STAKING_STATE}: ${stakinginfo_global[0]}" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_STAKING_COINS}: \Z4${info_global[${WALLET_BALANCE_XSPEC}]}\Zn-_-(\Z5${info_global[${WALLET_STAKE}]}\Zn ${TEXT_MATRUING_COINS})" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_EXP_TIME}: ${stakinginfo_global[1]}" \
                    "${_textWidth}")"\n"
    #
    if [[ ${TEXTHIGHT_INFO} -ge 13 ]] ; then
        echo "\n${TEXT_HEADLINE_CLIENT_INFO}\n"
    elif [[ ${TEXTHIGHT_INFO} -ge 10 ]] ; then
        echo "\n"
    fi
    echo $(fillLine "${TEXT_DAEMON_VERSION}: ${info_global[${WALLET_VERSION}]}-_-${TEXT_DAEMON_ERRORS_DURING_RUNTIME}: ${info_global[${WALLET_ERRORS}]}" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_DAEMON_IP}: ${info_global[${WALLET_IP}]}-_-${TEXT_DAEMON_PEERS}: ${info_global[${WALLET_CONNECTIONS}]}" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_DAEMON_DOWNLOADED_DATA}: ${info_global[${WALLET_DATARECEIVED}]}-_-${TEXT_DAEMON_UPLOADED_DATA}: ${info_global[${WALLET_DATASENT}]}" \
                    "${_textWidth}")"\n"
}

viewWalletInfo() {
    _mainMenuButton="${BUTTON_LABEL_MAIN_MENU}"
    calculateLayout
    getInfo
    dialog --backtitle "${TITLE_BACK}" \
           --colors \
           --title "${TITLE_ERROR}" \
           --ok-label "${BUTTON_LABEL_OK}" \
           --no-shadow \
           --msgbox "$(makeWalletInfoOutput $(( ${SIZE_X_TRANS_VIEW} - 4 )))" "${SIZE_Y_TRANS_VIEW}" "${SIZE_X_TRANS_VIEW}"

    refreshMainMenu_DATA
}
