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
# Ask user in which direction he wants to convert coins.
# Return:
# ${SEND_NOTHING} .. Nothing should be sent, back to main manu
# ${SEND_PUBLIC_COINS} .. Send public coins
# ${SEND_PRIVATE_COINS} .. Send anon coins
getCoinTypeToSend() {
    calculateLayout
    dialog \
        --backtitle "${TITLE_BACK}" \
        --colors \
        --no-shadow \
        --title "${TITLE_PLEASE_CHOOSE}" \
        --ok-label "${TEXT_CURRENCY}" \
        --cancel-label "${TEXT_CURRENCY_ANON}" \
        --extra-button --extra-label "${BUTTON_LABEL_MAIN_MENU}" \
        --default-button "extra" \
        --yesno "${TEXT_COIN_TYPE_TO_SEND_QUESTION}" 7 52
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_EXTRA})
            return ${SEND_NOTHING};;
        ${DIALOG_CANCEL})
            return ${SEND_PRIVATE_COINS};;
        ${DIALOG_OK})
            return ${SEND_PUBLIC_COINS};;
    esac
}

# ============================================================================
# Goal: Display form for the user to enter transaction details
#       Check if a valid address was entered
#       Check if a valid amount was entered
#
# Input $1 - address (important for address book functionality)
#
sendPublicCoins() {
    local _amount
    local _destinationAddress=$1
    local _buffer
    local _narration=''
    local _balance=$(echo "scale=8 ; ${info_global[${WALLET_BALANCE}]}+${info_global[${WALLET_STAKE}]}" | bc)
    if [[ ${_balance} == '.'* ]]; then
        _balance="0"${_balance}
    fi
    local _s="${TEXT_BALANCE}: ${_balance} ${TEXT_CURRENCY}\n"
          _s+="${TEXT_SEND_EXPL}\n"
          _s+="${TEXT_CLIPBOARD_HINT}"
    exec 3>&1
    oldIFS=${IFS}
    IFS="|"
    _buffer=$(dialog --backtitle "${TITLE_BACK}" \
        --ok-label "${BUTTON_LABEL_SEND}" \
        --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
        --extra-button \
        --extra-label "${BUTTON_LABEL_ADDRESS_BOOK}" \
        --no-shadow \
        --colors \
        --title "${TITLE_SEND}" \
        --form "${_s}" 16 70 0 \
        "${TEXT_SEND_DESTINATION_ADDRESS_EXPL}:" 2 2 "${_destinationAddress}" 2 26 35 0 \
        "${TEXT_SEND_AMOUNT_EXPL} ${TEXT_CURRENCY}:" 4 2 "${_amount}" 4 26 24 0 \
        "${TEXT_SEND_NARRATION}:" 6 2 "${_narration}" 6 26 24 0 \
        2>&1 1>&3)
    exit_status=$?
    IFS=${oldIFS}
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            refreshMainMenu_GUI;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI;;
        ${DIALOG_EXTRA})
            sry
            sendCoins "test1";;
        ${DIALOG_OK})
            # Convert buffer into array
            # $sendInput[0] = Destination address
            # $sendInput[1] = Amount
            # $sendInput[2] = Narration
            mapfile -t sendInput <<< "${_buffer}"

            if [[ ${info_global[${WALLET_TESTNET}]} = false ]] ; then
                # Check destination address
                if [[ ${sendInput[0]} =~ ^[S][a-km-zA-HJ-NP-Z1-9]{25,33}$ ]]; then
                    _destinationAddress="${sendInput[0]}"
                else
                    errorHandling "${ERROR_SEND_INVALID_ADDRESS}"
                    sendCoins
                fi
            else
                _destinationAddress="${sendInput[0]}"
            fi

            if [[ ${sendInput[1]} =~ ^[0-9]{0,8}[.]{0,1}[0-9]{0,8}$ ]] && [[ 1 -eq "$(echo "${sendInput[1]} > 0" | bc)" ]]; then
                _amount=${sendInput[1]}
                if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" == "${TEXT_WALLET_IS_UNLOCKED}" ]]; then
                    # iff wallet is unlocked, we have to look it first
                    executeCURL "walletlock"
                fi
                if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" != "${TEXT_WALLET_HAS_NO_PW}" ]]; then
                    passwordDialog "60" "false"
                fi
                if [[ -z "${sendInput[2]}" ]] ; then
                    # No narration given
                    executeCURL "sendtoaddress" "\"${_destinationAddress}\",${_amount}"
                else
                    executeCURL "sendtoaddress" "\"${_destinationAddress}\",${_amount},\"\",\"\",\"${sendInput[2]}\""
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
                sendCoins "${_destinationAddress}"
            fi
            sendCoins "${_destinationAddress}";;
    esac
    errorHandling "${ERROR_SEND_FATAL}" \
                  1
}
sendAnonCoins() {
    local _amount
    local _destinationAddress=$1
    local _buffer
    local _narration=''
    local _balance=$(echo "scale=8 ; ${info_global[${WALLET_BALANCE_ANON}]}+${info_global[${WALLET_STAKE_ANON}]}" | bc)
    if [[ ${_balance} == '.'* ]]; then
        _balance="0"${_balance}
    fi
    local _s="${TEXT_BALANCE}: ${_balance} ${TEXT_CURRENCY_ANON}\n"
          _s+="${TEXT_SEND_EXPL}\n"
          _s+="${TEXT_CLIPBOARD_HINT}"
    exec 3>&1
    oldIFS=${IFS}
    IFS="|"
    _buffer=$(dialog --backtitle "${TITLE_BACK}" \
        --ok-label "${BUTTON_LABEL_SEND}" \
        --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
        --extra-button \
        --extra-label "${BUTTON_LABEL_ADDRESS_BOOK}" \
        --no-shadow \
        --colors \
        --title "${TITLE_SEND}" \
        --form "${_s}" 17 70 0 \
        "${TEXT_SEND_DESTINATION_ADDRESS_EXPL}:" 2 2 "${_destinationAddress}" 2 26 102 0 \
        "${TEXT_SEND_AMOUNT_EXPL} ${TEXT_CURRENCY_ANON}:" 4 2 "${_amount}" 4 26 24 0 \
        "${TEXT_SEND_NARRATION}:" 6 2 "${_narration}" 6 26 24 0 \
        2>&1 1>&3)
    exit_status=$?
    IFS=${oldIFS}
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            refreshMainMenu_GUI;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI;;
        ${DIALOG_EXTRA})
            sry
            sendAnonCoins "test1";;
        ${DIALOG_OK})
            # Convert buffer into array
            # $sendInput[0] = Destination address
            # $sendInput[1] = Amount
            # $sendInput[2] = Narration
            mapfile -t sendInput <<< "${_buffer}"

            if [[ ${info_global[${WALLET_TESTNET}]} = false ]] ; then
                # Check destination address
                if [[ ${sendInput[0]} =~ ^[a-km-zA-HJ-NP-Z1-9]{102}$ ]]; then
                    _destinationAddress="${sendInput[0]}"
                else
                    errorHandling "${ERROR_SEND_INVALID_ANON_ADDRESS}"
                    sendAnonCoins
                fi
            else
                _destinationAddress="${sendInput[0]}"
            fi

            if [[ ${sendInput[1]} =~ ^[0-9]{0,8}[.]{0,1}[0-9]{0,8}$ ]] && [[ 1 -eq "$(echo "${sendInput[1]} > 0" | bc)" ]]; then
                _amount=${sendInput[1]}
                if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" == "${TEXT_WALLET_IS_UNLOCKED}" ]]; then
                    # iff wallet is unlocked, we have to look it first
                    executeCURL "walletlock"
                fi
                if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" != "${TEXT_WALLET_HAS_NO_PW}" ]]; then
                    passwordDialog "60" "false"
                fi
                if [[ -z "${sendInput[2]}" ]] ; then
                    # No narration given
                    executeCURL "sendprivate" "\"${_destinationAddress}\",${_amount},10"
                else
                    executeCURL "sendprivate" "\"${_destinationAddress}\",${_amount},10,\"${sendInput[2]}\""
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
                sendAnonCoins "${_destinationAddress}"
            fi
            sendAnonCoins "${_destinationAddress}";;
    esac
    errorHandling "${ERROR_SEND_FATAL}" \
                  1
}

sendCoins(){
    getCoinTypeToSend
    case $? in
        ${SEND_NOTHING})
            refreshMainMenu_GUI;;
        ${SEND_PRIVATE_COINS})
            sendAnonCoins;;
        ${SEND_PUBLIC_COINS})
            sendPublicCoins;;
    esac
}
