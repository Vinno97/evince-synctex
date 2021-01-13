# Evince SyncTeX

`evince-synctex.sh` provides an easy CLI method to sync your favorite text editor with Evince.

[SyncTex](https://github.com/jlaurens/synctex) is a utility that provides linkage between content in a PDF file and the TeX line it originates from. This can be used to synchronize your editor with your document viewer when writing LaTeX documents, assuming your editor and viewer support it. 
Evince has support for it, but only interacts with editors via D-Bus. Many editors, on the other hand, prefer to sync via commands.

This utility glues these two methods together by acting as an interface between them. It can both be used as a sync command by the editor and as a daemon listening for Evince's messages.

* For **forward syncs** (Editor -> Evince), it requests Evince to sync by sending a D-Bus message.
* For **backward syncs** (Evince -> Editor), the the script starts as a monitoring daemon that listens to Evince's backward sync requests. Each time it receives one, it executes a command to sync back to your editor of choice.

## Usage


### Forward sync

Each editor works slightly different. Please check how to use SyncTex with your specific editor or editor plugin. For instructions on how to use this tool with VSCode, see the end of this README.

To synchronize Evince to a line in your editor, make your editor call the `evince-synctex.sh sync` command with the right arguments for the PDF file, TeX file and line number. Depending on what wildcards your editor uses, it would look something like this:

```sh
evince-synctex.sh sync %PDF% %TEX% %LINE%
```

### Backward sync

Most editors allow you to direct the cursor to a certain line (+column) in a file through the command line. `evince-synctex.sh` allows you to specify these commands using two wildcards: `%f` and `%l`. Before execution, these wildcards are replaced by the TeX filename and line number that it receives from Evince.

VSCode, Sublime and Gedit work with the following commands, respectively:

* `evince-synctex.sh listen code --goto %f:%l`
* `evince-synctex.sh listen subl %f:%l`
* `evince-synctex.sh listen gedit %f +%l`

## Requirements

The utility is written for Bash, but relies on three external programs:

* dbus-monitor
  * For monitoring the D-Bus _(duhh)_
* gdbus
  * For sending D-Bus commands to Evince
* Python 3
  * Requesting the Evince window for a PDF file, requires the path to it to be formatted as an URI. I currently use Python to perform the required string escapes.


### Help

```
Sync your editor with Evince - the GNOME Document Viewer

Uses the D-Bus to send or listen to Evince's sync requests for forwards or
backwards sync. Allows arbitrary editors to sync editors with Evince.

Requires the PDF to be compiled using LaTeX with 'synctex=1'.

Usage:  evince-synctex.sh <method> [options...]
        evince-synctex.sh listen [command] [args...]
        evince-synctex.sh sync <pdfpath> <texpath> <line>
        evince-synctex.sh --help

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
```

## Usage with Visual Studio Code

I personally write my documents in [Visual Studio Code](https://code.visualstudio.com/) with the [Latex Workshop](https://github.com/James-Yu/LaTeX-Workshop) extension. To use `evince-synctex.sh` with it, add these lines to your `settings.json` to enable forward sync.

```json
{
  "latex-workshop.view.pdf.external.synctex.command": "/path/to/evince-synctex.sh",
  "latex-workshop.view.pdf.external.synctex.args": [
    "sync",
    "%PDF%",
    "%TEX%",
    "%LINE%"
  ],
  "latex-workshop.view.pdf.viewer": "external",
  "latex-workshop.view.pdf.external.viewer.command": "evince"
}
```

To enable backward sync, run the following command to start the daemon.

```sh
evince-synctex.sh listen code --goto %f:%l
```
