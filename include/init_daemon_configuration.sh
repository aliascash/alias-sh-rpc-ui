#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# Author: 2018 HLXEasy
#
# ============================================================================

configfileLocation=~/.aliaswallet/alias.conf
defaultPassword=supersupersuperlongpassword

stopAliaswalletd(){
    info "Stop Aliaswallet daemon in case it is already running"
    sudo systemctl stop aliaswalletd
    info "Done"
}

generatePassword(){
    randomRPCPassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 44 | head -n 1)
}

updateConfiguration(){
    generatePassword
    stopAliaswalletd
    sed "s#^rpcpassword=${defaultPassword}#rpcpassword=${randomRPCPassword}#g" -i ${configfileLocation}
}

createConfiguration(){
    generatePassword
    stopAliaswalletd
    sed "s#^rpcpassword=${defaultPassword}#rpcpassword=${randomRPCPassword}#g" ./sample_config_daemon/alias.conf > ${configfileLocation}
}

initDaemonConfiguration(){
    if [[ -e ${configfileLocation} ]] ; then
        # Daemon config found
        # Check for rpcuser
        if grep -q "^rpcuser=" ${configfileLocation} ; then
            # Key 'rpcuser' found, nothing to do
            :
        else
            echo ''
            error "Configuration key 'rpcuser' not found on ${configfileLocation}!"
            error "Please remove ${configfileLocation} and restart the ui,"
            error "so the configuration will be created again. "
            die 20 "Another solution would be to add key 'rpcuser=<username>'."
        fi
        # Check for rpcpassword
        if grep -q "^rpcpassword=" ${configfileLocation} ; then
            # Key 'rpcpassword' found, nothing to do
            # Check for default password
            if grep -q "^rpcpassword=${defaultPassword}" ${configfileLocation} ; then
                echo ''
                warning "============================================================="
                warning "You are using the default rpc password!"
                warning "It will be replaced with a random password now."
                warning "============================================================="
                info "Press return to continue"
                read -s
                updateConfiguration
            fi
        else
            echo ''
            error "Configuration key 'rpcpassword' not found on ${configfileLocation}!"
            error "Please remove ${configfileLocation} and restart the ui,"
            error "so the configuration will be created again. "
            die 21 "Another solution would be to add key 'rpcpassword=<mySuperPassword>'."
        fi
    else
        # Daemon config not existing, create one
        createConfiguration
    fi

    # Now load configuration
    . ${configfileLocation}

    if [[ -z "${logfile}" ]] ; then
        # Configuration value not found, set default
        logfile=~/.aliaswallet/debug.log
    fi
}
