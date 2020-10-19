#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# ============================================================================

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $curl_result_global
# Output: $info_global array
getInfo() {
    unset info_global
    local _oldIFS=$IFS
    local _itemBuffer
    local _unixtime

    # Remove leading '{' and trailing '}'
    curl_result_global=${curl_result_global#'{'}
    curl_result_global=${curl_result_global%'}'}

    # Replace '{' and '}' inside of result string with ','
    curl_result_global=${curl_result_global//\{/,}
    curl_result_global=${curl_result_global//\}/,}

    # Set default if wallet is not encrypted
    info_global[${WALLET_UNLOCKED_UNTIL}]="${TEXT_WALLET_HAS_NO_PW}"

    # Set some defaults
    info_global[${WALLET_BALANCE}]="0"
    info_global[${WALLET_BALANCE_PUBLIC}]="0"
    info_global[${WALLET_BALANCE_PRIVATE}]="0"
    info_global[${WALLET_STAKE}]="0"
    info_global[${WALLET_STAKE_PUBLIC}]="0"
    info_global[${WALLET_STAKE_PRIVATE}]="0"
    info_global[${WALLET_BALANCE_UNCONF}]="0"
    info_global[${WALLET_BALANCE_UNCONF_PUBLIC}]="0"
    info_global[${WALLET_BALANCE_UNCONF_PRIVATE}]="0"
    info_global[${WALLET_STAKE_WEIGHT}]="0"
    info_global[${WALLET_STAKE_WEIGHT_PUBLIC}]="0"
    info_global[${WALLET_STAKE_WEIGHT_PRIVATE}]="0"

    IFS=','
    for _itemBuffer in ${curl_result_global}; do
        case ${_itemBuffer%%:*} in
            'version')
                info_global[${WALLET_VERSION}]="${_itemBuffer#*:}";;
            'balance')
                info_global[${WALLET_BALANCE}]="${_itemBuffer#*:}";;
            'balance_public')
                info_global[${WALLET_BALANCE_PUBLIC}]="${_itemBuffer#*:}";;
            'balance_private')
                info_global[${WALLET_BALANCE_PRIVATE}]="${_itemBuffer#*:}";;
            'unconfirmedbalance')
                info_global[${WALLET_BALANCE_UNCONF}]="${_itemBuffer#*:}";;
            'unconfirmedbalance_public')
                info_global[${WALLET_BALANCE_UNCONF_PUBLIC}]="${_itemBuffer#*:}";;
            'unconfirmedbalance_private')
                info_global[${WALLET_BALANCE_UNCONF_PRIVATE}]="${_itemBuffer#*:}";;
            'stake')
                info_global[${WALLET_STAKE}]="${_itemBuffer#*:}";;
            'stake_public')
                info_global[${WALLET_STAKE_PUBLIC}]="${_itemBuffer#*:}";;
            'stake_private')
                info_global[${WALLET_STAKE_PRIVATE}]="${_itemBuffer#*:}";;
            'stakeweight')
                info_global[${WALLET_STAKE_WEIGHT}]="${_itemBuffer#*:}";;
            'stakeweight_public')
                info_global[${WALLET_STAKE_WEIGHT_PUBLIC}]="${_itemBuffer#*:}";;
            'stakeweight_private')
                info_global[${WALLET_STAKE_WEIGHT_PRIVATE}]="${_itemBuffer#*:}";;
            'connections')
                info_global[${WALLET_CONNECTIONS}]="${_itemBuffer#*:}";;
            'datareceived')
                info_global[${WALLET_DATARECEIVED}]="${_itemBuffer#*:}";;
            'datasent')
                info_global[${WALLET_DATASENT}]="${_itemBuffer#*:}";;
            'ip')
                info_global[${WALLET_IP}]="${_itemBuffer#*:}";;
            'unlocked_until')
                _unixtime="${_itemBuffer#*':'}"
                if [[ "$_unixtime" -gt 0 ]]; then
                    info_global[${WALLET_UNLOCKED_UNTIL}]="${TEXT_WALLET_IS_UNLOCKED}"
                else
                    info_global[${WALLET_UNLOCKED_UNTIL}]="${TEXT_WALLET_IS_LOCKED}"
                fi;;
            'errors')
                if [[ "${_itemBuffer#*':'}" == 'none' ]]; then
                    info_global[${WALLET_ERRORS}]="${TEXT_DAEMON_NO_ERRORS_DURING_RUNTIME}"
                else
                    info_global[${WALLET_ERRORS}]="\Z1${_itemBuffer#*:}\Zn"
                fi;;
            'mode')
                info_global[${WALLET_MODE}]="${_itemBuffer#*:}";;
            'state')
                info_global[${WALLET_STATE}]="${_itemBuffer#*:}";;
            'protocolversion')
                info_global[${WALLET_PROTOCOLVERSION}]="${_itemBuffer#*:}";;
            'walletversion')
                info_global[${WALLET_WALLETVERSION}]="${_itemBuffer#*:}";;
            'newmint')
                info_global[${WALLET_NEWMINT}]="${_itemBuffer#*:}";;
            'reserve')
                info_global[${WALLET_RESERVE}]="${_itemBuffer#*:}";;
            'blocks')
                info_global[${WALLET_BLOCKS}]="${_itemBuffer#*:}";;
            'timeoffset')
                info_global[${WALLET_TIMEOFFSET}]="${_itemBuffer#*:}";;
            'moneysupply')
                info_global[${WALLET_MONEY_SUPPLY}]="${_itemBuffer#*:}";;
            'moneysupply_public')
                info_global[${WALLET_MONEY_SUPPLY_PUBLIC}]="${_itemBuffer#*:}";;
            'moneysupply_private')
                info_global[${WALLET_MONEY_SUPPLY_PRIVATE}]="${_itemBuffer#*:}";;
            'proxy')
                info_global[${WALLET_PROXY}]="${_itemBuffer#*:}";;
            'proof-of-work')
                # PoW is a sub-entry of 'difficulty'
                info_global[${WALLET_PROOF_OF_WORK}]="${_itemBuffer#*:}";;
            'proof-of-stake')
                # PoS is a sub-entry of 'difficulty'
                info_global[${WALLET_PROOF_OF_STAKE}]="${_itemBuffer#*:}";;
            'testnet')
                info_global[${WALLET_TESTNET}]="${_itemBuffer#*:}";;
            'keypoolsize')
                info_global[${WALLET_KEYPOOLSIZE}]="${_itemBuffer#*:}";;
            'paytxfee')
                info_global[${WALLET_PAYTXFEE}]="${_itemBuffer#*:}";;
            'mininput')
                info_global[${WALLET_MININPUT}]="${_itemBuffer#*:}";;
            *)
                ;;
        esac
    done
    IFS=${_oldIFS}
}
