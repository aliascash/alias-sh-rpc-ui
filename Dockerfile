FROM hermsi/alpine-sshd
MAINTAINER HLXEasy <hlxeasy@gmail.com>

RUN apk update \
 && apk add bash bc curl dialog ncurses

RUN mkdir /root/spectrecoin-sh-rpc-ui
WORKDIR /root/spectrecoin-sh-rpc-ui

COPY include ./include/
COPY sample_config_daemon ./sample_config_daemon/
COPY spectrecoin_rpc_ui.sh .
RUN chmod +x spectrecoin_rpc_ui.sh
