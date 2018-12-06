#!/bin/bash

# ============================================================================
# Goal: Display form for the user to enter transaction details
#       Check if a valid address was entered
#       Check if a valid amount was entered
#
# Input $1 - address (important for address book functionality)
#
sendCoins() {
    local _amount
    local _destinationAddress=$1
    local _buffer
    local _narration=''
    local _balance=$(echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc)
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
        --no-shadow --colors \
        --title "${TITEL_SEND}" \
        --form "${_s}" 16 65 0 \
        "${TEXT_SEND_DESTINATION_ADDRESS_EXPL}:" 2 1 "${_destinationAddress}" 2 22 35 0 \
        "${TEXT_SEND_AMOUNT_EXPL}:" 4 1 "${_amount}" 4 22 20 0 \
        "${TEXT_SEND_NARRATION}:" 6 1 "${_narration}" 6 22 24 0 \
        2>&1 1>&3)
    IFS=${oldIFS}
    exit_status=$?
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

            # Check destination address
            if [[ ${sendInput[0]} =~ ^[S][a-km-zA-HJ-NP-Z1-9]{25,33}$ ]]; then
                _destinationAddress="${sendInput[0]}"
            else
                errorHandling "${ERROR_SEND_INVALID_ADDRESS}"
                sendCoins
            fi

            if [[ ${sendInput[1]} =~ ^[0-9]{0,8}[.]{0,1}[0-9]{0,8}$ ]] && [[ 1 -eq "$(echo "${sendInput[1]} > 0" | bc)" ]]; then
                _amount=${sendInput[1]}
                if [[ "${info_global[8]}" == "${TEXT_WALLET_IS_UNLOCKED}" ]]; then
                    # iff wallet is unlocked, we have to look it first
                    executeCURL "walletlock"
                fi
                if [[ "${info_global[8]}" != "${TEXT_WALLET_HAS_NO_PW}" ]]; then
                    passwordDialog "60" "false"
                fi
                if [[ -z "${sendInput[2]}" ]] ; then
                    # No narration given
                    executeCURL "sendtoaddress" "\"${_destinationAddress}\",${_amount}"
                else
                    executeCURL "sendtoaddress" "\"${_destinationAddress}\",${_amount},\"\",\"\",\"${sendInput[2]}\""
                fi
                if [[ "${info_global[8]}" != "${TEXT_WALLET_HAS_NO_PW}" ]]; then
                    executeCURL "walletlock"
                fi
                if [[ "${info_global[8]}" == "${TEXT_WALLET_IS_UNLOCKED}" ]]; then
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
