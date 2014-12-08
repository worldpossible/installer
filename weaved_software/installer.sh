#!/bin/bash

#  multi-installer.sh
#  
#
#  Weaved, Inc. Copyright 2014. All rights reserved.
#

##### Settings #####
VERSION=v1.2.6
AUTHOR="Mike Young"
MODIFIED="December 8, 2014"
DAEMON=weavedConnectd
WEAVED_DIR=/etc/weaved
BIN_DIR=/usr/bin
NOTIFIER=notify.sh
INIT_DIR=/etc/init.d
PID_DIR=/var/run
filename=`basename $0`
loginURL=https://api.weaved.com/api/user/login
unregdevicelistURL=https://api.weaved.com/api/device/list/unregistered
preregdeviceURL=https://api.weaved.com/v6/api/device/create
regdeviceURL=https://api.weaved.com/api/device/register
regdeviceURL2=http://api.weaved.com/v6/api/device/register
deleteURL=http://api.weaved.com/v6/api/device/delete
connectURL=http://api.weaved.com/v6/api/device/connect
##### End Settings #####

##### Version #####
displayVersion()
{
    printf "You are running installer script Version: %s \n" "$VERSION"
    printf "Last modified on %s, by %s. \n\n" "$MODIFIED" "$AUTHOR"
}
##### End Version #####

##### Compatibility checker #####
weavedCompatitbility()
{
    ./bin/"$DAEMON"."$PLATFORM" -n | grep OK > .networkDump
    printf "Checking for compatibility with Weaved's network... \n\n"
    number=$(cat .networkDump | wc -l)
    for i in $(seq 1 $number); do
        awk "NR==$i" .networkDump
        printf "\n"
        sleep 1
    done
    if [ "$number" -ge 3 ]; then
        printf "Congratulations! Your network is compatible with Weaved services.\n\n"
        sleep 5
    elif [ "$(cat .networkDump | grep "Send to" | grep "OK" | wc -l)" -lt 1 ]; then
        printf "Unfortunately, it appears your network may not currently be compatible with Weaved services\n."
        printf "Please visit https://forum.weaved.com for more support.\n\n"
        exit
    fi
}
##### End Compatibility checker #####

##### Check for existing services #####
checkforServices()
{
    if [ -e "/etc/weaved/services" ]; then
        ls /etc/weaved/services/* > ./.legacy_instances
        instanceNumber=$(cat .legacy_instances | wc -l)
        if [ -f ./.instances ]; then
            rm ./.instances
        fi
        echo -n "" > .instances
        printf "We have detected the following Weaved services already installed: \n\n"
        for i in $(seq 1 $instanceNumber); do
            instanceName=$(awk "NR==$i" .legacy_instances | xargs basename | awk -F "." {'print $1'})
            echo $instanceName >> .instances
        done 
        legacyInstances=$(cat .instances)
        echo $legacyInstances
        rm .instances
        if ask "Do you wish to continue?"; then
            echo "Continuing installation..."
        else
            echo "Now exiting..."
            exit
        fi
    fi
}
##### End Check for existing services #####

##### Platform detection #####
platformDetection()
{
    machineType="$(uname -m)"
    osName="$(uname -s)"
    if [ "$machineType" = "armv6l" ]; then
        PLATFORM=pi
        SYSLOG=/var/log/syslog
    elif [ "$machineType" = "armv7l" ]; then
        PLATFORM=beagle
        SYSLOG=/var/log/syslog
    elif [ "$machineType" = "x86_64" ] && [ "$osName" = "Linux" ]; then
        PLATFORM=linux
        if [ ! -f "/var/log/syslog" ]; then
            SYSLOG=/var/log/messages
        else
            SYSLOG=/var/log/syslog
        fi
    elif [ "$machineType" = "x86_64" ] && [ "$osName" = "Darwin" ]; then
            PLATFORM=macosx
            SYSLOG=/var/log/system.log
    else
        printf "Sorry, you are running this installer on an unsupported platform. But if you go to \n"
        printf "http://forum.weaved.com we'll be happy to help you get your platform up and running. \n\n"
        printf "Thanks! \n"
        exit
    fi

    printf "Detected platform type: %s \n" "$PLATFORM"
    printf "Using %s for your log file \n\n" "$SYSLOG"
}
##### End Syslog type #####

##### Protocol selection #####
protocolSelection()
{
    clear
    WEAVED_PORT=""
    CUSTOM=0
    if [ "$PLATFORM" = "pi" ]; then
        printf "\n\n\n"
        printf "*********** Protocol Selection Menu ***********\n"
        printf "*                                             *\n"
        printf "*    1) WebSSH (ssh browser client)           *\n"
        printf "*    2) SSH on default port 22                *\n"
        printf "*    3) Web (HTTP) on default port 80         *\n"
        printf "*    4) WebIOPi on default port 8000          *\n"
        printf "*    5) VNC on default port 5901              *\n"
        printf "*    6) Custom (TCP)                          *\n"
        printf "*                                             *\n"
        printf "***********************************************\n\n"
        unset get_num
        unset get_port
        while [[ ! "${get_num}" =~ ^[0-9]+$ ]]; do
            echo "Please select from the above options (1-6):"
            read get_num
            ! [[ "${get_num}" -ge 1 && "${get_num}" -le 6 ]] && unset get_num
        done
        printf "You have selected: %s. \n\n" "${get_num}"
        if [ "$get_num" = 4 ]; then
            PROTOCOL=webiopi
            if ask "The default port for WebIOPi is 8000. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536 ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=8000
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 1 ]; then
            PROTOCOL=webssh
            if ask "The default port for WebSSH is 3066. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536 ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=3066
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 3 ]; then
            PROTOCOL=web
            if ask "The default port for Web is 80. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536 ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=80
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 2 ]; then
            PROTOCOL=ssh
            if ask "The default port for SSH is 22. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536 ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=22
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 5 ]; then
            PROTOCOL=vnc
            if ask "The default port for VNC is 5901. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536 ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=5901
            fi    
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 6 ]; then
            CUSTOM=1
            if ask "Is your protocol viewable through a web browser (e.g., HTTP running port 8080 vs. 80)"; then
                PROTOCOL=web
            else
                PROTOCOL=tcp
            fi
            printf "Please enter the protocol name (e.g., ssh, http, nfs): \n"
            read port_name
            CUSTOM_PROTOCOL="$(echo "$port_name" | tr '[A-Z]' '[a-z]' | tr -d ' ')"
            while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                printf "Please enter your desired port number (1-65536):"
                read get_port
                ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536 ]] && unset get_port
            done
            PORT="$get_port"
            WEAVED_PORT=Weaved"$CUSTOM_PROTOCOL""$PORT"
        fi
        printf "We will install Weaved services for the following:\n\n"
        if [ "$CUSTOM" = 1 ]; then
            printf "Protocol: %s \n" "$CUSTOM_PROTOCOL"
        else
            printf "Protocol: %s \n" "$PROTOCOL"
        fi
        printf "Port #: %s \n" "$PORT"
        printf "Service name: %s \n" "$WEAVED_PORT"

    elif [ "$PLATFORM" = "beagle" ] || [ "$PLATFORM" = "linux" ]; then
        printf "\n\n\n"
        printf "*********** Protocol Selection Menu ***********\n"
        printf "*                                             *\n"
        printf "*    1) WebSSH on default port 3066           *\n"
        printf "*    2) SSH on default port 22                *\n"
        printf "*    3) Web (HTTP) on default port 80         *\n"
        printf "*    4) VNC on default port 5901              *\n"
        printf "*    5) Custom (TCP)                          *\n"
        printf "*                                             *\n"
        printf "***********************************************\n\n"
        unset get_num
        unset get_port
        while [[ ! "${get_num}" =~ ^[0-9]+$ ]]; do
            echo "Please select from the above options (1-5):"
            read get_num
            ! [[ "${get_num}" -ge 1 && "${get_num}" -le 5  ]] && unset get_num
        done
        printf "You have selected: %s. \n\n" "${get_num}"
        if [ "$get_num" = 1 ]; then
            PROTOCOL=webssh
            if ask "The default port for WebSSH is 3066. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536  ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=3066
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 3 ]; then
            PROTOCOL=web
            if ask "The default port for Web is 80. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536  ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=80
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 2 ]; then
            PROTOCOL=ssh
            if ask "The default port for SSH is 22. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536  ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=22
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 4 ]; then
            PROTOCOL=vnc
            if ask "The default port for VNC is 5901. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536  ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=5901
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 5 ]; then
            CUSTOM=1
            if ask "Is your protocol viewable through a web browser (e.g., HTTP running port 8080 vs. 80)"; then
                PROTOCOL=web
            else
                PROTOCOL=tcp
            fi
            printf "Please enter the protocol name (e.g., ssh, http, nfs): \n"
            read port_name
            CUSTOM_PROTOCOL=$(echo "$port_name" | tr '[A-Z]' '[a-z]' | tr -d ' ')
            while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                printf "Please enter your desired port number (1-65536):"
                read get_port
                ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536  ]] && unset get_port
            done
            PORT="$get_port"
            WEAVED_PORT=Weaved"$CUSTOM_PROTOCOL""$PORT"
        fi
        printf "We will install Weaved services for the following:\n\n"
        if [ "$CUSTOM" = 1 ]; then
            printf "Protocol: %s \n" "$CUSTOM_PROTOCOL"
        else
            printf "Protocol: %s \n" "$PROTOCOL"
        fi
        printf "Port #: %s \n" "$PORT"
        printf "Service name: %s \n" "$WEAVED_PORT"
    elif [ "$PLATFORM" = "macosx" ]; then
        printf "\n\n\n"
        printf "*********** Protocol Selection Menu ***********\n"
        printf "*                                             *\n"
        printf "*    1) SSH on default port 22                *\n"
        printf "*    2) Web (HTTP) on default port 80         *\n"
        printf "*    3) VNC on default port 5901              *\n"
        printf "*    4) Custom (TCP)                          *\n"
        printf "*                                             *\n"
        printf "***********************************************\n\n"
        unset get_num
        unset get_port
        while [[ ! "${get_num}" =~ ^[0-9]+$ ]]; do
            echo "Please select from the above options (1-3):"
            read get_num
            ! [[ "${get_num}" -ge 1 && "${get_num}" -le 3 ]] && unset get_num
        done
        printf "You have selected: %s. \n\n" "${get_num}"
        if [ "$get_num" = 2 ]; then
            PROTOCOL=web
            if ask "The default port for Web is 80. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536  ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=80
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 1 ]; then
            PROTOCOL=ssh
            if ask "The default port for SSH is 22. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536  ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=22
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 3 ]; then
            PROTOCOL=vnc
            if ask "The default port for VNC is 5901. Would you like to assign a different port number?"; then
                CUSTOM=2
                while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                    printf "Please enter your desired port number (1-65536):"
                    read get_port
                    ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536  ]] && unset get_port
                done
                PORT="$get_port"
            else
                PORT=5901
            fi
            WEAVED_PORT=Weaved"$PROTOCOL""$PORT"
        elif [ "$get_num" = 4 ]; then
            if ask "Is your protocol viewable through a web browser (e.g., HTTP running port 8080 vs. 80)"; then
                PROTOCOL=web
            else
                PROTOCOL=tcp
            fi
            printf "Please enter the protocol name (e.g., ssh, http, nfs): \n"
            read port_name
            CUSTOM_PROTOCOL="$(echo $port_name | tr '[A-Z]' '[a-z]' | tr -d ' ')"
            while [[ ! "${get_port}" =~ ^[0-9]+$ ]]; do
                printf "Please enter your desired port number (1-65536):"
                read get_port
                ! [[ "${get_port}" -ge 1 && "${get_port}" -le 65536 ]] && unset get_port
            done
            CUSTOM=1
            PORT="$get_port"
            WEAVED_PORT=Weaved"$CUSTOM_PROTOCOL""$PORT"
        fi
        printf "We will install Weaved services for the following:\n\n"
        if [ "$CUSTOM" = 1 ]; then
            printf "Protocol: %s \n" "$CUSTOM_PROTOCOL"
        else
            printf "Protocol: %s \n" "$PROTOCOL"
        fi
        printf "Port #: %s \n" "$PORT"
        printf "Service name: %s \n" "$WEAVED_PORT"
    fi
    if [ $(echo $legacyInstances | grep $WEAVED_PORT | wc -l) -gt 0 ]; then
        printf "You've selected to install %s, which is already installed. \n" "$WEAVED_PORT."
        if ask "Do you wish to overwrite your previous settings?"; then
            userLogin
            testLogin
            deleteDevice
            if [ -e $PID_DIR/$WEAVED_PORT.pid ]; then
                sudo $INIT_DIR/$WEAVED_PORT stop
                if [ -e $PID_DIR/$WEAVED_PORT.pid ]; then
                    sudo rm $PID_DIR/$WEAVED_PORT.pid
                fi
            fi
        else 
            printf "We will allow you to re-select your desired service to install... \n\n"
            protocolSelection
        fi
    else
        userLogin
        testLogin
    fi
}
##### End Protocol selection #####


##### Check for Bash #####
bashCheck()
{
    if [ "$BASH_VERSION" = '' ]; then
        clear
        printf "You executed this script with dash vs bash! \n\n"
        printf "Unfortunately, not all shells are the same. \n\n"
        printf "Please execute \"chmod +x "$filename"\" and then \n"
        printf "execute \"./"$filename"\".  \n\n"
        printf "Thank you! \n"
        exit
    else
        #clear
        echo "Now launching the Weaved connectd daemon installer..."
    fi
    #clear
}
##### End Bash Check #####

######### Ask Function #########
ask()
{
    while true; do
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
            fi
    # Ask the question
    read -p "$1 [$prompt] " REPLY
    # Default?
    if [ -z "$REPLY" ]; then
        REPLY=$default
    fi
    # Check if the reply is valid
    case "$REPLY" in
    Y*|y*) return 0 ;;
    N*|n*) return 1 ;;
    esac
    done
}
######### End Ask Function #########



#########  Install WebSSH #########
installWebSSH()
{
    if [ "$PROTOCOL" = "webssh" ]; then
        clear
        printf "You have selected to install Weaved for WebSSH, which utilizes Shellinabox. \n"
        if ask "Would you like us to install and configure Shellinabox?"; then
            sudo apt-get -q -y install shellinabox
            printf "Copying... \n"
            sudo cp -vf ./scripts/shellinabox.default /etc/default/shellinabox
            sudo "$INIT_DIR"/shellinabox restart
        fi
    fi
}
#########  End Install WebSSH #########

######### Begin Portal Login #########
userLogin () #Portal login function
{
    printf "\n\n\n"
    printf "Please enter your Weaved Username (email address): \n"
    read username
    printf "\nNow, please enter your password: \n"
    read  -s password
    resp=$(curl -s -S -X GET -H "content-type:application/json" -H "apikey:WeavedDeveloperToolsWy98ayxR" "$loginURL/$username/$password")
    token=$(echo "$resp" | awk -F ":" '{print $3}' | awk -F "," '{print $1}' | sed -e 's/^"//'  -e 's/"$//')
    loginFailed=$(echo "$resp" | grep "login failed" | sed 's/"//g')
    login404=$(echo "$resp" | grep 404 | sed 's/"//g')
}
######### End Portal Login #########

######### Test Login #########
testLogin()
{
    while [[ "$loginFailed" != "" || "$login404" != "" ]]; do
        clear
        printf "You have entered either an incorrect username or password. Please try again. \n\n"
        userLogin
    done
}
######### End Test Login #########

######### Install Enablement #########
installEnablement()
{
    if [ ! -d "WEAVED_DIR" ]; then
       sudo mkdir -p "$WEAVED_DIR"/services
    fi

    cat ./enablements/"$PROTOCOL"."$PLATFORM" > ./"$WEAVED_PORT".conf
}
######### End Install Enablement #########

######### Install Notifier #########
installNotifier()
{
    sudo chmod +x ./scripts/"$NOTIFIER"
    if [ ! -f "$BIN_DIR"/"$NOTIFIER" ]; then
        sudo cp ./scripts/"$NOTIFIER" "$BIN_DIR"
        printf "Copied %s to %s \n" "$NOTIFIER" "$BIN_DIR"
    fi
}
######### End Install Notifier #########

######### Install Send Notification #########
installSendNotification()
{
    if [ ! -e "$BIN_DIR/send_notification.sh" ]; then
        sed s/REPLACE/"$WEAVED_PORT"/ < ./scripts/send_notification.sh > ./send_notification.sh
        chmod +x ./send_notification.sh
        sudo mv ./send_notification.sh "$BIN_DIR"
        printf "Copied send_notification.sh to %s \n" "$BIN_DIR"
    fi
}
######### End Install Send Notification #########

######### Service Install #########
installWeavedConnectd()
{
    if [ ! -f "$BIN_DIR"/"$DAEMON" ]; then
        sudo chmod +x ./bin/"$DAEMON"."$PLATFORM"
        sudo cp ./bin/"$DAEMON"."$PLATFORM" "$BIN_DIR"/"$DAEMON"
        printf "Copied %s to %s \n" "$DAEMON" "$BIN_DIR"
    fi
}
######### End Service Install #########

######### Install Start/Stop Scripts #########
installStartStop()
{
    if [ "$PLATFORM" != "macosx" ]; then
        sed s/WEAVED_PORT=/WEAVED_PORT="$WEAVED_PORT"/ < ./scripts/init.sh > ./"$WEAVED_PORT".init
        sudo mv ./"$WEAVED_PORT".init $INIT_DIR/$WEAVED_PORT
        sudo chmod +x $INIT_DIR/$WEAVED_PORT
        # Add startup levels
        sudo update-rc.d "$WEAVED_PORT" defaults

        if [ ! -e "/usr/bin/startweaved.sh" ]; then
            sudo cp ./scripts/startweaved.sh "$BIN_DIR"
            printf "startweaved.sh copied to %s\n" "$BIN_DIR"
        fi
        checkCron=$(sudo crontab -l | grep startweaved.sh | wc -l)
        if [ "$checkCron" -lt 1 ]; then
            sudo crontab ./scripts/cront_boot.sh
        fi
        checkStartWeaved=$(cat "$BIN_DIR"/startweaved.sh | grep "$WEAVED_PORT" | wc -l)
        if [ "$checkStartWeaved" = 0 ]; then
            sed s/REPLACE_TEXT/"$WEAVED_PORT"/ < ./scripts/startweaved.add > ./startweaved.add
            sudo sh -c "cat startweaved.add >> /usr/bin/startweaved.sh"
            rm ./startweaved.add
        fi
        printf "\n\n"
    fi
}
######### End Start/Stop Scripts #########

######### Fetch UID #########
fetchUID()
{
    "$BIN_DIR"/"$DAEMON" -life -1 -f ./"$WEAVED_PORT".conf > .DeviceTypeSting
    DEVICETYPE="$(cat .DeviceTypeSting | grep DeviceType | awk -F "=" '{print $2}')"
    rm .DeviceTypeSting
}
######### End Fetch UID #########

######### Check for UID #########
checkUID()
{
    checkforUID="$(tail $WEAVED_PORT.conf | grep UID | wc -l)"
    if [ "$checkforUID" = 2 ]; then
        sudo cp ./"$WEAVED_PORT".conf /"$WEAVED_DIR"/services/
        uid=$(tail $WEAVED_DIR/services/$WEAVED_PORT.conf | grep UID | awk -F "UID" '{print $2}' | xargs echo -n)
        printf "\n\nYour device UID has been successfully provisioned as: %s. \n\n" "$uid"
    else
        retryFetchUID
    fi
}
######### Check for UID #########

######### Retry Fetch UID ##########
retryFetchUID()
{
    for run in {1..5}
    do
        fetchUID
        checkforUID="$(tail $WEAVED_PORT.conf | grep UID | wc -l)"
        if [ "$checkforUID" = 2 ]; then
            sudo cp ./"$WEAVED_PORT".conf /"$WEAVED_DIR"/services/
            uid="$(tail $WEAVED_DIR/services/$WEAVED_PORT.conf | grep UID | awk -F "UID" '{print $2}' | xargs echo -n)"
            printf "\n\nYour device UID has been successfully provisioned as: %s. \n\n" "$uid"
            break
        fi
    done
    checkforUID="$(tail $WEAVED_PORT.conf | grep UID | wc -l)"
    if [ "$checkforUID" != 2 ]; then
        printf "We have unsuccessfully retried to obtain a UID. Please contact Weaved Support at http://forum.weaved.com for more support.\n\n"
    fi
}
######### Retry Fetch UID ##########

######### Pre-register Device #########
preregisterUID()
{
    preregUID="$(curl -s $preregdeviceURL -X 'POST' -d "{\"deviceaddress\":\"$uid\", \"devicetype\":\"$DEVICETYPE\"}" -H “Content-Type:application/json” -H "apikey:WeavedDeveloperToolsWy98ayxR" -H "token:$token")"
    test1="$(echo $preregUID | grep "true" | wc -l)"
    test2="$(echo $preregUID | grep -E "missing api token|api token missing" | wc -l)"
    test3="$(echo $preregUID | grep "false" | wc -l)"
    if [ "$test1" = 1 ]; then
        printf "Pre-registration of UID: %s successful. \n\n" "$uid"
    elif [ "$test2" = 1 ]; then
        printf "You are missing a valid session token and must be logged back in. \n"
        userLogin
        preregisterUID
    elif [ "$test3" = 1 ]; then
        printf "Sorry, but for some reason, the pre-registration of UID: %s is failing. While we are working to resolve this problem, you can \n" "$uid"
        printf "finish your registration process manually via the following steps: \n\n"
        printf "1) From the same network as your device (e.g., Cannot have device on LAN and Client on LTE), please log into https://weaved.com \n"
        printf "2) Once logged in, please visit the following URL https://developer.weaved.com/portal/members/registerDevice.php \n"
        printf "3) Enter an alias for your device or service \n"
        printf "4) Please contact us at http://forum.weaved.com and let us know about this issue, including the version of installer, and whether \n"
        printf "the manual registration worked for you. Sorry for the inconvenience. \n\n"
        overridePort
        startService
        installYo
        exit
    fi
}
######### End Pre-register Device #########

######### Pre-register Device #########
getSecret()
{
    secretCall="$(curl -s $regdeviceURL2 -X 'POST' -d "{\"deviceaddress\":\"$uid\", \"devicealias\":\"$alias\", \"skipsecret\":\"true\"}" -H “Content-Type:application/json” -H "apikey:WeavedDeveloperToolsWy98ayxR" -H "token:$token")"
    test1="$(echo $secretCall | grep "true" | wc -l)"
    test2="$(echo $secretCall | grep -E "missing api token|api token missing" | wc -l)"
    test3="$(echo $secretCall | grep "false" | wc -l)"
    if [ "$test1" = 1 ]; then
        secret="$(echo $secretCall | awk -F "," '{print $2}' | awk -F "\"" '{print $4}' | sed s/://g)"
        echo "# password - erase this line to unregister the device" >> ./"$WEAVED_PORT".conf
        echo "password $secret" >> ./"$WEAVED_PORT".conf
        sudo mv ./"$WEAVED_PORT".conf "$WEAVED_DIR"/services/"$WEAVED_PORT".conf
    elif [ "$test2" = 1 ]; then
        printf "You are missing a valid session token and must be logged back in. \n"
        userLogin
        getSecret
    fi
}
######### End Pre-register Device #########

######### Reg Message #########
regMsg()
{
    clear
    printf "********************************************************************************* \n"
    printf "CONGRATULATIONS! You are now registered with Weaved. \n"
    printf "Your registration information is as follows: \n\n"
    printf "Device alias: \n"
    printf "%s \n\n" "$alias"
    printf "Device UID: \n"
    printf "%s \n\n" "$uid"
    printf "Device secret: \n"
    printf "%s \n\n" "$secret"
    printf "The alias, Device UID and Device secret are kept in the License File: \n"
    printf "%s/services/%s.conf \n\n" "$WEAVED_DIR" "$WEAVED_PORT"
    printf "If you delete this License File, you will have to re-run the installation process. \n"
    printf "********************************************************************************* \n\n"
}
######### End Reg Message #########

######### Register Device #########
registerDevice()
{
    clear
    printf "We will now register your device with the Weaved backend services. \n"
    printf "Please provide an alias for your device: \n"
    read alias
    if [ "$alias" != "" ]; then
        printf "Your device will be called %s. You can rename it later in the Weaved Portal. \n\n" "$alias"
    else
        alias="$uid"
        printf "For some reason, we're having problems using your desired alias. We will instead \n"
        printf "use %s as your device alias, but you may change it via the web portal. \n\n" "$uid"
    fi
}
######### End Register Device #########

######### Start Service #########
startService()
{
    echo -n "Starting Weaved services for $WEAVED_PORT ";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -n ".";sleep 1;echo -e "\n\n"
    if [ -e "$PID_DIR"/"$WEAVED_PORT.pid" ]; then
        sudo $INIT_DIR/$WEAVED_PORT stop
        if [ -e "$PID_DIR"/"$WEAVED_PORT.pid" ]; then
            sudo rm "$PID_DIR"/"$WEAVED_PORT".pid
        fi
    fi
    sudo $INIT_DIR/$WEAVED_PORT start
}
######### End Start Service #########

######### Install Yo #########
installYo()
{
    sudo cp ./Yo "$BIN_DIR"
}
######### End Install Yo #########

######### Port Override #########
overridePort()
{
    if [ "$CUSTOM" = 1 ]; then
        cp "$WEAVED_DIR"/services/"$WEAVED_PORT".conf ./
        echo "proxy_dest_port $PORT" >> ./"$WEAVED_PORT".conf
        sudo mv ./"$WEAVED_PORT".conf "$WEAVED_DIR"/services/
    elif [[ "$CUSTOM" = 2 ]]; then
        cp "$WEAVED_DIR"/services/"$WEAVED_PORT".conf ./
        echo "proxy_dest_port $PORT" >> ./"$WEAVED_PORT".conf
        sudo mv ./"$WEAVED_PORT".conf "$WEAVED_DIR"/services/
    fi
}
######### End Port Override #########

######### Delete device #########
deleteDevice()
{
    uid=$(tail $WEAVED_DIR/services/$WEAVED_PORT.conf | grep UID | awk -F "UID" '{print $2}' | xargs echo -n)
    curl -s $deleteURL -X 'POST' -d "{\"deviceaddress\":\"$uid\"}" -H “Content-Type:application/json” -H "apikey:WeavedDeveloperToolsWy98ayxR" -H "token:$token"
    printf "\n\n"
}
######### End Delete device #########

######### Main Program #########
main()
{
     clear
     displayVersion
     bashCheck
     platformDetection
     weavedCompatitbility
     checkforServices
     # userLogin
     # testLogin
     protocolSelection
     installWebSSH
     installEnablement
     installNotifier
     installSendNotification
     installWeavedConnectd
     installStartStop
     fetchUID
     checkUID
     preregisterUID
     registerDevice
     getSecret
     overridePort
     startService
     installYo
     regMsg
     exit
}
######### End Main Program #########
main
