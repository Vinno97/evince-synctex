#!/bin/bash

set -e
# set -x

usage="Usage:  evince-synctex.sh <method> [options...]
        evince-synctex.sh listen [command] [args...]
        evince-synctex.sh sync <pdfpath> <texpath> <line>
        evince-synctex.sh --help"

help="Sync your editor with Evince - the GNOME Document Viewer

Uses the D-Bus to send or listen to Evince's sync requests for forwards or
backwards sync. Allows arbitrary editors to sync editors with Evince.

Requires the PDF to be compiled using LaTeX with 'synctex=1'.

$usage

Methods:
    sync            Performs a forward sync.
                    Attempts to sync an open Evince window to a specific line
                    of a TeX file. Only works when the PDF is already opened.
    listen          Listens for a backward sync.
                    Waits for Evince's 'SyncSource' signal on the D-Bus and 
                    executes a command when one is received.
                    Defaults to running 'code --goto %f:%l'
                    
Options:
    Sync
        pdfpath     The path to the target PDF file
        texpath     The path to the originating TeX file
        line        The line of the TeX file to sync to
    Listen
        command     Command that is ran when Evince requests a backwards sync
        args...     Arguments to the commands, uses the following replacements:
                        %f  Gets replaced by the full TeX filename
                        %l  Gets replaced by the line number

Examples:
    Forward Sync:
        evince-synctex.sh sync document.pdf document.tex 30

    Backward Sync using VS Code (default):
        evince-synctex.sh listen code --goto %f:%l
    Backward Sync using Sublime:
        evince-synctex.sh listen subl %f:%l
    Backward Sync using Gedit (only works when file is already open):
        evince-synctex.sh listen gedit %f +%l
"

sync() {
    if [ ! $# -eq 3 ]; then
        echo -e "Expected exactly 3 arguments for sync, got $#\n$usage" 1>&2
        exit 1
    fi

    pdfpath=$(readlink -f "$1")
    srcpath=$(readlink -f "$2")
    line=$3

    if ! [ -f "$srcpath" ]; then
        echo "Warning: $srcpath does not exists." 1>&2
    fi
    if ! [ -f "$pdfpath" ]; then
        echo "Warning: $pdfpath does not exists." 1>&2
    fi
    if ! [ $line -eq $line ] 2>/dev/null; then
        echo -e "<line> should be a number, got $line\n$usage" 1>&2
        exit 1
    fi

    echo "Syncing Evince to line $line of '$(basename "$srcpath")' for '$(basename "$pdfpath")'"

    # TODO: Try to remove perl dependency
    pdfuri=$(perl -MURI::file -e 'print URI::file->new(<STDIN>)."\n"' <<<"$pdfpath")

    destination=$(gdbus call \
    --session \
    -d org.gnome.evince.Daemon \
    -o /org/gnome/evince/Daemon \
    -m org.gnome.evince.Daemon.FindDocument \
    "$pdfuri" false | cut -d\' -f2)

    if [ -z "$destination" ]; then
        echo "No Evince window found for $pdfpath" 1>&2
        exit 1
    fi

    gdbus call \
    --session \
    -d $destination \
    -o /org/gnome/evince/Window/0 \
    -m org.gnome.evince.Window.SyncView \
    "$srcpath" "($line, 1)" 0 > /dev/null

    echo "Done!"

}

listen() {
    cmd=${@:-'code --goto %f:%l'}
    echo "Listening to Evince SyncSource requests. Executing '$cmd' on new signals"
    # echo "Running command '$cmd' on SyncSource request"


    dbus-monitor "type=signal,interface=org.gnome.evince.Window,member=SyncSource" |
    while read -r line
    do
        parts=($line)

        if [ "${parts[0]}" == signal ]; then
            exc_cmd=($cmd)
            filename=""
            linenr=""
        elif [ ${parts[0]} == string ]; then
            filename=${parts[1]}
        elif [ ${parts[0]} == int32 ] && [ -z "$linenr" ]; then
            linenr=${parts[1]}

            echo "=================================================="

            filename=$(printf '%s' "$filename" | sed 's!%20! !' | head -c -1 | tail -c +9)
            echo "Filename: $filename"
            echo "Line number: $linenr"

            for i in "${!exc_cmd[@]}"; do
                # Do all replacements here
                exc_cmd[$i]=$(echo "${exc_cmd[$i]}" | sed "s/%l/$linenr/")
                exc_cmd[$i]=$(echo "${exc_cmd[$i]}" | sed 's!%f!'"$filename"'!')
            done

            echo "Executing: '${exc_cmd[@]}'"

            "${exc_cmd[@]}" < /dev/null
        fi
    done
}


if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo -e "$help"
    exit 0
fi

if [ $# -eq 0 ]; then
    echo -e "$usage" 1>&2
    exit 1
fi

method="$1"
shift 1

case $method in
  sync) sync "$@";;
  listen) listen "$@";;
  * ) echo -e "Unknown method \"$method\", expected one of: sync|listen\n$usage" 1>&2; exit 1;;
esac

