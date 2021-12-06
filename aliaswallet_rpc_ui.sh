#!/bin/bash
# ============================================================================
#
# FILE:         aliaswallet_rpc_ui.sh
#
# DESCRIPTION:  DIALOG based RPC interface for Aliaswallet.
#               It's a lightwight UI for aliaswalletd, the Aliaswallet daemon
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# REQUIREMENTS: bash 4.x, bc, curl, dialog
# OPTIONS:      Call script with '-h'
# NOTES:        You may resize your terminal to get most of it
# AUTHOR:       dave#0773@discord
# AUTHOR:       HLXEasy
# PROJECT:      https://alias.cash/
#               https://github.com/aliascash/alias
#               https://github.com/aliascash/alias-sh-rpc-ui
#
# ============================================================================

# Backup where we came from
callDir=$(pwd)
ownLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName=$(basename $0)
cd "${ownLocation}"

usedShell=$(readlink /proc/$$/exe)
usedShellMajorVersion=$(${usedShell} --version | head -n 1 | sed -e "s/.* \([0-9]\)/\1/g" -e "s/\..*//g")
if [[ ${usedShellMajorVersion} -lt 4 ]] ; then
    echo "ERROR: Your shell must be at least version 4.x!"
    exit 1
fi

# Handle separate version file
if [[ -e VERSION ]] ; then
    VERSION=$(cat VERSION)
else
    VERSION='unknown'
fi

# Include used functions
. include/calculateLayout.sh
. include/changeLanguage.sh
. include/constants.sh
. include/convertCoins.sh
. include/createTransactionList.sh
. include/createWalletInfo.sh
. include/developerCmdInput.sh
. include/getInfo.sh
. include/getStakingPrediction.sh
. include/getTransactions.sh
. include/handleSettings.sh
. include/helpers_console.sh
. include/init_daemon_configuration.sh
. include/loadLanguage.sh
. include/sendCoins.sh
. include/setWalletPW.sh
. include/startDaemon.sh
. include/updateBinaries.sh
. include/userCmdInput.sh
. include/viewAddresses.sh
. include/viewLog.sh
. include/viewStakingPrediction.sh
. include/viewSystemStats.sh
. include/viewTransactions.sh
. include/viewWalletInfo.sh
. include/walletEncryption.sh

rtc=0
_init

# ============================================================================
# Show some cmdline help without dialog or else
helpMe ()
{
    echo "

    This script opens a dialog based UI to handle a Aliaswallet wallet.

    Usage:
    ${0} [options]

    Optional parameters:
    -c <config-file-to-use>
        Optional configuration file. Using this option you might connect to
        different aliaswalletd instances. If the configuration file is not
        existing, a minimal one with a random rpc password will be generated.
        Default: ${configfileLocation}
    -h  Show this help

    "
}

# ============================================================================
# This function is the beating heart, it executes connectToDaemon
# and optimizes it's output via the cutCURLresult function
#
# Input: $1 will be executed by the daemon as command
#        $2 params for the daemon command
#
# Output: global variable curl_result_global (clean and bash optimized)
executeCURL() {
    unset msg_global
    connectToDaemon "$1" "$2"
    if [[ -z "${curl_result_global}" ]]; then
        startDaemon
    fi
    # clean the result (curl_result_global) and optimize it for bash
    cutCURLresult
}

# ============================================================================
# This function interacts via cURL with the daemon
#
# Input: $1 will be executed by the daemon as command
#        $2 params for the daemon command
#
# Output: global variable curl_result_global
connectToDaemon() {
    local _action=$1
    local _parameters=$2
    curl_result_global=$( curl \
                          --user "${rpcuser}:${rpcpassword}" \
                          --silent \
                          --data-binary \
                          "{\"jsonrpc\":\"1.0\",\"id\":\"curltext\",\"method\":\"${_action}\",\"params\":[${_parameters}]}" \
                          -H "content-type:text/plain;" \
                          "http://${rpcconnect}:${rpcport}" )
}

# ============================================================================
# Every CURL command will yield to a reply, but this reply
# is very long and surrounded by plain CURL data (non aliaswalletd)
#
# Goal: after this function call the global string curl_result_global will
#       contain just wallet data (bash-optimized)
#
# Input: global var. curl_result_global containing CURL transaction data,
#        lots of " and spaces
#
# Output: global var. result (bash optimized) without any spaces nor "
cutCURLresult() {
    # check if curl_result_global contains error msg
    # if there was an error print it and exit
    # NOTE: at this point the cURL result will either exactly contain
    #       one(!) substring "error":null or a substring "error":<errormsg>
    if [[ ${curl_result_global} == *'"error":null,'* ]]; then
        # goal: cut the result string so only the real output is left
        # problem: there exist special results that are 2-dimensional
        if [[ "${curl_result_global}" == '{"result":['* ]]; then
            #cut right side in case of 2-dim. result
            #cut left side in case of 2-dim. result
            curl_result_global="${curl_result_global%'],"error"'*}"
            curl_result_global="${curl_result_global#*'":['}"
#        elif [[ "${curl_result_global}" == '{"result":{'* ]]; then
#            #cut right side
#            #cut left side
#            curl_result_global="${curl_result_global%'},"error"'*}"
#            curl_result_global="${curl_result_global#*'":{'}"
        else
            #curl feedback in the form of {"result":<blabla>,"error":null,"id":"curltext"}
            #cut right side
            #cut left side
            curl_result_global="${curl_result_global%',"error"'*}"
            curl_result_global="${curl_result_global#*':'}"
        fi
        # the daemon gives feedback about errors
        # if there was no error, just display none instead of ""
        # (this holds also if the wallet.dat is not encrypted)
        curl_result_global=${curl_result_global//'""'/'none'}
        # optimize string for bash
        # get rid of the "
        curl_result_global=${curl_result_global//'"'/}
    elif [[ "${curl_result_global}" == *'401 Unauthorized'* ]]; then
        # The RPC login failed - since the daemon responded it's due to a wrong login
        errorHandling "${ERROR_401_UNAUTHORIZED}" \
                      2
    else
        # Most likely a parsing error in the CURL command parameters
        # Just hand over the error msg. within the CURL reply
        # cut right side
        msg_global="${curl_result_global%%'"}'*}"
        # cut left side
        msg_global="${msg_global#*'message":"'}"
        errorHandling "${ERROR_CURL_MSG_PROMPT}\n\n${msg_global}"
    fi
}

# ============================================================================
# Fills a string to a given length (filling is done where the marker -_- is)
# \Z1 etc color commands are ignored
#
# Input: $1 will be displayed as CURL response msg
#        $2 desired length $1 will be pumped up to. If the $1 lenght already
#        is >= this value, a \n (new line command will be added instead)
fillLine() {
    local _output=$1
    local buff
    local _len
    # remove dialog color commands
    buff=${_output//'\Z'?/}
    # remove expander command
    buff=${buff//'-_-'/}
    _len=${#buff}
    offset=$(( $2 - ${_len} ))
    if [[ ${offset} -gt 0 ]]; then
        local _i=0
        while [[ ${_i} -lt ${offset} ]]; do
            if (( $_i % 2 == 1 )); then
                filler=${filler}'.'
            else
                filler=${filler}' '
            fi
            _i=$((_i+1))
        done
    else
        filler='\n'
    fi
    _output=${_output//'-_-'/"$filler"}
    echo "${_output}"
}

# ============================================================================
# Gets an amount in sec that will be displayed human readable
#
# Input: $1 amount in sec
secToHumanReadable() {
    local _time=$1
    local _timeHuman=""
    if [[ $((_time / 31536000)) -gt 0 ]];then
        _timeHuman="$((_time / 31536000))y "
    fi
    if [[ $((_time % 31536000 /604800)) -gt 0 ]];then
        _timeHuman+="$((_time % 31536000 /604800))w "
    fi
    if [[ $((_time % 604800 /86400)) -gt 0 ]];then
        _timeHuman+="$((_time % 604800 /86400))d "
    fi
    if [[ $((_time % 86400 /3600)) -gt 0 ]];then
        _timeHuman+="$((_time % 86400 /3600))h "
    fi
    if [[ $((_time % 3600 /60)) -gt 0 ]];then
        _timeHuman+="$((_time % 3600 /60))m "
    fi
    if [[ $((_time % 60)) -gt 0 ]];then
        _timeHuman+="$((_time % 60))s"
    fi
    echo "${_timeHuman}"
}

# ============================================================================
# Gathers the data form the CURL result for the getstakinginfo command
#
# Input: $curl_result_global
# Output: $stakinginfo_global array
getStakingInfo() {
    unset stakinginfo_global
    local _i=0
    local _oldIFS=$IFS
    local _itemBuffer
    local _time
    curl_result_global=${curl_result_global#'{'}
    curl_result_global=${curl_result_global%'}'}
    # Satisfy IntelliJ editor: '
    IFS=','
    for _itemBuffer in ${curl_result_global}; do
        if [[ ${_itemBuffer} == 'staking'* ]]; then
            if [[ "${_itemBuffer#*':'}" == "true" ]]; then
                stakinginfo_global[0]="${TEXT_STAKING_ON}"
            else
                stakinginfo_global[0]="${TEXT_STAKING_OFF}"
            fi
        elif [[ ${_itemBuffer} == 'expectedtime:'* ]]; then
            _time="${_itemBuffer#*':'}"
            stakinginfo_global[1]=$(secToHumanReadable ${_time})
        fi
    done
    IFS=${_oldIFS}
}

# ============================================================================
# Simple error handling
# Input: $1 will be displayed as error msg
#        $2 exit status (errors are indicated
#           by an integer in the range 1 - 255).
# If no $2 is parsed the handler will just promp a dialog and continue,
# instead of prompting to terminal and exiting
errorHandling() {
    if [[ -z "$2" ]]; then
        dialog --backtitle "${TITLE_BACK}" \
               --colors \
               --title "${TITLE_ERROR}" \
               --ok-label "${BUTTON_LABEL_OK}" \
               --no-shadow \
               --msgbox "$1" 0 0
    else
        echo "$1"
        exit "$2"
    fi
}

# ============================================================================
# Placeholder checkbox just give the user visual feedback
sry() {
    dialog --backtitle "${TITLE_BACK}" \
           --no-shadow \
           --colors \
           --title "${TITLE_PLACEHOLDER_FUNCTION}" \
           --msgbox  "${TEXT_PLACEHOLDER_FUNCTION}" 0 0
    refreshMainMenu_GUI
}

# ============================================================================
# This marks the regular ending of the script
goodbye() {
    if [[ ( "${rpcconnect}" = '127.0.0.1' ) || ( "${rpcconnect}" = 'localhost' ) ]] ; then
        local _s=""
        dialog --no-shadow \
            --colors \
            --extra-button \
            --ok-label "${BUTTON_LABEL_JUST_LEAVE}" \
            --extra-label "${BUTTON_LABEL_STOP_DAEMON}" \
            --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
            --default-button 'ok' \
            --yesno "${TEXT_GOODBYE_WARNING}" 0 0
        exit_status=$?
        case ${exit_status} in
            ${DIALOG_ESC})
                refreshMainMenu_GUI;;
            ${DIALOG_OK})
                reset
                echo ''
                info "${TEXT_GOODBYE_DAEMON_STILL_RUNNING}";;
            ${DIALOG_EXTRA})
                reset
                sudo systemctl stop aliaswalletd
                echo ''
                info "${TEXT_GOODBYE_DAEMON_STOPPED}";;
            ${DIALOG_CANCEL})
                refreshMainMenu_GUI;;
            *)
                errorHandling "${ERROR_GOODBYE_FATAL}" \
                              1;;
        esac
        info "${TEXT_GOODBYE_FEEDBACK}"
        echo ''
    else
        dialog --no-shadow \
            --colors \
            --ok-label "${BUTTON_LABEL_JUST_LEAVE}" \
            --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
            --default-button 'ok' \
            --yesno "\n${TEXT_GOODBYE_WARNING_REMOTE}\n " 0 0
        exit_status=$?
        case ${exit_status} in
            ${DIALOG_ESC})
                refreshMainMenu_GUI;;
            ${DIALOG_OK})
                reset
                echo ''
                ;;
            ${DIALOG_CANCEL})
                refreshMainMenu_GUI;;
            *)
                errorHandling "${ERROR_GOODBYE_FATAL}" \
                              1;;
        esac
        info "${TEXT_GOODBYE_FEEDBACK}"
        echo ''
    fi
    exit 0
}

# ============================================================================
# Simple checkbox for the user to get some feedback
# Input $1 - title of the box
#       $2 - text within the box
#       $3 - button text
#
simpleMsg() {
    dialog --backtitle "${TITLE_BACK}" \
        --colors \
        --title "$1" \
        --ok-label "$3" \
        --no-shadow \
        --msgbox "$2" 0 0
}

# ============================================================================
advancedmenu() {
# Staking Analysis
  # count
  # estimante
  # log network: means staking coins global
  # gnu plot ( only if not 127.0.0.1 ) ?

# getpeerinfo

# daemon management
  # start / stop daemon ? (script startet bisher nicht wenn daemon nicht läuft!!!)
  # set daemon niceness ? (befehl? - problem tasks müssen auch angepasst werden)
  # rewind chain
  # addnode

# wallet management
  # reserve balance
  # get wallet addresses (inkl. stealth)
  # backup wallet
  # add address to account
  # change password of wallet

# command execution  <-- add help command ( = help text zu bereits eingegeben command)

# back to main
    local _cmdWallet
    local _explWalletStatus
    # ${info_global[${WALLET_UNLOCKED_UNTIL}]} indicates if wallet is open
    if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" = "${TEXT_WALLET_HAS_NO_PW}" ]]; then
        _cmdWallet="${CMD_MAIN_ENCRYPT_WALLET}"
        _explWalletStatus="${EXPL_CMD_MAIN_WALLETENCRYPT}"
    else
        _cmdWallet="${CMD_CHANGE_WALLET_PW}"
        _explWalletStatus="${EXPL_CMD_CHANGE_WALLET_PW}"
    fi
    exec 3>&1
    local _mainMenuPick
    if [[ "${developerMode}" = 1 ]] ; then
        # Developer mode activated, add corresponding menu entry
        _mainMenuPick=$(dialog --backtitle "${TITLE_BACK}" \
            --colors \
            --title "${TITLE_ADV_MENU}" \
            --nocancel \
            --ok-label "${BUTTON_LABEL_ENTER}" \
            --no-shadow \
            --menu "" 0 0 12 \
            \
            "${CMD_GET_WALLET_INFO}" "${EXPL_CMD_GET_WALLET_INFO}" \
            "${CMD_STAKING_ANALYSE}" "${EXPL_CMD_STAKING_ANALYSE}" \
            "${CMD_GET_PEER_INFO}" "${EXPL_CMD_GET_PEER_INFO}" \
            "${CMD_GET_SYSTEM_STATS}" "${EXPL_CMD_GET_SYSTEM_STATS_INFO}" \
            "${CMD_VIEW_LOG}" "${EXPL_CMD_VIEW_LOG}" \
            "${CMD_USER_COMMAND}" "${EXPL_CMD_USER_COMMAND}" \
            "${_cmdWallet}" "${_explWalletStatus}" \
            "${CMD_CHANGE_LANGUAGE}" "${EXPL_CMD_CHANGE_LANGUAGE}" \
            "${CMD_UPDATE}" "${EXPL_CMD_UPDATE}" \
            "${CMD_MAIN_MENU}" "${EXPL_CMD_MAIN_MENU}" \
            "${CMD_DEVELOPER_COMMAND}" "${EXPL_CMD_DEVELOPER_COMMAND}" \
            2>&1 1>&3
        )
    else
        _mainMenuPick=$(dialog --backtitle "${TITLE_BACK}" \
            --colors \
            --title "${TITLE_ADV_MENU}" \
            --nocancel \
            --ok-label "${BUTTON_LABEL_ENTER}" \
            --no-shadow \
            --menu "" 0 0 12 \
            \
            "${CMD_GET_WALLET_INFO}" "${EXPL_CMD_GET_WALLET_INFO}" \
            "${CMD_STAKING_ANALYSE}" "${EXPL_CMD_STAKING_ANALYSE}" \
            "${CMD_GET_PEER_INFO}" "${EXPL_CMD_GET_PEER_INFO}" \
            "${CMD_GET_SYSTEM_STATS}" "${EXPL_CMD_GET_SYSTEM_STATS_INFO}" \
            "${CMD_VIEW_LOG}" "${EXPL_CMD_VIEW_LOG}" \
            "${CMD_USER_COMMAND}" "${EXPL_CMD_USER_COMMAND}" \
            "${_cmdWallet}" "${_explWalletStatus}" \
            "${CMD_CHANGE_LANGUAGE}" "${EXPL_CMD_CHANGE_LANGUAGE}" \
            "${CMD_UPDATE}" "${EXPL_CMD_UPDATE}" \
            "${CMD_MAIN_MENU}" "${EXPL_CMD_MAIN_MENU}" \
            2>&1 1>&3
        )
    fi
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_ESC})
            refreshMainMenu_DATA;;
    esac
    case ${_mainMenuPick} in
        "${CMD_GET_SYSTEM_STATS}")
            viewSystemStats
            exit 100
            advancedmenu;;
        "${CMD_GET_WALLET_INFO}")
            viewWalletInfo;;
        "${CMD_STAKING_ANALYSE}")
            viewStakingPrediction;;
        "${CMD_MAIN_ENCRYPT_WALLET}")
            encryptWallet;;
        "${CMD_CHANGE_WALLET_PW}")
            changePasswordDialog;;
        "${CMD_UPDATE}")
            updateBinaries;;
        "${CMD_USER_COMMAND}")
            userCommandInput;;
        "${CMD_DEVELOPER_COMMAND}")
            developerCommandInput;;
        "${CMD_GET_PEER_INFO}")
            sry;;
        "${CMD_CHANGE_LANGUAGE}")
            changeLanguage;;
        "${CMD_VIEW_LOG}")
            viewLog
            refreshMainMenu_DATA;;
        "${CMD_MAIN_MENU}")
            refreshMainMenu_DATA;;
        *)
            errorHandling "${ERROR_ADVMENU_FATAL}" \
                          1;;
    esac
}

# ============================================================================
# Goal: ask for the wallet password, to unlock the wallet for staking
#       and sending transactions. Password will never leave this function.
#
# Input $1 - time amout the wallet will be opend
#       $2 - if true the wallet will only be opend for staking
#
# Return: nothing
passwordDialog() {
    local _wallet_password
    exec 3>&1
    _wallet_password=$(dialog --backtitle "${TITLE_BACK}" \
        --no-shadow \
        --insecure \
        --passwordbox "${TEXT_PW_EXPL}" 0 0 \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            # abort and reload main menu
            refreshMainMenu_DATA;;
        ${DIALOG_ESC})
            # abort and reload main menu
            refreshMainMenu_DATA;;
        ${DIALOG_OK})
            # literally nothing to do here since daemon responds is excellent
            # the user will be guided back to main menu by function which exceuted passwordDialog()
            executeCURL "walletpassphrase" "\"${_wallet_password}\",$1,$2";;
        *)
            errorHandling "${ERROR_PW_FATAL}" \
                          1;;
    esac
}

# ============================================================================
# Simple output for any CURL command the user entered
curlUserFeedbackHandling() {
    if [[ "${curl_result_global}" != '{"result":null'* ]]; then
        # split the string between the values using ',' as indicator
        # instead of replacing every ',' with '\n' just replace those followed by [a-z]
        curl_result_global=$(echo ${curl_result_global} | sed 's/\(,\)\([a-z]\)/\n\2/g')
        dialog --backtitle "${TITLE_BACK}" \
               --colors \
               --title "${TITLE_CURL_RESULT}" \
               --ok-label "${BUTTON_LABEL_CONTINUE}" \
               --no-shadow \
               --msgbox "${curl_result_global}" 0 0
    fi
}

# ============================================================================
# This function draws the main menu to the terminal
refreshMainMenu_GUI() {
    local _cmdWallet
    local _explWalletStatus
    # ${info_global[${WALLET_UNLOCKED_UNTIL}]} indicates if wallet is open
    if [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" = "${TEXT_WALLET_IS_UNLOCKED}" ]]; then
        _cmdWallet="${CMD_MAIN_LOCK_WALLET}"
        _explWalletStatus="${EXPL_CMD_MAIN_WALLETLOCK}"
    elif [[ "${info_global[${WALLET_UNLOCKED_UNTIL}]}" = "${TEXT_WALLET_HAS_NO_PW}" ]]; then
        _cmdWallet="${CMD_MAIN_ENCRYPT_WALLET}"
        _explWalletStatus="${EXPL_CMD_MAIN_WALLETENCRYPT}"
    else
        _cmdWallet="${CMD_MAIN_UNLOCK_WALLET}"
        _explWalletStatus="${EXPL_CMD_MAIN_WALLETUNLOCK}"
    fi
    local _mainMenuPick
    exec 3>&1
    if [[ ${SIZE_X_TRANS} -gt 0 ]] ; then
        _mainMenuPick=$(dialog --no-shadow \
            --begin 0 0 \
            --no-lines \
            --infobox "" "${currentTPutLines}" "${currentTPutCols}" \
            \
            --and-widget \
            --colors \
            --begin "${POS_Y_TRANS}" "${POS_X_TRANS}" \
            --title "${TITLE_TRANS}" \
            --no-collapse \
            --infobox "$(makeOutputTransactions)" "${SIZE_Y_TRANS}" "${SIZE_X_TRANS}" \
            \
            --and-widget \
            --colors \
            --begin "${POS_Y_INFO}" "${POS_X_INFO}" \
            --title "${TITLE_INFO}" \
            --no-shadow \
            --no-collapse \
            --infobox "$(makeOutputInfo)" "${SIZE_Y_INFO}" "${SIZE_X_INFO}" \
            \
            --and-widget \
            --colors \
            --begin "${POS_Y_MENU}" "${POS_X_MENU}" \
            --title "${TITLE_MENU}" \
            --nocancel \
            --ok-label "${BUTTON_LABEL_ENTER}" \
            --no-shadow \
            --menu "" "${SIZE_Y_MENU}" "${SIZE_X_MENU}" 10 \
            \
            "${CMD_MAIN_REFRESH}" "${EXPL_CMD_MAIN_REFRESH}" \
            "${_cmdWallet}" "${_explWalletStatus}" \
            "${CMD_MAIN_TRANS}" "${EXPL_CMD_MAIN_VIEWTRANS}" \
            "${CMD_MAIN_SEND}" "${EXPL_CMD_MAIN_SEND}" \
            "${CMD_MAIN_CONVERT_COINS}" "${EXPL_CMD_MAIN_CONVERT_COINS}" \
            "${CMD_MAIN_RECEIVE}" "${EXPL_CMD_MAIN_RECEIVE}" \
            "${CMD_MAIN_ADVANCED_MENU}" "${EXPL_CMD_MAIN_ADVANCEDMENU}" \
            "${CMD_MAIN_QUIT}" "${EXPL_CMD_MAIN_EXIT}" \
            2>&1 1>&3)
            exit_status=$?
    else
        _mainMenuPick=$(dialog --no-shadow \
            --begin 0 0 \
            --no-lines \
            --infobox "" "${currentTPutLines}" "${currentTPutCols}" \
            \
            --and-widget \
            --colors \
            --begin "${POS_Y_INFO}" "${POS_X_INFO}" \
            --title "${TITLE_INFO}" \
            --no-shadow \
            --no-collapse \
            --infobox "$(makeOutputInfo)" "${SIZE_Y_INFO}" "${SIZE_X_INFO}" \
            \
            --and-widget \
            --colors \
            --begin "${POS_Y_MENU}" "${POS_X_MENU}" \
            --title "${TITLE_MENU}" \
            --nocancel \
            --ok-label "${BUTTON_LABEL_ENTER}" \
            --no-shadow \
            --menu "" "${SIZE_Y_MENU}" "${SIZE_X_MENU}" 10 \
            \
            "${CMD_MAIN_REFRESH}" "${EXPL_CMD_MAIN_REFRESH}" \
            "${_cmdWallet}" "${_explWalletStatus}" \
            "${CMD_MAIN_TRANS}" "${EXPL_CMD_MAIN_VIEWTRANS}" \
            "${CMD_MAIN_SEND}" "${EXPL_CMD_MAIN_SEND}" \
            "${CMD_MAIN_CONVERT_COINS}" "${EXPL_CMD_MAIN_CONVERT_COINS}" \
            "${CMD_MAIN_RECEIVE}" "${EXPL_CMD_MAIN_RECEIVE}" \
            "${CMD_MAIN_ADVANCED_MENU}" "${EXPL_CMD_MAIN_ADVANCEDMENU}" \
            "${CMD_MAIN_QUIT}" "${EXPL_CMD_MAIN_EXIT}" \
            2>&1 1>&3)
            exit_status=$?
    fi
    exec 3>&-
    case ${exit_status} in
        "${DIALOG_ESC}")
            goodbye;;
        "${DIALOG_ERROR}")
            errorHandling "${ERROR_MAINMENU_FATAL} Screensize"
                           1;;
    esac
    case ${_mainMenuPick} in
        "${CMD_MAIN_REFRESH}")
            refreshMainMenu_DATA;;
        "${CMD_MAIN_UNLOCK_WALLET}")
            unlockWalletForStaking;;
        "${CMD_MAIN_LOCK_WALLET}")
            lockWallet;;
        "${CMD_MAIN_ENCRYPT_WALLET}")
            encryptWallet;;
        "${CMD_MAIN_TRANS}")
            viewAllTransactions;;
        "${CMD_MAIN_SEND}")
            sendCoins;;
        "${CMD_MAIN_CONVERT_COINS}")
            convertCoins;;
        "${CMD_MAIN_RECEIVE}")
            viewAddresses;;
        "${CMD_MAIN_ADVANCED_MENU}")
            advancedmenu;;
        "${CMD_MAIN_QUIT}")
            goodbye;;
        *)
            errorHandling "${ERROR_MAINMENU_FATAL}"
                           1;;
    esac
}

# ============================================================================
# Goal: Refresh the main menu - which means we must gather new data
# and redraw gui
refreshMainMenu_DATA() {
    unset transactions
    declare -A transactions

    dialog --no-shadow \
           --infobox "\n${TEXT_LOADING_UI}" 6 40
    # have to recalc layout since it might have changed
    # (needed for transactions amount to fetch)
    calculateLayout
#    drawGauge "0" \
#            "${TEXT_GAUGE_GET_STAKING_DATA}"
    executeCURL "getstakinginfo"
#    drawGauge "15" \
#            "${TEXT_GAUGE_PROCESS_STAKING_DATA}"
    getStakingInfo
#    drawGauge "33" \
#            "${TEXT_GAUGE_GET_INFO}"
    executeCURL "getinfo"
#    drawGauge "48" \
#            "${TEXT_GAUGE_PROCESS_INFO}"
    getInfo

    # At this point, after getInfo() call, the wallet version is known
    handleSettings

    if [[ ${SIZE_X_TRANS} -gt 0 ]] ; then
#        drawGauge "66" \
#                "${TEXT_GAUGE_GET_TRANS}"
        executeCURL "listtransactions" '"*",'"${COUNT_TRANS_MENU}"',0,"1"'
#        drawGauge "85" \
#                "${TEXT_GAUGE_PROCESS_TRANS}"
        getTransactions
    fi
#    drawGauge "100" \
#            "${TEXT_GAUGE_ALLDONE}"
    refreshMainMenu_GUI
}

# ============================================================================
# Goal: lock the wallet
lockWallet() {
    executeCURL "walletlock"
    dialog --backtitle "${TITLE_BACK}" \
           --colors \
           --no-shadow \
           --ok-label "${BUTTON_LABEL_CONTINUE}" \
           --msgbox "${TEXT_FEEDBACK_WALLET_LOCKED}\n\n${TEXT_SUGGESTION_STAKING}" 0 0
    refreshMainMenu_DATA
}

# ============================================================================
# Goal: unlock the wallet for staking only
unlockWalletForStaking() {
    passwordDialog "999999999" \
                   "true"
    local _s
    # if there was no error
    if [[ -z "${msg_global}" ]]; then
        dialog --backtitle "${TITLE_BACK}" \
               --colors \
               --no-shadow \
               --ok-label "${BUTTON_LABEL_CONTINUE}" \
               --msgbox "${TEXT_FEEDBACK_WALLET_UNLOCKED}\n\n${TEXT_SUGGESTION_STAKING}" 0 0
        refreshMainMenu_DATA
    fi
    # todo change with new dialog version
    #unlockWalletForStaking
    refreshMainMenu_DATA
}

# ============================================================================
# Goal: draw a gauge to give user feedback
# Input $1 - amount the gauge will display integer (0-100)
#       $2 - text in the gauge box
drawGauge() {
    echo "$1" | dialog --no-shadow \
                       --title "${TITLE_GAUGE}" \
                       --gauge "$2" "${SIZE_Y_GAUGE}" "${SIZE_X_GAUGE}" 0
}

# ============================================================================
# Check if given tool is installed
checkRequirement() {
    local _toolToCheck=$1
    ${_toolToCheck} --version > /dev/null 2>&1 ; rtc=$?
    if [[ "$rtc" -ne 0 ]] ; then
        die 20 "Required tool '${_toolToCheck}' not found!"
    fi
}

checkDialogRCConfig() {
    if [[ ! -e ~/.dialogrc ]] ; then
        info "~/.dialogrc not found, installing it"
        cp sample_config_daemon/dialogrc ~/.dialogrc
        chmod 644 ~/.dialogrc
    fi
}

# ============================================================================
# Use ca-certificates if available
setupCacertParam() {
    if [[ -e /etc/ssl/certs/ca-certificates.crt ]] ; then
        cacertParam='--cacert /etc/ssl/certs/ca-certificates.crt'
    fi
}


while getopts c:h? option; do
    case ${option} in
        c) configfileLocation="${OPTARG}";;
        h|?) helpMe && exit 0;;
        *) die 90 "invalid option \"${OPTARG}\"";;
    esac
done

cacertParam=''
checkRequirement dialog
checkRequirement bc
checkRequirement curl
checkRequirement jq
checkDialogRCConfig
handleSettings
setupCacertParam

#Putty fix
#export NCURSES_NO_UTF8_ACS=1
#printf '\033[8;29;134t'
initDaemonConfiguration
if [[ $(tput lines) -lt 28 ]] || [[ $(tput cols) -lt 74 ]]; then
    simpleMsg "${TITLE_SUGGESTION}" \
              "${TEXT_SUGGESTION_TO_INCREASE_TERMINAL_SIZE} 45x28.\n" \
              "${BUTTON_LABEL_CONTINUE}"
else
    message="\n"
    message+="$(sh ./include/logo.sh | base64 -d)"
    message+="\n"
    message+="${TEXT_USE_AT_YOUR_OWN_RISC}"
    #message+="    Terminal: $(tput longname)\n"
    #message+="    Dialog $(dialog --version)\n"
    #message+="      Interface version: ${VERSION}\n"

    simpleMsg "- --- === WARNING === --- -" \
              "${message}" \
              "${BUTTON_LABEL_I_HAVE_UNDERSTOOD}"
fi
#trap refreshMainMenu_DATA INT
#while :; do
    refreshMainMenu_DATA
#done
#goodbye
