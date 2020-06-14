#!/usr/bin/bash

header()
{
    echo -e "\n    >> Secure Kali Linux"
    echo -e "    >> https://www.github.com/gh0x0st \n"
}

check_root()
{
    if [ "$EUID" -ne 0 ]
    then
        echo "[!] Please run with sudo"
        exit
    fi
}

upgrade_kali()
{
    echo "[*] Upgrading Kali Linux"
    apt update && apt full-upgrade -y
}

install_utils()
{
    echo "[*] Installing Fail2ban and PortSentry"
    apt install fail2ban portsentry
}

config_utils()
{
    repo="https://raw.githubusercontent.com/gh0x0st/Secure_Kali/master"
    echo "[*] Downloading jail.conf from repo"
    curl $repo/jail.local -s  -o '/etc/fail2ban/jail.local'
    echo "[*] Downloading http-get-dos.conf from repo"
    curl $repo/http-get-dos.conf -s -o '/etc/fail2ban/filter.d/http-get-dos.conf'
    echo "[*] Downloading portsentry.conf from repo"
    curl $repo/portsentry.conf -s -o '/etc/portsentry/portsentry.conf'
    echo "[*] Create PortSentry history file"
    touch '/var/lib/portsentry/portsentry.history'
}

config_ssh()
{
    echo "[*] Explicitly denying root ssh access"
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    echo "[*] Generating new SSH host keys"
    mkdir /etc/ssh/temp
    mv /etc/ssh/ssh_host_* /etc/ssh/temp
    dpkg-reconfigure openssh-server
    echo '[!] Restart SSH and ensure you can still connect to SSH. If you can, purge /etc/ssh/temp'
}

start_services()
{
    services=("fail2ban" "portsentry")
    for s in "${services[@]}"
    do
        systemctl restart "$s"
        if ( systemctl is-active --quiet "$s" )
        then
            echo "[*] $s is now running"
        else
            echo "[!] $s did not start properly"
        fi
    done
}

footer()
{
    echo "[*] Done"
}

run()
{
    header
    check_root
    upgrade_kali
    install_utils
    config_utils
    config_ssh
    start_services
    footer
}

run
