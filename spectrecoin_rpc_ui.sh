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
# VERSION: 1.9alpha
# CREATED: 05-09-2018
# ============================================================================

VERSION='v1.9alpha'
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
    local _parameter1=$2
    curl_login="--user $RPCUSER:$RPCPASSWORD"
    curl_connection_parameters="-H content-type:text/plain; http://$IP:$PORT"
    curl_command="--silent --data-binary "
    curl_command+='{"jsonrpc":"1.0","id":"curltext","method":"'"$_action"'","params":['"$_parameter1"']}'
    curl_result_global=$( ${CURL} ${curl_login} ${curl_command} ${curl_connection_parameters} )
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
        s+='CURL="/usr/bin/curl"'"\n\n"
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
# starts the daemon (spectrecoind)
#
startDaemon() {
    printf "\nDaemon is not running.\n"
    printf "starting Daemon "'\e[0;32m'"(will take 1 min)"'\e[0m\n\n'"..."
    /usr/local/bin/spectrecoind '--daemon'
    sleep 60
    printf "\nall done.\nStarting Interface...\n"
    sleep .1
    refreshMainMenu_DATA
}

# ============================================================================
# Fills a string to a given length (filling is done where the marker -_- is)
# \Z1 etc color commands are ignored
#
# Input: $1 will be displayed as CURL response msg
fillLine() {
    local _output=$1
    # remove dialog color commands
    buff=${_output//'\Z'?/}
    # remove expander command
    buff=${buff//'-_-'/}
    len=${#buff}
    offset=$(( $2 - $len ))
    if [ ${offset} -ge 0 ]; then
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
    if [ $((_time / 31536000)) -gt 0 ];then
        timeHuman="$((_time / 31536000))y "
    fi
    if [ $((_time % 31536000 /604800)) -gt 0 ];then
        timeHuman+="$((_time % 31536000 /604800))w "
    fi
    if [ $((_time % 604800 /86400)) -gt 0 ];then
        timeHuman+="$((_time % 604800 /86400))d "
    fi
    if [ $((_time % 86400 /3600)) -gt 0 ];then
        timeHuman+="$((_time % 86400 /3600))h "
    fi
    if [ $((_time % 3600 /60)) -gt 0 ];then
        timeHuman+="$((_time % 3600 /60))m "
    fi
    if [ $((_time % 60)) -gt 0 ];then
        timeHuman+="$((_time % 60))s"
    fi
    echo "$timeHuman"
}

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $curl_result_global
# Outpunt: $info_global array
getInfo() {
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
    local _i=0
    local _oldIFS=$IFS
    local _itemBuffer
    local _time
    IFS=','
    for _itemBuffer in ${curl_result_global}; do
        if [[ ${_itemBuffer} == 'expectedtime:'* ]]; then
            _time="${_itemBuffer#*':'}"
            stakinginfo_global[_i]=$(secToHumanReadable ${_time})
            _i=$((_i+1))
        elif [[ ${_itemBuffer} == 'staking'* ]]; then
            if [ "${_itemBuffer#*':'}" == "true" ]; then
                stakinginfo_global[_i]="\Z4ON\Zn"
            else
                stakinginfo_global[_i]="\Z1OFF\Zn"
            fi
            _i=$((_i+1))
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
#        $1 - desired width the text should take
#        $2 - desired hight - not used yet
makeOutputInfo() {
    echo "Wallet Info\n"
    echo $(fillLine "Balance:-_-$(echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc) XSPEC" $1)"\n"
    echo $(fillLine "Stealth spectre coins:-_-\Z6${info_global[2]}\Zn" $1)"\n"

    echo "\nStaking Info\n"
    echo $(fillLine "Wallet unlocked: ${info_global[8]}-_-Staking: ${stakinginfo_global[0]}" $1)"\n"
    echo $(fillLine "Coins: \Z4${info_global[1]}\Zn-_-(\Z5${info_global[3]}\Zn aging)" $1)"\n"
    echo $(fillLine "Expected time: ${stakinginfo_global[1]}" $1)"\n"

    echo "\nClient info\n"
    echo $(fillLine "Daemon: ${info_global[0]}-_-Errors: ${info_global[9]}" $1)"\n"
    echo $(fillLine "IP: ${info_global[7]}-_-Peers: ${info_global[4]}" $1)"\n"
    echo $(fillLine "Download: ${info_global[5]}-_-Upload: ${info_global[6]}" $1)"\n"
}

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $curl_result_global
# Outpunt: $transactions_global array
#          $1  - if "full" a staking analysis is done
getTransactions() {
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
                transactions_global[_i]='\Z5STAKE_Pending\Zn'
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
# Input: $transactions_global
#        $1 - desired width the text should take
#        $2 - desired hight - not used yet
makeOutputTransactions() {
    for ((i=${#transactions_global[@]}-1;i >= 0;i=$(( $i - 6 )))); do
        echo $(fillLine "${transactions_global[$i-4]}: ${transactions_global[$i-3]}-_-${transactions_global[$i]}" $1)"\n"
        if (( $1 >= 43 ));then
            echo $(fillLine "confirmations: ${transactions_global[$i-2]}-_-address: ${transactions_global[$i-5]}" $1)"\n"
        else
            echo "confirmations: ${transactions_global[$i-2]}\n"
        fi
        if (( $1 >= 70 ));then
            echo $(fillLine "txid: ${transactions_global[$i-1]}" $1)"\n"
        fi
        echo "\n"
    done
}

# ============================================================================
# Define the dialog exit status codes
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_HELP=2
DIALOG_EXTRA=3
DIALOG_ITEM_HELP=4
DIALOG_ESC=255
DIALOG_TEXT_CONTINUE='Continue'
DIALOG_TEXT_OK='OK'
DIALOG_TEXT_ERROR='ERROR'

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
            --title "${DIALOG_TEXT_ERROR}" \
            --ok-label "${DIALOG_TEXT_CONTINUE}" \
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
# Simple goodbye checkbox, this marks the regular ending of the script
goodbye() {
    dialog --backtitle "$TITLE_BACK" \
        --no-shadow \
        --colors \
        --title "GOODBYE" \
        --ok-label 'Leave' \
        --msgbox  "\nHope you enjoyed.\n" 0 0
    reset
    exit 0
}

# ============================================================================
# Simple warning checkbox for the user at startup
welcomeMsg() {
    local _WARNING="\nUse at your own risc!!!\n\nYou are using Terminal: $(tput longname)\n\n\
    Interface version: $VERSION"
    dialog --backtitle "$TITLE_BACK" \
        --colors \
        --title "WARNING" \
        --ok-label 'YES - I´ve understood' \
        --no-shadow \
        --msgbox "$_WARNING" 0 0
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
    --ok-label "${DIALOG_TEXT_CONTINUE}" \
    --msgbox "$s" 0 0
    unset s
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
# Input: $1 - start
#        $2 - if "true" stakes will be displayed
viewAllTransactions() {
    local _start
    local _count=$(( ($(tput lines) - 4) / 4 ))
    if [ -z "$1" ]; then
        _start="0"
    else
        _start="$1"
    fi
    local _SIZEX=$((74<$(tput cols)?"74":$(tput cols)))
    local _SIZEY=$(tput lines)
    if [ $2 = "true" ]; then
        executeCURL "listtransactions" '"*",'${_count}','${_start}',"1"'
    else
        executeCURL "listtransactions" '"*",'${_count}','${_start}',"0"'
    fi
    getTransactions
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
        --cancel-label "$(viewAllTransactionsHelper "$2")" \
        --default-button 'extra' \
        --yesno "$(makeOutputTransactions $(( $_SIZEX - 4 )))" \
        "$_SIZEY" "$_SIZEX"
    exit_status=$?
    case ${exit_status} in
        ${DIALOG_ESC})
            refreshMainMenu_DATA
            ;;
        ${DIALOG_OK})
            if [[ ${_start} -ge 6 ]]; then
                viewAllTransactions $(( $_start - $_count )) $2
            else
                viewAllTransactions 0 $2
            fi
            ;;
        ${DIALOG_EXTRA})
            viewAllTransactions $(( $_start + $_count )) $2
            ;;
        ${DIALOG_CANCEL})
            if [ $2 = "true" ]; then
            viewAllTransactions "0" "false"
            else
            viewAllTransactions "0" "true"
            fi
            ;;
        ${DIALOG_HELP})
            refreshMainMenu_DATA
            ;;
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
        --no-shadow \
        --colors \
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
            refreshMainMenu_GUI
            ;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI
            ;;
        ${DIALOG_EXTRA})
            sry
            sendCoins "test1"
            ;;
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
                        if [ "${info_global[8]}" == "\Z4true\Zn" ]; then
                        # iff wallet is unlocked, we have to look it first
                        executeCURL "walletlock"
                        fi
                        if [ "${info_global[8]}" != "\Z1no PW\Zn" ]; then
                        passwordDialog "60" "false"
                        fi
                        executeCURL "sendtoaddress" "\"${_destinationAddress}\"" "${_amount}"
                        if [ "${info_global[8]}" != "\Z1no PW\Zn" ]; then
                        executeCURL "walletlock"
                        fi
                else
                    local _s="Amount must be a number, with:"
                    _s+="\n- greater than 0"
                    _s+="\n- max. 8 digits behind decimal point"
                    errorHandling "${_s}"
                    sendCoins "${_destinationAddress}"
                    fi
                fi
            done
            sendCoins "${_destinationAddress}"
            ;;
    esac
    refreshMainMenu_DATA
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
            refreshMainMenu_GUI
            ;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI
            ;;
    esac
    executeCURL "walletpassphrase" "\"$_wallet_password\",$1,$2"
    # literally nothing to do here since daemon responds is excellent
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
        --no-shadow \
        --colors \
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
            refreshMainMenu_GUI
            ;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI
            ;;
        ${DIALOG_EXTRA})
            executeCURL "help" ""
            curlUserFeedbackHandling
            userCommandInput
            ;;
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
            executeCURL "$USER_DAEMON_COMMAND" "$USER_DAEMON_PARAMS"
            curlUserFeedbackHandling
            userCommandInput
            ;;
    esac
}

# ============================================================================
# Simple output for any CURL command the user entered
curlUserFeedbackHandling() {
    if [[ "$curl_result_global" != '{"result":null'* ]]; then
        curl_result_global=${curl_result_global//','/'\n'}
#        curl_result_global=${curl_result_global//'}\n{'/'\n\n'}
        dialog \
            --backtitle "$TITLE_BACK" \
            --colors \
            --title "CURL result" \
            --ok-label "${DIALOG_TEXT_CONTINUE}" \
            --no-shadow \
            --msgbox "$curl_result_global" 0 0
    fi
}

# ============================================================================
# Helper function that decides whether if LOCK or UNLOCK will be displayed
#
# Input: $MENU_WALLET_UNLOCKED indicates if wallet is open
mainMenu_helper() {
    if [ "${info_global[8]}" = "\Z4true\Zn" ]; then
        echo 'Lock'
    elif [ "${info_global[8]}" = "\Z1no PW\Zn" ]; then
        echo 'Encrypt'
    else
        echo 'Unlock'
    fi
}

# ============================================================================
# This function draws the main menu to the terminal
refreshMainMenu_GUI() {
    local _max_buff
    POSY_MENU=0
    _max_buff=$(($(tput cols) / 2))
    _max_buff=$((45>$_max_buff?"45":$_max_buff))
    SIZEX_MENU=$((60<$_max_buff?"60":$_max_buff))
    SIZEY_MENU=13
    _max_buff=$(($(tput cols) - $SIZEX_MENU))
    SIZEX_TRANSACTIONS=$((85<$_max_buff?"85":$_max_buff))
    SIZEY_TRANSACTIONS=$(($(tput lines) - $POSY_MENU))
    SIZEX_INFO=${SIZEX_MENU}
    SIZEY_INFO=$(($(tput lines) - $POSY_MENU - $SIZEY_MENU))
    POSX_MENU=$(($(($(tput cols) - $SIZEX_MENU - $SIZEX_TRANSACTIONS)) / 2))
    POSX_TRANSACTIONS=$(($POSX_MENU + $SIZEX_MENU))
    POSY_TRANSACTIONS=${POSY_MENU}
    POSX_INFO=${POSX_MENU}
    POSY_INFO=$(($POSY_MENU + $SIZEY_MENU))
    TEXTWIDTH_TRANS=$(($SIZEX_TRANSACTIONS - 4))
    TEXTWIDTH_INFO=$(($SIZEX_INFO - 5))
    WIDTHTEXT_MENU=${TEXTWIDTH_INFO}
    TEXTHIGHT_TRANS=$(($(tput lines) - 2 - $POSY_TRANSACTIONS))
    TEXTHIGHT_INFO=$(($(tput lines) - 2 - $POSY_INFO - $SIZEY_MENU))
    TITLE_TRANSACTIONS='RECENT TRANSACTIONS'
    TITLE_INFO=''
    TITLE_MENU="$TITLE_BACK"
    exec 3>&1
    local _mainMenuPick=$(dialog --no-shadow \
        --begin 0 0 \
        --no-lines \
        --infobox "" "$(tput lines)" "$(tput cols)" \
        \
        --and-widget \
        --colors \
        --begin "$POSY_TRANSACTIONS" "$POSX_TRANSACTIONS" \
        --title "$TITLE_TRANSACTIONS" \
        --no-collapse \
        --infobox "$(makeOutputTransactions ${TEXTWIDTH_TRANS} ${TEXTHIGHT_TRANS})" "$SIZEY_TRANSACTIONS" "$SIZEX_TRANSACTIONS" \
        \
        --and-widget \
        --colors \
        --begin "$POSY_INFO" "$POSX_INFO" \
        --title "$TITLE_INFO" \
        --no-shadow \
        --no-collapse \
        --infobox "$(makeOutputInfo ${TEXTWIDTH_INFO} ${TEXTHIGHT_INFO})" "$SIZEY_INFO" "$SIZEX_INFO" \
        \
        --and-widget \
        --colors \
        --begin "$POSY_MENU" "$POSX_MENU" \
        --title "$TITLE_MENU" \
        --nocancel \
        --ok-label "Enter" \
        --no-shadow \
        --menu "" "$SIZEY_MENU" "$SIZEX_MENU" 10 \
        \
        Refresh "Update Interface" \
        $(mainMenu_helper) "Wallet for staking" \
        Transaktions "View all transactions" \
        Send "Send XSPEC from wallet" \
        Command "Sending commands to daemon" \
        Quit "Exit interface" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_ESC})
            goodbye
            ;;
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
            viewAllTransactions "0" "true";;
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
        errorHandling "$_s" 1
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
    passwordDialog "999999999" "true"
    refreshMainMenu_DATA
}

waitDialog(){
    echo "$1" | dialog --no-shadow \
        --title "Please wait" \
        --gauge "Getting data from daemon..." 7 70 0
}

# ============================================================================
# Goal: Refresh the main menu - which means we must gather new data
# and redraw gui
refreshMainMenu_DATA() {
    waitDialog "0"
    executeCURL "getstakinginfo"
    waitDialog "15"
    getStakingInfo
    waitDialog "33"
    executeCURL "getinfo"
    waitDialog "48"
    getInfo
    waitDialog "66"
    executeCURL "listtransactions" '"*",7,0,"1"'
    waitDialog "85"
    getTransactions
    waitDialog "100"
    refreshMainMenu_GUI
}

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

export NCURSES_NO_UTF8_ACS=1
printf '\033[8;29;134t'
TITLE_BACK="Spectrecoin Bash RPC Wallet Interface ($VERSION)"
readConfig ${SETTINGSFILE_TO_USE}
welcomeMsg
refreshMainMenu_DATA
goodbye
