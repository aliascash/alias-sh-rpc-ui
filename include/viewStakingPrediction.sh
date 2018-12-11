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
    for (( _i = 0 ; _i <= ${#staking_analysis[@]} ; _i++ )) ; do
        echo "${staking_analysis[$_i]}\n"
    done
}



# ============================================================================
# Gathers the data form the RPC 'listtransactions' command and extract all
# information regarding current state of staking
viewStakingPrediction() {
    unset stakes
    declare -A stakes
    calculateLayout
    executeCURL "listtransactions" \
                '"*",1000,0,"1"'
    getStakingPrediction
    dialog --backtitle "${TITLE_BACK}" \
           --colors \
           --title "${TITLE_STAKING_INFO}" \
           --ok-label "${BUTTON_LABEL_OK}" \
           --no-shadow \
           --msgbox "$(makeStakeInfoOutput)" 34 "${SIZE_X_TRANS_VIEW}"

    refreshMainMenu_DATA
}
