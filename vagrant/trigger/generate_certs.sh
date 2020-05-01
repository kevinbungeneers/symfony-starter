#! /usr/bin/env bash

if [[ -f vagrant/trigger/cert.args && $(< vagrant/trigger/cert.args) == "$@" ]]; then
    exit 0
fi

# Check if mkcert has been installed
command -v mkcert >/dev/null 2>&1 || { echo >&2 "mkcert is required but is not installed. Aborting."; exit 1; }

# Generate the cetificates
(cd docker/traefik/certs; mkcert "$@")

# Rename them to something universal
for f in docker/traefik/certs/*; do mv "$f"  "${f/$1+[0-9]/application}"; done

# Dump the passed arguments to a file, so we can compare the args of future runs
# and decide to skip generation if they're the same
echo $@ > vagrant/trigger/cert.args