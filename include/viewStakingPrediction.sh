#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# Author: 2018 HLXEasy
#
# ============================================================================

# ============================================================================
# Print prepared data regarding staking from RPC 'listtransactions' to stdout
makeStakeInfoOutput() {
    local _textWidth=50
    echo "\n$(fillLine "${TEXT_STAKING_ANALYSIS_TIMEFRAME}:-_-${staking_analysis[1]}" \
                    "${_textWidth}")\n"

    echo "\n${TEXT_STAKING_ANALYSIS_LAST_THOUSAND}:\n"
    echo "$(fillLine " - ${TEXT_STAKING_ANALYSIS_AMOUNTS}:-_-${staking_analysis[2]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " - ${TEXT_STAKING_ANALYSIS_TOTAL_REWARD}:-_-${staking_analysis[3]}" \
                    "${_textWidth}")\n"

    echo "\n$(fillLine "${TEXT_STAKING_ANALYSIS_TOTAL_TODAY}:-_-${staking_analysis[4]}" \
                    "${_textWidth}")\n"

    echo "\n${TEXT_ESTIMATIONS}:\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_REWARD_PER_YEAR}:-_-${staking_analysis[5]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_COINS_IN_ONE_MONTH}:-_-${staking_analysis[6]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_STAKED_COINS_IN} ${TEXT_ONE_MONTH}:-_-${staking_analysis[7]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_TOTAL_COINS_IN} ${TEXT_HALF_YEAR}:-_-${staking_analysis[8]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_STAKED_COINS_IN} ${TEXT_HALF_YEAR}:-_-${staking_analysis[9]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_TOTAL_COINS_IN} ${TEXT_ONE_YEAR}:-_-${staking_analysis[10]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_STAKED_COINS_IN} ${TEXT_ONE_YEAR}:-_-${staking_analysis[11]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_TOTAL_COINS_IN} ${TEXT_TWO_YEARS}:-_-${staking_analysis[12]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_STAKED_COINS_IN} ${TEXT_TWO_YEARS}:-_-${staking_analysis[13]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_TOTAL_COINS_IN} ${TEXT_THREE_YEARS}:-_-${staking_analysis[14]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_STAKED_COINS_IN} ${TEXT_THREE_YEARS}:-_-${staking_analysis[15]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_TOTAL_COINS_IN} ${TEXT_FOUR_YEARS}:-_-${staking_analysis[16]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_STAKED_COINS_IN} ${TEXT_FOUR_YEARS}:-_-${staking_analysis[17]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_TOTAL_COINS_IN} ${TEXT_FIVE_YEARS}:-_-${staking_analysis[18]}" \
                    "${_textWidth}")\n"
    echo "$(fillLine " ${TEXT_STAKING_ANALYSIS_STAKED_COINS_IN} ${TEXT_FIVE_YEARS}:-_-${staking_analysis[19]}" \
                    "${_textWidth}")\n"
}



# ============================================================================
# Gathers the data form the RPC 'listtransactions' command and extract all
# information regarding current state of staking
viewStakingPrediction() {
    unset stakes
    declare -A stakes
    executeCURL "listtransactions" \
                '"*",1000,0,"1"'
    getStakingPrediction
    dialog --backtitle "${TITLE_BACK}" \
           --colors \
           --title "${TITLE_STAKING_INFO}" \
           --ok-label "${BUTTON_LABEL_OK}" \
           --no-shadow \
           --msgbox "$(makeStakeInfoOutput)" 30 54

    refreshMainMenu_DATA
}
