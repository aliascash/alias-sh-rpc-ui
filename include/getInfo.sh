#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
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
    info_global[${WALLET_BALANCE_XSPEC}]="0"
    info_global[${WALLET_BALANCE_SPECTRE}]="0"
    info_global[${WALLET_STAKE}]="0"
    info_global[${WALLET_SPECTRE_STAKE}]="0"

    IFS=','
    for _itemBuffer in ${curl_result_global}; do
        case ${_itemBuffer%%:*} in
            'version')
                info_global[${WALLET_VERSION}]="${_itemBuffer#*:}";;
            'balance')
                info_global[${WALLET_BALANCE_XSPEC}]="${_itemBuffer#*:}";;
            'spectrebalance')
                info_global[${WALLET_BALANCE_SPECTRE}]="${_itemBuffer#*:}";;
            'unconfirmedbalance')
                info_global[${WALLET_BALANCE_XSPEC_UNCONF}]="${_itemBuffer#*:}";;
            'unconfirmedspectrebalance')
                info_global[${WALLET_BALANCE_SPECTRE_UNCONF}]="${_itemBuffer#*:}";;
            'stake')
                info_global[${WALLET_STAKE}]="${_itemBuffer#*:}";;
            'spectrestake')
                info_global[${WALLET_SPECTRE_STAKE}]="${_itemBuffer#*:}";;
            'stakeweight')
                info_global[${WALLET_STAKE_WEIGHT}]="${_itemBuffer#*:}";;
            'spectrestakeweight')
                info_global[${WALLET_SPECTRE_STAKE_WEIGHT}]="${_itemBuffer#*:}";;
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
                info_global[${WALLET_MONEYSUPPLY}]="${_itemBuffer#*:}";;
            'spectresupply')
                info_global[${WALLET_SPECTRESUPPLY}]="${_itemBuffer#*:}";;
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
