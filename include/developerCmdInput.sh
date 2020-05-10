#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 The Spectrecoin developers
# SPDX-License-Identifier: MIT
# ============================================================================

# ============================================================================
# This function provides a mask for the user to enter commands, that are
# send to the spectrecoind daemon. Additionally it can be configured, how often
# the command should be executed. The result of the cmd is written to the file
# "/tmp/<date>-cmd-result.txt".
#
# Input: USER_DAEMON_COMMAND global var. that stores the last entered command
#        USER_DAEMON_PARAMS global var. that stores the last entered parameters
#
# Output: USER_DAEMON_COMMAND updated
#         USER_DAEMON_PARAMS updated
developerCommandInput() {
    local _itemBuffer
    local _oldIFS=$IFS
    local _buffer
    IFS=','
    local _i=0
    for _itemBuffer in ${USER_DAEMON_PARAMS}; do
        _i=$((_i+1))
        if [[ ${_i} -gt 1 ]]; then
            _buffer+=' '
        fi
        _buffer+="${_itemBuffer}"
    done
    USER_DAEMON_PARAMS="${_buffer}"
    EXECUTION_AMOUNT=1
    EXECUTION_TIMESTAMP=$(date +%Y-%m-%d_%H%M)
    IFS=${_oldIFS}
    local _s="${TEXT_USERCOMMAND_EXPL}\n"
         _s+="${TEXT_CLIPBOARD_HINT}"
    exec 3>&1
    _buffer=$(dialog --backtitle "${TITLE_BACK}" \
        --ok-label "${BUTTON_LABEL_EXECUTE}" \
        --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
        --extra-button \
        --extra-label "${BUTTON_LABEL_HELP}" \
        --no-shadow --colors \
        --title "${TITLE_USERCOMMAND}" \
        --form "$_s" 0 0 0 \
        "${TEXT_USERCOMMAND_CMD_EXPL}" 1 12 "" 1 11 -1 0 \
        "${TEXT_USERCOMMAND_CMD}:" 2 1 "${USER_DAEMON_COMMAND}" 2 11 33 0 \
        "${TEXT_USERCOMMAND_PARAMS_EXPL}" 4 12 "" 3 11 -1 0 \
        "${TEXT_USERCOMMAND_PARAMS}:" 5 1 "${USER_DAEMON_PARAMS}" 5 11 65 0 \
        "${TEXT_USERCOMMAND_AMOUNT}:" 7 1 "${EXECUTION_AMOUNT}" 7 11 5 0 \
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
                if [[ ${_i} -eq 1 ]]; then
                    USER_DAEMON_COMMAND="${_itemBuffer}"
                else
                    if [[ ${_i} -gt 2 ]]; then
                        if [[ ${_argContainsSpaces} != "true" ]]; then
                            USER_DAEMON_PARAMS+=','
                        else
                            USER_DAEMON_PARAMS+=' '
                        fi
                    fi
                    if [[ "${_itemBuffer}" != "true" ]] \
                    && [[ "${_itemBuffer}" != "false" ]] \
                    && [[ ! ${_itemBuffer} =~ ^[0-9]+$ ]]; then
                        if [[ "${_itemBuffer}" != '"'* ]] && [[ ${_argContainsSpaces} != "true" ]]; then
                            USER_DAEMON_PARAMS+='"'
                        else
                            _argContainsSpaces="true"
                        fi
                        USER_DAEMON_PARAMS+="${_itemBuffer}"
                        if [[ "${_itemBuffer}" != *'"' ]] && [[ ${_argContainsSpaces} != "true" ]]; then
                            USER_DAEMON_PARAMS+='"'
                        elif [[ "${_itemBuffer}" == *'"' ]]; then
                            _argContainsSpaces="false"
                        fi
                    else
                        USER_DAEMON_PARAMS+="${_itemBuffer}"
                    fi
                fi
            done
            idx=1
            while [[ ${idx} -le ${EXECUTION_AMOUNT} ]] ; do
                idx=$((idx+1))
                gauge=$(echo "${idx}*100/${EXECUTION_AMOUNT}" | bc)
                drawGauge "${gauge}" \
                          "${TEXT_GAUGE_DEFAULT}"
                executeCURL "${USER_DAEMON_COMMAND}" \
                            "${USER_DAEMON_PARAMS}"
                echo "${curl_result_global}" >> /tmp/${EXECUTION_TIMESTAMP}-cmd-result.txt
            done
            drawGauge "100" \
                      "${TEXT_GAUGE_ALLDONE}"
            curlUserFeedbackHandling
            developerCommandInput;;
    esac
    errorHandling "${ERROR_USERCOMMAND_FATAL}" \
                  1
}
