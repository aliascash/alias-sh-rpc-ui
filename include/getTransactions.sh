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
# Output: $transactions array
getTransactions() {
#    unset transactions_global
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
                fee)
                    transactions[${_i},${TA_FEE}]="${detail#*:}";;
                generated)
                    transactions[${_i},${TA_GENERATED}]="${detail#*:}";;
                narration)
                    transactions[${_i},${TA_NARRATION}]="${detail#*:}";;
                timereceived)
                    transactions[${_i},${TA_TIMERECEIVED}]="${detail#*:}";;
                time)
                    transactions[${_i},${TA_TIME}]="${detail#*:}";;
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
}
