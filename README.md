```
                                      ___ ___  ___ _____                             
                                     |_  ||  \/  |/  ___|                            
                                       | || .  . |\ `--.                             
                                       | || |\/| | `--. \                            
                                   /\__/ /| |  | |/\__/ /                            
                                   \____/ \_|  |_/\____/                             
            ___  ___        _      _  _          ______              _               
            |  \/  |       | |    (_)| |         |  _  \            | |              
            | .  . |  ___  | |__   _ | |  ___    | | | | ___    ___ | | __ ___  _ __ 
            | |\/| | / _ \ | '_ \ | || | / _ \   | | | |/ _ \  / __|| |/ // _ \| '__|
            | |  | || (_) || |_) || || ||  __/   | |/ /| (_) || (__ |   <|  __/| |   
            \_|  |_/ \___/ |_.__/ |_||_| \___|   |___/  \___/  \___||_|\_\\___||_|   
```                                                

# just-mobile-security-mobile-docker
This Docker aims to help to the Mobile Cybersecurity Community to have several Android and iOS Tools pre-configured.

This docker was tested for Ubuntu 22.04 and using the MASTG TOOLS (https://mas.owasp.org/MASTG/tools) as reference. Covering the Generic, Android, iOS and Network tools in case it applies.


The full list implemented is covered in the following documment https://docs.google.com/spreadsheets/d/10kHjVb7YZzyA_nzCAFTjtfaSZa9TnsAgILbttIPcYTE/edit?gid=1839499844#gid=1839499844 

How to run it?

* Docker configuration.

1. Download the git project.
2. Build the docker container.
2.1. sudo docker build -t just-mobile-security-mobile-docker .
3. Run the container
3.1. docker run -it --rm -v $(pwd):/workspace just-mobile-security-mobile-docker	

After that you only need to use the docker image as the following example.

$jadx

> Due to various OS‑ and architecture‑specific limitations around exposing USB ports inside Docker containers, we’re sharing this **workaround** to use ADB, SSH, and Frida **over Wi‑Fi** from within the container.

---

## 🚀 Wi‑Fi Connectivity Guide

Below are the steps to connect your Android and iOS devices over Wi‑Fi **from inside** the Docker container using ADB, SSH, and Frida.

---

### 🔌 Android: ADB over Wi‑Fi

> **Prerequisite**: On your **host** machine (outside the container), enable wireless debugging on the device:
> ```
> adb tcpip 5555
> adb connect <DEVICE_IP>:5555
> ```
> This puts the device into TCP mode on port 5555.

Then, **inside** the container:
```
# Re-connect via TCP (device is already listening)
adb connect <DEVICE_IP>:5555

# Verify connection
adb devices

🐉 Android: Frida over Wi‑Fi

    Push and start the Frida server (or frodo) on the device:

adb shell "su -c 'nohup /data/local/tmp/frida-server 0.0.0.0:27042 >/dev/null 2>&1 &'"
sleep 1

From inside the container, list processes via Frida:

    frida-ps -H <DEVICE_IP>:27042

🍏 iOS: Frida via SSH + Wi‑Fi

    Prerequisite: Frida installed on your iPhone (e.g. via Sileo) so that frida-server auto-starts.

    From inside the container, establish an SSH tunnel:

ssh -o ExitOnForwardFailure=yes -fNT \
    -L 27042:127.0.0.1:27042 \
    root@<IPHONE_IP>

Verify the tunnel and list processes remotely:

frida-ps -H 127.0.0.1:27042

To close the tunnel when you’re done:

pkill -9 -f 'ssh.*27042'


Additional tool implementations

Some additional tools were added to this docker image as Nuclei, disarm and more! These aren't within the OWASP Project (https://mas.owasp.org/MASTG/tools) if you want to add any additional tool, please create a PR for this repo with the tool and the instructions.
