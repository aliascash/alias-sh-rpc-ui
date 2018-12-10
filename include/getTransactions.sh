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
# Output: $transactions_global array
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

    local _oldIFS=$IFS
    IFS='{'
    for transaction in ${curl_result_global} ; do
        # Remove trailing '},'
        transaction=${transaction%\}*}
        IFS=','
        for detail in ${transaction} ; do
            case ${detail%%:*} in
                account)
                    transactions[${_i},${TA_ACCOUNT}]="${detail#*:}";;
                address)
                    transactions[${_i},${TA_ADDRESS}]="${detail#*:}";;
                amount)
                    transactions[${_i},${TA_AMOUNT}]="${detail#*:}";;
                blockhash)
                    transactions[${_i},${TA_BLOCKHASH}]="${detail#*:}";;
                blockindex)
                    transactions[${_i},${TA_BLOCKINDEX}]="${detail#*:}";;
                blocktime)
                    transactions[${_i},${TA_BLOCKTIME}]="${detail#*:}";;
                category)
                    case ${detail#*:} in
                        receive)
                            transactions[${_i},${TA_CATEGORY}]="${TEXT_RECEIVED}";;
                        generate)
                            transactions[${_i},${TA_CATEGORY}]="${TEXT_STAKE}";;
                        immature)
                            transactions[${_i},${TA_CATEGORY}]="${TEXT_IMMATURE}";;
                        *)
                            transactions[${_i},${TA_CATEGORY}]="${TEXT_TRANSFERRED}";;
                    esac;;
                confirmations)
                    transactions[${_i},${TA_CONFIRMATIONS}]="${detail#*:}";;
                currency)
                    transactions[${_i},${TA_CURRENCY}]="${detail#*:}";;
                generated)
                    transactions[${_i},${TA_GENERATED}]="${detail#*:}";;
                narration)
                    transactions[${_i},${TA_NARRATION}]="${detail#*:}";;
                timereceived)
                    transactions[${_i},${TA_TIMERECEIVED}]="$(date -d "@${detail#*:}" +%d-%m-%Y" at "%H:%M:%S)";;
                time)
                    transactions[${_i},${TA_TIME}]="$(date -d "@${detail#*:}" +%d-%m-%Y" at "%H:%M:%S)";;
                txid)
                    transactions[${_i},${TA_TXID}]="${detail#*:}";;
                version)
                    transactions[${_i},${TA_VERSION}]="${detail#*:}";;
            esac
        done
        IFS='{'
        _i=$((${_i}+1))
    done
    IFS=${_oldIFS}
    currentAmountOfTransactions=$((${_i}-1))

    # ToDo: The following might be obsolete, to be removed...
    IFS='},{'
    for _itemBuffer in ${curl_result_global}; do
        if [[ ${_itemBuffer} == 'time'* ]]; then
            _unixtime="${_itemBuffer#*':'}"
            if ([[ ${_thisWasAStake} = "true" ]] && [[ ${_unixtime} -lt ${_oldestStakeDate} ]]); then
                _oldestStakeDate=${_unixtime}
                _firstStakeIndex="${_i}"
            fi
            if ([[ ${_thisWasAStake} = "true" ]] && [[ ${_unixtime} -gt ${_newestStakeDate} ]]); then
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
    if ([[ "$1" = "full" ]] && [[ ${_oldestStakeDate} != ${_newestStakeDate} ]] && [[ ${_newestStakeDate} !=  "0" ]]); then
        local _stakedAmount=0
        local _stakeCounter=0
        local _i
        local _dataTimeFrame=$((${_newestStakeDate} - ${_oldestStakeDate}))
        for ((_i=$(( ${_firstStakeIndex} + 1));_i<${#transactions_global[@]};_i=$(( ${_i} + 6)))); do
            if [[ ${transactions_global[$_i+1]} = "${TEXT_STAKE}" ]]; then
                _stakedAmount=$(echo "scale=8; ${_stakedAmount} + ${transactions_global[$_i+2]}" | bc)
                _stakeCounter=$(( ${_stakeCounter} + 1 ))
            fi
        done
        local _totalCoins=$(echo "scale=8 ; ${info_global[${WALLET_BALANCE_XSPEC}]}+${info_global[${WALLET_STAKE}]}" | bc)
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
