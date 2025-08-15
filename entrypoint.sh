#!/bin/sh

COMMAND=/usr/local/bin/i2pd
if [ "$1" = "--help" ]; then
    set -- $COMMAND --help
else
    # To make ports exposeable
    # Note: $DATA_DIR is defined in /etc/profile
    [ -e "$DATA_DIR"/certificates ] || ln -s /i2pd_certificates "$DATA_DIR"/certificates
    set -- $COMMAND $DEFAULT_ARGS $@
    while [ -e "$DATA_DIR"/.wait ]; do sleep 5; done
fi

exec "$@"
