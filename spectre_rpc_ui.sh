#!/bin/bash
# ============================================================================
#
# FILE: spectre_rpc_ui.sh
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
# VERSION: 1.8alpha
# CREATED: 26-08-2018
# ============================================================================

# ============================================================================
# This function is the beating heart, it interacts via CURL with the daemon
# and optimizes it's output via the cutCURLresult function
#
# Input: $1 will be executed by the daemon as command
#        $2 params for the daemon command
#        $3 optional parameter to indicate if this was done in the user
#           command mask ($3="u") - in this case we will just display the
#           result and do not update the UI (except in case of wallet lock/unlock)
#
# Output: global variable curl_result_global (clean and bash optimized)
executeCURL() {
    local _action=$1
    local _parameter1=$2
    local _parameter2=$3
    curl_login="--user $RPCUSER:$RPCPASSWORD"
    curl_connection_parameters="-H content-type:text/plain; http://$IP:$PORT"
    curl_command="--silent --data-binary "
    curl_command+='{"jsonrpc":"1.0","id":"curltext","method":"'"$_action"'","params":['"$_parameter1"']}'
    curl_result_global=$( ${CURL} ${curl_login} ${curl_command} ${curl_connection_parameters} )
    # clean the result (curl_result_global) and optimize it for bash
    cutCURLresult
    if [ "$_action" = "listtransactions" ] && [ "$_parameter2" != "u" ]; then
        getTransactions
    elif [ "$_action" = "getinfo" ] && [ "$_parameter2" != "u" ]; then
        getInfo
    elif [ "$_action" = "getstakinginfo" ] && [ "$_parameter2" != "u" ]; then
        getStakingInfo
    elif [ "$_action" = "walletlock" ]; then
        # no error occurred, since cutCURLresult checked it
        walletLockedFeedback
    elif [ "$_action" = "walletpassphrase" ]; then
        # no error occurred, since cutCURLresult checked it
        : # literally nothing to do here since daemon responds is excellent
    else
        # User command
        # let's display the result of the user command, if there is any
        # if we had a CURL error the msg was already displayed
        if [[ "$curl_result_global" != '{"result":null'* ]]; then
            curl_result_global=${curl_result_global//','/'\n'}
#            curl_result_global=${curl_result_global//'}\n{'/'\n\n'}
            curlFeedbackHandling "$curl_result_global"
        fi
    fi
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
        # typically the wallet daemon gives feedback about errors within the daemon
        # if there was no error, just display none instead of ""
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
            _i=$(( $_i + 1 ))
        done
    else
        filler='\n'
    fi
    output=${output//'-_-'/"$filler"}
    echo ${output}
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
    unset info_global
    local i=0
    local oldIFS=$IFS
    local itemBuffer
    local unixtime
    export IFS=','
    for itemBuffer in $curl_result_global; do
        if [[ $itemBuffer == 'unlocked_until:'* ]]; then
            unixtime="${itemBuffer#*':'}"
            if [ "$unixtime" -gt 0 ]; then
                info_global[i]="\Z4true\Zn"
                MENU_WALLET_UNLOCKED="true"
            else
                info_global[i]="false"
                MENU_WALLET_UNLOCKED="false"
            fi
            i=$(( $i + 1 ))
        elif [[ $itemBuffer == 'errors'* ]]; then
            if [ "${itemBuffer#*':'}" != "none" ]; then
                info_global[i]="\Z1""${itemBuffer#*':'}""\Zn"
            else
                info_global[i]="${itemBuffer#*':'}"
            fi
            i=$(( $i + 1 ))
        elif [[ $itemBuffer == 'version'* || $itemBuffer == *'balance'* || \
            $itemBuffer == 'stake'* || $itemBuffer == 'connections'* || \
            $itemBuffer == 'data'* || $itemBuffer == 'ip'* ]]; then
            info_global[i]="${itemBuffer#*':'}"
            i=$(( $i + 1 ))
        fi
    done
    IFS=$oldIFS
    unset oldIFS
    unset unixtime
    unset curl_result_global
    unset itemBuffer
    unset i
}

getStakingInfo() {
    unset stakinginfo_global
    local i=0
    local oldIFS=$IFS
    local itemBuffer
    local time
    export IFS=','
    for itemBuffer in $curl_result_global; do
        if [[ $itemBuffer == 'expectedtime:'* ]]; then
            time="${itemBuffer#*':'}"
            stakinginfo_global[i]=$(secToHumanReadable $time)
            i=$(( $i + 1 ))
        elif [[ $itemBuffer == 'staking'* ]]; then
            if [ "${itemBuffer#*':'}" == "true" ]; then
                stakinginfo_global[i]="\Z4ON\Zn"
            else
                stakinginfo_global[i]="\Z1OFF\Zn"
            fi
            i=$(( $i + 1 ))
        fi
    done
    IFS=$oldIFS
    unset oldIFS
    unset time
    unset curl_result_global
    unset itemBuffer
    unset i
}

makeOutputInfo() {
    echo "Wallet Info\n"
    echo $(fillLine "Balance:-_-`echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc` XSPEC" $1)"\n"
    echo $(fillLine "Stealth spectre coins:-_-\Z6${info_global[2]}\Zn" $1)"\n"
    echo "\nStaking Info\n"
    echo $(fillLine "Wallet unlocked: ${info_global[8]}-_-Staking: ${stakinginfo_global[0]}" $1)"\n"
    echo $(fillLine "Coins: \Z4${info_global[1]}\Zn-_-(\Z5${info_global[3]}\Zn aging)" $1)"\n"
    echo $(fillLine "Expected time: ${stakinginfo_global[1]}" $1)"\n"
    echo "\nClient info\n"
    echo $(fillLine "Deamon: ${info_global[0]}-_-Errors: ${info_global[9]}" $1)"\n"
    echo $(fillLine "IP: ${info_global[7]}-_-Peers: ${info_global[4]}" $1)"\n"
    echo $(fillLine "Download: ${info_global[5]}-_-Upload: ${info_global[6]}" $1)"\n"
}

getTransactions() {
    unset transactions_global
    local i=0
    local oldestStakeDate=9999999999
    local newestStakeDate=0
    local firstStakeIndex
    local thisWasAStake="false"
    local valueBuffer
    local oldIFS=$IFS
    local itemBuffer
    local unixtime
    export IFS='},{'
    for itemBuffer in $curl_result_global; do
        if [[ $itemBuffer == 'timereceived'* ]]; then
            unixtime="${itemBuffer#*':'}"
            if ([ $thisWasAStake = "true" ] && [ $unixtime -lt $oldestStakeDate ]); then
                oldestStakeDate=$unixtime
                firstStakeIndex="$i"
            fi
            if ([ $thisWasAStake = "true" ] && [ $unixtime -gt $newestStakeDate ]); then
                newestStakeDate=$unixtime
            fi
            unixtime=$(date -d "@$unixtime" +%d-%m-%Y" at "%H:%M:%S)
            transactions_global[i]=$unixtime
            i=$(( $i + 1 ))
        elif [[ $itemBuffer == 'category'* ]]; then
            valueBuffer="${itemBuffer#*':'}"
            thisWasAStake="false"
            if [[ $valueBuffer == 'receive' ]]; then
                transactions_global[i]='\Z2RECEIVED\Zn'
            elif [[ $valueBuffer == 'generate' ]]; then
                transactions_global[i]='\Z4STAKE\Zn'
                thisWasAStake="true"
            elif [[ $valueBuffer == 'immature' ]]; then
                transactions_global[i]='\Z5STAKE_Pending\Zn'
            else
                transactions_global[i]='\Z1TRANSFERRED\Zn'
            fi
            i=$(( $i + 1 ))
        elif [[ $itemBuffer == 'address'* || $itemBuffer == 'amount'* \
            || $itemBuffer == 'confirmations'* || $itemBuffer == 'txid'* ]]; then
            transactions_global[i]="${itemBuffer#*':'}"
            i=$(( $i + 1 ))
        fi
    done
    IFS=$oldIFS
    unset oldIFS
    unset unixtime
    unset thisWasAStake
    unset curl_result_global
    unset itemBuffer
    unset valueBuffer
    unset i
    if ([ "$1" = "full" ] && [ $oldestStakeDate != $newestStakeDate ] && [ $newestStakeDate !=  "0" ]); then
        local stakedAmount=0
        local stakeCounter=0
        local i
        local dataTimeFrame=$(($newestStakeDate - $oldestStakeDate))
        for ((i=$(( $firstStakeIndex + 1));i<${#transactions_global[@]};i=$(( $i + 6)))); do
            if [ ${transactions_global[$i+1]} = '\Z4STAKE\Zn' ]; then
                stakedAmount=`echo "scale=8; $stakedAmount + ${transactions_global[$i+2]}" | bc`
                stakeCounter=$(( $stakeCounter + 1 ))
            fi
        done
        local totalCoins=`echo "scale=8 ; ${info_global[1]}+${info_global[3]}" | bc`
        local stakedCoinRate=`echo "scale=16 ; $stakedAmount / $totalCoins" | bc`
        local buff=`echo "scale=16 ; $stakedCoinRate + 1" | bc`
        local buff2=`echo "scale=16 ; 31536000 / $dataTimeFrame" | bc`
        local buff3=`echo "scale=16 ; e($buff2*l($buff))" | bc -l`
        local estCoinsY1=`echo "scale=8 ; $buff3 * $totalCoins" | bc`
        local estGainY1=`echo "scale=8 ; $estCoinsY1 - $totalCoins" | bc`
        local estStakingRatePerYear=`echo "scale=2 ; $estGainY1 * 100 / $totalCoins" | bc`
        buff3=`echo "scale=16 ; e(2*$buff2*l($buff))" | bc -l`
        local estCoinsY2=`echo "scale=8 ; $buff3 * $totalCoins" | bc`
        local estGainY2=`echo "scale=8 ; $estCoinsY2 - $totalCoins" | bc`
        buff3=`echo "scale=16 ; e(3*$buff2*l($buff))" | bc -l`
        local estCoinsY3=`echo "scale=8 ; $buff3 * $totalCoins" | bc`
        local estGainY3=`echo "scale=8 ; $estCoinsY3 - $totalCoins" | bc`
        buff3=`echo "scale=16 ; e(4*$buff2*l($buff))" | bc -l`
        local estCoinsY4=`echo "scale=8 ; $buff3 * $totalCoins" | bc`
        local estGainY4=`echo "scale=8 ; $estCoinsY4 - $totalCoins" | bc`
        buff3=`echo "scale=16 ; e(5*$buff2*l($buff))" | bc -l`
        local estCoinsY5=`echo "scale=8 ; $buff3 * $totalCoins" | bc`
        local estGainY5=`echo "scale=8; $estCoinsY5 - $totalCoins" | bc`
        buff3=`echo "scale=16 ; e(1/12*$buff2*l($buff))" | bc -l`
        local estCoinsM1=`echo "scale=8 ; $buff3 * $totalCoins" | bc`
        local estGainM1=`echo "scale=8; $estCoinsM1 - $totalCoins" | bc`
        buff3=`echo "scale=16 ; e(1/2*$buff2*l($buff))" | bc -l`
        local estCoinsM6=`echo "scale=8 ; $buff3 * $totalCoins" | bc`
        local estGainM6=`echo "scale=8; $estCoinsM6 - $totalCoins" | bc`
        stakedAmount=`echo "scale=8; $stakedAmount + ${transactions_global[$firstStakeIndex-3]}" | bc`
        stakeCounter=$(( $stakeCounter + 1 ))
        unset oldestStakeDate
        unset newestStakeDate
        unset firstStakeIndex
        staking_analysis[1]="analysis time frame for estimation"
        staking_analysis[2]=$(secToHumanReadable $dataTimeFrame)
        staking_analysis[3]="times wallet staked within the last 1000 transactions"
        staking_analysis[4]="$stakeCounter"
        staking_analysis[5]="total staking reward within the last 1000 transactions"
        staking_analysis[6]="$stakedAmount"
        staking_analysis[7]="total coins today"
        staking_analysis[8]="$totalCoins"
        staking_analysis[9]="est. staking reward rate per year"
        staking_analysis[10]="$estStakingRatePerYear"
        staking_analysis[11]="est. total coins in one month"
        staking_analysis[12]="${estCoinsM1%.*}"
        staking_analysis[13]="est. staked coins in one month"
        staking_analysis[14]="${estGainM1%.*}"
        staking_analysis[15]="est. total coins in six months"
        staking_analysis[16]="${estCoinsM6%.*}"
        staking_analysis[17]="est. staked coins in six months"
        staking_analysis[18]="${estGainM6%.*}"
        staking_analysis[19]="est. total coins in one year"
        staking_analysis[20]="${estCoinsY1%.*}"
        staking_analysis[21]="est. staked coins in one year"
        staking_analysis[22]="${estGainY1%.*}"
        staking_analysis[23]="est. total coins in two years"
        staking_analysis[24]="${estCoinsY2%.*}"
        staking_analysis[25]="est. staked coins in two years"
        staking_analysis[26]="${estGainY2%.*}"
        staking_analysis[27]="est. total coins in three years"
        staking_analysis[28]="${estCoinsY3%.*}"
        staking_analysis[29]="est. staked coins in three years"
        staking_analysis[30]="${estGainY3%.*}"
        staking_analysis[31]="est. total coins in four years"
        staking_analysis[32]="${estCoinsY4%.*}"
        staking_analysis[33]="est. staked coins in four years"
        staking_analysis[34]="${estGainY4%.*}"
        staking_analysis[35]="est. total coins in five years"
        staking_analysis[36]="${estCoinsY5%.*}"
        staking_analysis[37]="est. staked coins in five years"
        staking_analysis[38]="${estGainY5%.*}"
        unset totalCoins
        unset dataTimeFrame
        unset stakeCounter
        unset stakedAmount
        unset stakedCoinRate
        unset estStakingRatePerYear
        unset estCoinsY1
        unset estGainY1
        unset estCoinsY2
        unset estGainY2
        unset estCoinsY3
        unset estGainY3
        unset estCoinsY4
        unset estGainY4
        unset estCoinsY5
        unset estGainY5
        unset estCoinsM1
        unset estGainM1
        unset estCoinsM6
        unset estGainM6
        for ((i=0;i <= ${#staking_analysis[@]};i++)); do
            echo "${staking_analysis[$i]}"
        done
        exit 1
    fi
}

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

: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

errorHandling() {
    if [ -z "$2" ]; then
        dialog --backtitle "$TITLE_BACK" \
            --colors \
            --title "ERROR" \
            --ok-label 'Continue' \
            --no-shadow \
            --msgbox "$1" 0 0
    else
        echo "$1"
        exit "$2"
    fi
}

sry() {
    dialog --backtitle "$TITLE_BACK" \
        --no-shadow \
        --colors \
        --title "SRY" \
        --msgbox  "\nUnder construction...\n\nSry right now this is a placeholder." 0 0
    refreshMainMenu_GUI
}

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

warning() {
    WARNING="\nUse at your own risc!!!\n\nYou are using Terminal: $(tput longname)\n\n\
    Interface version: $VERSION"
    dialog --backtitle "$TITLE_BACK" \
        --colors \
        --title "WARNING" \
        --ok-label 'YES - I´ve understood' \
        --no-shadow \
        --msgbox "$WARNING" 0 0
}

walletLockedFeedback() {
    local s="Wallet successfully locked."
    s+="\n\n\Z5You will not be able to stake anymore.\Zn\n\n"
    s+="Use Unlock in main menu to unlock the wallet for staking only again."
    dialog --backtitle "$TITLE_BACK" --colors --no-shadow \
    --ok-label 'Continue' --msgbox "$s" 0 0
    unset s
}

viewAllTransactionsHelper() {
    if [ "$1" = "true" ]; then
        echo 'Hide Stakes'
    else
        echo 'Show Stakes'
    fi
}

viewAllTransactions() {
    local start
    local count=$(( ($(tput lines) - 4) / 4 ))
    if [ -z "$1" ]; then
        start="0"
    else
        start="$1"
    fi
    local SIZEX=$((74<$(tput cols)?"74":$(tput cols)))
    local SIZEY=$(tput lines)
    if [ $2 = "true" ]; then
        executeCURL "listtransactions" '"*",'$count','$start',"1"'
    else
        executeCURL "listtransactions" '"*",'$count','$start',"0"'
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
        --cancel-label "$(viewAllTransactionsHelper "$2")" \
        --default-button 'extra' \
        --yesno "$(makeOutputTransactions $(( $SIZEX - 4 )))" \
        "$SIZEY" "$SIZEX"
    exit_status=$?
    case $exit_status in
        $DIALOG_ESC)
            refreshMainMenu_DATA
            ;;
        $DIALOG_OK)
            if [[ $start -ge 6 ]]; then
                viewAllTransactions $(( $start - $count )) $2
            else
                viewAllTransactions 0 $2
            fi
            ;;
        $DIALOG_EXTRA)
            viewAllTransactions $(( $start + $count )) $2
            ;;
        $DIALOG_CANCEL)
            if [ $2 = "true" ]; then
            viewAllTransactions "0" "false"
            else
            viewAllTransactions "0" "true"
            fi
            ;;
        $DIALOG_HELP)
            refreshMainMenu_DATA
            ;;
    esac
    errorHandling "Error while displaying transactions."
}

advancedMainMenu() {
:
}

sendCoins() {
:
}

passwordDialog() {
    exec 3>&1
    local wallet_password=$(dialog --backtitle "$TITLE_BACK" \
        --no-shadow \
        --insecure \
        --passwordbox "Enter wallet password" 0 0  \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case $exit_status in
        $DIALOG_CANCEL)
            refreshMainMenu_GUI
            ;;
        $DIALOG_ESC)
            refreshMainMenu_GUI
            ;;
    esac
    executeCURL "walletpassphrase" "\"$wallet_password\",$1,$2"
    unset wallet_password
}

commandInput() {
    local itemBuffer
    local oldIFS=$IFS
    local buffer
    export IFS=','
    local i=0
    for itemBuffer in $USER_DAEMON_PARAMS; do
        i=$(( $i + 1 ))
        if [ $i -gt 1 ]; then
            buffer+=' '
        fi
        buffer+="$itemBuffer"
    done
    USER_DAEMON_PARAMS="$buffer"
    IFS=$oldIFS
    unset oldIFS
    unset itemBuffer
    unset buffer
    local s="Here you can enter commands that will be send to the Daemon.\n"
    s+="Use \Z6[CTRL]\Zn + \Z6[SHIFT]\Zn + \Z6[V]\Zn to copy from clipboard."
    exec 3>&1
    buffer=$(dialog --backtitle "$TITLE_BACK" \
        --ok-label "Execute" \
        --cancel-label "Main Menu" \
        --extra-button \
        --extra-label "Help" \
        --no-shadow \
        --title "Enter Command" \
        --form "$s" 0 0 0 \
        "type help for info" 1 12 "" 1 11 -1 0 \
        "Command:" 2 1 "$USER_DAEMON_COMMAND" 2 11 33 0 \
        "seperated by spaces" 4 12 "" 3 11 -1 0 \
        "Parameter:" 5 1 "$USER_DAEMON_PARAMS" 5 11 65 0 \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    unset s
    case $exit_status in
        $DIALOG_CANCEL)
        refreshMainMenu_GUI;;
        $DIALOG_ESC)
        refreshMainMenu_GUI;;
        $DIALOG_EXTRA)
        executeCURL "help" "" "u"
        commandInput;;
        $DIALOG_OK)
        i=0
        unset USER_DAEMON_COMMAND
        unset USER_DAEMON_PARAMS
        for itemBuffer in $buffer; do
            i=$(( $i + 1 ))
            if [ $i -eq 1 ]; then
                USER_DAEMON_COMMAND="$itemBuffer"
            else
                if [ $i -gt 2 ]; then
                USER_DAEMON_PARAMS+=','
                fi
                if [ "$itemBuffer" != "true" ] \
                && [ "$itemBuffer" != "false" ] \
                && [[ ! $itemBuffer =~ ^[0-9]+$ ]]; then
                    if [[ "$itemBuffer" != '"'* ]]; then
                        USER_DAEMON_PARAMS+='"'
                    fi
                    USER_DAEMON_PARAMS+="$itemBuffer"
                    if [[ "$itemBuffer" != *'"' ]]; then
                        USER_DAEMON_PARAMS+='"'
                    fi
                else
                    USER_DAEMON_PARAMS+="$itemBuffer"
                fi
            fi
        done
        unset i
        unset itemBuffer
        unset buffer
        executeCURL "$USER_DAEMON_COMMAND" "$USER_DAEMON_PARAMS" "u"
        commandInput;;
    esac
}

curlFeedbackHandling() {
    dialog \
        --backtitle "$TITLE_BACK" \
        --colors \
        --title "CURL result" \
        --ok-label 'Continue' \
        --no-shadow \
        --msgbox "$1" 0 0
}

mainMenu_helper() {
    if [ "$MENU_WALLET_UNLOCKED" = "true" ]; then
        echo 'Lock'
    else
        echo 'Unlock'
    fi
}

refreshMainMenu_GUI() {
    local max_buff
    POSY_MENU=0
    max_buff=$(($(tput cols) / 2))
    max_buff=$((45>$max_buff?"45":$max_buff))
    SIZEX_MENU=$((60<$max_buff?"60":$max_buff))
    SIZEY_MENU=13
    max_buff=$(($(tput cols) - $SIZEX_MENU))
    SIZEX_TRANSACTIONS=$((85<$max_buff?"85":$max_buff))
    SIZEY_TRANSACTIONS=$(($(tput lines) - $POSY_MENU))
    unset max_buff
    SIZEX_INFO=$SIZEX_MENU
    SIZEY_INFO=$(($(tput lines) - $POSY_MENU - $SIZEY_MENU))
    POSX_MENU=$(($(($(tput cols) - $SIZEX_MENU - $SIZEX_TRANSACTIONS)) / 2))
    POSX_TRANSACTIONS=$(($POSX_MENU + $SIZEX_MENU))
    POSY_TRANSACTIONS=$POSY_MENU
    POSX_INFO=$POSX_MENU
    POSY_INFO=$(($POSY_MENU + $SIZEY_MENU))
    TEXTWIDTH_TRANS=$(($SIZEX_TRANSACTIONS - 4))
    TEXTWIDTH_INFO=$(($SIZEX_INFO - 5))
    WIDTHTEXT_MENU=$TEXTWIDTH_INFO
    TEXTHIGHT_TRANS=$(($(tput lines) - 2 - $POSY_TRANSACTIONS))
    TEXTHIGHT_INFO=$(($(tput lines) - 2 - $POSY_INFO - $SIZEY_MENU))
    TITLE_TRANSACTIONS='RECENT TRANSACTIONS'
    TITLE_INFO=''
    TITLE_MENU="$TITLE_BACK"
    exec 3>&1
    local mainMenuPick=$(dialog --no-shadow \
        --begin 0 0 \
        --no-lines \
        --infobox "" "$(tput lines)" "$(tput cols)" \
        \
        --and-widget \
        --colors \
        --begin "$POSY_TRANSACTIONS" "$POSX_TRANSACTIONS" \
        --title "$TITLE_TRANSACTIONS" \
        --no-collapse \
        --infobox "$(makeOutputTransactions $TEXTWIDTH_TRANS $TEXTHIGHT_TRANS)" "$SIZEY_TRANSACTIONS" "$SIZEX_TRANSACTIONS" \
        \
        --and-widget \
        --colors \
        --begin "$POSY_INFO" "$POSX_INFO" \
        --title "$TITLE_INFO" \
        --no-shadow \
        --no-collapse \
        --infobox "$(makeOutputInfo $TEXTWIDTH_INFO $TEXTHIGHT_INFO)" "$SIZEY_INFO" "$SIZEX_INFO" \
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
        Command "Sending commands to deamon" \
        Quit "Exit interface" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case $exit_status in
        $DIALOG_ESC)
            goodbye
        ;;
    esac
    case $mainMenuPick in
        Refresh) refreshMainMenu_DATA;;
        Unlock) unlockWalletForStaking;;
        Lock) lockWallet;;
        Transaktions) viewAllTransactions "0" "true";;
        Send) sry;;
        Command) commandInput;;
        Quit) goodbye;;
    esac
    unset mainMenuPick
}

readConfig() {
    local file
    if [ -z "$1" ]; then
        file="script.conf"
    else
        file=$1
    fi
    if [ ! -f "$file" ]; then
        local s="Config file for this interface missing. The file $file was not found."
        errorHandling "$s" 1
        unset s
    fi
    input=`cat "$file"|grep -v "^#"`
    set -- $input
    while [ $1 ]; do
        eval $1
        shift 1
    done
    unset file
}

lockWallet() {
    executeCURL "walletlock"
    refreshMainMenu_DATA
}

unlockWalletForStaking() {
    passwordDialog "999999999" "true"
    refreshMainMenu_DATA
}

refreshMainMenu_DATA() {
    executeCURL "getstakinginfo"
    executeCURL "getinfo"
    executeCURL "listtransactions" '"*",7,0,"1"'
    refreshMainMenu_GUI
}

export NCURSES_NO_UTF8_ACS=1
printf '\033[8;29;134t'
VERSION='v1.8alpha'
TITLE_BACK="Spectrecoin Bash RPC Wallet Interface ($VERSION)"
readConfig $1
warning
refreshMainMenu_DATA
goodbye
