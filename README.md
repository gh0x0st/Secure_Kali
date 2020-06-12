# Securing your Kali Linux machine
Online labs are a great place for you to hone in on your skills. Although, while you're practicing in these platforms your primary focus is probably going to be focused on your own offensive activities and may not have too much attention on the defense of your own machine while in a VPN-based setting.

While the admins of these labs will do their own due diligence in making sure that students can't attack each other, one thing to keep in mind that while you likely cannot talk to a student machine directly from your own computer, the machines you're targeting can. Not to mention you never know if the people who are sharing the same space as you are ethical or not and whether they found a way around controls.

Before you jump into these labs, you should add a few levels of protection on your Kali Linux machine. With some being around awareness and some are technical. Essentially, you're creating a security policy for yourself.

## Objectives
When you define a security policy, you need to ask yourself what are you trying to protect what are you trying to protect from? In this case here, I'll show you a few steps you can take to help protect your Kali Linux machine from being compromised from common exposures that you may be introducing yourself.

1. Patching Kali Linux 
2. Monitoring Apache Web using Fail2ban
3. Restrict access to your listeners
4. Monitoring and restricting SSH
5. Monitoring and restricting port scans using PortSentry

## Patching Kali Linux
Keeping your system up to date can help you ensure that you receive the latest security updates in your Kali install. On very rare occasions you may install an update that breaks a tool that you need, so be sure to test what you plan on using ahead of time. 

```console
tristram@kali:~$ sudo apt update && apt full-upgrade -y
```

## Monitoring Apache Web using Fail2ban
We use Apache to deliver payloads, transfer files and host other pages and as we know, web servers can be compromised if you're not cognizant of what you're publishing. This includes what you decide to host on Kali. 

We can keep our system safe by keeping at least these two points in mind:

1. Turn off Apache when you're not using it
2. Utilize fail2ban to protect Apache while it's running

### Turn off Apache when you're not using it
This is simple, if you need it, use it. When you're done, turn it off. A very common hardening technique is disabling services that aren't in use and we should not forget this even within Kali. If you don't need your web server running, take it down. This will help lower your attack surface.

```console
tristram@kali:~$ sudo service apache2 start
tristram@kali:~$ sudo service apache2 stop
```

### Utilize Fail2ban to protect Apache while it's running
Fail2ban is a python-based framework that scans log files to detect malicious activity and automatically blocks their IP from accessing your system. The logic is based off using regex against designated log files. 

A common phrase you'll hear in the realm of Fail2ban is 'jails'. Think of jails as the conditions that have to trigger in order for a source ip to be flagged and jailed (blocked). At the time of writing this and including the custom conf file we'll be adding shortly, Fail2ban includes 88 different jails it can work with. 

#### Install Fail2ban
This package doesn't come with Kali out of the box, so we just need to install it using apt. After it's on your system, keep in mind that the service itself isn't set to automatically run on boot up. This is important in the event you ever reboot your system without having to remember to manually kick off the service.

```console
tristram@kali:~$ sudo apt update && sudo apt install fail2ban
tristram@kali:~$ sudo systemctl enable fail2ban.service
```

#### Create your configuration file
This utility comes with a jail.conf file, but you should not be modifying this file; create a jail.local file instead.
```console
tristram@kali:~$ sudo touch /etc/fail2ban/jail.local
```

#### Create your filters
Adding the filters to your jail.local file are pretty straight forward. You simply declare the jail you want and you set a few variables to tell fail2ban what to do, from where and for how long. For example:

```
# Block attempts to brute force http logins
[apache-auth] 
enabled = true 
port = http,https 
filter = apache-auth 
logpath = /var/log/apache2/*error.log 
maxretry = 3 
bantime = 600 
ignoreip = 127.0.0.1
```

**Let's break down that down a bit:**

* [apache-auth] - Declaration for the jail you're configuring
* enabled - Determines if the filter is on or off
* port - Protocol being targeted
* filter - The name of the filter to be used by the jail to detect matches
* logpath - Path to the log that's provided by the filter
* maxretry - Number of matches that have to occur to trigger an action against the IP
* bantime - Amount of time (in seconds) you want that ip banned. Supply a negative number for a static ban.
* ignoreip - IPs you do not want to action taken against. The loopback address here is just an example

In regards to Apache specifically, I like to use apache-auth, apache-overflows and apache-noscript. You can also create your own jails with a bit of regex foo. For example, you can flag a large amount of HTTP GET or POST requests as denial of service attempt and ban their ip. Be sure to create `/etc/fail2ban/filter.d/http-get-dos.conf`.

After you create or make your changes to your jail.local file, make sure to restart the service and check the status to make sure it's running. I've included a copy of jail.local template in the repository.

![Alt text](https://github.com/gh0x0st/Secure_Kali/blob/master/Screenshots/f2b_service.png?raw=true "f2b_service")
```
# Fail2Ban configuration file 
[Definition]
 
# Option: failregex 
# Note: This regex will match any GET entry in your logs, so basically all valid and not valid entries are a match. 
# You should set up in the jail.conf file, the maxretry and findtime carefully in order to avoid false positives. 
failregex = ^<HOST> -.*"(GET|POST).* 
# Option: ignoreregex 
ignoreregex =
```
#### Checking your jail status

**To view IPs that have been blocked**
```console
tristram@kali:~$ sudo fail2ban-client status JAILNAME
```
**To unblock ip from fail2ban**
```console
tristram@kali:~$ sudo fail2ban-client set JAILNAME unbanip 1.2.3.4
```

## Restrict access to your listeners
I've ran into cases where I had a listener setup on my machine and ended up catching a shell from a completely different machine because someone fat fingered an ip address. The security control here is simply utilizing `iptables` to ensure the only connection that's coming for this port is going to be the intended target. 

Keep in mind you don't have to limit this to just `reverse shells`,  you can also use this limit access to `apache` or even python's `SimpleHTTPServer`.

```console
tristram@kali:~$ sudo iptables -A INPUT -p tcp --destination-port 1234 \! -d 10.10.10.10 -j DROP
tristram@kali:~$ nc -nvlp 1234
```

## Monitoring and Restricting SSH
This falls right into line with a comment that I made before; if you do not need this service enabled, don't turn it on. However, if you're one of those that have a reason for keeping it while in a vpn-based lab, there are some steps you can take. Starting with adding a new configuration in fail2ban for SSH. In this particular case, we can utilize it to ban IPs that try to brute force logins against our ssh server. 

```
# Block attempts to brute force SSH logins
[ssh] 
enabled = true 
port = ssh 
filter = sshd 
logpath = /var/log/auth.log 
maxretry = 3 
bantime = 600 
ignoreip = 127.0.0.1
```

#### Password
We all know how passwords work, the weaker they are, the easier they are to crack. If you're sitting in a lab network with other people, make sure you change your password to something complex. If you want a sanity check, try to crack your own password using the wordlists that come with kali. If you manage to crack it relatively fast using a wordlist or with minor password mutation, you're going to have a bad day.

#### SSH Keys
If you ever utilize SSH, you should always regenerate your ssh_host_* keys. Move out the keys that currently exist to a temp directory and use `dpkg-reconfigure` to regenerate your keys. After it's finished, restart SSH and ensure you can still SSH in. If you're able to connect then you're good to delete the old keys.

![Alt text](https://github.com/gh0x0st/Secure_Kali/blob/master/Screenshots/ssh_keys.png?raw=true "ssh_keys")

#### Root Access
There is no fundamental reason to be using root interactively, especially when sudo is easy to use. With that being said, you're better off making sure that root is not explicitly allowed to SSH to your box. Edit the `/etc/ssh/sshd_config` file and add `PermitRootLogin no`. This will ensure that even if you leave SSH open and your root password is weak, someone can't just connect in through this protocol using root and a weak password.

## Monitoring and restricting port scans using PortSentry
The final piece I wanted to talk about is port scanning. The idea of this control is more so for the awareness aspect that someone may be probing your machine for open ports. To facilitate this, we'll utilize another utility called PortSentry. What this will do is simply alert us when someone is probing a port that we designate to monitor and we can block them using PortSentry or Fail2ban.

### Install PortSentry
This package doesn't come with Kali out of the box, so we just need to install it using apt. After it's on your system, keep in mind that the service itself isn't set to automatically run on boot up. This is important in the event you ever reboot your system without having to remember to manually kick off the service. <CHECK THIS ON REBOOT>

```console
tristram@kali:~$ sudo apt update && sudo apt install portsentry
```

#### Configuration Files
This utility comes with three files in /etc/portsentry:

1. portsentry.conf - Main configuration file
2. portsentry.ignore - List of IPs that will be ignored
3. portsentry.ignore.static - This file merges with the previous ignore file when you start the daemon. Use this file to add custom exclusions and reload via `/etc/init.d/portsentry restart`

#### Configure PortSentry to monitor
Open up the configuration file and starting on lines 34-39 you'll see examples of ports you can monitor. You do not need to go overboard, cause you could potentially block legit traffic, but keep yourself in the mind of a hacker. 

Chances are if you're going to run a port sweep of a target, you're going to scan for all possible ports so you can likely detect these operations if you monitor just 1 and 65535. I added 4444 in there because that seems to be a pretty common go to in a lot of reverse shell guides I've seen posted so as a sanity check I include that in my config.

![Alt text](https://github.com/gh0x0st/Secure_Kali/blob/master/Screenshots/portsentry_config.png?raw=true "portsentry_config")

Out of the box, PortSentry will not take any action other than notify if it detects a connection to a port you're monitoring. These notifications go to `/varlog/syslog` and a log also gets appended in `/var/lib/portsentry/portsentry.history`. 

#### Configure PortSentry to block port scans
If you wish for PortSentry to start taking action against detected scans, go to the configuration file and change BLOCK_TCP and/or BLOCK_UDP from 0 to 1. 

```console
# To view IPs that have been blocked
tristram@kali:~$ route | grep '!H'

# To unblock IPs
tristram@kali:~$ sudo ip route del 1.2.3.4
```

![Alt text](https://github.com/gh0x0st/Secure_Kali/blob/master/Screenshots/portsentry_block.png?raw=true "portsentry_block")

*You may have noticed an option to execute a script on detections. Don't risk getting yourself in trouble with the admins due to a retaliation strike against another student*

#### Configure Fail2ban to block port scans
One of the things that I really like about Fail2ban is that you can incorporate it with so many different systems that generate log files. In this case, we can also use it to monitor a log file from PortSentry.

```
# Block port scans detected by portsentry
[portsentry]
enabled = true
logpath = /var/lib/portsentry/portsentry.history
maxretry = 1
```

Our filter for the PortSentry jail is pretty straight forward. One thing to keep in mind is that portsentry.history doesn't exist by default until it detects activity so if you haven't used it yet.

**Create history file**
```console
tristram@kali:~$ sudo touch /var/lib/portsentry/portsentry.history
```

**To view IPs that have been blocked**
```console
tristram@kali:~$ sudo fail2ban-client status portsentry
tristram@kali:~$ sudo iptables -L f2b-portsentry
```

**To unblock ip from fail2ban**
```console
tristram@kali:~$ sudo fail2ban-client set portsentry unbanip 1.2.3.4
```

**To unblock ip from PortSentry**

You also need to remove the line from /var/lib/portsentry/portsentry.blocked.tcp/udp respectively. There's a few extra steps you need to take if you want Fail2ban to manage the blocks for you, but you can decide which route you want to go.

## Putting it all together
When it comes down to it, protecting your Kali machine is similar to the way you would protect any other machine. Patch often, disable unused services, use complex passwords, utilize least privilege and monitor where appropriate. When in doubt, after you put in these controls, test them yourself. Spin up a second machine and attack your kali machine and see if you can bust yourself. 

Be informed, be secure.
