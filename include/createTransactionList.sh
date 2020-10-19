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
# Input:  $1  - optional var determing the text width (default: TEXTWIDTH_TRANS)
# Operating with:  $transactions
makeOutputTransactions() {
    local _textWidth
    if [[ -z "$1" ]] ; then
        _textWidth="${TEXTWIDTH_TRANS}"
    else
        _textWidth="$1"
    fi
    for ((i=${currentAmountOfTransactions} ; i >= 0 ; i=$(($i-1)))) ; do
        local _currentTaTime=$(date -d "@${transactions[${i},${TA_TIME}]}" +%d-%m-%Y" at "%H:%M:%S)

        # 1st line: Transaction and date
        echo $(fillLine "${transactions[${i},${TA_CATEGORY}]}: ${transactions[${i},${TA_AMOUNT}]} ${transactions[${i},${TA_CURRENCY}]}-_-${_currentTaTime}" \
                        "${_textWidth}")"\n"

        # 2nd line: Confirmations and narration
        if (( ${_textWidth} >= 43 )) ; then
            narrationContent='---'
            if [[ -n "${transactions[${i},${TA_NARRATION}]}" ]] ; then
                narrationContent="${transactions[${i},${TA_NARRATION}]}"
            fi
            echo $(fillLine "${TEXT_CONFIRMATIONS}: ${transactions[${i},${TA_CONFIRMATIONS}]}-_-${TEXT_NARRATION}: ${narrationContent}" \
                            "${_textWidth}")"\n"
        else
            echo "${TEXT_CONFIRMATIONS}: ${transactions[${i},${TA_CONFIRMATIONS}]}\n"
        fi

        if (( ${_textWidth} >= 70 )) ; then
            # 3rd line: Address
            local _address="${TEXT_ADDRESS}: ${transactions[${i},${TA_ADDRESS}]}"
            local _lineLength=$(echo -n ${_address} | wc -c)
            if [[ "${transactions[${i},${TA_CATEGORY}]}" = "${TEXT_TRANSFERRED}" ]] ; then
                # It's a SENDED entry, so show it's fee
                if [[ ${_lineLength} -lt ${_textWidth} ]] ; then
                    echo $(fillLine "${_address}-_-${TEXT_FEE}: ${transactions[${i},${TA_FEE}]}" \
                                    "${_textWidth}")"\n"
                else
                    echo "${_address:0:${_textWidth}}\n"
                    echo $(fillLine "${_address:${_textWidth}}-_-${TEXT_FEE}: ${transactions[${i},${TA_FEE}]}" \
                                    "${_textWidth}")"\n"
                fi
            else
                if [[ ${_lineLength} -lt ${_textWidth} ]] ; then
                    echo "${_address}\n"
                else
                    echo "${_address:0:${_textWidth}}\n"
                    echo "${_address:${_textWidth}}\n"
                fi
            fi
            # 4th line: Transaction Id
            echo $(fillLine "${TEXT_TXID}: ${transactions[${i},${TA_TXID}]}" \
                            "${_textWidth}")"\n"
        fi
        echo "\n"
    done
}
