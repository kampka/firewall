#!/bin/sh
#
# Copyright (c) 2012, Christian Kampka <chris@emerge-life.de>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the <organization> nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# firewall - A simple firewall management tool based on iptables.
# See README for propper documentation.


VERBOSE=0

CONFIG_DIR="/etc/firewall"
RULES_DIR="$CONFIG_DIR/rules.d"

# If iptables is spcified via the environment, use is
IPTABLES=$IPTABLES

# Execute all scripts in a given directory
run_dir()
{
    DIR=$1; shift
    ARG=$1; shift
    OPTS=$@

    if [ $VERBOSE -gt 0 ]; then
        OPTS="$OPTS -v"
    fi

    /bin/run-parts $OPTS --regex .*rules$ -a $ARG $DIR
}


# Evaluate the standard input and try to find the proper target to run for a given action.
# A valid target can be a directory, a full filepath or the name of a file located in $RULES_DIR.
run()
{

    ACTION=$1; shift
    TARGET=$@

    OPTS=""
    if [ $ACTION = "stop" ];
    then
        OPTS="$OPTS --reverse"
    fi

    if [ -z "$TARGET" ];
    then
        TARGET=$RULES_DIR
    fi
    for e in $TARGET;
    do
        debug "Evaluating target $e"
        if [ -d "$e" ];
        then
            run_dir "$e" $ACTION $OPTS
        elif [ -x "$e" ];
        then
            $e $ACTION
        elif [ -x "$RULES_DIR/$e" ];
        then
            e="$RULES_DIR/$e"
            $e $ACTION
        else
            log "Found nothing to do for target $e"
        fi
    done
}

# Try to determain the correct iptables binary.
# Defaults to '/sbin/iptables' as the most common location.
find_iptables()
{

    if [ -z $IPTABLES ];
    then
        IPTABLES=$(which iptables 2>/dev/null || echo "/sbin/iptables")
    fi

}

# Only log messages if verbosity is high enough
debug()
{
    if [ $VERBOSE -gt 0 ]; then
        log $@
    fi
}

# Log messages to stdout
log()
{
    echo $@
}

usage() {
    echo "usage: firewall [OPTIONS] subcommand [rule] "
    echo
    echo "Available options are:"
    echo "   -e,--executable <path>     Path to the iptables executable (default: auto)."
    echo "   -v                         Produce verbose output, can be given more than once."
    echo "   -h                         Print this help message."
    echo "Available subcommands are:"
    echo "   start                      Start the firewall. If rule is specified, only start that rule."
    echo "   stop                       Stop the firewall. If rule is specified, only stop that rule."
}

verbosity()
{
    if [ $VERBOSE -gt 1 ];
    then
        set -v
        set -x
    fi
}

main()
{
    # If there is not at least one action given, exit
    if [ $# -lt 1 ]; then
        usage
        exit 1
    fi

    # probe for an iptables executable
    find_iptables

    ACTION=""

    while [ $# -gt 0 ]
    do
        case "$1" in
            start)
                shift
                ACTION=start
                break
                ;;
            stop)
                shift
                ACTION=stop
                break
                ;;
            -v)
                VERBOSE=$((VERBOSE+1))
                verbosity
                ;;
            -e|--executable)
                shift
                IPTABLES=$1
                ;;
            -h|*)
                usage
                exit 1
                ;;
        esac
        shift

    done

    # If no action could be found in arguments, exit.
    if [ -z $ACTION ]; then
        usage
        exit 1
    fi

    debug "Using '$IPTABLES' as iptables"
    run $ACTION $@
}

main "$@"
