# /*
#  * Copyright (C) Trafikito.com
#  * All rights reserved.
#  *
#  * Redistribution and use in source and binary forms, with or without
#  * modification, are permitted provided that the following conditions
#  * are met:
#  * 1. Redistributions of source code must retain the above copyright
#  *    notice, this list of conditions and the following disclaimer.
#  * 2. Redistributions in binary form must reproduce the above copyright
#  *    notice, this list of conditions and the following disclaimer in the
#  *    documentation and/or other materials provided with the distribution.
#  *
#  * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
#  * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
#  * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#  * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
#  * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#  * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#  * SUCH DAMAGE.
#  */

echo ""
echo ""
echo "  _____           __ _ _    _ _"
echo " |_   _| __ __ _ / _(_) | _(_) |_ ___"
echo "   | || '__/ _\` | |_| | |/ / | __/ _ \\"
echo "   | || | | (_| |  _| |   <| | || (_) |"
echo "   |_||_|  \__,_|_| |_|_|\_\_|\__\___/"
echo ""
echo ""
echo "    Trafikito agent installation"
echo ""
echo ""

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

export URL="https://ap-southeast-1.api.trafikito.com"

ECHO=/bin/echo
fn_prompt() {
    default=$1
    mesg=$2
    # if not running with a tty returns $default
    if [ ! "`tty`" ]; then
        return 1
    fi
    while true; do
        $ECHO -n "$mesg "; read x
        if [ -z "$x" ]; then
            answer="$default"
        else
            case "$x" in
                y*|Y*) answer=Y ;;
                n*|N*) answer=N ;;
                *) $ECHO "Please reply y or n"
                continue
            esac
        fi
        if [ "$answer" = "$default" ]; then
            return 1
        else
            return 0
        fi
    done
}

usage() {
    (
    echo
    echo "Usage: sh $0 --user_api_key=<api_key> --workspace_id=<workspace_id> [--servername=<servername>]"
    echo
    echo "To install Trafikito agent you need to get server api key, workspace id, and (optional)"
    echo "default name."
    echo
    echo "To get all the details please follow these steps:"
    echo "  1. Visit https://trafikito.com/servers"
    echo "  2. Find your server on servers list or add new one"
    echo "  3. Click 3 dots button to open menu and select: How to install?"
    echo "  4. Use this command (replace <user_api_key> and <server_id> with correct values):"
    echo "     sh $0 --user_api_key=<user_api_key> --workspace_id=<workspace_id> [--hostnae=<default name>]"
    ) 1>&2
    exit 1
}

# parse arguments
for x in $*; do
    option=`echo "$x" | sed -e 's#=.*##'`
    arg=`echo "$x" | sed -e 's#.*=##'`
    case "$option" in
        --user_api_key) USER_API_KEY="$arg" ;;
        --workspace_id) WORKSPACE_ID="$arg" ;;
        --servername)   SERVER_NAME="$arg" ;;
        *) echo "Bad option '$option'" 1>&2
           usage
    esac
done

test -z "$USER_API_KEY" && echo "Option '--user_api_key' with an argument is required" 1>&2 && usage
test -z "$WORKSPACE_ID" && echo "Option '--workspace_id' with an argument is required" 1>&2 && usage
if [ -z "$SERVER_NAME" ]; then
    SERVER_NAME=`hostname -f`
    "$ECHO" -n "Name this Trafikito instance [${SERVER_NAME}]: "; read x
    if [ "$x" ]; then
        SERVER_NAME="$x"
    fi
fi

# running as root or user ?
RUNAS="nobody"
WHOAMI=`whoami`
if [ "$WHOAMI" != "root" ]; then
    echo "If possible, run installation as root user."
    echo "Root user is used to make script running as 'nobody' which improves security."
    echo "To install as root either log in as root and execute the script or use:"
    echo
    echo "  sudo sh $0"
    echo
    fn_prompt "N" "Continue as $WHOAMI [yN]: " || exit 1
    RUNAS="$WHOAMI"
fi

# get BASEDIR
export BASEDIR="/opt/trafikito"
while true; do
    fn_prompt "Y" "Going to install Trafikito in $BASEDIR [Yn]: "
    if [ $? -eq 0 ]; then
        echo -n "  Enter directory for installation: "; read BASEDIR
        # test for starting /
        echo $BASEDIR | grep -q '^\/'
        if [ $? -ne 0 ]; then
            echo "    Directory for installation must be an absolute path!"
            BASEDIR="/opt/trafikito"
            continue
        fi
        # test for spaces in path
        echo $BASEDIR | grep -vq ' '
        if [ $? -ne 0 ]; then
            echo "    Directory name for installation must not contain spaces!"
            BASEDIR="/opt/trafikito"
            continue
        fi
    fi
    if [ -d $BASEDIR ]; then
        fn_prompt "Y" "  Found existing $BASEDIR: okay to remove it? [Yn]: "
        if [ $? -eq 1 ]; then
            if [ -f $BASEDIR/lib/remove_startup.sh ]; then
                . $BASEDIR/lib/remove_startup.sh
            fi
            reason=`rm -rf $BASEDIR 2>&1`
            if [ $? -ne 0 ]; then
                echo "  Remove failed: $reason - please try again"
                continue
            fi
        else
            continue
        fi
    fi
    break
done

mkdir -p $BASEDIR 2>/dev/null
if [ $? -ne 0 ]; then
    fn_prompt "Y" "Found existing $BASEDIR: okay to remove it? [Yn]: "
    rm -rf $BASEDIR
    mkdir -p $BASEDIR || exit 1
fi

# create std subdirs
mkdir -p $BASEDIR/etc
mkdir -p $BASEDIR/lib
mkdir -p $BASEDIR/var

# build config and source it
CONFIG=$BASEDIR/etc/trafikito.cfg
(
echo export RUNAS=\"$RUNAS\"
echo export USER_API_KEY=\"$USER_API_KEY\"
echo export WORKSPACE_ID=\"$WORKSPACE_ID\"
echo export SERVER_NAME=\"$SERVER_NAME\"
echo export TMP_FILE=\"$BASEDIR/var/trafikito.tmp\"
) >$CONFIG

. $CONFIG

# function to install a tool
fn_install_tool() {
    tool=$1
    help=$2
    pkg=$tool  # in case $tool is in a package
    echo -n "  $tool - $help: "

    # check if command is installed
    x=`which $tool`
    if [ -z "$x" ]; then
        echo "not found - going to install it"
    else
        echo "found $x"
        return 0
    fi

    if [ "$WHOAMI" != 'root' ]; then
        echo -n "  Need root privilege to install '$pkg': please install it manually [enter]: "; read x
        return
    fi

    fn_prompt "Y" "  Install package $pkg [Yn]: "
    if [ $? -eq 0 ]; then
        return 1
    fi
    if [ -x /usr/bin/apt-get ]; then # Debian
        /usr/bin/apt-get -y install "$pkg"
    elif [ -x /usr/bin/yum ]; then # RedHat
        /usr/bin/yum -y install "$pkg"
    elif [ -x /sbin/apk ]; then # alpine
        /sbin/apk --no-cache add "$pkg"
    else
        echo "  ERROR: this system's package manager is not supported"
        echo "    Please contact Trafikito support for help"  # TODO
        return 1
    fi
    if [ $? ]; then
        echo "  Something went wrong: please contact Trafikito support for help"  # TODO
        return 1
    else
        echo "  installed `which $tool`"
        return 0
    fi
}

# install curl
echo -n "Checking for curl..."
fn_install_tool "curl" "transfer an url"
if [ $? -ne 0 ]; then
    echo "  Looks like your distro does not have curl: please contact trafikito support"
    exit 1
fi

echo "* Looking for required commands..."
fn_install_tool "df"     "report file system disk space usage"
fn_install_tool "free"   "report amount of free and used memory in the system"
fn_install_tool "egrep"  "print lines matching a pattern"
fn_install_tool "pgrep"  "look up or signal processes based on name and other attributes"
fn_install_tool "lsof"   "list open files"
fn_install_tool "sed"    "stream editor for filtering and transforming text"
fn_install_tool "su"     "change user ID or become superuser"
fn_install_tool "top"    "display processes"
fn_install_tool "uptime" "tell how long the system has been running"
fn_install_tool "vmstat" "report virtual memory statistics"

echo ""
echo "* Installing agent..."

fn_download ()
{
    # for development
    case `hostname -f` in
        *home) echo "http://tui.home/trafikito/$1" ;;
            *) echo "$URL/v2/agent/get_agent_file?file=$1 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain'"
    esac
}

echo "*** Starting to download agent files"
file=$BASEDIR/trafikito
curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "$file" `fn_download trafikito` > /dev/null
if [ ! -f "$file" ]; then
    echo "*** 1/5 Failed to download. Retrying."
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 60 --output "$file" `fn_download trafikito` > /dev/null
    if [ ! -f "$file" ]; then
        echo "*** 1/5 Failed to download: $file"
        exit 1;
    fi
else
    echo "*** 1/5 done"
fi

file=$BASEDIR/uninstall.sh
curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "$file" `fn_download uninstall.sh` > /dev/null
if [ ! -f "$file" ]; then
    echo "*** 2/5 Failed to download. Retrying."
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 60 --output "$file" `fn_download uninstall.sh` > /dev/null
    if [ ! -f "$file" ]; then
        echo "*** 2/5 Failed to download: $file"
        exit 1;
    fi
else
    echo "*** 2/5 done"
fi

file=$BASEDIR/lib/trafikito_wrapper.sh
curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "$file" `fn_download lib/trafikito_wrapper.sh` > /dev/null
if [ ! -f "$file" ]; then
    echo "*** 3/5 Failed to download. Retrying."
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 60 --output "$file" `fn_download lib/trafikito_wrapper.sh` > /dev/null
    if [ ! -f "$file" ]; then
        echo "*** 3/5 Failed to download: $file"
        exit 1;
    fi
else
    echo "*** 3/5 done"
fi

file=$BASEDIR/lib/trafikito_agent.sh
curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "$file" `fn_download lib/trafikito_agent.sh` > /dev/null
if [ ! -f "$file" ]; then
    echo "*** 4/5 Failed to download. Retrying."
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 60 --output "$file" `fn_download lib/trafikito_agent.sh` > /dev/null
    if [ ! -f "$file" ]; then
        echo "*** 4/5 Failed to download: $file"
        exit 1;
    fi
else
    echo "*** 4/5 done"
fi

file=$BASEDIR/lib/set_os.sh
curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "$file" `fn_download lib/set_os.sh` > /dev/null
if [ ! -f "$file" ]; then
    echo "*** 5/5 Failed to download. Retrying."
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 60 --output "$file" `fn_download lib/set_os.sh` > /dev/null
    if [ ! -f "$file" ]; then
        echo "*** 5/5 Failed to download: $file"
        exit 1;
    fi
else
    echo "*** 5/5 done"
fi

echo
chmod +x $BASEDIR/trafikito $BASEDIR/uninstall.sh $BASEDIR/lib/*

# get os facts
. $BASEDIR/lib/set_os.sh
fn_set_os

echo "* Create server and get config file"
curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 $URL/v2/agent/get_agent_file?file=trafikito.conf \
    -H 'Cache-Control: no-cache' \
    -H 'Content-Type: application/json' \
    -d "{ \
        \"workspaceId\"  : \"$WORKSPACE_ID\", \
        \"userApiKey\": \"$USER_API_KEY\", \
        \"serverName\": \"$SERVER_NAME\", \
        \"tmpFilePath\": \"$TMP_FILE\" \
        }" >$TMP_FILE

# TODO LUKAS: The only stuff I need from this is the serverid and api_key as follows
# (the config file has moved to $TRAFIKITO/etc/trafikito.conf)
# SERVER_ID="jhgfhjgff"
# API_KEY="jhgfhjgff"
# capitals because that is standard for global variables in shell
# no spaces before or after '=' and value protected with "..." (in case you allow an '=' to be part of the server id)
# will the Trafikito API URLs change? If not we don't need it

export SERVER_ID=`grep server_id $TMP_FILE | sed -e 's/.*= //'`
export API_KEY=`grep api_key   $TMP_FILE | sed -e 's/.*= //'`
echo export SERVER_ID=$SERVER_ID >>$CONFIG
echo export API_KEY=$API_KEY     >>$CONFIG

echo "* Generating initial settings"
>$TMP_FILE
(
cat <<STOP
trafikito_free="free"
trafikito_cpu_info_full="cat /proc/cpuinfo | sed '/^\s*$/q'"
trafikito_cpu_info="cat /proc/cpuinfo | sed '/^\s*$/q' | egrep -i 'cache\|core\|model\|mhz\|sibling\|vendor\|family'"
trafikito_uptime="uptime"
trafikito_cpu_processors_count="cat /proc/cpuinfo 2>&1 | grep processor | wc -l"
trafikito_vmstat="vmstat"
trafikito_df_p="df -P"
trafikito_hostname="hostname"
trafikito_curl="curl --version"
trafikito_df_h="df -h"
trafikito_lsof_count_network_connections="lsof -i | grep -- '->' | wc -l"
trafikito_lsof_count_open_files="lsof | wc -l"
trafikito_netstat_i="netstat -i"
trafikito_vmstat_s="vmstat -s"
trafikito_top="top -bcn1"
STOP
) | while read line; do
    command=`echo "$line" | sed -e 's#^[^=]*=##' -e 's#^"##' -e 's#"$##'`
    echo "  executing $command..."
    echo "*-*-*-*------------ Trafikito command: $command" >>$TMP_FILE
    eval "$command" >>$TMP_FILE 2>&1
done

echo "* Getting available commands file & setting default dashboard"
curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30 \
     --url    "$URL/v2/agent/get_agent_file?file=available_commands.sh" \
     --header "content-type: multipart/form-data" \
     --form   "output=@$TMP_FILE" \
     --form   "userApiKey=$USER_API_KEY" \
     --form   "workspaceId=$WORKSPACE_ID" \
     --form   "serverId=$SERVER_ID" \
     --form   "os=$os" \
     --form   "osCodename=$os_codename" \
     --form   "osRelease=$os_release" \
     --form   "centosFlavor=$centos_flavor" \
     --output "$BASEDIR/available_commands.sh"

# now everything will be owned by $RUNAS
chown -R "$RUNAS" $BASEDIR

# configure restart
if [ "$WHOAMI" != "root" ]; then
    echo "Script was not installed as root: cannot configure startup"
    echo "You can control the script manually with:"
    echo
    echo "  $BASEDIR/trafikito {start|stop|restart|status}"
    exit 0
fi

#####################################
# systemd: test for useable systemctl
#####################################
x=`which systemctl`
if [ $? -eq 0 ]; then
    echo "You are running systemd..."
    fn_prompt "Y" "Shall I configure, enable and start the agent? [Yn]: "
    if [ $? -eq 1 ]; then

        # WARNING: keep 8 space indent until STOP!
        cat << STOP | sed -e 's/^        //' >/etc/systemd/system/trafikito.service
        [Unit]
        Description=Trafikito Agent
        After=network.target
        [Service]
        Type=simple
        ExecStart=$BASEDIR/lib/trafikito_wrapper.sh $SERVER_ID $BASEDIR
        User=nobody
        Group=nogroup
        [Install]
        WantedBy=multi-user.target
STOP
 
        # WARNING: keep 8 space indent until STOP!
        cat << STOP | sed -e 's/        //' >$BASEDIR/lib/remove_startup.sh
        echo "  Disabling systemd"
        systemctl stop trafikito
        systemctl disable trafikito
        rm -f /etc/systemd/system/trafikito.service
STOP

       systemctl enable trafikito
       systemctl start trafikito
       systemctl status trafikito

        exit 0
    fi
fi

#################################################################
# System V the Debian/Ubuntu flavour: test for usable update-rc.d
#################################################################
x=`which update-rc.d`
if [ $? -eq 0 ]; then
    echo "System V using update-rc.d is available on this server..."
    fn_prompt "Y" "Shall I configure, enable and start the agent? [Yn]: "
    if [ $? -eq 1 ]; then

    cat << STOP | sed -e 's/^        //' >/etc/init.d/trafikito
        #!/bin/sh
        ### BEGIN INIT INFO
        # Provides:          trafikito
        # Required-Start:    $local_fs $network
        # Required-Stop:     $local_fs $network
        # Should-Start:      $syslog
        # Should-Stop:       $syslog
        # Default-Start:     2 3 4 5
        # Default-Stop:      0 1 6
        # Short-Description: Starts or stops the trafikito agent
        # Description:       Starts and stops the trafikito agent.
        ### END INIT INFO

        . /lib/lsb/init-functions

        PIDLIST="trafikito_wrapper.sh $SERVER_ID"

        case "\$1" in
            start)
                log_daemon_msg "Starting trafikito"
                start-stop-daemon --start --quiet --background --chuid nobody --exec $BASEDIR/lib/trafikito_wrapper.sh $SERVER_ID $BASEDIR
                log_end_msg \$?
                ;;
            stop)
                log_daemon_msg "Stopping \$NAME"
                PID=\`pgrep -f "\$PIDLIST"\`
                if [ \$? -ne 0 ]; then
                    log_failure_msg "Trafikito alread stopped"
                else
                    kill -9 \$PID
                    log_end_msg \$?
                fi
                ;;
            restart)
                \$0 stop
                \$0 start
                ;;
            status)
                PID=\`pgrep -f "\$PIDLIST"\`
                R=\$?
                if [ \$R -eq 0 ]; then
                    set \$PID; echo "Trafikito agent running (pid=\$*)"
                else
                    echo "Trafikito agent stopped"
                    tail /opt/trafikito/var/trafikito.log 2>/dev/null
                fi
                exit \$R
                ;;
            *)
                echo "Usage: /etc/init.d/trafikito {start|stop|restart|status}"
                exit 1
                ;;
        esac

        exit 0
STOP

       echo "Removing System V startup"        >$BASEDIR/lib/remove_startup.sh
       echo "update-rc.d -f trafikito remove" >>$BASEDIR/lib/remove_startup.sh

        exit 0
    fi
fi
