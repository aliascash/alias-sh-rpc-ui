#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# Author: 2019 HLXEasy
#
# ============================================================================

settingsfile=~/.spectrecoin-ui-settings

# ============================================================================
# Goal:
handleSettings() {
    # Use default
    . include/ui_content_en.sh
    TITLE_MENU="${TITLE_BACK}(${info_global[${WALLET_VERSION}]%% *}, UI v${VERSION}) "
    if [[ -e "${settingsfile}" ]] ; then
        # Settingsfile found
        . "${settingsfile}"
        if [[ -n "${UI_LANGUAGE}" ]] ; then
            # Language var not empty
            if [[ -e "include/ui_content_${UI_LANGUAGE}.sh" ]] ; then
                # Language file existing
                . "include/ui_content_${UI_LANGUAGE}.sh"
                TITLE_MENU="${TITLE_BACK}(${info_global[${WALLET_VERSION}]%% *}, UI v${VERSION}) "
            fi
        fi
    fi
}

updateSettings() {
    cat > "${settingsfile}" <<EOF
UI_LANGUAGE=${UI_LANGUAGE}
EOF
}
