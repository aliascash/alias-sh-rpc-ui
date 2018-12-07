#!/bin/bash

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $1 - start (optional - default "0")
#        $2 - if "true" stakes will be displayed (optional - default "true")
makeWalletInfoOutput() {
    local _showBalance=$1
    echo "\n"
    echo "Version:            ${info_global[${WALLET_VERSION}]}\n"
    if ${_showBalance} ; then
        echo "Balance XSPEC:      ${info_global[${WALLET_BALANCE_XSPEC}]}\n"
        echo "Balance SPECTRE:    ${info_global[${WALLET_BALANCE_SPECTRE}]}\n"
        echo "Stake:              ${info_global[${WALLET_STAKE}]}\n"
    else
        echo "Balance XSPEC:      ---\n"
        echo "Balance SPECTRE:    ---\n"
        echo "Stake:              ---\n"
    fi
    echo "Connections:        ${info_global[${WALLET_CONNECTIONS}]}\n"
    echo "Data received:      ${info_global[${WALLET_DATARECEIVED}]}\n"
    echo "Data sent:          ${info_global[${WALLET_DATASENT}]}\n"
    echo "IP:                 ${info_global[${WALLET_IP}]}\n"
    echo "Unlocked until:     ${info_global[${WALLET_UNLOCKED_UNTIL}]}\n"
    echo "Errors:             ${info_global[${WALLET_ERRORS}]}\n"
    echo "Mode:               ${info_global[${WALLET_MODE}]}\n"
    echo "State:              ${info_global[${WALLET_STATE}]}\n"
    echo "Protocol version:   ${info_global[${WALLET_PROTOCOLVERSION}]}\n"
    echo "Wallet version:     ${info_global[${WALLET_WALLETVERSION}]}\n"
    echo "Newmint:            ${info_global[${WALLET_NEWMINT}]}\n"
    echo "Reserve:            ${info_global[${WALLET_RESERVE}]}\n"
    echo "Blocks:             ${info_global[${WALLET_BLOCKS}]}\n"
    echo "Timeoffset:         ${info_global[${WALLET_TIMEOFFSET}]}\n"
    echo "Moneysupply:        ${info_global[${WALLET_MONEYSUPPLY}]}\n"
    echo "Spectresupply:      ${info_global[${WALLET_SPECTRESUPPLY}]}\n"
    echo "Proxy:              ${info_global[${WALLET_PROXY}]}\n"
    echo "Proof of work:      ${info_global[${WALLET_PROOF_OF_WORK}]}\n"
    echo "Proof of stake:     ${info_global[${WALLET_PROOF_OF_STAKE}]}\n"
    echo "Testnet:            ${info_global[${WALLET_TESTNET}]}\n"
    echo "Keypoolsize:        ${info_global[${WALLET_KEYPOOLSIZE}]}\n"
    echo "Paytxfee:           ${info_global[${WALLET_PAYTXFEE}]}\n"
    echo "Mininput:           ${info_global[${WALLET_MININPUT}]}\n"
}

viewWalletInfo() {
    local _showBalance
    local _balanceButtonText
    if [[ -z "$1" ]] || [[ "$1" = true ]] ; then
        _showBalance=true
        _balanceButtonText="${BUTTON_LABEL_HIDE_BALANCE}"
    else
        _showBalance=false
        _balanceButtonText="${BUTTON_LABEL_SHOW_BALANCE}"
    fi
    _mainMenuButton="${BUTTON_LABEL_MAIN_MENU}"
    calculateLayout
    executeCURL "getinfo"
    drawGauge "48" \
            "${TEXT_GAUGE_PROCESS_INFO}"
    getInfo
    dialog --backtitle "${TITLE_BACK}" \
           --colors \
           --title "${TITLE_WALLET_INFO}" \
           --ok-label "${BUTTON_LABEL_OK}" \
           --no-shadow \
           --extra-button \
           --extra-label "${_balanceButtonText}" \
           --msgbox "$(makeWalletInfoOutput ${_showBalance})" 34 "${SIZE_X_TRANS_VIEW}"
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_EXTRA})
            if ${_showBalance} ; then
                viewWalletInfo false
            else
                viewWalletInfo true
            fi;;
    esac
    refreshMainMenu_DATA
}
