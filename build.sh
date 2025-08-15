#!/bin/bash

[[ -n "${1}" ]] || exit 254

I2PD_VERSION="${1}"

( export BUILDAH_FORMAT=docker && \
    podman build --network slirp4netns:allow_host_loopback=true,port_handler=slirp4netns --pull --layers --force-rm --build-arg GIT_TAG="${I2PD_VERSION}" -t "local/i2pd:${I2PD_VERSION}" . )
