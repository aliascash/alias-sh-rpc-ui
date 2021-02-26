#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# Author: 2020-08 HLXEasy
#
# ============================================================================

# ============================================================================
# Goal: Display the wallets addresses for the "Default Address"-account
# (equals default addr)
viewAddresses() {
    executeCURL "getaddressesbyaccount" "\"Default Public Address\""
    curl_result_global=${curl_result_global//','/'\n'}
    curl_result_global=${curl_result_global//'['/''}
    local _defaultPublicAddress=${curl_result_global//']'/''}
    # If default public address name is empty, search with the old default name
    if [ -z "${_defaultPublicAddress}" ] ; then
        executeCURL "getaddressesbyaccount" "\"Default Address\""
        curl_result_global=${curl_result_global//','/'\n'}
        curl_result_global=${curl_result_global//'['/''}
        _defaultPublicAddress=${curl_result_global//']'/''}
    fi
    executeCURL "listprivateaddresses"
    curl_result_global=${curl_result_global//','/'\n'}
    curl_result_global=${curl_result_global//'['/''}
    local _defaultPrivateAddress=$(echo ${curl_result_global} | sed -e 's/.*Stealth Address://g' -e 's/ -.*//g')

    dialog --backtitle "${TITLE_BACK}" \
           --colors \
           --title "${TITLE_RECEIVE}" \
           --ok-label "${BUTTON_LABEL_OK}" \
           --no-shadow \
           --msgbox "\n${TEXT_DEFAULT_PUBLIC_ADDRESS}:\n${_defaultPublicAddress}\n\n${TEXT_DEFAULT_PRIVATE_ADDRESS}:\n${_defaultPrivateAddress}" 12 55
    refreshMainMenu_GUI
}
