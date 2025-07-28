FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}"

ARG TARGETARCH

# Step 1: Install base tools and add repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        checkinstall \
        gnupg2 \
        curl \
        wget \
        build-essential \
        libmagic-dev \
        ca-certificates \
        pkg-config \
        cmake \
        unzip \
        m4 && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Step 2: Install Python 3.12 (in a separate layer to avoid space issues)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 \
        python3.12-venv \
        python3-clang-12 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*


# Step 4: Set up Python virtual environment and install pip using ensurepip
RUN python3.12 -m venv /opt/mobile-docker && \
    /opt/mobile-docker/bin/python -m ensurepip && \
    /opt/mobile-docker/bin/pip install --upgrade pip setuptools wheel

# Step 5: Additional tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        openjdk-17-jdk \
        usbutils \
        libzip-dev \
        libtool-bin \
        autoconf \
        automake \
        libplist-dev \
        libusbmuxd-dev \
        libimobiledevice-dev \
        libimobiledevice6 \
        libimobiledevice-utils \
        ideviceinstaller \
        libusb-1.0-0-dev \
        udev \
        libssl-dev \
        lldb \
        busybox \
        # Optional tools (heavy or pending review)
        # gdb \
        # tcpdump \
        # tshark \
        # wireshark \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*


########################    
## GENERIC  TOOLS   #### 
######################## 

# Install Dependency-check #
#OK#
RUN curl -L -o /opt/mobile-docker/bin/dependency-check.zip "https://github.com/jeremylong/DependencyCheck/releases/download/v8.4.0/dependency-check-8.4.0-release.zip" && \
    unzip /opt/mobile-docker/bin/dependency-check.zip -d /opt/mobile-docker/bin && \
    ln -s /opt/mobile-docker/bin/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check && \
    rm /opt/mobile-docker/bin/dependency-check.zip


#Install Go
ENV GOROOT=/usr/local/go
ENV GOPATH=/go
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin
# Instala Go solo si la arquitectura es soportada (amd64 o arm64)
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
      ARCH=$TARGETARCH && \
      echo "[INFO] Installing Go for architecture: $ARCH" && \
      curl -s https://go.dev/dl/ | grep "linux-${ARCH}.tar.gz" | head -n 1 | \
      grep -oP 'href="\K[^"]+' | \
      xargs -I {} curl -sSL -o go.tar.gz https://go.dev{} && \
      tar -C /usr/local -xzf go.tar.gz && \
      rm go.tar.gz ; \
    else \
      echo "[INFO] Skipping Go install: unsupported architecture '$TARGETARCH'" ; \
    fi
#OK#
# Install Nuclei   
RUN if command -v go > /dev/null; then \
      echo "[INFO] Installing nuclei..." && \
      mkdir -p /opt/mobile-docker/bin/nuclei && \
      go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && \
      mv $GOPATH/bin/nuclei /opt/mobile-docker/bin/nuclei/nuclei && \
      ln -s /opt/mobile-docker/bin/nuclei/nuclei /usr/local/bin/nuclei ; \
    else \
      echo "[INFO] Skipping nuclei install: Go not available" ; \
    fi

#OK#
RUN mkdir -p /opt/mobile-docker/bin/radare2 && \
    cd /opt/mobile-docker/bin/radare2 && \
    git clone https://github.com/radareorg/radare2.git --depth=1 && \
    cd radare2 && \
    ./sys/install.sh 

#Install disarm (x86_64 only)
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      echo "[INFO] Installing disarm (x86_64 only)..." && \
      mkdir -p /opt/mobile-docker/bin/disarm && \
      curl -sSL -o /opt/mobile-docker/bin/disarm/disarm.tar https://newosxbook.com/tools/disarm.tar && \
      tar -xvf /opt/mobile-docker/bin/disarm/disarm.tar -C /opt/mobile-docker/bin/disarm && \
      chmod +x /opt/mobile-docker/bin/disarm/binaries/disarm.x86 && \
      ln -s /opt/mobile-docker/bin/disarm/binaries/disarm.x86 /usr/local/bin/disarm && \
      rm /opt/mobile-docker/bin/disarm/disarm.tar ; \
    else \
      echo "[INFO] Skipping disarm: unsupported architecture '$TARGETARCH'" ; \
    fi

# Compile and install libplist >= 2.6.0
RUN git clone https://github.com/libimobiledevice/libplist.git /tmp/libplist && \
    cd /tmp/libplist && \
    ./autogen.sh --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd ~ && rm -rf /tmp/libplist

# Compile and install libimobiledevice-glue
RUN git clone https://github.com/libimobiledevice/libimobiledevice-glue.git /tmp/libimobiledevice-glue && \
    cd /tmp/libimobiledevice-glue && \
    ./autogen.sh --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    ldconfig && \
    cd ~ && rm -rf /tmp/libimobiledevice-glue

#OK#
# Compile and install usbmuxd from source
RUN git clone https://github.com/libimobiledevice/usbmuxd.git /tmp/usbmuxd && \
    cd /tmp/usbmuxd && \
    ./autogen.sh --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/usbmuxd

# Install iproxy and other CLI tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libimobiledevice-utils \
        libusbmuxd-tools && \
    rm -rf /var/lib/apt/lists/*

########################    
# ANDROID APPLICATIONS # 
########################  

#OK#
# Install hermes-dec in virtual env
RUN git clone https://github.com/P1sec/hermes-dec.git /opt/mobile-docker/bin/hermes-dec && \
    cd /opt/mobile-docker/bin/hermes-dec && \
    ln -s /opt/mobile-docker/bin/hermes-dec/hbc_decompiler.py /usr/local/bin/hermes-dec && \
    ln -s /opt/mobile-docker/bin/hermes-dec/hbc_disassembler.py /usr/local/bin/hermes-dis

#NO#
# Install pidcat
#RUN git clone https://github.com/JakeWharton/pidcat.git /opt/mobile-docker/bin/pidcat && \
#    cd /opt/mobile-docker/bin/pidcat && \
#    ln -s /opt/mobile-docker/bin/pidcat/pidcat.py /usr/local/bin/pidcat

#OK#
# Install JADX (CLI only)
RUN wget https://github.com/skylot/jadx/releases/download/v1.4.7/jadx-1.4.7.zip -O /tmp/jadx.zip && \
   unzip /tmp/jadx.zip -d /opt/jadx && \
   ln -s /opt/jadx/bin/jadx /usr/local/bin/jadx && \
   rm /tmp/jadx.zip

#OK#
# Install APKTool
RUN wget https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.9.3.jar -O /opt/apktool.jar && \
   echo '#!/bin/bash\njava -jar /opt/apktool.jar "$@"' > /usr/local/bin/apktool && \
   chmod +x /usr/local/bin/apktool

# Install Android SDK tools (includes aapt2, adb, apksigner, etc.)
ENV ANDROID_SDK_ROOT=/opt/android-sdk
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
   wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/android-sdk.zip && \
   unzip /tmp/android-sdk.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
   mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
   rm /tmp/android-sdk.zip && \
   yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses && \
   ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager "platform-tools" "build-tools;34.0.0" && \
   ln -s ${ANDROID_SDK_ROOT}/platform-tools/adb /usr/local/bin/adb && \
   ln -s ${ANDROID_SDK_ROOT}/build-tools/34.0.0/apksigner /usr/local/bin/apksigner && \
   ln -s ${ANDROID_SDK_ROOT}/build-tools/34.0.0/aapt2 /usr/local/bin/aapt2

#OK#
# Install uber-apk-signer
RUN wget https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar -O /opt/uber-apk-signer.jar && \
   echo '#!/bin/bash\njava -jar /opt/uber-apk-signer.jar "$@"' > /usr/local/bin/uber-apk-signer && \
   chmod +x /usr/local/bin/uber-apk-signer

# Install justtrustme (assuming Xposed module, placeholder for manual APK handling)
#RUN echo "justtrustme is an Xposed module; install manually on Android device or clarify if a different #tool is meant" > /usr/local/bin/justtrustme && \
#    chmod +x /usr/local/bin/justtrustme

#OK#
# Install apkx
RUN git clone https://github.com/b-mueller/apkx.git /opt/apkx && \
   cd /opt/apkx && \
   chmod +x apkx && \
   ln -s /opt/apkx/apkx /usr/local/bin/apkx

#################
###Frida Based###
#################

# Install Fridump
RUN git clone https://github.com/Nightbringer21/fridump.git /opt/mobile-docker/bin/fridump && \
   cd /opt/mobile-docker/bin/fridump && \
   chmod +x fridump.py && \
   ln -s /opt/mobile-docker/bin/fridump/fridump.py /usr/local/bin/fridump

# Install frida-ios-dump
RUN git clone https://github.com/AloneMonkey/frida-ios-dump.git /opt/frida-ios-dump && \
   cd /opt/frida-ios-dump && \
   /opt/mobile-docker/bin/pip3.12 install -r requirements.txt && \
   chmod +x dump.py && \
   ln -s /opt/frida-ios-dump/dump.py /usr/local/bin/frida-ios-dump

# Install frida-ipa-dump (assuming a similar tool, using a placeholder if no official repo)
RUN git clone https://github.com/AloneMonkey/frida-ios-dump.git /opt/frida-ipa-dump && \
   cd /opt/frida-ipa-dump && \
   /opt/mobile-docker/bin/pip3.12 install -r requirements.txt && \
   chmod +x dump.py && \
   ln -s /opt/frida-ipa-dump/dump.py /usr/local/bin/frida-ipa-dump && \
   echo "Note: frida-ipa-dump is assumed to be similar to frida-ios-dump; adjust if a different tool #is intended" > /usr/local/bin/frida-ipa-dump-note


#OK#
# Install Busybox (already included in apt-get above, ensure symlink)
RUN ln -s /bin/busybox /usr/local/bin/busybox

#OK#
# Install Frida and related tools in virtual env
# I added the frida commands as ln  
RUN /opt/mobile-docker/bin/pip3.12 install frida frida-tools
RUN ln -s /opt/mobile-docker/bin/frida /usr/local/bin/frida
RUN ln -s /opt/mobile-docker/bin/frida-ps /usr/local/bin/frida-ps
RUN ln -s /opt/mobile-docker/bin/frida-itrace /usr/local/bin/frida-itrace
RUN ln -s /opt/mobile-docker/bin/frida-apk /usr/local/bin/frida-apk
RUN ln -s /opt/mobile-docker/bin/frida-compile /usr/local/bin/frida-compile
RUN ln -s /opt/mobile-docker/bin/frida-create /usr/local/bin/frida-create
RUN ln -s /opt/mobile-docker/bin/frida-discover /usr/local/bin/frida-discover
RUN ln -s /opt/mobile-docker/bin/frida-join /usr/local/bin/frida-join
RUN ln -s /opt/mobile-docker/bin/frida-kill /usr/local/bin/frida-kill
RUN ln -s /opt/mobile-docker/bin/frida-ls /usr/local/bin/frida-ls
RUN ln -s /opt/mobile-docker/bin/frida-ls-devices /usr/local/bin/frida-ls-devices
RUN ln -s /opt/mobile-docker/bin/frida-pull /usr/local/bin/frida-pull
RUN ln -s /opt/mobile-docker/bin/frida-push /usr/local/bin/frida-push
RUN ln -s /opt/mobile-docker/bin/frida-rm /usr/local/bin/frida-rm
RUN ln -s /opt/mobile-docker/bin/frida-trace /usr/local/bin/frida-trace

# Install objection in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install objection
RUN ln -s /opt/mobile-docker/bin/objection /usr/local/bin/objection

# Install APKID in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install apkid
RUN ln -s /opt/mobile-docker/bin/apkid /usr/local/bin/apkid

# Install Semgrep in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install semgrep
RUN ln -s /opt/mobile-docker/bin/semgrep /usr/local/bin/semgrep

# Install APKLeaks in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install apkleaks
RUN ln -s /opt/mobile-docker/bin/apkleaks /usr/local/bin/apkleaks

# Install angr in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install angr
RUN ln -s /opt/mobile-docker/bin/angr /usr/local/bin/angr

# Install blint in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install blint
RUN ln -s /opt/mobile-docker/bin/blint /usr/local/bin/blint

# Install reflutter in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install reflutter==0.8.5
RUN ln -s /opt/mobile-docker/bin/reflutter /usr/local/bin/reflutter

# Install jnitrace in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install jnitrace
RUN ln -s /opt/mobile-docker/bin/jnitrace /usr/local/bin/jnitrace

# Install mitmproxy in virtual env
RUN /opt/mobile-docker/bin/pip3.12 install mitmproxy
RUN ln -s /opt/mobile-docker/bin/mitmproxy /usr/local/bin/mitmproxy

# Install jdb (already included with OpenJDK, just ensure symlink)
RUN ln -s /usr/lib/jvm/java-17-openjdk-amd64/bin/jdb /usr/local/bin/jdb



#those are broken #
#broken symbolic link to /opt/mobile-docker/bin/binarycookies

# Install iOSBackup 

#RUN /opt/mobile-docker/bin/pip3.12 install iOSbackup 
#RUN ln -s /opt/mobile-docker/bin/iOSbackup /usr/local/bin/iOSbackup


# Install binarycookies in virtual env
#RUN /opt/mobile-docker/bin/pip3.12 install binarycookies
#RUN ln -s /opt/mobile-docker/bin/binarycookies /usr/local/bin/binarycookies 


########################    
# IOS APPLICATIONS     # 
########################  

# Install otool and nm (macOS-specific, so we'll use binutils equivalents for Linux)
RUN apt-get update && apt-get install -y binutils && \
    ln -s /usr/bin/objdump /usr/local/bin/otool && \
    ln -s /usr/bin/nm /usr/local/bin/nm

# Install plutil (macOS-specific, using libplist-utils instead)
#RUN apt-get install -y libplist-utils && \
#    echo "plutil is macOS-specific; using libplist-utils equivalent in Linux" > /usr/local/bin/plutil #&& \
#    chmod +x /usr/local/bin/plutil



#NO#
# Install IPSW (commented out)
#RUN cd /opt/mobile-docker/bin/ && \
#    git clone https://github.com/blacktop/ipsw.git && \
#    cd ipsw && \
#    go install ./... && \
#    mv /opt/mobile-docker/bin/ipsw/go/bin/ipsw /usr/local/bin/ipsw

# Install LIEF in virtual env
#RUN /opt/mobile-docker/bin/pip3.12 install lief
#RUN ln -s /opt/mobile-docker/bin/lief /usr/local/bin/lief



##################################
# With some installation problem #  
################################## 

# Install iaito (GUI for Radare2, commented out)
#RUN git clone --recurse-submodules https://github.com/radareorg/iaito.git /opt/iaito && \
#    cd /opt/iaito && \
#    mkdir build && cd build && \
#    cmake .. && \
#    make -j$(nproc) && \
#    make install && \
#    ln -s /usr/local/bin/iaito /usr/local/bin/iaito

# Accept GitHub PAT as a build argument (for Butter, commented out)
#ARG GITHUB_PAT
# Install Butter (using PAT for authentication)
#RUN git clone https://${GITHUB_PAT}@github.com/Margular/Butter.git /opt/butter && \
#    cd /opt/butter && \
#    if [ -f requirements.txt ]; then /opt/mobile-docker/bin/pip3 install -r requirements.txt; else echo "No requirements.txt found, skipping pip install"; fi && \
#    ln -s /opt/butter/butter.py /usr/local/bin/butter

# Install Ghidra (commented out)
#RUN wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0.1_build/ghidra_11.0.1_PUBLIC_20240130.zip -O /tmp/ghidra.zip && \
#    unzip /tmp/ghidra.zip -d /opt/ && \
#    ln -s /opt/ghidra_11.0.1_PUBLIC/ghidraRun /usr/local/bin/ghidra && \
#    rm /tmp/ghidra.zip

# Install MobSF (commented out)
#RUN git clone https://github.com/MobSF/Mobile-Security-Framework-MobSF.git /opt/mobsf && \
#    cd /opt/mobsf && \
#    python3 -m venv venv && \
#    . venv/bin/activate && \
#    pip install --upgrade pip && \
#    pip install -r requirements.txt && \
#    ./setup.sh && \
#    ln -s /opt/mobsf/run.sh /usr/local/bin/mobsf

# Install RMS (assuming Runtime Mobile Security, commented out)
#RUN git clone https://github.com/m0bilesecurity/RMS-Runtime-Mobile-Security.git /opt/rms && \
#    cd /opt/rms && \
#    /opt/mobile-docker/bin/pip3 install -r requirements.txt && \
#    ln -s /opt/rms/rms.py /usr/local/bin/rms

# Install scrcpy (requires additional dependencies, commented out)
#RUN apt-get update && apt-get install -y \
#    ffmpeg libsdl2-2.0-0 adb wget gcc git pkg-config meson ninja-build \
#    libsdl2-dev libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
#    libswresample-dev libusb-1.0-0 libusb-1.0-0-dev && \
#    git clone https://github.com/Genymobile/scrcpy.git /opt/scrcpy && \
#    cd /opt/scrcpy && \
#    meson setup build --buildtype=release -Dprebuilt_server=/opt/scrcpy/prebuilt/scrcpy-server-v2.4 && \
#    cd build && ninja && ninja install && \
#    ln -s /usr/local/bin/scrcpy /usr/local/bin/scrcpy

# Install ProGuard (standalone version, commented out)
#RUN wget https://github.com/Guardsquare/proguard/releases/download/v7.5.0/proguard-7.5.0.tar.gz -O /tmp/proguard.tar.gz && \
#    tar -xzf /tmp/proguard.tar.gz -C /opt/ && \
#    ln -s /opt/proguard-7.5.0/bin/proguard.sh /usr/local/bin/proguard && \
#    chmod +x /usr/local/bin/proguard && \
#    rm /tmp/proguard.tar.gz


# Set working directory
WORKDIR /just-mobile-security-mobile-docker

# Default command
CMD ["/bin/bash"]
