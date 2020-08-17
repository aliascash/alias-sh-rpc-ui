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
# Ask user in which direction he wants to convert coins.
# Return:
# ${CONVERT_NOTHING} .. Nothing should be converted, back to main manu
# ${CONVERT_ANON_TO_PUBLIC} .. Convert anon coins to public coins
# ${CONVERT_PUBLIC_TO_ANON} .. Convert public coins to anon coins
getConversionDestination() {
    calculateLayout
    dialog \
        --backtitle "${TITLE_BACK}" \
        --colors \
        --no-shadow \
        --title "${TITLE_PLEASE_CHOOSE}" \
        --ok-label "${BUTTON_LABEL_PUBLIC_TO_ANON}" \
        --cancel-label "${BUTTON_LABEL_ANON_TO_PUBLIC}" \
        --extra-button --extra-label "${BUTTON_LABEL_MAIN_MENU}" \
        --default-button "extra" \
        --yesno "${TEXT_CONVERSION_QUESTION}" 7 60
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_EXTRA})
            return ${CONVERT_NOTHING};;
        ${DIALOG_CANCEL})
            return ${CONVERT_ANON_TO_PUBLIC};;
        ${DIALOG_OK})
            return ${CONVERT_PUBLIC_TO_ANON};;
    esac
}

# ============================================================================
# Ask user for coin conversion direction, amount and narration
# and convert the given amount.
convertCoins() {
    local _destinationAddress=''
    local _buffer=''
    local _narration=''
    local _balance=0
    local _convertDialogTitle=''
    local _headline=''
    local _conversionCmd=''
    local _ringSizeParam=''

    executeCURL "listprivateaddresses"
    curl_result_global=${curl_result_global//','/'\n'}
    curl_result_global=${curl_result_global//'['/''}
    _destinationAddress=$(echo ${curl_result_global} | sed -e 's/.*Stealth Address://g' -e 's/ -.*//g')

    getConversionDestination
    case $? in
        ${CONVERT_NOTHING})
            refreshMainMenu_GUI;;
        ${CONVERT_PUBLIC_TO_ANON})
            _convertDialogTitle="${TITLE_CONVERT}: ${TEXT_CURRENCY} > ${TEXT_CURRENCY_ANON}"
            _conversionCmd="sendpublictoprivate"
            _balance=$(echo "scale=8 ; ${info_global[${WALLET_BALANCE}]}+${info_global[${WALLET_STAKE}]}" | bc)
            if [[ ${_balance} == '.'* ]]; then
                _balance="0"${_balance}
            fi
            _headline="${TEXT_BALANCE}: ${_balance} ${TEXT_CURRENCY}"
            ;;
        ${CONVERT_ANON_TO_PUBLIC})
            _convertDialogTitle="${TITLE_CONVERT}: ${TEXT_CURRENCY_ANON} > ${TEXT_CURRENCY}"
            _conversionCmd="sendprivatetopublic"
            _balance=$(echo "scale=8 ; ${info_global[${WALLET_BALANCE_ANON}]}+${info_global[${WALLET_STAKE_ANON}]}" | bc)
            if [[ ${_balance} == '.'* ]]; then
                _balance="0"${_balance}
            fi
            _headline="${TEXT_BALANCE}: ${_balance} ${TEXT_CURRENCY_ANON}"
            _ringSizeParam=',10'
            ;;
    esac

    exec 3>&1
    oldIFS=${IFS}
    IFS="|"
    _buffer=$(dialog --backtitle "${TITLE_BACK}" \
        --ok-label "${BUTTON_LABEL_SEND}" \
        --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
        --no-shadow \
        --colors \
        --title "${_convertDialogTitle}" \
        --form "${_headline}" 12 65 0 \
        "${TEXT_AMOUNT_TO_CONVERT}:" 2 2 "${_amount}" 2 29 24 0 \
        "${TEXT_SEND_NARRATION}:" 4 2 "${_narration}" 4 29 24 0 \
        " " 5 1 "" 5 0 0 0\
        2>&1 1>&3)
    exit_status=$?
    IFS=${oldIFS}
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            refreshMainMenu_GUI;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI;;
        ${DIALOG_OK})
            # Convert buffer into array
            # $sendInput[0] = Amount
            # $sendInput[1] = Narration
            mapfile -t sendInput <<< "${_buffer}"
            if [[ ${sendInput[0]} =~ ^[0-9]{0,8}[.]{0,1}[0-9]{0,8}$ ]] && [[ 1 -eq "$(echo "${sendInput[0]} > 0" | bc)" ]]; then
                if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" == "${TEXT_WALLET_IS_UNLOCKED}" ]]; then
                    # If wallet is unlocked, we have to look it first
                    executeCURL "walletlock"
                fi
                if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" != "${TEXT_WALLET_HAS_NO_PW}" ]]; then
                    passwordDialog "60" "false"
                fi
                if [[ -z "${sendInput[1]}" ]] ; then
                    # No narration given
                    executeCURL "${_conversionCmd}" "\"${_destinationAddress}\",${sendInput[0]}${_ringSizeParam}"
                else
                    executeCURL "${_conversionCmd}" "\"${_destinationAddress}\",${sendInput[0]}${_ringSizeParam},\"${sendInput[1]}\""
                fi
                if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" != "${TEXT_WALLET_HAS_NO_PW}" ]]; then
                    executeCURL "walletlock"
                fi
                if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" == "${TEXT_WALLET_IS_UNLOCKED}" ]]; then
                    simpleMsg "" \
                              "${TEXT_SEND_UNLOCK_WALLET_AGAIN}" \
                              "${BUTTON_LABEL_I_HAVE_UNDERSTOOD}"
                    unlockWalletForStaking
                fi
                refreshMainMenu_DATA
            else
                errorHandling "${ERROR_SEND_INVALID_AMOUNT}"
                convertCoins
            fi
            ;;
    esac
    errorHandling "${ERROR_CONVERT_FATAL}" \
                  1
}
