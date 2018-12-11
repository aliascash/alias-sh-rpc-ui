#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# Author: 2018 HLXEasy
#
# ============================================================================

# ============================================================================
# Gathers the data form the CURL result for the getinfo command
#
# Input: $curl_result_global
# Output: $transactions array
getStakingPrediction() {
    local _i=0
    local _oldestStakeDate=9999999999
    local _newestStakeDate=0
    local _firstStakeIndex
    local _thisWasAStake="false"
    local _valueBuffer
    local _oldIFS=$IFS
    local _itemBuffer
    local _unixtime
    local _stakedAmount=0
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
                amount)
                    stakes[${_i},${TA_AMOUNT}]="${detail#*:}";;
                category)
                    case ${detail#*:} in
                        receive)
                            stakes[${_i},${TA_CATEGORY}]="${TEXT_RECEIVED}";;
                        generate)
                            stakes[${_i},${TA_CATEGORY}]="${TEXT_STAKE}";;
                        immature)
                            stakes[${_i},${TA_CATEGORY}]="${TEXT_IMMATURE}";;
                        *)
                            stakes[${_i},${TA_CATEGORY}]="${TEXT_TRANSFERRED}";;
                    esac;;
                currency)
                    stakes[${_i},${TA_CURRENCY}]="${detail#*:}";;
                generated)
                    stakes[${_i},${TA_GENERATED}]="${detail#*:}";;
                time)
                    stakes[${_i},${TA_TIME}]="${detail#*:}";;
            esac
        done
        IFS='{'
        if [[ ${stakes[${_i},${TA_CATEGORY}]} = "${TEXT_STAKE}" ]] ; then
            amountOfStakes=${_i}

            # Calculate staked amount
            _stakedAmount=$(echo "scale=8; ${_stakedAmount} + ${stakes[${_i},${TA_AMOUNT}]}" | bc)

            # Only stakes should be stored, other entries will be overwritten during next loop
            _i=$((${_i}+1))
        fi
    done
    IFS=${_oldIFS}
    calculateStakingPrediction ${_stakedAmount}
}

calculateStakingPrediction()
{
    local _stakedAmount=$1
    local _i
    local _newestStakeDate=${stakes[${amountOfStakes},${TA_TIME}]}
    local _oldestStakeDate=${stakes[0,${TA_TIME}]}
    local _dataTimeFrame=$((${_newestStakeDate} - ${_oldestStakeDate}))
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
    _stakeCounter=$(( ${_stakeCounter} + 1 ))
    staking_analysis[1]="analysis time frame for estimation: $(secToHumanReadable ${_dataTimeFrame})"
    staking_analysis[2]="times wallet staked within the last 1000 transactions: ${amountOfStakes}"
    staking_analysis[3]="total staking reward within the last 1000 transactions: ${_stakedAmount}"
    staking_analysis[4]="total coins today:                  ${_totalCoins}"
    staking_analysis[5]="est. staking reward rate per year:  ${_estStakingRatePerYear}"
    staking_analysis[6]="est. total coins in one month:      ${_estCoinsM1%.*}"
    staking_analysis[7]="est. staked coins in one month:     ${_estGainM1%.*}"
    staking_analysis[8]="est. total coins in six months:     ${_estCoinsM6%.*}"
    staking_analysis[9]="est. staked coins in six months:    ${_estGainM6%.*}"
    staking_analysis[10]="est. total coins in one year:       ${_estCoinsY1%.*}"
    staking_analysis[11]="est. staked coins in one year:      ${_estGainY1%.*}"
    staking_analysis[12]="est. total coins in two years:      ${_estCoinsY2%.*}"
    staking_analysis[13]="est. staked coins in two years:     ${_estGainY2%.*}"
    staking_analysis[14]="est. total coins in three years:    ${_estCoinsY3%.*}"
    staking_analysis[15]="est. staked coins in three years:   ${_estGainY3%.*}"
    staking_analysis[16]="est. total coins in four years:     ${_estCoinsY4%.*}"
    staking_analysis[17]="est. staked coins in four years:    ${_estGainY4%.*}"
    staking_analysis[18]="est. total coins in five years:     ${_estCoinsY5%.*}"
    staking_analysis[19]="est. staked coins in five years:    ${_estGainY5%.*}"
}
