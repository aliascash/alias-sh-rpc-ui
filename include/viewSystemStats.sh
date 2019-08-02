#!/bin/bash
# ============================================================================
#
# This is a component of the Spectrecoin shell rpc ui
#
# Author: 2019 dave#0773@discord
#
# ============================================================================
viewSystemStats() {
    local _space_free=$(df -h /home/$(whoami) \
                            | grep "/dev/root" \
                            | tr -s ' ' \
                            | cut -d' '  -f 4)
    local _space_total=$(df -h /home/$(whoami) \
                            | grep "/dev/root" \
                            | tr -s ' ' \
                            | cut -d' '  -f 2)
    local _temp=$(vcgencmd measure_temp \
                            | cut -d'=' -f 2)
    local _ram_total=$(grep "MemTotal" /proc/meminfo \
                            | tr -s ' ' \
                            | cut -d' '  -f 2)
    _ram_total=$(echo "scale=0 ; ${_ram_total}/1024" | bc)
    local _ram_available=$(grep "MemAvailable" /proc/meminfo \
                            | tr -s ' ' \
                            | cut -d' '  -f 2)
    _ram_available=$(echo "scale=0 ; ${_ram_available}/1024" | bc)
    local _swap=$(grep "SwapTotal" /proc/meminfo \
                            | tr -s ' ' \
                            | cut -d' '  -f 2)
    local _pi_version=$(cat /sys/firmware/devicetree/base/model)
    local _cpu_max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
    local _cpu_max_freq="$(echo ${_cpu_max_freq} | sed 's/\(.\{1\}\)\(.\{1\}\)\(.*\)/\1.\2/')GHz"
    local _cpu_threshold_freq=$(cat /sys/devices/system/cpu/cpufreq/ondemand/up_threshold)
    local _kernel=$(uname -r)
    local _s="${TEXT_SYSTEM}:\n"
          _s+="${_pi_version}\n"
          _s+="${TEXT_MAX_FREQENCY}: ${_cpu_max_freq} (${TEXT_THRESHOLD} ${_cpu_threshold_freq}%)\n"
          _s+="${TEXT_TEMPERATURE}: ${_temp}\n"
          _s+="\n${TEXT_SD_CARD}:\n"
          _s+="${TEXT_FREE_DISK_SPACE}: ${_space_free}B/${_space_total}B\n"
          _s+="\n${TEXT_OS}:\n"
          _s+="${TEXT_KERNEL}: ${_kernel}\n"
          _s+="${TEXT_FREE_RAM}: ${_ram_available}MB/${_ram_total}MB\n"
          if [ ${_swap} -eq 0 ]; then
              _s+="${TEXT_SWAP_DISABLED}"
          else
              _swap=$(echo "scale=0 ; ${_swap}/1024" | bc)
              _s+="${TEXT_SWAP_SIZE}: ${_swap}MB"
          fi
    local _exit_status
    dialog \
        --backtitle "${TITLE_BACK}" \
        --colors \
        --no-shadow \
        --title "${TITLE_SYSTEM_STATS}" \
        --yes-label "${BUTTON_LABEL_REFRESH}" \
        --no-label "${BUTTON_LABEL_BACK}" \
        --default-button 'ok' \
        --yesno "${_s}" 0 0
    _exit_status=$?
    case ${_exit_status} in
        ${DIALOG_ESC})
            advancedmenu;;
        ${DIALOG_OK})
            viewSystemStats;;
        ${DIALOG_CANCEL})
            advancedmenu;;
        *)
            errorHandling "${ERROR_SYSTEM_STATS_FATAL}" \
                                 1;;
    esac
}
