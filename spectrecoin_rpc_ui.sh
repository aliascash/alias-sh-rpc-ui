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
# VERSION: 2.1alpha
# CREATED: 05-09-2018
# ============================================================================

VERSION='v2.1alpha'
SETTINGSFILE_TO_USE=script.conf

# Backup where we came from
callDir=$(pwd)
ownLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName=$(basename $0)
cd "${ownLocation}"
. include/helpers_console.sh
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
    -s <settingsfile>
        Settingsfile to use. File respectively its given path must be relative
        to the location where this script is located! Default: ${SETTINGSFILE_TO_USE}
    -h  Show this help

    "
}

# ============================================================================
# This function is the beating heart, it interacts via CURL with the daemon
# and optimizes it's output via the cutCURLresult function
#
# Input: $1 will be executed by the daemon as command
#        $2 params for the daemon command
#
# Output: global variable curl_result_global (clean and bash optimized)
executeCURL() {
    local _action=$1
    local _parameters=$2
    curl_result_global=$( ${CURL} \
                          --user "$RPCUSER:$RPCPASSWORD" \
                          --silent \
                          --data-binary \
                          "{\"jsonrpc\":\"1.0\",\"id\":\"curltext\",\"method\":\"$_action\",\"params\":[$_parameters]}" \
                          -H "content-type:text/plain;" \
                          "http://${IP}:${PORT}" )
    if [ -z "$curl_result_global" ]; then
        startDaemon
    fi
    # clean the result (curl_result_global) and optimize it for bash
    cutCURLresult
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
    if [[ ${curl_result_global} == *'"error":null,'* ]]; then
        # goal: cut the result string so only the real output is left
        # problem: there exist special results that are 2-dimensional
        if [[ "$curl_result_global" == '{"result":[{'* ]]; then
            #cut right side in case of 2-dim. result
            #cut left side in case of 2-dim. result
            curl_result_global="${curl_result_global%'}],"error"'*}"
            curl_result_global="${curl_result_global#*'":[{'}"
        elif [[ "$curl_result_global" == '{"result":{'* ]]; then
            #cut right side
            #cut left side
            curl_result_global="${curl_result_global%'},"error"'*}"
            curl_result_global="${curl_result_global#*'":{'}"
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
    elif [[ "$curl_result_global" == *'401 Unauthorized'* ]]; then
        # The RPC login failed - since the daemon responded it's due to a wrong login
        s="Error: RPC login failed. Check username and password in script.conf file.\n"
        s+="sample config could be:\n"
        s+='RPCUSER="spectrecoinrpc"'"\n"
        s+='RPCPASSWORD="44_char_pw_(lower_&_upper_letters_&_numbers)"'"\n"
        s+='IP="127.0.0.1"'"\n"
        s+='PORT="8332"'"\n"
        s+='CURL="curl"'"\n\n"
        s+="IMPORTANT: The login information must match the /.spectrecoin/spectrecoin.conf data."
        errorHandling "$s" 2
    else
        # Most likely a parsing error in the CURL command parameters
        # Just hand over the error msg. within the CURL reply
        # cut right side
        msg="${curl_result_global%%'"}'*}"
        # cut left side
        msg="${msg#*'message":"'}"
        errorHandling "CURL error message:\n\n$msg"
    fi
}

# ============================================================================
# Starts the daemon (spectrecoind)
#
startDaemon() {

    if (( $(ps -ef | grep -v grep | grep spectrecoind | wc -l) > 0 )) ; then
        printf "\nSpectrecoind already running!\n"
    else
        printf "\nSpectrecoind is not running.\n"
        printf "Starting Daemon "'\e[0;32m'"and waiting 1 minute"'\e[0m'"..."
        sudo service spectrecoind start
        sleep 60
        printf "\nAll done.\nStarting Interface...\n"
    fi
    sleep .1
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
    # remove dialog color commands
    buff=${_output//'\Z'?/}
    # remove expander command
    buff=${buff//'-_-'/}
    len=${#buff}
    offset=$(( $2 - $len ))
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
    IFS=','
    # if wallet is not encrypted
    info_global[8]="\Z1no PW\Zn"
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
                info_global[8]="\Z4true\Zn"
            else
                info_global[8]="false"
            fi
        elif [[ ${_itemBuffer} == 'errors'* ]]; then
            if [ "${_itemBuffer#*':'}" != "none" ]; then
                info_global[9]="\Z1""${_itemBuffer#*':'}""\Zn"
            else
                info_global[9]="${_itemBuffer#*':'}"
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
    IFS=','
    for _itemBuffer in ${curl_result_global}; do
        if [[ ${_itemBuffer} == 'staking'* ]]; then
            if [ "${_itemBuffer#*':'}" == "true" ]; then
                stakinginfo_global[0]="\Z4ON\Zn"
            else
                stakinginfo_global[0]="\Z1OFF\Zn"
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
# Input: $info_global
#        $stakinginfo_global
#        $balance_global
makeOutputInfo() {
    echo "Wallet Info\n"
    echo $(fillLine "Balance:-_-$(echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc) XSPEC" "${TEXTWIDTH_INFO}")"\n"
    echo $(fillLine "Stealth spectre coins:-_-\Z6${info_global[2]}\Zn" "${TEXTWIDTH_INFO}")"\n"

    echo "\nStaking Info\n"
    echo $(fillLine "Wallet unlocked: ${info_global[8]}-_-Staking: ${stakinginfo_global[0]}" "${TEXTWIDTH_INFO}")"\n"
    echo $(fillLine "Coins: \Z4${info_global[1]}\Zn-_-(\Z5${info_global[3]}\Zn aging)" "${TEXTWIDTH_INFO}")"\n"
    echo $(fillLine "Expected time: ${stakinginfo_global[1]}" "${TEXTWIDTH_INFO}")"\n"

    echo "\nClient info\n"
    echo $(fillLine "Daemon: ${info_global[0]}-_-Errors: ${info_global[9]}" "${TEXTWIDTH_INFO}")"\n"
    echo $(fillLine "IP: ${info_global[7]}-_-Peers: ${info_global[4]}" "${TEXTWIDTH_INFO}")"\n"
    echo $(fillLine "Download: ${info_global[5]}-_-Upload: ${info_global[6]}" "${TEXTWIDTH_INFO}")"\n"
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
            transactions_global[_i]=${_unixtime}
            _i=$((_i+1))
        elif [[ ${_itemBuffer} == 'category'* ]]; then
            _valueBuffer="${_itemBuffer#*':'}"
            _thisWasAStake="false"
            if [[ ${_valueBuffer} == 'receive' ]]; then
                transactions_global[_i]='\Z2RECEIVED\Zn'
            elif [[ ${_valueBuffer} == 'generate' ]]; then
                transactions_global[_i]='\Z4STAKE\Zn'
                _thisWasAStake="true"
            elif [[ ${_valueBuffer} == 'immature' ]]; then
                transactions_global[_i]='\Z5STAKE Pending\Zn'
            else
                transactions_global[_i]='\Z1TRANSFERRED\Zn'
            fi
            _i=$((_i+1))
        elif [[ ${_itemBuffer} == 'address'* || ${_itemBuffer} == 'amount'* \
            || ${_itemBuffer} == 'confirmations'* || ${_itemBuffer} == 'txid'* ]]; then
            transactions_global[_i]="${_itemBuffer#*':'}"
            _i=$((_i+1))
        fi
    done
    IFS=${_oldIFS}
    if ([ "$1" = "full" ] && [ ${_oldestStakeDate} != ${_newestStakeDate} ] && [ ${_newestStakeDate} !=  "0" ]); then
        local _stakedAmount=0
        local _stakeCounter=0
        local _i
        local _dataTimeFrame=$(($_newestStakeDate - $_oldestStakeDate))
        for ((_i=$(( $_firstStakeIndex + 1));_i<${#transactions_global[@]};_i=$(( $_i + 6)))); do
            if [ ${transactions_global[$_i+1]} = '\Z4STAKE\Zn' ]; then
                _stakedAmount=`echo "scale=8; $_stakedAmount + ${transactions_global[$_i+2]}" | bc`
                _stakeCounter=$(( $_stakeCounter + 1 ))
            fi
        done
        local _totalCoins=`echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc`
        local _stakedCoinRate=`echo "scale=16 ; $_stakedAmount / $_totalCoins" | bc`
        local _buff=`echo "scale=16 ; $_stakedCoinRate + 1" | bc`
        local _buff2=`echo "scale=16 ; 31536000 / $_dataTimeFrame" | bc`
        local _buff3=`echo "scale=16 ; e($_buff2*l($_buff))" | bc -l`
        local _estCoinsY1=`echo "scale=8 ; $_buff3 * $_totalCoins" | bc`
        local _estGainY1=`echo "scale=8 ; $_estCoinsY1 - $_totalCoins" | bc`
        local _estStakingRatePerYear=`echo "scale=2 ; $_estGainY1 * 100 / $_totalCoins" | bc`
        _buff3=`echo "scale=16 ; e(2*$_buff2*l($_buff))" | bc -l`
        local _estCoinsY2=`echo "scale=8 ; $_buff3 * $_totalCoins" | bc`
        local _estGainY2=`echo "scale=8 ; $_estCoinsY2 - $_totalCoins" | bc`
        _buff3=`echo "scale=16 ; e(3*$_buff2*l($_buff))" | bc -l`
        local _estCoinsY3=`echo "scale=8 ; $_buff3 * $_totalCoins" | bc`
        local _estGainY3=`echo "scale=8 ; $_estCoinsY3 - $_totalCoins" | bc`
        _buff3=`echo "scale=16 ; e(4*$_buff2*l($_buff))" | bc -l`
        local _estCoinsY4=`echo "scale=8 ; $_buff3 * $_totalCoins" | bc`
        local _estGainY4=`echo "scale=8 ; $_estCoinsY4 - $_totalCoins" | bc`
        _buff3=`echo "scale=16 ; e(5*$_buff2*l($_buff))" | bc -l`
        local _estCoinsY5=`echo "scale=8 ; $_buff3 * $_totalCoins" | bc`
        local _estGainY5=`echo "scale=8; $_estCoinsY5 - $_totalCoins" | bc`
        _buff3=`echo "scale=16 ; e(1/12*$_buff2*l($_buff))" | bc -l`
        local _estCoinsM1=`echo "scale=8 ; $_buff3 * $_totalCoins" | bc`
        local _estGainM1=`echo "scale=8; $_estCoinsM1 - $_totalCoins" | bc`
        _buff3=`echo "scale=16 ; e(1/2*$_buff2*l($_buff))" | bc -l`
        local _estCoinsM6=`echo "scale=8 ; $_buff3 * $_totalCoins" | bc`
        local _estGainM6=`echo "scale=8; $_estCoinsM6 - $_totalCoins" | bc`
        _stakedAmount=`echo "scale=8; $_stakedAmount + ${transactions_global[$_firstStakeIndex-3]}" | bc`
        _stakeCounter=$(( $_stakeCounter + 1 ))
        staking_analysis[1]="analysis time frame for estimation"
        staking_analysis[2]=$(secToHumanReadable ${_dataTimeFrame})
        staking_analysis[3]="times wallet staked within the last 1000 transactions"
        staking_analysis[4]="$_stakeCounter"
        staking_analysis[5]="total staking reward within the last 1000 transactions"
        staking_analysis[6]="$_stakedAmount"
        staking_analysis[7]="total coins today"
        staking_analysis[8]="$_totalCoins"
        staking_analysis[9]="est. staking reward rate per year"
        staking_analysis[10]="$_estStakingRatePerYear"
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
#         $transactions_global
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
            echo $(fillLine "confirmations: ${transactions_global[$i-2]}-_-address: ${transactions_global[$i-5]}" \
                            "${_textWidth}")"\n"
        else
            echo "confirmations: ${transactions_global[$i-2]}\n"
        fi
        if (( ${_textWidth} >= 70 ));then
            echo $(fillLine "txid: ${transactions_global[$i-1]}" \
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
        dialog --backtitle "$TITLE_BACK" \
               --colors \
               --title "$TITLE_ERROR" \
               --ok-label 'OK' \
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
    dialog --backtitle "$TITLE_BACK" \
           --no-shadow \
           --colors \
           --title "SRY" \
           --msgbox  "\nUnder construction...\n\nSry right now this is a placeholder." 0 0
    refreshMainMenu_GUI
}

# ============================================================================
# This marks the regular ending of the script
goodbye() {
    local _s=""
    dialog --no-shadow \
        --colors \
        --extra-button \
        --ok-label 'No, just leave' \
        --extra-label 'Yes, stop daemon' \
        --cancel-label 'Main Menu' \
        --default-button 'ok' \
        --yesno "\Z1If you plan to shutdown the system, daemon must be stopped before!\Zn\n\nDo you want to stop the daemon (no more staking) or just exit the UI?\n\n\Zn" 0 0
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_ESC})
            refreshMainMenu_GUI;;
        ${DIALOG_OK})
            _s+="\n\Z2Daemon is still running.\Zn\n";;
        ${DIALOG_EXTRA})
            sudo service spectrecoind stop
            _s+="\n\Z1Daemon stopped.\Zn\n";;
        ${DIALOG_CANCEL})
            refreshMainMenu_GUI;;
    esac
    _s+="\nHope you enjoyed.\n\n\Z4Please give feedback.\Zn\n"
    dialog --backtitle "$TITLE_BACK" \
           --no-shadow \
           --colors \
           --title "GOODBYE" \
           --ok-label 'Leave' \
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
    dialog --backtitle "$TITLE_BACK" \
        --colors \
        --title "$1" \
        --ok-label "$3" \
        --no-shadow \
        --msgbox "$2" 0 0
}

# ============================================================================
# Goal: Give a visual feedback for the user that the wallet is now locked
#       and there will be no staking anymore.
walletLockedFeedback() {
    local s="Wallet successfully locked."
          s+="\n\n\Z5You will not be able to stake anymore.\Zn\n\n"
          s+="Use Unlock in main menu to unlock the wallet for staking only again."
    dialog --backtitle "$TITLE_BACK" \
           --colors \
           --no-shadow \
           --ok-label 'Continue' \
           --msgbox "$s" 0 0
}

# ============================================================================
# decides whether if Hide Stakes or Show Stakes will be displayed
#
# Input: $1
viewAllTransactionsHelper() {
    if [ "$1" = "true" ]; then
        echo 'Hide Stakes'
    else
        echo 'Show Stakes'
    fi
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
    if [ -z "$2" ]; then
        _displayStakes="true"
    else
        _displayStakes="$2"
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
    if [ ${#transactions_global[@]} -eq 0 ]; then
        viewAllTransactions $(( ${_start} - ${COUNT_TRANS_VIEW} )) \
                           "${_displayStakes}"
    fi
    dialog --no-shadow \
        --begin 0 0 \
        --no-lines \
        --infobox "" "$(tput lines)" "$(tput cols)" \
        \
        --and-widget \
        --colors \
        --extra-button \
        --help-button \
        --ok-label 'Previous' \
        --extra-label 'Next' \
        --help-label 'Main Menu' \
        --cancel-label "$(viewAllTransactionsHelper "${_displayStakes}")" \
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
    errorHandling "Error while displaying transactions."
}

# ============================================================================
advancedMainMenu() {
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
  # encryptwallet
  # change password of wallet

# command execution  <-- add help command ( = help text zu bereits eingegeben command)

# back to main
    :
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
    local _s="Enter the destination address.\n"
        _s+="Use \Z6[CTRL]\Zn + \Z6[SHIFT]\Zn + \Z6[V]\Zn to copy from clipboard."
    exec 3>&1
    _buffer=$(dialog --backtitle "$TITLE_BACK" \
        --ok-label "Send" \
        --cancel-label "Main Menu" \
        --extra-button \
        --extra-label "Address Book" \
        --no-shadow --colors \
        --title "Send XSPEC" \
        --form "$_s" 0 0 0 \
        "Destination address" 1 12 "" 1 11 -1 0 \
        "Address:" 2 1 "${_destinationAddress}" 2 11 35 0 \
        "Amount of XSPEC" 4 12 "" 3 11 -1 0 \
        "Amount:" 5 1 "${_amount}" 5 11 20 0 \
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
                local _s="\Z1You entered an invalid address.\Zn\n\n"
                    _s+="A valid Spectrecoin address must be in the form:"
                    _s+="\n- beginning with \"S\""
                    _s+="\n- length 27-34"
                    _s+="\n- uppercase letter \"O\", \"I\", "
                    _s+="lowercase letter \"l\", and the number \"0\" "
                    _s+="are never used to prevent visual ambiguity"
                errorHandling "${_s}"
                sendCoins
            fi
            elif [ ${_i} -eq 2 ]; then
                if [[ ${_itemBuffer} =~ ^[0-9]{0,8}[.]{0,1}[0-9]{0,8}$ ]] && [ 1 -eq "$(echo "${_itemBuffer} > 0" | bc)" ]; then
                    _amount=${_itemBuffer}
                    if [ "${info_global[8]}" == "\Z4true\Zn" ]; then
                        # iff wallet is unlocked, we have to look it first
                        executeCURL "walletlock"
                    fi
                    if [ "${info_global[8]}" != "\Z1no PW\Zn" ]; then
                        passwordDialog "60" "false"
                    fi
                    executeCURL "sendtoaddress" "\"${_destinationAddress}\",${_amount}"
                    if [ "${info_global[8]}" != "\Z1no PW\Zn" ]; then
                        executeCURL "walletlock"
                    fi
                    simpleMsg "Notice" \
                    "\nPlease note:\nYou may have to 'unlock' the wallet for staking again.\n" \
                    'YES - I´ve understood'
                    refreshMainMenu_DATA
                else
                    local _s="Amount must be a number, with:"
                        _s+="\n- greater than 0"
                        _s+="\n- max. 8 digits behind decimal point"
                    errorHandling "${_s}"
                    sendCoins "${_destinationAddress}"
                fi
            fi
        done
        sendCoins "${_destinationAddress}";;
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
    exec 3>&1
    local _wallet_password=$(dialog --backtitle "$TITLE_BACK" \
        --no-shadow \
        --insecure \
        --passwordbox "Enter wallet password" 0 0  \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            refreshMainMenu_DATA
            ;;
        ${DIALOG_ESC})
            refreshMainMenu_DATA
            ;;
    esac
    executeCURL "walletpassphrase" "\"$_wallet_password\",$1,$2"
    # literally nothing to do here since daemon responds is excellent

    #encryptwallet "\"$_wallet_password\"
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
        _buffer+="$_itemBuffer"
    done
    USER_DAEMON_PARAMS="$_buffer"
    IFS=${_oldIFS}
    local _s="Here you can enter commands that will be send to the Daemon.\n"
    _s+="Use \Z6[CTRL]\Zn + \Z6[SHIFT]\Zn + \Z6[V]\Zn to copy from clipboard."
    exec 3>&1
    _buffer=$(dialog --backtitle "$TITLE_BACK" \
        --ok-label "Execute" \
        --cancel-label "Main Menu" \
        --extra-button \
        --extra-label "Help" \
        --no-shadow --colors \
        --title "Enter Command" \
        --form "$_s" 0 0 0 \
        "type help for info" 1 12 "" 1 11 -1 0 \
        "Command:" 2 1 "$USER_DAEMON_COMMAND" 2 11 33 0 \
        "seperated by spaces" 4 12 "" 3 11 -1 0 \
        "Parameter:" 5 1 "$USER_DAEMON_PARAMS" 5 11 65 0 \
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
                    USER_DAEMON_COMMAND="$_itemBuffer"
                else
                    if [ ${_i} -gt 2 ]; then
                        if [ ${_argContainsSpaces} != "true" ]; then
                            USER_DAEMON_PARAMS+=','
                        else
                            USER_DAEMON_PARAMS+=' '
                        fi
                    fi
                    if [ "$_itemBuffer" != "true" ] \
                    && [ "$_itemBuffer" != "false" ] \
                    && [[ ! ${_itemBuffer} =~ ^[0-9]+$ ]]; then
                        if [[ "$_itemBuffer" != '"'* ]] && [ ${_argContainsSpaces} != "true" ]; then
                            USER_DAEMON_PARAMS+='"'
                        else
                            _argContainsSpaces="true"
                        fi
                        USER_DAEMON_PARAMS+="$_itemBuffer"
                        if [[ "$_itemBuffer" != *'"' ]] && [ ${_argContainsSpaces} != "true" ]; then
                            USER_DAEMON_PARAMS+='"'
                        elif [[ "$_itemBuffer" == *'"' ]]; then
                            _argContainsSpaces="false"
                        fi
                    else
                        USER_DAEMON_PARAMS+="$_itemBuffer"
                    fi
                fi
            done
            drawGauge "0" \
                      "Getting data from daemon..."
            executeCURL "$USER_DAEMON_COMMAND" \
                        "$USER_DAEMON_PARAMS"
            drawGauge "100" \
                      "All done."
            curlUserFeedbackHandling
            userCommandInput;;
    esac
}

# ============================================================================
# Simple output for any CURL command the user entered
curlUserFeedbackHandling() {
    if [[ "$curl_result_global" != '{"result":null'* ]]; then
        curl_result_global=${curl_result_global//','/'\n'}
#        curl_result_global=${curl_result_global//'}\n{'/'\n\n'}
        dialog --backtitle "$TITLE_BACK" \
               --colors \
               --title "CURL result" \
               --ok-label 'Continue' \
               --no-shadow \
               --msgbox "$curl_result_global" 0 0
    fi
}

# ============================================================================
# Helper function that decides whether if LOCK, UNLOCK or ENCRYPT will be displayed
#
# Input: $MENU_WALLET_UNLOCKED indicates if wallet is open
mainMenu_helper_wallet_cmd() {
    if [ "${info_global[8]}" = "\Z4true\Zn" ]; then
        echo 'Lock'
    elif [ "${info_global[8]}" = "\Z1no PW\Zn" ]; then
        echo 'Encrypt'
    else
        echo 'Unlock'
    fi
}

# ============================================================================
# Helper function that decides what explaination text will be displayed
#
# Input: $MENU_WALLET_UNLOCKED indicates if wallet is open
mainMenu_helper_wallet_cmd_expl() {
    if [ "${info_global[8]}" = "\Z4true\Zn" ]; then
        echo "$EXPL_CMD_MAIN_WALLETLOCK"
    elif [ "${info_global[8]}" = "\Z1no PW\Zn" ]; then
        echo "$EXPL_CMD_MAIN_WALLETENCRYPT"
    else
        echo "$EXPL_CMD_MAIN_WALLETUNLOCK"
    fi
}

# ============================================================================
# This function calculates global arrangement variables (i.e. for main menu).
calculateLayout() {
    if [ $(tput lines) -lt 28 ] || [ $(tput cols) -lt 74 ]; then
        simpleMsg "Suggestion" \
                  "\nIncrease the terminal size to at least 45x28.\n" \
                  "OK"
    fi
    local _max_buff
    POS_Y_MENU=0
    _max_buff=$(($(tput cols) / 2))
#    _max_buff=$((45>${_max_buff}?45:${_max_buff}))
    if [ ${_max_buff} -lt 45 ] ; then
        _max_buff=45
    fi

#    SIZE_X_MENU=$((60<${_max_buff}?60:${_max_buff}))
    if [ ${_max_buff} -gt 60 ] ; then
        SIZE_X_MENU=60
    else
        SIZE_X_MENU=${_max_buff}
    fi

    SIZE_Y_MENU=13

    #Size for the displayed transactions in main menu
    _max_buff=$(($(tput cols) - ${SIZE_X_MENU}))
#    SIZE_X_TRANS=$((85<${_max_buff}?85:${_max_buff}))
    if [ ${_max_buff} -gt 85 ] ; then
        SIZE_X_TRANS=85
    else
        SIZE_X_TRANS=${_max_buff}
    fi


    SIZE_Y_TRANS=$(($(tput lines) - ${POS_Y_MENU}))

    # Size for the displayed info in main menu
    SIZE_X_INFO=${SIZE_X_MENU}
    _max_buff=$(($(tput lines) - ${POS_Y_MENU} - ${SIZE_Y_MENU}))
#    SIZE_Y_INFO=$((15<${_max_buff}?15:${_max_buff}))
    if [ ${_max_buff} -gt 15 ] ; then
        SIZE_Y_INFO=15
    else
        SIZE_Y_INFO=${_max_buff}
    fi

    # Size for view all transactions dialog
#    SIZE_X_TRANS_VIEW=$((74<$(tput cols)?74:$(tput cols)))
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
    # if we do not have enough place just fuck it and tease by showing only left half
    if [ ${SIZE_X_TRANS} -lt 29 ]; then
        SIZE_X_TRANS=29
    fi

    # not used yet
    TEXTHIGHT_INFO=$(( ${SIZE_Y_INFO} - 2 ))

#    SIZE_X_GAUGE=$((60<$(tput cols)?60:$(tput cols)))
    if [ ${currentTPutCols} -gt 60 ] ; then
        SIZE_X_GAUGE=60
    else
        SIZE_X_GAUGE=${currentTPutCols}
    fi
    SIZE_Y_GAUGE=0
    #
    TITLE_BACK="Spectrecoin Bash RPC Wallet Interface ($VERSION)"
    TITLE_TRANS='RECENT TRANSACTIONS'
    TITLE_INFO=''
    TITLE_MENU="$TITLE_BACK"
    TITLE_GAUGE="Please wait"
    TITLE_ERROR="ERROR"
    #
    EXPL_CMD_MAIN_EXIT="Exit interface"
    EXPL_CMD_MAIN_USERCOMMAND="Sending commands to daemon"
    EXPL_CMD_MAIN_SEND="Send XSPEC from wallet"
    EXPL_CMD_MAIN_VIEWTRANS="View all transactions"
    EXPL_CMD_MAIN_REFRESH="Update Interface"
    EXPL_CMD_MAIN_WALLETLOCK="Wallet, no more staking"
    EXPL_CMD_MAIN_WALLETUNLOCK="Wallet for staking only"
    EXPL_CMD_MAIN_WALLETENCRYPT="Wallet, provides Security"
}

# ============================================================================
# This function draws the main menu to the terminal
refreshMainMenu_GUI() {
    exec 3>&1
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
        --ok-label "Enter" \
        --no-shadow \
        --menu "" "${SIZE_Y_MENU}" "${SIZE_X_MENU}" 10 \
        \
        Refresh "$EXPL_CMD_MAIN_REFRESH" \
        "$(mainMenu_helper_wallet_cmd)" "$(mainMenu_helper_wallet_cmd_expl)" \
        Transaktions "$EXPL_CMD_MAIN_VIEWTRANS" \
        Send "$EXPL_CMD_MAIN_SEND" \
        Command "$EXPL_CMD_MAIN_USERCOMMAND" \
        Quit "$EXPL_CMD_MAIN_EXIT" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_ESC})
            goodbye;;
    esac
    case ${_mainMenuPick} in
        Refresh)
            refreshMainMenu_DATA;;
        Unlock)
            unlockWalletForStaking;;
        Lock)
            lockWallet;;
        Encrypt)
            sry;;
        Transaktions)
            viewAllTransactions;;
        Send)
            sendCoins;;
        Command)
            userCommandInput;;
        Quit)
            goodbye;;
    esac
}

# ============================================================================
# Reading script.conf to get values RPCUSER, RPCPASSWORD, IP, PORT, CURL
#
# Input: $1 [optional] The filepath can be parsed as parameter
readConfig() {
    local _file=$1
    if [ ! -f "$_file" ]; then
        local _s="Config file for this interface missing. The file '$_file' was not found."
        errorHandling "$_s" \
                      "1"
    fi
    . ${_file}
}

# ============================================================================
# Goal: lock the wallet
lockWallet() {
    executeCURL "walletlock"
    walletLockedFeedback
    refreshMainMenu_DATA
}

# ============================================================================
# Goal: unlock the wallet for staking only
unlockWalletForStaking() {
    passwordDialog "999999999" \
                   "true"
    refreshMainMenu_DATA
}

# ============================================================================
# Goal: draw a gauge to give user feedback
# Input $1 - amount the gauge will display integer (0-100)
#       $2 - text in the gauge box
drawGauge() {
    echo "$1" | dialog --no-shadow \
                       --title "$TITLE_GAUGE" \
                       --gauge "$2" "${SIZE_Y_GAUGE}" "${SIZE_X_GAUGE}" 0
}

# ============================================================================
# Goal: Refresh the main menu - which means we must gather new data
# and redraw gui
refreshMainMenu_DATA() {
    # have to recalc layout since it might have changed
    # (needed for transactions amount to fetch)
    calculateLayout
    drawGauge "0" \
            "Getting staking data from daemon..."
    executeCURL "getstakinginfo"
    drawGauge "15" \
            "Processing staking data..."
    getStakingInfo
    drawGauge "33" \
            "Getting general info data from daemon..."
    executeCURL "getinfo"
    drawGauge "48" \
            "Processing general info data..."
    getInfo
    drawGauge "66" \
            "Getting transactions data from daemon..."
    executeCURL "listtransactions" '"*",'"$COUNT_TRANS_MENU"',0,"1"'
    drawGauge "85" \
            "Processing transactions data..."
    getTransactions
    drawGauge "100" \
            "All done."
    refreshMainMenu_GUI
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

while getopts s:h? option; do
    case ${option} in
        s) SETTINGSFILE_TO_USE="${OPTARG}";;
        h|?) helpMe && exit 0;;
        *) die 90 "invalid option \"${OPTARG}\"";;
    esac
done

checkRequirement dialog
checkRequirement bc
checkRequirement curl

export NCURSES_NO_UTF8_ACS=1
printf '\033[8;29;134t'
readConfig ${SETTINGSFILE_TO_USE}

message="\n"
message+="        Use at your own risc!!!\n"
message+="    Terminal: $(tput longname)\n"
message+="      Interface version: $VERSION\n"

simpleMsg "- --- === WARNING === --- -" \
          "${message}" \
          'YES - I´ve understood'

refreshMainMenu_DATA
goodbye
