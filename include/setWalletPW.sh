#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# Author: 2018 dave#0773@discord
#
# ============================================================================


# ============================================================================
# Goal: ask for a new wallet password
#       Password will never leave this function.
#
# Input $1 - title of the dialog
#
# Return: nothing
setWalletPW() {
    exec 3>&1
    local _buffer=$(dialog --backtitle "${TITLE_BACK}" \
                           --no-shadow \
                           --insecure \
                           --title "${TITLE_ENCRYPT_WALLET}" \
                           --ok-label "${BUTTON_LABEL_ENCRYPT}" \
                           --cancel-label "${BUTTON_LABEL_MAIN_MENU}" \
                           --mixedform "Note: Password must be at least 10 char long.\nEnter new wallet password:" 12 50 0 \
                                       "Password:" 1 1 "" 1 11 30 0 1 \
                                       "Retype:" 3 1 "" 3 11 30 0 1 \
                         2>&1 1>&3)
    exit_status=$?
    echo "exitstatus: ${exit_status}"
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            refreshMainMenu_GUI;;
        ${DIALOG_ESC})
            refreshMainMenu_GUI;;
        ${DIALOG_OK})
            _i=0
            local _itemBuffer
            for _itemBuffer in ${_buffer}; do
                _i=$((_i+1))
                if [[ ${_i} -eq 1 ]]; then
                if [[ ${#_itemBuffer} -ge 10 ]]; then
                    _pw="${_itemBuffer}"
                else
                    local _s="\Z1You entered an invalid password.\Zn\n\n"
                        _s+="A valid wallet password must be in the form:"
                        _s+="\n- at least 10 char long"
                    errorHandling "${_s}"
                    setWalletPW
                fi
                elif [[ ${_i} -eq 2 ]]; then
                    if [[ ${_itemBuffer} == ${_pw} ]]; then
                        executeCURL "encryptwallet" "\"${_pw}\""
                        #walletpassphrasechange "oldpassphrase" "newpassphrase"
                        # maybe stops daemon?
                        sudo service spectrecoind stop
                        dialog --backtitle "${TITLE_BACK}" \
                               --no-shadow \
                               --colors \
                               --ok-label "${BUTTON_LABEL_RESTART_DAEMON}" \
                               --msgbox  "$TEXT_GOODBYE_FEEDBACK_DAEMON_STOPPED" 0 0
                        refreshMainMenu_DATA
                    else
                        local _s="Passwords do not match."
                        errorHandling "${_s}"
                        setWalletPW
                    fi
                fi
            done;;
        *)
            setWalletPW;;
        esac
        echo "error: ${exit_status}"
        exit 1
}
