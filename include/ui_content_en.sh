#!/bin/bash
# ============================================================================
# Set global variables for text output(i.e. for main menu).
#
# Interpret embedded "\Z" sequences in the dialog text by the following character,
# which tells dialog to set colors or video attributes: 0 through 7 are the ANSI
# used in curses: black, red, green, yellow, blue, magenta, cyan and white respectively.
# Bold is set by 'b', reset by 'B'.
# Reverse is set by 'r', reset by 'R'.
# Underline is set by 'u', reset by 'U'.
# The settings are cumulative,
# e.g., "\Zb\Z1" makes the following text bold (perhaps bright) red.
# Restore normal settings with "\Zn".
TITLE_BACK="Spectrecoin Bash RPC Wallet Interface ($VERSION)"
TITLE_TRANS="RECENT TRANSACTIONS"
TITLE_INFO=""
TITLE_MENU="$TITLE_BACK"
TITLE_GAUGE="Please wait"
TITLE_ERROR="ERROR"
TITLE_STARTING_DAEMON="Starting Daemon"
TITEL_GOODBYE="GOODBYE"
TITEL_SEND="Send XSPEC"
TITEL_USERCOMMAND="Enter Command"
TITEL_CURL_RESULT="cURL result"
#
BUTTON_LABEL_ENTER="Enter"
BUTTON_LABEL_OK="OK"
BUTTON_LABEL_LEAVE="Leave"
BUTTON_LABEL_CONTINUE="Continue"
BUTTON_LABEL_PREVIOUS="Previous"
BUTTON_LABEL_NEXT="Next"
BUTTON_LABEL_SEND="Send"
BUTTON_LABEL_EXECUTE="Execute"
BUTTON_LABEL_HELP="Help"
BUTTON_LABEL_ADDRESS_BOOK="Address Book"
BUTTON_LABEL_MAIN_MENU="Main Menu"
BUTTON_LABEL_SHOW_STAKES="Show Stakes"
BUTTON_LABEL_HIDE_STAKES="Hide Stakes"
#
CMD_MAIN_LOCK_WALLET="Lock"
CMD_MAIN_UNLOCK_WALLET="Unlock"
CMD_MAIN_ENCRYPT_WALLET="Encrypt"
CMD_MAIN_REFRESH="Refresh"
CMD_MAIN_TRANS="Transactions"
CMD_MAIN_SEND="Send"
CMD_MAIN_RECEIVE="Receive"
CMD_MAIN_COMMAND="Command"
CMD_MAIN_QUIT="Quit"
#
EXPL_CMD_MAIN_EXIT="Exit interface"
EXPL_CMD_MAIN_USERCOMMAND="Sending commands to daemon"
EXPL_CMD_MAIN_SEND="Send XSPEC from wallet"
EXPL_CMD_MAIN_VIEWTRANS="View all transactions"
EXPL_CMD_MAIN_REFRESH="Update Interface"
EXPL_CMD_MAIN_WALLETLOCK="Wallet, no more staking"
EXPL_CMD_MAIN_WALLETUNLOCK="Wallet for staking only"
EXPL_CMD_MAIN_WALLETENCRYPT="Wallet, provides Security"
EXPL_CMD_MAIN_RECEIVE="Show wallet addresses"
#
ERROR_CURL_MSG_PROMPT="CURL error message:"
ERROR_401_UNAUTHORIZED="Error: RPC login failed.\nDid you change the password without restarting the daemon?\n"
ERROR_DAEMON_NO_CONNECT_FROM_REMOTE="No connection to sprectrecoind could be established.\nYou may need to check your config."
ERROR_DAEMON_ALREADY_RUNNING="Spectrecoind (daemon) already running!\nBut no connection could be established.\nThis means the daemon was just started."
ERROR_DAEMON_STARTING="Spectrecoind is not running.\nStarting Spectrecoind (daemon)..."
ERROR_DAEMON_WAITING_BEGIN="Daemon needs some time to initialize.\nWaiting 1 minute for the daemon..."
ERROR_DAEMON_WAITING_MSG="seconds to go..."
ERROR_DAEMON_WAITING_END="All done. Starting Interface..."
ERROR_TRANS="Error while displaying transactions."
#
TEXT_HEADLINE_WALLET_INFO="Wallet Info"
TEXT_BALANCE="Balance"
TEXT_CURRENCY="XSPEC"
TEXT_WALLET_STATE="Wallet"
TEXT_WALLET_HAS_NO_PW="\Z1no PW\Zn"
TEXT_WALLET_IS_UNLOCKED="\Z4unlocked\Zn"
TEXT_WALLET_IS_LOCKED="\Z1locked\Zn"
#
TEXT_HEADLINE_CLIENT_INFO="Client info"
TEXT_DAEMON_VERSION="Daemon"
TEXT_DAEMON_ERRORS_DURING_RUNTIME="Errors"
TEXT_DAEMON_NO_ERRORS_DURING_RUNTIME="none"
TEXT_DAEMON_IP="IP"
TEXT_DAEMON_PEERS="Peers"
TEXT_DAEMON_DOWNLOADED_DATA="Download"
TEXT_DAEMON_UPLOADED_DATA="Upload"
#
TEXT_HEADLINE_STAKING_INFO="Staking Info"
TEXT_STAKING_STATE="Staking"
TEXT_STAKING_ON="\Z4ON\Zn"
TEXT_STAKING_OFF="\Z1OFF\Zn"
TEXT_STAKING_COINS="Coins"
TEXT_MATRUING_COINS="aging"
TEXT_EXP_TIME="Expected time"
#
TEXT_STAKE="\Z4STAKE\Zn"
TEXT_IMMATURE="\Z5STAKE Pending\Zn"
TEXT_RECEIVED="\Z2RECEIVED\Zn"
TEXT_TRANSFERRED="\Z1TRANSFERRED\Zn"
TEXT_CONFIRMATIONS="confirmations"
TEXT_ADDRESS="address"
TEXT_TXID="txid"
#
TEXT_CLIPBOARD_HINT="Use \Z6[CTRL]\Zn + \Z6[SHIFT]\Zn + \Z6[V]\Zn to copy from clipboard."
TEXT_SEND_DESTINATION_ADDRESS_EXPL="Destination address"
TEXT_SEND_DESTINATION_ADDRESS="Address"
TEXT_SEND_AMOUNT_EXPL="Amount of XSPEC"
TEXT_SEND_AMOUNT="Amount"
TEXT_SEND_EXPL="Enter the destination address."
#
TEXT_PW_EXPL="Enter wallet password"
#
TEXT_USERCOMMAND_EXPL="Here you can enter commands that will be send to the Daemon."
TEXT_USERCOMMAND_CMD_EXPL="type help for info"
TEXT_USERCOMMAND_CMD="Command"
TEXT_USERCOMMAND_PARAMS_EXPL="seperated by spaces"
TEXT_USERCOMMAND_PARAMS="Parameter"
#
TEXT_GAUGE_ALLDONE="All done."
TEXT_GAUGE_DEFAULT="Getting data from daemon..."
TEXT_GAUGE_GET_INFO="Getting general info data from daemon..."
TEXT_GAUGE_PROCESS_INFO="Processing general info data..."
TEXT_GAUGE_GET_STAKING_DATA="Getting staking data from daemon..."
TEXT_GAUGE_PROCESS_STAKING_DATA="Processing staking data..."
TEXT_GAUGE_GET_TRANS="Getting transactions data from daemon..."
TEXT_GAUGE_PROCESS_TRANS="Processing transactions data..."
