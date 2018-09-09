#!/bin/bash
# ---------------------------------------------------------------------------
#  @author   HLXEasy - Helix
# ---------------------------------------------------------------------------

configfileLocation=~/.spectrecoin/spectrecoin.conf
defaultPassword=supersupersuperlongpassword

writeConfiguration(){
    randomRPCPassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 44 | head -n 1)
    sed "s#^rpcpassword=${defaultPassword}#rpcpassword=${randomRPCPassword}#g" ./sample_config_daemon/spectrecoin.conf > ${configfileLocation}
}

initDaemonConfiguration(){
    if [ -e ${configfileLocation} ] ; then
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
                warning "You are using the default rpc password! Consider changing it!"
                warning "============================================================="
                info "Press return to continue"
                read a
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
        writeConfiguration
    fi

    # Now load configuration
    . ${configfileLocation}
}
