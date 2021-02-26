#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2021 Alias Developers
# SPDX-License-Identifier: MIT
#
# Author: 2021 HLXEasy
#
# ============================================================================

# ============================================================================
# Load the given language file and set all keys with their values as variables
# $1: Short lang name i. e. "en" or "de"
#
# 1. Yaml syntax because translations are generated with https://transifex.com/
# 2. Comments must start with "#" as the first character on the line
# 3. Syntax line by line like this example (without the ' of course):
#    'TEXT_PW_EXPL: "Enter wallet password"'
# 4. Character '@' is replaced by backslash during evaluation of strings, so
#    each '@Z' will be '\Z' afterwards
# 5. Interpret embedded "\Z" sequences in the dialog text by the following character,
#    which tells dialog to set colors or video attributes: 0 through 7 are the ANSI
#    used in curses: black, red, green, yellow, blue, magenta, cyan and white respectively.
#    Bold is set by 'b', reset by 'B'.
#    Reverse is set by 'r', reset by 'R'.
#    Underline is set by 'u', reset by 'U'.
#    The settings are cumulative,
#    e.g., "\Zb\Z1" makes the following text bold (perhaps bright) red.
#    Restore normal settings with "\Zn".
loadLanguage() {
    local languageToLoad=$1
    local currentLine
    local currentKey
    local currentValue
    while read -r currentLine ; do
        case "$currentLine" in
            \#*)
                #echo "Skipping comment '${currentLine}'"
                ;;
            *)
                #echo "Evaluating '${currentLine}'"
                currentKey="${currentLine%%: *}"
                currentValue=${currentLine#*: }
                if [ -n "${currentValue}" ] ; then
                    #echo "Key: $currentKey / Value: $currentValue"
                    eval "$currentKey"="${currentValue//@/\\}"
                else
                    #echo "Value of key ${currentKey} is empty, skipping evaluation"
                    :
                fi
                ;;
        esac
    done < "locale/ui_content_${languageToLoad}.yml"
}
