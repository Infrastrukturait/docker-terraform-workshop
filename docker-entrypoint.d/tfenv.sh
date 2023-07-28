#!/usr/bin/env bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

## Global Bash settings
# The exit status of the last command that threw a non-zero exit code is returned.
set -o pipefail

# Exit when your script tries to use undeclared variables.
set -o nounset

# If set, Bash includes filenames beginning with a ‘.’ in the results of filename expansion.
# The filenames ‘.’ and ‘..’ must always be matched explicitly, even if dotglob is set.
shopt -s dotglob

if [ -f ".terraform-version" ]; then

    unset TFENV_TERRAFORM_VERSION

    TFENV_BIN=$(which tfenv)

    $TFENV_BIN use
fi

