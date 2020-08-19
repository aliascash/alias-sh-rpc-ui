#!/bin/bash
# ============================================================================
#
# This is a component of the Aliaswallet shell rpc ui
#
# SPDX-FileCopyrightText: © 2020 Alias Developers
# SPDX-FileCopyrightText: © 2016 SpectreCoin Developers
# SPDX-License-Identifier: MIT
#
# Definition of used constants
#
# Author: 2018 HLXEasy
#
# ============================================================================

# Dialog exit status codes
idx=0
DIALOG_OK=${idx}
DIALOG_CANCEL=$((idx+=1))
DIALOG_HELP=$((idx+=1))
DIALOG_EXTRA=$((idx+=1))
DIALOG_ITEM_HELP=$((idx+=1))
DIALOG_ESC=255
DIALOG_ERROR=-1

# Fields on transaction array (RPC listtransactions)
idx=0
TA_ACCOUNT=${idx}
TA_ADDRESS=$((idx+=1))
TA_AMOUNT=$((idx+=1))
TA_BLOCKHASH=$((idx+=1))
TA_BLOCKINDEX=$((idx+=1))
TA_BLOCKTIME=$((idx+=1))
TA_CATEGORY=$((idx+=1))
TA_CONFIRMATIONS=$((idx+=1))
TA_CURRENCY=$((idx+=1))
TA_FEE=$((idx+=1))
TA_GENERATED=$((idx+=1))
TA_NARRATION=$((idx+=1))
TA_TIME=$((idx+=1))
TA_TIMERECEIVED=$((idx+=1))
TA_TXID=$((idx+=1))
TA_VERSION=$((idx+=1))

# Fields on wallet info (RPC getinfo)
idx=0
WALLET_VERSION=${idx}
WALLET_BALANCE=$((idx+=1))
WALLET_BALANCE_PUBLIC=$((idx+=1))
WALLET_BALANCE_PRIVATE=$((idx+=1))
WALLET_BALANCE_UNCONF=$((idx+=1))
WALLET_BALANCE_UNCONF_PUBLIC=$((idx+=1))
WALLET_BALANCE_UNCONF_PRIVATE=$((idx+=1))
WALLET_STAKE=$((idx+=1))
WALLET_STAKE_PUBLIC=$((idx+=1))
WALLET_STAKE_PRIVATE=$((idx+=1))
WALLET_STAKE_WEIGHT=$((idx+=1))
WALLET_STAKE_WEIGHT_PUBLIC=$((idx+=1))
WALLET_STAKE_WEIGHT_PRIVATE=$((idx+=1))
WALLET_CONNECTIONS=$((idx+=1))
WALLET_DATARECEIVED=$((idx+=1))
WALLET_DATASENT=$((idx+=1))
WALLET_IP=$((idx+=1))
WALLET_UNLOCKED_UNTIL=$((idx+=1))
WALLET_ERRORS=$((idx+=1))
WALLET_MODE=$((idx+=1))
WALLET_STATE=$((idx+=1))
WALLET_PROTOCOLVERSION=$((idx+=1))
WALLET_WALLETVERSION=$((idx+=1))
WALLET_NEWMINT=$((idx+=1))
WALLET_RESERVE=$((idx+=1))
WALLET_BLOCKS=$((idx+=1))
WALLET_TIMEOFFSET=$((idx+=1))
WALLET_MONEY_SUPPLY=$((idx+=1))
WALLET_MONEY_SUPPLY_PUBLIC=$((idx+=1))
WALLET_MONEY_SUPPLY_PRIVATE=$((idx+=1))
WALLET_PROXY=$((idx+=1))
WALLET_PROOF_OF_WORK=$((idx+=1))
WALLET_PROOF_OF_STAKE=$((idx+=1))
WALLET_TESTNET=$((idx+=1))
WALLET_KEYPOOLSIZE=$((idx+=1))
WALLET_PAYTXFEE=$((idx+=1))
WALLET_MININPUT=$((idx+=1))

# Conversion direction
idx=0
CONVERT_NOTHING=${idx}
CONVERT_PUBLIC_TO_PRIVATE=$((idx+=1))
CONVERT_PRIVATE_TO_PUBLIC=$((idx+=1))

# Coin type to send
idx=0
SEND_NOTHING=${idx}
SEND_PUBLIC_COINS=$((idx+=1))
SEND_PRIVATE_COINS=$((idx+=1))
