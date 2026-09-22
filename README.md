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
This Docker image provides a pre-configured collection of Android, iOS, and generic mobile security tools.

The image is based on Ubuntu 22.04 and uses the [OWASP MASTG tool catalog](https://mas.owasp.org/MASTG/tools) as a reference.

The [Docker MASTG List Android & iOS](https://docs.google.com/spreadsheets/d/10kHjVb7YZzyA_nzCAFTjtfaSZa9TnsAgILbttIPcYTE/edit?gid=1839499844#gid=1839499844) is a planning matrix. The Dockerfile's final smoke test and the multi-architecture CI build are the source of truth for tools included in the image.

Core validated commands include `adb`, `fastboot`, `apktool`, `jadx`, `apksigner`, `nuclei`, `radare2`, `frida`, `objection`, `semgrep`, `mitmproxy`, `iproxy`, and `frida-ios-dump`. Architecture-specific tools are validated only where they are installed; for example, `disarm` and Google's `aapt2` build are AMD64-only.

## Responsible Use

This toolkit gathers penetration testing and research utilities. Use it only on systems where you have explicit permission and comply with all applicable laws. The maintainers do not endorse or take responsibility for malicious or unauthorized activity carried out with this image.

## Prerequisites

Docker Desktop is required to run this project locally. Please install Docker Desktop for your operating system before continuing.

macOS — [Install Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/). 

Ubuntu — [Install Docker Engine on Ubuntu](https://docs.docker.com/desktop/setup/install/linux/ubuntu/)

Linux (All distros) — [Install Docker Desktop for Linux](https://docs.docker.com/desktop/setup/install/linux/) 

Windows — [Install Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/)
><sub>In Windows Docker Desktop uses the WSL 2 backend on modern Windows; please make sure WSL 2 is enabled and configured before installing. </sub>



### How to run it?

1. Clone this repository.
2. Build the image:

```bash
docker build -t just-mobile-security-mobile-docker .
```

3. Run the container with the current directory mounted as the workspace:

```bash
docker run -it --rm -v "$(pwd):/workspace" just-mobile-security-mobile-docker
```

The container runs as root because some device tooling requires elevated access. Mount only a trusted working directory and do not expose the Docker socket or unrelated host directories.

After that you only need to use the docker image as the following example.

```bash
jadx --version
```


## Mobile Device Wi‑Fi Connectivity Guide

Due to various OS‑ and architecture‑specific limitations around exposing USB ports inside Docker containers, we’re sharing this **workaround** to use ADB, SSH, and Frida **over Wi‑Fi** from within the container.

---

Below are the steps to connect your Android and iOS devices over Wi‑Fi **from inside** the Docker container using ADB, SSH, and Frida.

---

### Android: ADB over Wi‑Fi

> **Prerequisite**: On your **host** machine (outside the container), enable wireless debugging on the device:
> ```
> adb tcpip 5555
> adb connect <DEVICE_IP>:5555
> ```
> This puts the device into TCP mode on port 5555.

Then, **inside** the container:

#### Re-connect via TCP (device is already listening)
```
adb connect <DEVICE_IP>:5555
```
#### Verify connection
```
adb devices
```
### Android: Frida over Wi‑Fi

Start Frida on the device's loopback interface, then forward its port through the existing ADB connection. This avoids exposing a root Frida service to the Wi-Fi network:

```
adb shell "su -c 'nohup /data/local/tmp/frida-server >/dev/null 2>&1 &'"
adb forward tcp:27042 tcp:27042
```

List processes through the local forwarded port:

```
frida-ps -H 127.0.0.1:27042
```

### iOS: Frida via SSH + Wi‑Fi

> **Prerequisite**: Frida installed on your iPhone (e.g. via Sileo) so that frida-server auto-starts.

From inside the container, establish an SSH tunnel:
```
ssh -S /tmp/frida-ios-tunnel -M -o ExitOnForwardFailure=yes -fNT \
  -L 27042:127.0.0.1:27042 root@<IPHONE_IP>
```
Verify the tunnel and list processes remotely:
```
frida-ps -H 127.0.0.1:27042
```
To close the tunnel when you're done:
```
ssh -S /tmp/frida-ios-tunnel -O exit root@<IPHONE_IP>
```

## Additional tool implementations

Some additional tools were added to this docker image as Nuclei, disarm and more! These aren't within the OWASP Project (https://mas.owasp.org/MASTG/tools) if you want to add any additional tool, please create a PR for this repo with the tool and the instructions.
