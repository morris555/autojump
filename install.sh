#!/usr/bin/env bash

function add_msg {
    echo
    echo "Please add the line to ~/.${2}rc :"
    echo

    if [ "${1}" == "global" ]; then
        echo -e "\t[[ -s /etc/profile.d/autojump.${2} ]] && source /etc/profile.d/autojump.${2}"
    elif [ "${1}" == "local" ]; then
        echo -e "\t[[ -s ~/.autojump/etc/profile.d/autojump.${2} ]] && source ~/.autojump/etc/profile.d/autojump.${2}"
    fi

    echo
    echo "You need to run 'source ~/.${2}rc' before you can start using autojump."
    echo
    echo "To remove autojump, run './uninstall.sh'"
    echo
}

function help_msg {
    echo
    echo "./install.sh [--global or --local] [--bash or --zsh] [--prefix /usr/] "
    echo
    echo "If run without any arguments, the installer will:"
    echo
    echo -e "\t- as root install globally into /usr/"
    echo -e "\t- as non-root install locally to ~/.autojump/"
    echo -e "\t- version will be based on \$SHELL environmental variable"
    echo
}

# Default install directory.
shell=`echo ${SHELL} | awk -F/ '{ print $NF }'`
force=
if [[ ${UID} -eq 0 ]]; then
    local=
    prefix=/usr
else
    local=true
    prefix=~/.autojump
fi

# Command line parsing
while true; do
    case "$1" in
        -b|--bash)
            shell="bash"
            shift
            ;;
        -f|--force)
            force=true
            shift
            ;;
        -g|--global)
            local=
            shift
            ;;
        -h|--help|-\?)
            help_msg;
            exit 0
            ;;
        -l|--local)
            local=true
            prefix=~/.autojump
            shift
            ;;
        -p|--prefix)
            if [ $# -gt 1 ]; then
                prefix=$2; shift 2
            else
                echo "--prefix or -p requires an argument" 1>&2
                exit 1
            fi
            ;;
        -z|--zsh)
            shell="zsh"
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "invalid option: $1" 1>&2;
            help_msg;
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# check for valid local install options
if [[ ${UID} != 0 ]] && [ ! ${local} ]; then
    echo
    echo "Please rerun as root or use the --local option."
    echo
    exit 1
fi

# check shell if supported
if [[ ${shell} != "bash" ]] && [[ ${shell} != "zsh" ]]; then
    echo "Unsupported shell (${shell}). Use --bash or --zsh to explicitly define shell."
    exit 1
fi

# check Python version
if [ ! ${force} ]; then
    python_version=`python -c 'import sys; print(sys.version_info[:])'`

    if [[ ${python_version:1:1} -eq 2 && ${python_version:4:1} -lt 6 ]]; then
        echo
        echo "Incompatible Python version, please upgrade to v2.6+."
        if [[ ${python_version:4:1} -ge 4 ]]; then
            echo
            echo "Alternatively, you can download v12 that supports Python v2.4+ from:"
            echo
            echo -e "\thttps://github.com/joelthelion/autojump/downloads"
            echo
        fi
        exit 1
    fi
fi

echo
echo "Installing ${shell} version of autojump to ${prefix} ..."
echo

# INSTALL AUTOJUMP
mkdir -p ${prefix}/share/autojump/
mkdir -p ${prefix}/bin/
mkdir -p ${prefix}/share/man/man1/
cp -v ./bin/icon.png ${prefix}/share/autojump/
cp -v ./bin/jumpapplet ${prefix}/bin/
cp -v ./bin/autojump ${prefix}/bin/
cp -v ./bin/autojump_argparse.py ${prefix}/bin/
cp -v ./docs/autojump.1 ${prefix}/share/man/man1/

# global installation
if [ ! ${local} ]; then
    # install _j to the first accessible directory
    if [ ${shell} == "zsh" ]; then
        success=
        fpath=`/usr/bin/env zsh -c 'echo $fpath'`
        for f in ${fpath}; do
            install -v -m 0755 ./bin/_j ${f} && success=true && break
        done

        if [ ! ${success} ]; then
            echo
            echo "Couldn't find a place to put the autocompletion file, please copy _j into your \$fpath"
            echo "Installing the rest of autojump ..."
            echo
        fi
    fi

    if [ -d "/etc/profile.d" ]; then
        cp -v ./bin/autojump.sh /etc/profile.d/
        cp -v ./bin/autojump.${shell} /etc/profile.d/
        add_msg "global" ${shell}
    else
        echo "Your distribution does not have a '/etc/profile.d/' directory, please create it manually or use the local install option."
    fi
else # local installation
    mkdir -p ${prefix}/etc/profile.d/
    cp -v ./bin/autojump.sh ${prefix}/etc/profile.d/
    cp -v ./bin/autojump.${shell} ${prefix}/etc/profile.d/

    if [ ${shell} == "zsh" ]; then
        mkdir -p ${prefix}/functions/
        install -v -m 0755 ./bin/_j ${prefix}/functions/
    fi

    add_msg "local" ${shell}
fi
