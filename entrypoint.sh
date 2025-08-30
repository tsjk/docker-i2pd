#!/bin/bash

set -m

declare -g -i DO_RUN=0
declare -g -i I2PD_PID=0

__graceful_stop() {
  [[ "${1}" == "-q" ]] || printf " -- gracefully stopping i2pd..."
  DO_RUN=0; kill -INT ${I2PD_PID}
  local -i t=0 T=600
  while kill -0 ${I2PD_PID} > /dev/null 2>&1 && [[ ${t} -lt ${T} ]]; do
    sleep 1; t+=1; [[ $((t % 15)) -ne 0 ]] || printf '.'
  done
}

__terminate() {
  [[ "${1}" == "-q" ]] || printf " -- terminating i2pd..."
  DO_RUN=-1; kill -TERM ${I2PD_PID}
  local -i t=0 T=60
  while kill -0 ${I2PD_PID} > /dev/null 2>&1 && [[ ${t} -lt ${T} ]]; do
    sleep 1; t+=1; [[ $((t % 5)) -ne 0 ]] || printf '+'
  done
}

__kill() {
  kill -KILL ${I2PD_PID}; printf '!'
}

__sigterm_handler() {
  printf "SIGTERM received"
  if mkdir "/tmp/.sigterm-handler-lock-1" > /dev/null 2>&1; then
    if [[ ${I2PD_PID} -gt 0 && ${DO_RUN} -gt 0 ]]; then
      __graceful_stop
      ! kill -0 ${I2PD_PID} > /dev/null 2>&1 || __terminate -q
      ! kill -0 ${I2PD_PID} > /dev/null 2>&1 || __kill
      kill -0 ${I2PD_PID} > /dev/null 2>&1 || printf ' Stopped.'
    fi
    rmdir "/tmp/.sigterm-handler-lock-1"
  elif mkdir "/tmp/.sigterm-handler-lock-2" > /dev/null 2>&1; then
    if [[ ${I2PD_PID} -gt 0 &&  ${DO_RUN} -eq -1 ]]; then
      __terminate
      ! kill -0 ${I2PD_PID} > /dev/null 2>&1 || __kill
    fi
    kill -0 ${I2PD_PID} > /dev/null 2>&1 || printf ' Stopped.'
    rmdir "/tmp/.sigterm-handler-lock-2" > /dev/null 2>&1
  else
    printf " - signal ignored."
  fi
  printf '\n'
}

__sighup_handler() {
  printf "SIGHUP received"
  if mkdir "/tmp/.sighup-handler-lock" > /dev/null 2>&1; then
    if [[ ${I2PD_PID} -gt 0 && ${DO_RUN} -gt 0 ]]; then
      printf ' -- restarting i2pd...'
      __graceful_stop -q
      ! kill -0 ${I2PD_PID} > /dev/null 2>&1 || __terminate -q
      ! kill -0 ${I2PD_PID} > /dev/null 2>&1 || __kill
      kill -0 ${I2PD_PID} > /dev/null 2>&1 || printf ' i2pd stopped.\n'
    fi
    rmdir "/tmp/.sigterm-handler-lock-1"
  else
    printf " - signal ignored."
  fi
}

trap '__sigterm_handler' SIGTERM
trap '__sighup_handler' SIGHUP


COMMAND=/usr/local/bin/i2pd
if [ "$1" = "--help" ]; then
    set -- "${COMMAND}" --help
    exec "${@}"
else
    # To make ports exposeable
    # Note: ${DATA_DIR} is defined in /etc/profile
    [ -e "${DATA_DIR}"/certificates ] || ln -s /i2pd_certificates "${DATA_DIR}"/certificates
    set -- "${COMMAND}" ${DEFAULT_ARGS} "${@}"
    while [ -e "${DATA_DIR}"/.wait ]; do sleep 5; done
fi

DO_RUN=1
while [[ ${DO_RUN} -gt 0 ]]; do
  printf 'Starting i2pd...\n'
  "${@}" "$(: i2pd)" &
  I2PD_PID=${!}
  printf 'i2pd started.\n'
  while kill -0 ${I2PD_PID} > /dev/null 2>&1; do
    wait ${I2PD_PID}; done
  printf 'i2pd exited.'
  [[ ${DO_RUN} -le 0 ]] || { printf ' Restarting i2pd in 5 seconds...'; sleep 5; }
  printf '\n'
done
