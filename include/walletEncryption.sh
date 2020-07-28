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
# Goal: Ask the user for a password by using the given question
# $1 - The question to ask right above the input field
#
getPassword(){
    local _question=$1
    local _varToStoreValue=$2
    local _currentPassword
    exec 3>&1
    _currentPassword=$(dialog --backtitle "${TITLE_BACK}" \
        --no-shadow \
        --insecure \
        --passwordbox "${_question}" 0 0 \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case ${exit_status} in
        ${DIALOG_CANCEL})
            # abort and reload main menu
            refreshMainMenu_DATA;;
        ${DIALOG_ESC})
            # abort and reload main menu
            refreshMainMenu_DATA;;
        ${DIALOG_OK})
            eval ${_varToStoreValue}=${_currentPassword};;
        *)
            errorHandling "${ERROR_PW_FATAL}" \
                          1;;
    esac
}

# ============================================================================
# Goal: ask for the wallet password, to unlock the wallet for staking
#       and sending transactions. Password will never leave this function.
#
# Input $1 - time amout the wallet will be opend
#       $2 - if true the wallet will only be opend for staking
#
# Return: nothing
changePasswordDialog() {
    unset currentPassword
    unset newPassword1
    unset newPassword2

    getPassword "${TEXT_CURRENT_PW_EXPL}" currentPassword
    if [[ -z "${currentPassword}" ]] ; then
        dialog --title "${TITLE_ERROR}" --no-shadow --msgbox "${TEXT_NO_PASS_GIVEN}" 6 30
        changePasswordDialog
    else
        getPassword "${TEXT_NEW_PW1_EXPL}" newPassword1
        getPassword "${TEXT_NEW_PW2_EXPL}" newPassword2
        if [[ -z "${newPassword1}" ]] ; then
            dialog --title "${TITLE_ERROR}" --no-shadow --msgbox "${TEXT_NO_NEW_PASS_GIVEN}" 6 30
            changePasswordDialog
        elif [[ "${newPassword1}" != "${newPassword2}" ]] ; then
            dialog --title "${TITLE_ERROR}" --no-shadow --msgbox "${TEXT_NEW_PASS_NOT_EQUAL}" 6 30
            changePasswordDialog
        else
            executeCURL "walletpassphrasechange" "\"${currentPassword}\",\"${newPassword1}\""
            dialog --title "${TITLE_SUCCESS}" --no-shadow --msgbox "${TEXT_PASS_CHANGE_SUCCESSFUL}" 6 30
        fi
    fi
    unset currentPassword
    unset newPassword1
    unset newPassword2
    refreshMainMenu_DATA
}

encryptWallet() {
    unset newPassword1
    unset newPassword2

    getPassword "${TEXT_NEW_PW1_EXPL}" newPassword1
    getPassword "${TEXT_NEW_PW2_EXPL}" newPassword2
    if [[ -z "${newPassword1}" ]] ; then
        dialog --title "${TITLE_ERROR}" --no-shadow --msgbox "${TEXT_NO_NEW_PASS_GIVEN}" 6 30
        encryptWallet
    elif [[ "${newPassword1}" != "${newPassword2}" ]] ; then
        dialog --title "${TITLE_ERROR}" --no-shadow --msgbox "${TEXT_NEW_PASS_NOT_EQUAL}" 6 30
        encryptWallet
    else
        executeCURL "encryptwallet" "\"${newPassword1}\""
        dialog --title "${TITLE_SUCCESS}" --no-shadow --msgbox "${TEXT_WALLET_ENCRYPTION_SUCCESSFUL}" 6 30
    fi
    unset newPassword1
    unset newPassword2
    refreshMainMenu_DATA
}