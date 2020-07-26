#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# Author: 2019-03 HLXEasy
#
# ============================================================================

# ============================================================================
# Open a dialog tailbox and show debug.log
viewLog() {
    dialog --backtitle "${TITLE_BACK}" \
           --no-shadow \
           --colors \
           --begin 2 0 \
           --no-lines \
           --infobox "${TEXT_LOGFILE_HEADER}" ${LOG_TAIL_WINDOW_HEADER_X} ${LOG_TAIL_WINDOW_Y} \
           \
           --and-widget \
           --title " ${logfile} " \
           --no-shadow \
           --colors \
           --begin $((${LOG_TAIL_WINDOW_HEADER_X}+1)) 0 \
           --ok-label "${BUTTON_LABEL_CLOSE}" \
           --tailbox "${logfile}" \
           ${LOG_TAIL_WINDOW_X} ${LOG_TAIL_WINDOW_Y}
}
