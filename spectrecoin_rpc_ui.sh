#!/bin/bash
# ============================================================================
#
# FILE: spectrecoin_rpc_ui.sh
#
# DESCRIPTION: DIALOG RPC interface for Spectrecoin,
#              It's a lightwight GUI for the spectrecoind (headless) wallet
#
# OPTIONS: path to config file can be parsed as an argument,
#          if the file is not located in the same folder
# REQUIREMENTS: dialog, bc
# NOTES: you may resize your terminal to get most of it
# AUTHOR: dave#0773@discord
# Project: https://spectreproject.io/ and https://github.com/spectrecoin/spectre
# ============================================================================

# Backup where we came from
callDir=$(pwd)
ownLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName=$(basename $0)
cd "${ownLocation}"
. include/helpers_console.sh
. include/init_daemon_configuration.sh

# ToDo: Possibility to switch between different language files
. include/ui_content_en.sh

# Handle separate version file
if [ -e VERSION ] ; then
    VERSION=$(cat VERSION)
else
    VERSION='unknown'
fi

rtc=0
_init

# ============================================================================
# Show some cmdline help without dialog or else
helpMe ()
{
    echo "

    This script opens a dialog based UI to handle a Spectrecoin wallet.

    Usage:
    ${0} [options]

    Optional parameters:
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
    if [ -z "${curl_result_global}" ]; then
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
# is very long and surrounded by plain CURL data (non spectrecoind)
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
# Starts the daemon (spectrecoind)
#
startDaemon() {
    if [ "${rpcconnect}" != "127.0.0.1" ]; then
        local _s="Settings:\n"
              _s+="RPC USER:${rpcuser}\nRPC PW:${rpcpassword}\n"
              _s+="IP:${rpcconnect}\nPort:${rpcport}\n"
        errorHandling "${ERROR_DAEMON_NO_CONNECT_FROM_REMOTE}\n${_s}" \
                      1
    fi
    (
         local _oldIFS=$IFS
         local _itemBuffer
         IFS='\\'
         if (( $(ps -ef | grep -v grep | grep spectrecoind | wc -l) > 0 )) ; then
            for _itemBuffer in ${ERROR_DAEMON_ALREADY_RUNNING}; do
                echo "${_itemBuffer}"
            done
        else
            for _itemBuffer in ${ERROR_DAEMON_STARTING}; do
                echo "${_itemBuffer}"
            done
            sudo service spectrecoind start
        fi
        for _itemBuffer in ${ERROR_DAEMON_WAITING_BEGIN}; do
            echo "${_itemBuffer}"
        done
        local _i=60
        while [ -z "${curl_result_global}" ] && [ ${_i} -gt 0 ]; do
            echo "- ${_i} ${ERROR_DAEMON_WAITING_MSG}"
            _i=$((_i-5))
            sleep 5
            connectToDaemon "getinfo"
        done
        if [ -z "${curl_result_global}" ]; then
            # exit script
            errorHandling "${ERROR_DAEMON_NO_CONNECT}" \
                          1
        else
            for _itemBuffer in ${ERROR_DAEMON_WAITING_MSG_SUCCESS}; do
                echo "${_itemBuffer}"
            done
        fi
        for _itemBuffer in ${ERROR_DAEMON_WAITING_END}; do
            echo "${_itemBuffer}"
        done
        sleep 1
        IFS=${_oldIFS}
    ) | dialog --backtitle "${TITLE_BACK}" \
               --title "${TITLE_STARTING_DAEMON}" \
               --no-shadow \
               --progressbox 20 45
    refreshMainMenu_DATA
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
    if [ ${offset} -gt 0 ]; then
        local _i=0
        while [ ${_i} -lt ${offset} ]; do
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
    echo ${_output}
}

# ============================================================================
# Gets an amount in sec that will be displayed human readable
#
# Input: $1 amount in sec
secToHumanReadable() {
    local _time=$1
    local _timeHuman=""
    if [ $((_time / 31536000)) -gt 0 ];then
        _timeHuman="$((_time / 31536000))y "
    fi
    if [ $((_time % 31536000 /604800)) -gt 0 ];then
        _timeHuman+="$((_time % 31536000 /604800))w "
    fi
    if [ $((_time % 604800 /86400)) -gt 0 ];then
        _timeHuman+="$((_time % 604800 /86400))d "
    fi
    if [ $((_time % 86400 /3600)) -gt 0 ];then
        _timeHuman+="$((_time % 86400 /3600))h "
    fi
    if [ $((_time % 3600 /60)) -gt 0 ];then
        _timeHuman+="$((_time % 3600 /60))m "
    fi
    if [ $((_time % 60)) -gt 0 ];then
        _timeHuman+="$((_time % 60))s"
    fi
    echo "${_timeHuman}"
}

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $curl_result_global
# Outpunt: $info_global array
getInfo() {
    unset info_global
    local _oldIFS=$IFS
    local _itemBuffer
    local _unixtime
    curl_result_global=${curl_result_global#'{'}
    curl_result_global=${curl_result_global%'}'}
    IFS=','
    # if wallet is not encrypted
    info_global[8]="${TEXT_WALLET_HAS_NO_PW}"
    for _itemBuffer in ${curl_result_global}; do
        if [[ ${_itemBuffer} == 'version'* ]]; then
            info_global[0]="${_itemBuffer#*':'}"
        elif [[ ${_itemBuffer} == 'balance'* ]]; then
            info_global[1]="${_itemBuffer#*':'}"
        elif [[ ${_itemBuffer} == 'spectrebalance'* ]]; then
            info_global[2]="${_itemBuffer#*':'}"
        elif [[ ${_itemBuffer} == 'stake'* ]]; then
            info_global[3]="${_itemBuffer#*':'}"
        elif [[ ${_itemBuffer} == 'connections'* ]]; then
            info_global[4]="${_itemBuffer#*':'}"
        elif [[ ${_itemBuffer} == 'datareceived'* ]]; then
            info_global[5]="${_itemBuffer#*':'}"
        elif [[ ${_itemBuffer} == 'datasent'* ]]; then
            info_global[6]="${_itemBuffer#*':'}"
        elif [[ ${_itemBuffer} == 'ip'* ]]; then
            info_global[7]="${_itemBuffer#*':'}"
        elif [[ ${_itemBuffer} == 'unlocked_until:'* ]]; then
            _unixtime="${_itemBuffer#*':'}"
            if [ "$_unixtime" -gt 0 ]; then
                info_global[8]="${TEXT_WALLET_IS_UNLOCKED}"
            else
                info_global[8]="${TEXT_WALLET_IS_LOCKED}"
            fi
        elif [[ ${_itemBuffer} == 'errors'* ]]; then
            if [ "${_itemBuffer#*':'}" == 'none' ]; then
                info_global[9]="${TEXT_DAEMON_NO_ERRORS_DURING_RUNTIME}"
            else
                #todo remove } at the end of error msg
                info_global[9]="\Z1""${_itemBuffer#*':'}""\Zn"
            fi
        fi
    done
    IFS=${_oldIFS}
}

# ============================================================================
# Gathers the data form the CURL result for the getstakinginfo command
#
# Input: $curl_result_global
# Outpunt: $stakinginfo_global array
getStakingInfo() {
    unset stakinginfo_global
    local _i=0
    local _oldIFS=$IFS
    local _itemBuffer
    local _time
    curl_result_global=${curl_result_global#'{'}
    curl_result_global=${curl_result_global%'}'}
    IFS=','
    for _itemBuffer in ${curl_result_global}; do
        if [[ ${_itemBuffer} == 'staking'* ]]; then
            if [ "${_itemBuffer#*':'}" == "true" ]; then
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
# Gathers the data form the CURL result for the getinfo command
#
# Input:  $1  - optional var determing the text width (default: TEXTWIDTH_INFO)
#
# Operating with:  $info_global
#                  $stakinginfo_global
makeOutputInfo() {
    local _textWidth
    if [ -z "$1" ]; then
        _textWidth="${TEXTWIDTH_INFO}"
    else
        _textWidth="$1"
    fi
    echo "${TEXT_HEADLINE_WALLET_INFO}\n"
    local _balance=$(echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc)
    if [[ ${_balance} == '.'* ]]; then
        _balance="0"${_balance}
    fi
    echo $(fillLine "${TEXT_BALANCE}:-_-${_balance} ${TEXT_CURRENCY}" \
                    "${_textWidth}")"\n"
    echo $(fillLine "Stealth spectre coins:-_-\Z6${info_global[2]}\Zn" \
                    "${_textWidth}")"\n"
    #
    echo "\n${TEXT_HEADLINE_STAKING_INFO}\n"
    echo $(fillLine "${TEXT_WALLET_STATE}: ${info_global[8]}-_-${TEXT_STAKING_STATE}: ${stakinginfo_global[0]}" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_STAKING_COINS}: \Z4${info_global[1]}\Zn-_-(\Z5${info_global[3]}\Zn ${TEXT_MATRUING_COINS})" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_EXP_TIME}: ${stakinginfo_global[1]}" \
                    "${_textWidth}")"\n"
    #
    echo "\n${TEXT_HEADLINE_CLIENT_INFO}\n"
    echo $(fillLine "${TEXT_DAEMON_VERSION}: ${info_global[0]}-_-${TEXT_DAEMON_ERRORS_DURING_RUNTIME}: ${info_global[9]}" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_DAEMON_IP}: ${info_global[7]}-_-${TEXT_DAEMON_PEERS}: ${info_global[4]}" \
                    "${_textWidth}")"\n"
    echo $(fillLine "${TEXT_DAEMON_DOWNLOADED_DATA}: ${info_global[5]}-_-${TEXT_DAEMON_UPLOADED_DATA}: ${info_global[6]}" \
                    "${_textWidth}")"\n"
}

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $curl_result_global
# Outpunt: $transactions_global array
#          $1  - if "full" a staking analysis is done
getTransactions() {
    unset transactions_global
    local _i=0
    local _oldestStakeDate=9999999999
    local _newestStakeDate=0
    local _firstStakeIndex
    local _thisWasAStake="false"
    local _valueBuffer
    local _oldIFS=$IFS
    local _itemBuffer
    local _unixtime
    curl_result_global=${curl_result_global#'{'}
    curl_result_global=${curl_result_global%'}'}
    IFS='},{'
    for _itemBuffer in ${curl_result_global}; do
        if [[ ${_itemBuffer} == 'timereceived'* ]]; then
            _unixtime="${_itemBuffer#*':'}"
            if ([ ${_thisWasAStake} = "true" ] && [ ${_unixtime} -lt ${_oldestStakeDate} ]); then
                _oldestStakeDate=${_unixtime}
                _firstStakeIndex="${_i}"
            fi
            if ([ ${_thisWasAStake} = "true" ] && [ ${_unixtime} -gt ${_newestStakeDate} ]); then
                _newestStakeDate=${_unixtime}
            fi
            _unixtime=$(date -d "@$_unixtime" +%d-%m-%Y" at "%H:%M:%S)
            transactions_global[${_i}]=${_unixtime}
            _i=$((${_i}+1))
        elif [[ ${_itemBuffer} == 'category'* ]]; then
            _valueBuffer="${_itemBuffer#*':'}"
            _thisWasAStake="false"
            if [[ ${_valueBuffer} == 'receive' ]]; then
                transactions_global[${_i}]="${TEXT_RECEIVED}"
            elif [[ ${_valueBuffer} == 'generate' ]]; then
                transactions_global[${_i}]="${TEXT_STAKE}"
                _thisWasAStake="true"
            elif [[ ${_valueBuffer} == 'immature' ]]; then
                transactions_global[${_i}]="${TEXT_IMMATURE}"
            else
                transactions_global[${_i}]="${TEXT_TRANSFERRED}"
            fi
            _i=$((${_i}+1))
        elif [[ ${_itemBuffer} == 'address'* || ${_itemBuffer} == 'amount'* \
            || ${_itemBuffer} == 'confirmations'* || ${_itemBuffer} == 'txid'* ]]; then
            transactions_global[${_i}]="${_itemBuffer#*':'}"
            _i=$((${_i}+1))
        fi
    done
    IFS=${_oldIFS}
    if ([ "$1" = "full" ] && [ ${_oldestStakeDate} != ${_newestStakeDate} ] && [ ${_newestStakeDate} !=  "0" ]); then
        local _stakedAmount=0
        local _stakeCounter=0
        local _i
        local _dataTimeFrame=$((${_newestStakeDate} - ${_oldestStakeDate}))
        for ((_i=$(( ${_firstStakeIndex} + 1));_i<${#transactions_global[@]};_i=$(( ${_i} + 6)))); do
            if [ ${transactions_global[$_i+1]} = "${TEXT_STAKE}" ]; then
                _stakedAmount=$(echo "scale=8; ${_stakedAmount} + ${transactions_global[$_i+2]}" | bc)
                _stakeCounter=$(( ${_stakeCounter} + 1 ))
            fi
        done
        local _totalCoins=$(echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc)
        local _stakedCoinRate=$(echo "scale=16 ; $_stakedAmount / $_totalCoins" | bc)
        local _buff=$(echo "scale=16 ; ${_stakedCoinRate} + 1" | bc)
        local _buff2=$(echo "scale=16 ; 31536000 / ${_dataTimeFrame}" | bc)
        local _buff3=$(echo "scale=16 ; e(${_buff2}*l($_buff))" | bc -l)
        local _estCoinsY1=$(echo "scale=8 ; ${_buff3} * ${_totalCoins}" | bc)
        local _estGainY1=$(echo "scale=8 ; ${_estCoinsY1} - ${_totalCoins}" | bc)
        local _estStakingRatePerYear=$(echo "scale=2 ; ${_estGainY1} * 100 / ${_totalCoins}" | bc)
        _buff3=$(echo "scale=16 ; e(2*${_buff2}*l(${_buff}))" | bc -l)
        local _estCoinsY2=$(echo "scale=8 ; ${_buff3} * ${_totalCoins}" | bc)
        local _estGainY2=$(echo "scale=8 ; ${_estCoinsY2} - ${_totalCoins}" | bc)
        _buff3=$(echo "scale=16 ; e(3*${_buff2}*l(${_buff}))" | bc -l)
        local _estCoinsY3=$(echo "scale=8 ; ${_buff3} * ${_totalCoins}" | bc)
        local _estGainY3=$(echo "scale=8 ; ${_estCoinsY3} - ${_totalCoins}" | bc)
        _buff3=$(echo "scale=16 ; e(4*${_buff2}*l(${_buff}))" | bc -l)
        local _estCoinsY4=$(echo "scale=8 ; ${_buff3} * ${_totalCoins}" | bc)
        local _estGainY4=$(echo "scale=8 ; ${_estCoinsY4} - ${_totalCoins}" | bc)
        _buff3=$(echo "scale=16 ; e(5*${_buff2}*l(${_buff}))" | bc -l)
        local _estCoinsY5=$(echo "scale=8 ; ${_buff3} * ${_totalCoins}" | bc)
        local _estGainY5=$(echo "scale=8; ${_estCoinsY5} - ${_totalCoins}" | bc)
        _buff3=$(echo "scale=16 ; e(1/12*${_buff2}*l(${_buff}))" | bc -l)
        local _estCoinsM1=$(echo "scale=8 ; ${_buff3} * ${_totalCoins}" | bc)
        local _estGainM1=$(echo "scale=8; ${_estCoinsM1} - ${_totalCoins}" | bc)
        _buff3=$(echo "scale=16 ; e(1/2*${_buff2}*l(${_buff}))" | bc -l)
        local _estCoinsM6=$(echo "scale=8 ; ${_buff3} * ${_totalCoins}" | bc)
        local _estGainM6=$(echo "scale=8; ${_estCoinsM6} - ${_totalCoins}" | bc)
        _stakedAmount=$(echo "scale=8; ${_stakedAmount} + ${transactions_global[${_firstStakeIndex}-3]}" | bc)
        _stakeCounter=$(( ${_stakeCounter} + 1 ))
        staking_analysis[1]="analysis time frame for estimation"
        staking_analysis[2]=$(secToHumanReadable ${_dataTimeFrame})
        staking_analysis[3]="times wallet staked within the last 1000 transactions"
        staking_analysis[4]="${_stakeCounter}"
        staking_analysis[5]="total staking reward within the last 1000 transactions"
        staking_analysis[6]="${_stakedAmount}"
        staking_analysis[7]="total coins today"
        staking_analysis[8]="${_totalCoins}"
        staking_analysis[9]="est. staking reward rate per year"
        staking_analysis[10]="${_estStakingRatePerYear}"
        staking_analysis[11]="est. total coins in one month"
        staking_analysis[12]="${_estCoinsM1%.*}"
        staking_analysis[13]="est. staked coins in one month"
        staking_analysis[14]="${_estGainM1%.*}"
        staking_analysis[15]="est. total coins in six months"
        staking_analysis[16]="${_estCoinsM6%.*}"
        staking_analysis[17]="est. staked coins in six months"
        staking_analysis[18]="${_estGainM6%.*}"
        staking_analysis[19]="est. total coins in one year"
        staking_analysis[20]="${_estCoinsY1%.*}"
        staking_analysis[21]="est. staked coins in one year"
        staking_analysis[22]="${_estGainY1%.*}"
        staking_analysis[23]="est. total coins in two years"
        staking_analysis[24]="${_estCoinsY2%.*}"
        staking_analysis[25]="est. staked coins in two years"
        staking_analysis[26]="${_estGainY2%.*}"
        staking_analysis[27]="est. total coins in three years"
        staking_analysis[28]="${_estCoinsY3%.*}"
        staking_analysis[29]="est. staked coins in three years"
        staking_analysis[30]="${_estGainY3%.*}"
        staking_analysis[31]="est. total coins in four years"
        staking_analysis[32]="${_estCoinsY4%.*}"
        staking_analysis[33]="est. staked coins in four years"
        staking_analysis[34]="${_estGainY4%.*}"
        staking_analysis[35]="est. total coins in five years"
        staking_analysis[36]="${_estCoinsY5%.*}"
        staking_analysis[37]="est. staked coins in five years"
        staking_analysis[38]="${_estGainY5%.*}"
        for ((_i=0;_i <= ${#staking_analysis[@]};_i++)); do
            echo "${staking_analysis[$_i]}"
        done
        exit 1
    fi
}

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input:  $1  - optional var determing the text width (default: TEXTWIDTH_TRANS)
# Operating with:  $transactions_global
makeOutputTransactions() {
    local _textWidth
    if [ -z "$1" ]; then
        _textWidth="${TEXTWIDTH_TRANS}"
    else
        _textWidth="$1"
    fi
    for ((i=${#transactions_global[@]}-1;i >= 0;i=$(( $i - 6 )))); do
        echo $(fillLine "${transactions_global[$i-4]}: ${transactions_global[$i-3]}-_-${transactions_global[$i]}" \
                        "${_textWidth}")"\n"
        if (( ${_textWidth} >= 43 ));then
            echo $(fillLine "${TEXT_CONFIRMATIONS}: ${transactions_global[$i-2]}-_-${TEXT_ADDRESS}: ${transactions_global[$i-5]}" \
                            "${_textWidth}")"\n"
        else
            echo "${TEXT_CONFIRMATIONS}: ${transactions_global[$i-2]}\n"
        fi
        if (( ${_textWidth} >= 70 ));then
            echo $(fillLine "${TEXT_TXID}: ${transactions_global[$i-1]}" \
                            "${_textWidth}")"\n"
        fi
        echo "\n"
    done
}

# ============================================================================
# Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

# ============================================================================
# Simple error handling
# Input: $1 will be displayed as error msg
#        $2 exit status (errors are indicated
#           by an integer in the range 1 - 255).
# If no $2 is parsed the handler will just promp a dialog and continue,
# instead of prompting to terminal and exiting
errorHandling() {
    if [ -z "$2" ]; then
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
            _s+="${TEXT_GOODBYE_FEEDBACK_DAEMON_STILL_RUNNING}";;
        ${DIALOG_EXTRA})
            sudo service spectrecoind stop
            _s+="${TEXT_GOODBYE_FEEDBACK_DAEMON_STOPPED}";;
        ${DIALOG_CANCEL})
            refreshMainMenu_GUI;;
        *)
            errorHandling "${ERROR_GOODBYE_FATAL}" \
                          1;;
    esac
    _s+="\n\n${TEXT_GOODBYE_FEEDBACK_EXIT}"
    dialog --backtitle "${TITLE_BACK}" \
           --no-shadow \
           --colors \
           --title "${TITEL_GOODBYE}" \
           --ok-label "${BUTTON_LABEL_LEAVE}" \
           --msgbox  "${_s}" 0 0
    reset
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
# Gathers the data form the CURL result for the getinfo command
#
# Input: $1 - start (optional - default "0")
#        $2 - if "true" stakes will be displayed (optional - default "true")
viewAllTransactions() {
    local _start
    if [ -z "$1" ]; then
        _start="0"
    else
        _start="$1"
    fi
    local _displayStakes
    if [ -z "$2" ] || [ "$2" = "true" ]; then
        _displayStakes="true"
        _displayStakesButton="${BUTTON_LABEL_HIDE_STAKES}"
    else
        _displayStakes="false"
        _displayStakesButton="${BUTTON_LABEL_SHOW_STAKES}"
    fi
    calculateLayout
    if [ "${_displayStakes}" = "true" ]; then
        executeCURL "listtransactions" \
                    '"*",'"${COUNT_TRANS_VIEW},${_start}"',"1"'
    else
        executeCURL "listtransactions" \
                    '"*",'"${COUNT_TRANS_VIEW},${_start}"',"0"'
    fi
    getTransactions
    if [ ${#transactions_global[@]} -eq 0 ] && [ ${_start} -ge ${COUNT_TRANS_VIEW} ]; then
        viewAllTransactions "$(( ${_start} - ${COUNT_TRANS_VIEW} ))" \
                           "${_displayStakes}"
    fi
    local _page=$(( (${_start} / ${COUNT_TRANS_VIEW}) + 1 ))
    dialog --no-shadow \
        --begin 0 0 \
        --no-lines \
        --infobox "" "$(tput lines)" "$(tput cols)" \
        \
        --and-widget \
        --colors \
        --extra-button \
        --help-button \
        --title "${TITEL_VIEW_TRANSACTIONS} ${_page}" \
        --ok-label "${BUTTON_LABEL_PREVIOUS}" \
        --extra-label "${BUTTON_LABEL_NEXT}" \
        --help-label "${BUTTON_LABEL_MAIN_MENU}" \
        --cancel-label "${_displayStakesButton}" \
        --default-button 'extra' \
        --yesno "$(makeOutputTransactions $(( ${SIZE_X_TRANS_VIEW} - 4 )))" "${SIZE_Y_TRANS_VIEW}" "${SIZE_X_TRANS_VIEW}"
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_ESC})
            refreshMainMenu_DATA;;
        ${DIALOG_OK})
            if [[ ${_start} -ge ${COUNT_TRANS_VIEW} ]]; then
                viewAllTransactions $(( ${_start} - ${COUNT_TRANS_VIEW} )) \
                                   "${_displayStakes}"
            else
                viewAllTransactions "0" \
                                    "${_displayStakes}"
            fi;;
        ${DIALOG_EXTRA})
            viewAllTransactions $(( ${_start} + ${COUNT_TRANS_VIEW} )) \
                               "${_displayStakes}";;
        ${DIALOG_CANCEL})
            if [ "${_displayStakes}" = "true" ]; then
            viewAllTransactions "0" \
                                "false"
            else
            viewAllTransactions "0" \
                                "true"
            fi;;
        ${DIALOG_HELP})
            refreshMainMenu_DATA;;
    esac
    errorHandling "${ERROR_TRANS_FATAL}" \
                  1
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
    # ${info_global[8]} indicates if wallet is open
    if [ "${info_global[8]}" = "${TEXT_WALLET_HAS_NO_PW}" ]; then
        _cmdWallet="${CMD_MAIN_ENCRYPT_WALLET}"
        _explWalletStatus="${EXPL_CMD_MAIN_WALLETENCRYPT}"
    else
        _cmdWallet="${CMD_CHANGE_WALLET_PW}"
        _explWalletStatus="${EXPL_CMD_CHANGE_WALLET_PW}"
    fi
    exec 3>&1
    local _mainMenuPick=$(dialog --no-shadow \
        --begin 0 0 \
        --no-lines \
        --infobox "" "$(tput lines)" "$(tput cols)" \
        \
        --and-widget \
        --colors \
        --begin "${POS_Y_MENU}" "${POS_X_MENU}" \
        --title "${TITLE_ADV_MENU}" \
        --nocancel \
        --ok-label "${BUTTON_LABEL_ENTER}" \
        --no-shadow \
        --menu "" "${SIZE_Y_MENU}" "${SIZE_X_MENU}" 10 \
        \
        "${_cmdWallet}" "${_explWalletStatus}" \
        "${CMD_STAKING_ANALYSE}" "${EXPL_CMD_STAKING_ANALYSE}" \
        "${CMD_USER_COMMAND}" "${EXPL_CMD_USER_COMMAND}" \
        "${CMD_GET_PEER_INFO}" "${EXPL_CMD_GET_PEER_INFO}" \
        "${CMD_CHANGE_LANGUAGE}" "${EXPL_CMD_CHANGE_LANGUAGE}" \
        "${CMD_MAIN_MENU}" "${EXPL_CMD_MAIN_MENU}" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_ESC})
            refreshMainMenu_DATA;;
    esac
    case ${_mainMenuPick} in
        "${CMD_MAIN_ENCRYPT_WALLET}")
            sry;;
        "${CMD_CHANGE_WALLET_PW}")
            sry;;
        "${CMD_STAKING_ANALYSE}")
            sry;;
        "${CMD_SETUP_PI}")
            sry;;
        "${CMD_USER_COMMAND}")
            userCommandInput;;
        "${CMD_GET_PEER_INFO}")
            sry;;
        "${CMD_CHANGE_LANGUAGE}")
            sry;;
        "${CMD_MAIN_MENU}")
            refreshMainMenu_DATA;;
        *)
            errorHandling "${ERROR_ADVMENU_FATAL}" \
                          1;;
    esac
}

# ============================================================================
# Goal: Display the wallets addresses for the "Default Address"-account (equals default addr)
#
receiveCoins() {
    executeCURL "getaddressesbyaccount" "\"Default Address\""
    curl_result_global=${curl_result_global//','/'\n'}
    curl_result_global=${curl_result_global//'['/''}
    curl_result_global=${curl_result_global//']'/''}
    dialog --backtitle "${TITLE_BACK}" \
               --colors \
               --title "${TITEL_RECEIVE}" \
               --no-shadow \
               --infobox "${TEXT_FEEDBACK_RECEIVE}\n${curl_result_global}" 0 0
    read -s
    refreshMainMenu_GUI
}

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
    local _balance=$(echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc)
    if [[ ${_balance} == '.'* ]]; then
        _balance="0"${_balance}
    fi
    local _s="${TEXT_BALANCE}: ${_balance} ${TEXT_CURRENCY}\n"
          _s+="${TEXT_SEND_EXPL}\n"
          _s+="${TEXT_CLIPBOARD_HINT}"
    exec 3>&1
    _buffer=$(dialog --backtitle "${TITLE_BACK}" \
        --ok-label "${BUTTON_LABEL_SEND}" \
        --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
        --extra-button \
        --extra-label "${BUTTON_LABEL_ADDRESS_BOOK}" \
        --no-shadow --colors \
        --title "${TITEL_SEND}" \
        --form "${_s}" 0 0 0 \
        "${TEXT_SEND_DESTINATION_ADDRESS_EXPL}" 1 12 "" 1 11 -1 0 \
        "${TEXT_SEND_DESTINATION_ADDRESS}:" 2 1 "${_destinationAddress}" 2 11 35 0 \
        "${TEXT_SEND_AMOUNT_EXPL}" 4 12 "" 3 11 -1 0 \
        "${TEXT_SEND_AMOUNT}:" 5 1 "${_amount}" 5 11 20 0 \
        2>&1 1>&3)
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
        _i=0
        local _itemBuffer
        for _itemBuffer in ${_buffer}; do
            _i=$((_i+1))
            if [ ${_i} -eq 1 ]; then
            if [[ ${_itemBuffer} =~ ^[S][a-km-zA-HJ-NP-Z1-9]{25,33}$ ]]; then
                _destinationAddress="${_itemBuffer}"
            else
                errorHandling "${ERROR_SEND_INVALID_ADDRESS}"
                sendCoins
            fi
            elif [ ${_i} -eq 2 ]; then
                if [[ ${_itemBuffer} =~ ^[0-9]{0,8}[.]{0,1}[0-9]{0,8}$ ]] && [ 1 -eq "$(echo "${_itemBuffer} > 0" | bc)" ]; then
                    _amount=${_itemBuffer}
                    if [ "${info_global[8]}" == "${TEXT_WALLET_IS_UNLOCKED}" ]; then
                        # iff wallet is unlocked, we have to look it first
                        executeCURL "walletlock"
                    fi
                    if [ "${info_global[8]}" != "${TEXT_WALLET_HAS_NO_PW}" ]; then
                        passwordDialog "60" "false"
                    fi
                    executeCURL "sendtoaddress" "\"${_destinationAddress}\",${_amount}"
                    if [ "${info_global[8]}" != "${TEXT_WALLET_HAS_NO_PW}" ]; then
                        executeCURL "walletlock"
                    fi
                    if [ "${info_global[8]}" == "${TEXT_WALLET_IS_UNLOCKED}" ]; then
                        simpleMsg "${TEXT_SEND_UNLOCK_WALLET_AGAIN}" \
                                  "${BUTTON_LABEL_I_HAVE_UNDERSTOOD}"
                        unlockWalletForStaking
                    fi
                    refreshMainMenu_DATA
                else
                    errorHandling "${ERROR_SEND_INVALID_AMOUNT}"
                    sendCoins "${_destinationAddress}"
                fi
            fi
        done
        sendCoins "${_destinationAddress}";;
    esac
    errorHandling "${ERROR_SEND_FATAL}" \
                  1
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
    exec 3>&1
    local _wallet_password=$(dialog --backtitle "${TITLE_BACK}" \
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
# Goal: ask for a new wallet password
#       Password will never leave this function.
#
# Input $1 - title of the dialog
#
# Return: nothing
setWalletPW() {
    exec 3>&1
    local _buffer=$(dialog --backtitle "${TITLE_BACK}" \
                           --no-shadow \
                           --insecure \
                           --title "${TITLE_ENCRYPT_WALLET}" \
                           --ok-label "${BUTTON_LABEL_ENCRYPT}" \
                           --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
                           --mixedform "Note: Password must be at least 10 char long.\nEnter new wallet password:" 12 50 0 \
                                       "Password:" 1 1 "" 1 11 30 0 1 \
                                       "Retype:" 3 1 "" 3 11 30 0 1 \
                         2>&1 1>&3)
    exit_status=$?
    echo "exitstatus: ${exit_status}"
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            refreshMainMenu_GUI;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI;;
        ${DIALOG_OK})
            _i=0
            local _itemBuffer
            for _itemBuffer in ${_buffer}; do
                _i=$((_i+1))
                if [ ${_i} -eq 1 ]; then
                if [ ${#_itemBuffer} -ge 10 ]; then
                    _pw="${_itemBuffer}"
                else
                    local _s="\Z1You entered an invalid password.\Zn\n\n"
                        _s+="A valid wallet password must be in the form:"
                        _s+="\n- at least 10 char long"
                    errorHandling "${_s}"
                    setWalletPW
                fi
                elif [ ${_i} -eq 2 ]; then
                    if [ ${_itemBuffer} == ${_pw} ]; then
                        executeCURL "encryptwallet" "\"${_pw}\""
                        #walletpassphrasechange "oldpassphrase" "newpassphrase"
                        # maybe stops daemon?
                        sudo service spectrecoind stop
                        dialog --backtitle "${TITLE_BACK}" \
                               --no-shadow \
                               --colors \
                               --ok-label "${BUTTON_LABEL_RESTART_DAEMON}" \
                               --msgbox  "$TEXT_GOODBYE_FEEDBACK_DAEMON_STOPPED" 0 0
                        refreshMainMenu_DATA
                    else
                        local _s="Passwords do not match."
                        errorHandling "${_s}"
                        setWalletPW
                    fi
                fi
            done;;
        *)
            setWalletPW;;
        esac
        echo "error: ${exit_status}"
        exit 1
}

# ============================================================================
# This function provides a mask for the user to enter commands, that are
# send to the spectrecoind daemon. The result will then be displayed.
#
# Input: USER_DAEMON_COMMAND global var. that stores the last entered command
#        USER_DAEMON_PARAMS global var. that stores the last entered parameters
#
# Output: USER_DAEMON_COMMAND updated
#         USER_DAEMON_PARAMS updated
userCommandInput() {
    local _itemBuffer
    local _oldIFS=$IFS
    local _buffer
    IFS=','
    local _i=0
    for _itemBuffer in ${USER_DAEMON_PARAMS}; do
        _i=$((_i+1))
        if [ ${_i} -gt 1 ]; then
            _buffer+=' '
        fi
        _buffer+="${_itemBuffer}"
    done
    USER_DAEMON_PARAMS="${_buffer}"
    IFS=${_oldIFS}
    local _s="${TEXT_USERCOMMAND_EXPL}\n"
         _s+="${TEXT_CLIPBOARD_HINT}"
    exec 3>&1
    _buffer=$(dialog --backtitle "${TITLE_BACK}" \
        --ok-label "${BUTTON_LABEL_EXECUTE}" \
        --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
        --extra-button \
        --extra-label "${BUTTON_LABEL_HELP}" \
        --no-shadow --colors \
        --title "${TITEL_USERCOMMAND}" \
        --form "$_s" 0 0 0 \
        "${TEXT_USERCOMMAND_CMD_EXPL}" 1 12 "" 1 11 -1 0 \
        "${TEXT_USERCOMMAND_CMD}:" 2 1 "${USER_DAEMON_COMMAND}" 2 11 33 0 \
        "${TEXT_USERCOMMAND_PARAMS_EXPL}" 4 12 "" 3 11 -1 0 \
        "${TEXT_USERCOMMAND_PARAMS}:" 5 1 "${USER_DAEMON_PARAMS}" 5 11 65 0 \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            refreshMainMenu_GUI;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI;;
        ${DIALOG_EXTRA})
            executeCURL "help" ""
            curlUserFeedbackHandling
            userCommandInput;;
        ${DIALOG_OK})
            _i=0
            local _argContainsSpaces="false"
            unset USER_DAEMON_PARAMS
            for _itemBuffer in ${_buffer}; do
                _i=$((_i+1))
                if [ ${_i} -eq 1 ]; then
                    USER_DAEMON_COMMAND="${_itemBuffer}"
                else
                    if [ ${_i} -gt 2 ]; then
                        if [ ${_argContainsSpaces} != "true" ]; then
                            USER_DAEMON_PARAMS+=','
                        else
                            USER_DAEMON_PARAMS+=' '
                        fi
                    fi
                    if [ "${_itemBuffer}" != "true" ] \
                    && [ "${_itemBuffer}" != "false" ] \
                    && [[ ! ${_itemBuffer} =~ ^[0-9]+$ ]]; then
                        if [[ "${_itemBuffer}" != '"'* ]] && [ ${_argContainsSpaces} != "true" ]; then
                            USER_DAEMON_PARAMS+='"'
                        else
                            _argContainsSpaces="true"
                        fi
                        USER_DAEMON_PARAMS+="${_itemBuffer}"
                        if [[ "${_itemBuffer}" != *'"' ]] && [ ${_argContainsSpaces} != "true" ]; then
                            USER_DAEMON_PARAMS+='"'
                        elif [[ "${_itemBuffer}" == *'"' ]]; then
                            _argContainsSpaces="false"
                        fi
                    else
                        USER_DAEMON_PARAMS+="${_itemBuffer}"
                    fi
                fi
            done
            drawGauge "0" \
                      "${TEXT_GAUGE_DEFAULT}"
            executeCURL "${USER_DAEMON_COMMAND}" \
                        "${USER_DAEMON_PARAMS}"
            drawGauge "100" \
                      "${TEXT_GAUGE_ALLDONE}"
            curlUserFeedbackHandling
            userCommandInput;;
    esac
    errorHandling "${ERROR_USERCOMMAND_FATAL}" \
                  1
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
               --title "${TITEL_CURL_RESULT}" \
               --ok-label "${BUTTON_LABEL_CONTINUE}" \
               --no-shadow \
               --msgbox "${curl_result_global}" 0 0
    fi
}

# ============================================================================
# This function calculates global arrangement variables (i.e. for main menu).
calculateLayout() {
    local _max_buff
    POS_Y_MENU=0
    _max_buff=$(($(tput cols) / 2))
    if [ ${_max_buff} -lt 45 ] ; then
        _max_buff=45
    fi
    if [ ${_max_buff} -gt 60 ] ; then
        SIZE_X_MENU=60
    else
        SIZE_X_MENU=${_max_buff}
    fi
    SIZE_X_MENU=60
    SIZE_Y_MENU=13

    #Size for the displayed transactions in main menu
    _max_buff=$(($(tput cols) - ${SIZE_X_MENU}))
#    SIZE_X_TRANS=$((85<${_max_buff}?85:${_max_buff}))
    if [ ${_max_buff} -gt 85 ] ; then
        SIZE_X_TRANS=85
    else
        # if we do not have enough place just fuck it and tease by showing only left half
        if [ ${_max_buff} -lt 29 ]; then
            # hide transactions in main
            SIZE_X_TRANS=0
        else
            SIZE_X_TRANS=${_max_buff}
        fi
    fi

    SIZE_Y_TRANS=$(($(tput lines) - ${POS_Y_MENU}))

    # Size for the displayed info in main menu
    SIZE_X_INFO=${SIZE_X_MENU}
    _max_buff=$(($(tput lines) - ${POS_Y_MENU} - ${SIZE_Y_MENU}))
    if [ ${_max_buff} -gt 15 ] ; then
        SIZE_Y_INFO=15
    else
        SIZE_Y_INFO=${_max_buff}
    fi

    # Size for view all transactions dialog
    currentTPutCols=$(tput cols)
    if [ ${currentTPutCols} -gt 74 ] ; then
        SIZE_X_TRANS_VIEW=74
    else
        SIZE_X_TRANS_VIEW=${currentTPutCols}
    fi
    SIZE_Y_TRANS_VIEW=$(tput lines)

    POS_X_MENU=$(($(($(tput cols) - ${SIZE_X_MENU} - ${SIZE_X_TRANS})) / 2))
    POS_X_TRANS=$((${POS_X_MENU} + ${SIZE_X_MENU}))
    POS_Y_TRANS=${POS_Y_MENU}
    POS_X_INFO=${POS_X_MENU}
    POS_Y_INFO=$((${POS_Y_MENU} + ${SIZE_Y_MENU}))
    TEXTWIDTH_TRANS=$((${SIZE_X_TRANS} - 4))
    TEXTWIDTH_INFO=$((${SIZE_X_INFO} - 5))
    WIDTHTEXT_MENU=${TEXTWIDTH_INFO}
    #
    # Amount of transactions that can be displayed in main menu
    COUNT_TRANS_MENU=$(( ((${SIZE_Y_TRANS} - 5 - ${POS_Y_TRANS}) / 4) + 1 ))
    #
    # Amount of transactions that can be displayed in the view all transactions dialog
    COUNT_TRANS_VIEW=$(( ((${SIZE_Y_TRANS} - 7 - ${POS_Y_TRANS}) / 4) + 1 ))
    #


    # not used yet
    TEXTHIGHT_INFO=$(( ${SIZE_Y_INFO} - 2 ))

    if [ ${currentTPutCols} -gt 60 ] ; then
        SIZE_X_GAUGE=60
    else
        SIZE_X_GAUGE=${currentTPutCols}
    fi
    SIZE_Y_GAUGE=0
    #
}

# ============================================================================
# This function draws the main menu to the terminal
refreshMainMenu_GUI() {
    local _cmdWallet
    local _explWalletStatus
    # ${info_global[8]} indicates if wallet is open
    if [ "${info_global[8]}" = "${TEXT_WALLET_IS_UNLOCKED}" ]; then
        _cmdWallet="${CMD_MAIN_LOCK_WALLET}"
        _explWalletStatus="${EXPL_CMD_MAIN_WALLETLOCK}"
    elif [ "${info_global[8]}" = "${TEXT_WALLET_HAS_NO_PW}" ]; then
        _cmdWallet="${CMD_MAIN_ENCRYPT_WALLET}"
        _explWalletStatus="${EXPL_CMD_MAIN_WALLETENCRYPT}"
    else
        _cmdWallet="${CMD_MAIN_UNLOCK_WALLET}"
        _explWalletStatus="${EXPL_CMD_MAIN_WALLETUNLOCK}"
    fi
    exec 3>&1
    if [ ${SIZE_X_TRANS} -gt 0 ] ; then
        local _mainMenuPick=$(dialog --no-shadow \
            --begin 0 0 \
            --no-lines \
            --infobox "" "$(tput lines)" "$(tput cols)" \
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
            "${CMD_MAIN_RECEIVE}" "${EXPL_CMD_MAIN_RECEIVE}" \
            "${CMD_MAIN_ADVANCED_MENU}" "${EXPL_CMD_MAIN_ADVANCEDMENU}" \
            "${CMD_MAIN_QUIT}" "${EXPL_CMD_MAIN_EXIT}" \
            2>&1 1>&3)
    else
        local _mainMenuPick=$(dialog --no-shadow \
            --begin 0 0 \
            --no-lines \
            --infobox "" "$(tput lines)" "$(tput cols)" \
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
            "${CMD_MAIN_RECEIVE}" "${EXPL_CMD_MAIN_RECEIVE}" \
            "${CMD_MAIN_ADVANCED_MENU}" "${EXPL_CMD_MAIN_ADVANCEDMENU}" \
            "${CMD_MAIN_QUIT}" "${EXPL_CMD_MAIN_EXIT}" \
            2>&1 1>&3)
    fi
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_ESC})
            goodbye;;
    esac
    case ${_mainMenuPick} in
        "${CMD_MAIN_REFRESH}")
            refreshMainMenu_DATA;;
        "${CMD_MAIN_UNLOCK_WALLET}")
            unlockWalletForStaking;;
        "${CMD_MAIN_LOCK_WALLET}")
            lockWallet;;
        "${CMD_MAIN_ENCRYPT_WALLET}")
            # todo change with new dialog version
            sry;;
            #setWalletPW;;
        "${CMD_MAIN_TRANS}")
            viewAllTransactions;;
        "${CMD_MAIN_SEND}")
            sendCoins;;
        "${CMD_MAIN_RECEIVE}")
            receiveCoins;;
        "${CMD_MAIN_ADVANCED_MENU}")
            advancedmenu;;
        "${CMD_MAIN_QUIT}")
            goodbye;;
    esac
}

# ============================================================================
# Goal: Refresh the main menu - which means we must gather new data
# and redraw gui
refreshMainMenu_DATA() {
    # have to recalc layout since it might have changed
    # (needed for transactions amount to fetch)
    calculateLayout
    drawGauge "0" \
            "${TEXT_GAUGE_GET_STAKING_DATA}"
    executeCURL "getstakinginfo"
    drawGauge "15" \
            "${TEXT_GAUGE_PROCESS_STAKING_DATA}"
    getStakingInfo
    drawGauge "33" \
            "${TEXT_GAUGE_GET_INFO}"
    executeCURL "getinfo"
    drawGauge "48" \
            "${TEXT_GAUGE_PROCESS_INFO}"
    getInfo
    if [ ${SIZE_X_TRANS} -gt 0 ] ; then
        drawGauge "66" \
                "${TEXT_GAUGE_GET_TRANS}"
        executeCURL "listtransactions" '"*",'"${COUNT_TRANS_MENU}"',0,"1"'
        drawGauge "85" \
                "${TEXT_GAUGE_PROCESS_TRANS}"
        getTransactions
    fi
    drawGauge "100" \
            "${TEXT_GAUGE_ALLDONE}"
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
    if [ -z "${msg_global}" ]; then
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
    if [ "$rtc" -ne 0 ] ; then
        die 20 "Required tool '${_toolToCheck}' not found!"
    fi
}

while getopts h? option; do
    case ${option} in
        h|?) helpMe && exit 0;;
        *) die 90 "invalid option \"${OPTARG}\"";;
    esac
done

checkRequirement dialog
checkRequirement bc
checkRequirement curl

export NCURSES_NO_UTF8_ACS=1
printf '\033[8;29;134t'
initDaemonConfiguration
if [ $(tput lines) -lt 28 ] || [ $(tput cols) -lt 74 ]; then
    simpleMsg "${TITEL_SUGGESTION}" \
              "${TEXT_SUGGESTION_TO_INCREASE_TERMINAL_SIZE} 45x28.\n" \
              "${BUTTON_LABEL_CONTINUE}"
fi
message="\n"
message+="        Use at your own risc!!!\n\n"
message+="    Terminal: $(tput longname)\n"
message+="    Dialog $(dialog --version)\n"
message+="      Interface version: ${VERSION}\n"

simpleMsg "- --- === WARNING === --- -" \
          "${message}" \
          "${BUTTON_LABEL_I_HAVE_UNDERSTOOD}"

trap refreshMainMenu_DATA INT
while :; do
    refreshMainMenu_DATA
done
goodbye