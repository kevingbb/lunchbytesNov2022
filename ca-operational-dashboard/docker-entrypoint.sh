#!/bin/sh
# vim:sw=4:ts=4:et

set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

if [ "$1" = "nginx" -o "$1" = "nginx-debug" ]; then
    if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
        entrypoint_log "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"

        entrypoint_log "$0: Looking for shell scripts in /docker-entrypoint.d/"
        find "/docker-entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
            case "$f" in
                *.envsh)
                    if [ -x "$f" ]; then
                        entrypoint_log "$0: Sourcing $f";
                        . "$f"
                    else
                        # warn on shell scripts without exec bit
                        entrypoint_log "$0: Ignoring $f, not executable";
                    fi
                    ;;
                *.sh)
                    if [ -x "$f" ]; then
                        entrypoint_log "$0: Launching $f";
                        "$f"
                    else
                        # warn on shell scripts without exec bit
                        entrypoint_log "$0: Ignoring $f, not executable";
                    fi
                    ;;
                *) entrypoint_log "$0: Ignoring $f";;
            esac
        done

        entrypoint_log "$0: Configuration complete; ready for start up"
    else
        entrypoint_log "$0: No files found in /docker-entrypoint.d/, skipping configuration"
    fi
fi


# Set up endpoint for env retrieval
echo "window._env_ = {" > /usr/share/nginx/html/env_config.js
# Collect enviroment variables for react
eval enviroment_variables="$(env | grep REACT_APP.*=)"
# Loop over variables
env | grep REACT_APP.*= | while read -r line; 
do
    printf "%s',\n" $line | sed "s/=/:'/" >> /usr/share/nginx/html/env_config.js
    # Notify the user
    printf "REACT_APP env variable %s' was injected into React App. \n" $line | sed "0,/=/{s//:'/}"
done
# Collect enviroment variables for ACA
eval enviroment_variables="$(env | grep CONTAINER_APP_ENV.*=)"
# Loop over variables
env | grep CONTAINER_APP_ENV.*= | while read -r line; 
do
    printf "%s',\n" $line | sed "s/=/:'/" >> /usr/share/nginx/html/env_config.js
    # Notify the user
    printf "CONTAINER_APP_ENV env variable %s' was injected into React App. \n" $line | sed "0,/=/{s//:'/}"
done
# End the object creation
echo "}" >> /usr/share/nginx/html/env_config.js
echo "Enviroment Variable Injection Complete."


exec "$@"