#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# Author: 2019 HLXEasy
#
# ============================================================================

settingsfile=~/.aliaswallet-ui-settings

# ============================================================================
# Goal:
handleSettings() {
    # Load default language, which define and fill all variables.
    loadLanguage en
    if [[ -e "${settingsfile}" ]] ; then
        # Settingsfile found
        . "${settingsfile}"
        if [[ -n "${UI_LANGUAGE}" ]] ; then
            # Language var not empty
            if [[ -e "locale/ui_content_${UI_LANGUAGE}.yml" ]] ; then
                # Language file exists, so load it "on top" of already loaded
                # default language. Not existing entries on the choosen
                # language stay at their default value.
                loadLanguage "${UI_LANGUAGE}"
            fi
        fi
    fi
    TITLE_MENU="${TITLE_BACK}(${info_global[${WALLET_VERSION}]%% *}, UI v${VERSION}) "
}

updateSettings() {
    cat > "${settingsfile}" <<EOF
UI_LANGUAGE=${UI_LANGUAGE}
EOF
}
