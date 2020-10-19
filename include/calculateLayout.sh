#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# ============================================================================

# ============================================================================
# This function calculates global arrangement variables (i.e. for main menu).
calculateLayout() {
    currentTPutCols=$(tput cols)
    currentTPutLines=$(tput lines)
    amountOfLinesPerTransaction=6
    local _max_buff
    POS_Y_MENU=0
    _max_buff=$((${currentTPutCols} / 2))
    if [[ ${_max_buff} -lt 45 ]] ; then
        _max_buff=45
    fi
    if [[ ${_max_buff} -gt 60 ]] ; then
        SIZE_X_MENU=60
    else
        SIZE_X_MENU=${_max_buff}
    fi
    SIZE_Y_MENU=14

    #Size for the displayed transactions in main menu
    _max_buff=$((${currentTPutCols} - ${SIZE_X_MENU}))
    if [[ ${_max_buff} -gt 85 ]] ; then
        SIZE_X_TRANS=85
    else
        # if we do not have enough place just fuck it and tease by showing only left half
        if [[ ${_max_buff} -lt 29 ]]; then
            # hide transactions in main
            SIZE_X_TRANS=0
            # recalc main menu size (make it max)
            if [[ ${currentTPutCols} -gt 60 ]] ; then
                SIZE_X_MENU=60
            else
                SIZE_X_MENU=${currentTPutCols}
            fi
        else
            SIZE_X_TRANS=${_max_buff}
        fi
    fi
    SIZE_Y_TRANS=$(($(tput lines) - ${POS_Y_MENU}))

    # Size for the displayed info in main menu
    SIZE_X_INFO=${SIZE_X_MENU}
    _max_buff=$(($(tput lines) - ${POS_Y_MENU} - ${SIZE_Y_MENU}))
    if [[ ${_max_buff} -gt 21 ]] ; then
        SIZE_Y_INFO=21
    else
        SIZE_Y_INFO=${_max_buff}
    fi

    # Size for view all transactions dialog
    _max_buff=${currentTPutCols}
    if [[ ${_max_buff} -gt 74 ]] ; then
        SIZE_X_TRANS_VIEW=74
    else
        SIZE_X_TRANS_VIEW=${_max_buff}
    fi
    SIZE_Y_TRANS_VIEW=$(tput lines)

    POS_X_MENU=$(($((${currentTPutCols} - ${SIZE_X_MENU} - ${SIZE_X_TRANS})) / 2))
    POS_X_TRANS=$((${POS_X_MENU} + ${SIZE_X_MENU}))
    POS_Y_TRANS=${POS_Y_MENU}
    POS_X_INFO=${POS_X_MENU}
    POS_Y_INFO=$((${POS_Y_MENU} + ${SIZE_Y_MENU}))
    TEXTWIDTH_TRANS=$((${SIZE_X_TRANS} - 4))
    TEXTWIDTH_INFO=$((${SIZE_X_INFO} - 5))
#   WIDTHTEXT_MENU=${TEXTWIDTH_INFO}
    #
    # Amount of transactions that can be displayed in main menu
    # = ((amount of terminal lines - amount of border lines - y-offset) / amount of lines per transaction ) + 1
    COUNT_TRANS_MENU=$(( ((${SIZE_Y_TRANS} - 2 - ${POS_Y_TRANS}) / ${amountOfLinesPerTransaction}) ))
    #
    # Amount of transactions that can be displayed in the view all transactions dialog
    # = ((amount of terminal lines - amount of border lines - y-offset) / amount of lines per transaction ) + 1
    COUNT_TRANS_VIEW=$(( ((${SIZE_Y_TRANS} - 4 - ${POS_Y_TRANS}) / ${amountOfLinesPerTransaction}) ))
    #
    TEXTHIGHT_INFO=$(( ${SIZE_Y_INFO} - 2 ))

    if [[ ${currentTPutCols} -gt 60 ]] ; then
        SIZE_X_GAUGE=60
    else
        SIZE_X_GAUGE=${currentTPutCols}
    fi
    SIZE_Y_GAUGE=0
    #
    LOG_TAIL_WINDOW_HEADER_X=5
    LOG_TAIL_WINDOW_Y=$((${currentTPutCols}))
    LOG_TAIL_WINDOW_X=$((${currentTPutLines}-6))
}
