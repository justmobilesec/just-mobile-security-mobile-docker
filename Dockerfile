# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32

FROM ubuntu:22.04@sha256:b8b6ee6aa931ecd9d0d952abc34dc0e5f7c6a30c6bb71b079fe399fde0329c02

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETARCH

# Step 1: Install base tools and add repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        checkinstall \
        gnupg2 \
        zsh \
        curl \
        wget \
        openssh-client \
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
        python3.12-dev \
        python3-clang-12 \
        python-is-python3 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Some third-party tools still look for /usr/bin/python
RUN if [ ! -e /usr/bin/python ]; then ln -s /usr/bin/python3 /usr/bin/python; fi


# Step 4: Set up Python virtual environment and install pip using ensurepip
RUN python3.12 -m venv /opt/mobile-docker && \
    /opt/mobile-docker/bin/python -m ensurepip && \
    /opt/mobile-docker/bin/pip install --no-cache-dir --upgrade \
        pip==26.2.1 \
        setuptools==84.0.0 \
        wheel==0.48.0
ENV PATH=/opt/mobile-docker/bin:${PATH}

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
        jq \
        tar \
        # Optional tools (heavy or pending review)
        # gdb \
        # tcpdump \
        # tshark \
        # wireshark \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Step 5.1: Install Oh My Zsh for a nicer interactive shell
ARG OH_MY_ZSH_REF=40bddc3c1a100feafccb01403f74c1d4e7380380
RUN mkdir -p /root/.oh-my-zsh && \
    curl -fsSL --retry 3 "https://github.com/ohmyzsh/ohmyzsh/archive/${OH_MY_ZSH_REF}.tar.gz" | \
        tar -xz --strip-components=1 -C /root/.oh-my-zsh && \
    cp /root/.oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc && \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /root/.zshrc && \
    sed -i 's/^# DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/' /root/.zshrc


########################    
## GENERIC  TOOLS   #### 
######################## 

# Install Dependency-check #
#OK#
ARG DEPENDENCY_CHECK_VERSION=12.1.0
ARG DEPENDENCY_CHECK_SHA256=0e5ba6ae58e753d5841048c6c8e495dbc4c7a4ea921a2b14daeac65195700532
RUN curl -fsSL --retry 3 -o /opt/mobile-docker/bin/dependency-check.zip \
        "https://github.com/jeremylong/DependencyCheck/releases/download/v${DEPENDENCY_CHECK_VERSION}/dependency-check-${DEPENDENCY_CHECK_VERSION}-release.zip" && \
    echo "${DEPENDENCY_CHECK_SHA256}  /opt/mobile-docker/bin/dependency-check.zip" | sha256sum -c - && \
    unzip /opt/mobile-docker/bin/dependency-check.zip -d /opt/mobile-docker/bin && \
    ln -s /opt/mobile-docker/bin/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check && \
    rm /opt/mobile-docker/bin/dependency-check.zip


#OK#
# Install Nuclei   
ARG NUCLEI_VERSION=3.11.1
ARG NUCLEI_SHA256_AMD64=ea63d4ae232808cd7c6bc00d0142428e231fab59dae01042246097d195835ab6
ARG NUCLEI_SHA256_ARM64=8044e3d9768ba0a744b2872c1a87e813006f013da97ca9f50f7661a4203bec07
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) NUCLEI_SHA256="${NUCLEI_SHA256_AMD64}" ;; \
      arm64) NUCLEI_SHA256="${NUCLEI_SHA256_ARM64}" ;; \
      *) echo "[ERROR] unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    TMPDIR=$(mktemp -d); \
    ASSET="nuclei_${NUCLEI_VERSION}_linux_${TARGETARCH}.zip"; \
    curl -fsSL --retry 3 \
      "https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/${ASSET}" \
      -o "$TMPDIR/$ASSET"; \
    echo "${NUCLEI_SHA256}  $TMPDIR/$ASSET" | sha256sum -c -; \
    unzip -q "$TMPDIR/$ASSET" -d "$TMPDIR"; \
    install -m 0755 "$TMPDIR/nuclei" /usr/local/bin/nuclei; \
    case "$TMPDIR" in /tmp/tmp.*) rm -rf -- "$TMPDIR" ;; *) exit 1 ;; esac; \
    /usr/local/bin/nuclei -version

#OK#
ARG RADARE2_REF=8e2566b5478604ee34dca1f412af23beb7602036
RUN mkdir -p /opt/mobile-docker/bin/radare2/radare2 && \
    curl -fsSL --retry 3 "https://github.com/radareorg/radare2/archive/${RADARE2_REF}.tar.gz" | \
        tar -xz --strip-components=1 -C /opt/mobile-docker/bin/radare2/radare2 && \
    cd /opt/mobile-docker/bin/radare2/radare2 && \
    ./sys/install.sh 

#Install disarm (x86_64 only)
# The upstream tarball was removed, so use a pinned web-archive snapshot.
ARG DISARM_SHA256=d320d6ef00e71ab4948040cb9f7601fd94ac1bc4eb58f3256768a4930cdc1a40
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      echo "[INFO] Installing disarm (x86_64 only)..." && \
      mkdir -p /opt/mobile-docker/bin/disarm && \
      curl -fsSL -o /opt/mobile-docker/bin/disarm/disarm.tar https://web.archive.org/web/20240401070850if_/https://newosxbook.com/tools/disarm.tar && \
      echo "${DISARM_SHA256}  /opt/mobile-docker/bin/disarm/disarm.tar" | sha256sum -c - && \
      tar -xvf /opt/mobile-docker/bin/disarm/disarm.tar -C /opt/mobile-docker/bin/disarm && \
      chmod +x /opt/mobile-docker/bin/disarm/binaries/disarm.x86 && \
      ln -s /opt/mobile-docker/bin/disarm/binaries/disarm.x86 /usr/local/bin/disarm && \
      rm /opt/mobile-docker/bin/disarm/disarm.tar ; \
    else \
      echo "[INFO] Skipping disarm: unsupported architecture '$TARGETARCH'" ; \
    fi

# Compile and install libplist >= 2.6.0
ARG LIBPLIST_REF=32428abacb909988e8e960a8845a6430b17b6a60
RUN mkdir -p /tmp/libplist && \
    curl -fsSL --retry 3 "https://github.com/libimobiledevice/libplist/archive/${LIBPLIST_REF}.tar.gz" | \
        tar -xz --strip-components=1 -C /tmp/libplist && \
    cd /tmp/libplist && \
    printf '%s\n' '2.7.0' > .tarball-version && \
    ./autogen.sh --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd ~ && rm -rf /tmp/libplist

# Compile and install libimobiledevice-glue
ARG LIBIMOBILEDEVICE_GLUE_REF=da770a7687f35fbb981db4d7b47b1b032cd5c2c7
RUN mkdir -p /tmp/libimobiledevice-glue && \
    curl -fsSL --retry 3 "https://github.com/libimobiledevice/libimobiledevice-glue/archive/${LIBIMOBILEDEVICE_GLUE_REF}.tar.gz" | \
        tar -xz --strip-components=1 -C /tmp/libimobiledevice-glue && \
    cd /tmp/libimobiledevice-glue && \
    printf '%s\n' '1.3.2' > .tarball-version && \
    ./autogen.sh --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    ldconfig && \
    cd ~ && rm -rf /tmp/libimobiledevice-glue

#OK#
# Compile and install usbmuxd from source
ARG USBMUXD_REF=3ded00c9985a5108cfc7591a309f9a23d57a8cba
RUN mkdir -p /tmp/usbmuxd && \
    curl -fsSL --retry 3 "https://github.com/libimobiledevice/usbmuxd/archive/${USBMUXD_REF}.tar.gz" | \
        tar -xz --strip-components=1 -C /tmp/usbmuxd && \
    cd /tmp/usbmuxd && \
    printf '%s\n' '1.0.8' > .tarball-version && \
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
ARG HERMES_DEC_REF=a0f18f97ab661eb8ed659c8c683a0d21ea619e69
RUN mkdir -p /opt/mobile-docker/bin/hermes-dec && \
    curl -fsSL --retry 3 "https://github.com/P1sec/hermes-dec/archive/${HERMES_DEC_REF}.tar.gz" | \
        tar -xz --strip-components=1 -C /opt/mobile-docker/bin/hermes-dec && \
    pip install --no-cache-dir /opt/mobile-docker/bin/hermes-dec && \
    ln -s /opt/mobile-docker/bin/hbc-decompiler /usr/local/bin/hermes-dec && \
    ln -s /opt/mobile-docker/bin/hbc-disassembler /usr/local/bin/hermes-dis

#NO#
# Install pidcat
#RUN git clone https://github.com/JakeWharton/pidcat.git /opt/mobile-docker/bin/pidcat && \
#    cd /opt/mobile-docker/bin/pidcat && \
#    ln -s /opt/mobile-docker/bin/pidcat/pidcat.py /usr/local/bin/pidcat

#OK#
# Install JADX (CLI only)
ARG JADX_VERSION=1.5.6
ARG JADX_SHA256=545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974
RUN curl -fsSL --retry 3 \
        "https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip" \
        -o /tmp/jadx.zip && \
   echo "${JADX_SHA256}  /tmp/jadx.zip" | sha256sum -c - && \
   unzip /tmp/jadx.zip -d /opt/jadx && \
   ln -s /opt/jadx/bin/jadx /usr/local/bin/jadx && \
   rm /tmp/jadx.zip

#OK#
# Install APKTool
ARG APKTOOL_VERSION=3.0.3
ARG APKTOOL_SHA256=dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423
RUN curl -fsSL --retry 3 \
        "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar" \
        -o /opt/apktool.jar && \
   echo "${APKTOOL_SHA256}  /opt/apktool.jar" | sha256sum -c - && \
   printf '%s\n' '#!/usr/bin/env bash' 'exec java -jar /opt/apktool.jar "$@"' > /usr/local/bin/apktool && \
   chmod +x /usr/local/bin/apktool

# — ANDROID SDK (latest cross-platform release) —

# ========= ANDROID SDK (common block) =========
ARG TARGETARCH
ARG ANDROID_SDK_ROOT=/opt/android-sdk
ARG ANDROID_BUILD_TOOLS_VERSION=34.0.0
ARG CMDLINE_TOOLS_VERSION=9477386
ARG CMDLINE_TOOLS_SHA256=bd1aa17c7ef10066949c88dc6c9c8d536be27f992a1f3b5a584f9bd2ba5646a0
ENV ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}
ENV ANDROID_BUILD_TOOLS_VERSION=${ANDROID_BUILD_TOOLS_VERSION}
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget unzip && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    cd ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip \
         -O cmdline-tools.zip && \
    echo "${CMDLINE_TOOLS_SHA256}  cmdline-tools.zip" | sha256sum -c - && \
    unzip cmdline-tools.zip && \
    rm cmdline-tools.zip && \
    mv cmdline-tools latest
ENV PATH=${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${PATH}

# ========= ANDROID SDK (AMD64) INICIO =========
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      set +o pipefail; \
      yes | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses; \
      set -o pipefail; \
      sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" \
        "platform-tools" \
        "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"; \
    fi

RUN if [ "$TARGETARCH" = "amd64" ]; then \
      BUILD_TOOLS_DIR="${ANDROID_SDK_ROOT}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}"; \
      if [ ! -d "$BUILD_TOOLS_DIR" ]; then \
        echo "[ERROR] Expected Android build-tools in $BUILD_TOOLS_DIR"; \
        exit 1; \
      fi; \
      ln -sf "${ANDROID_SDK_ROOT}/platform-tools/adb" /usr/local/bin/adb && \
      ln -sf "${ANDROID_SDK_ROOT}/platform-tools/fastboot" /usr/local/bin/fastboot && \
      ln -sf "$BUILD_TOOLS_DIR/apksigner" /usr/local/bin/apksigner && \
      ln -sf "$BUILD_TOOLS_DIR/aapt" /usr/local/bin/aapt && \
      ln -sf "$BUILD_TOOLS_DIR/aapt2" /usr/local/bin/aapt2; \
    fi
# ========= ANDROID SDK (AMD64) FIN =========

# ========= ANDROID SDK (ARM64) INICIO =========
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      apt-get update && \
      apt-get install -y --no-install-recommends \
        android-tools-adb \
        android-tools-fastboot \
        aapt \
        apksigner && \
      rm -rf /var/lib/apt/lists/*; \
    fi
# ========= ANDROID SDK (ARM64) FIN =========


#OK#
# Install uber-apk-signer
ARG UBER_APK_SIGNER_VERSION=1.3.0
ARG UBER_APK_SIGNER_SHA256=e1299fd6fcf4da527dd53735b56127e8ea922a321128123b9c32d619bba1d835
RUN curl -fsSL --retry 3 \
        "https://github.com/patrickfav/uber-apk-signer/releases/download/v${UBER_APK_SIGNER_VERSION}/uber-apk-signer-${UBER_APK_SIGNER_VERSION}.jar" \
        -o /opt/uber-apk-signer.jar && \
   echo "${UBER_APK_SIGNER_SHA256}  /opt/uber-apk-signer.jar" | sha256sum -c - && \
   printf '%s\n' '#!/usr/bin/env bash' 'exec java -jar /opt/uber-apk-signer.jar "$@"' > /usr/local/bin/uber-apk-signer && \
   chmod +x /usr/local/bin/uber-apk-signer

# Install justtrustme (assuming Xposed module, placeholder for manual APK handling)
#RUN echo "justtrustme is an Xposed module; install manually on Android device or clarify if a different #tool is meant" > /usr/local/bin/justtrustme && \
#    chmod +x /usr/local/bin/justtrustme

#OK#
# Install apkx with venv wrapper (script expects python interpreter)
ARG APKX_REF=fcb74ff37c9fe4428d7ff11a4863c273096698e8
RUN mkdir -p /opt/apkx && \
   curl -fsSL --retry 3 "https://github.com/b-mueller/apkx/archive/${APKX_REF}.tar.gz" | \
      tar -xz --strip-components=1 -C /opt/apkx && \
   cd /opt/apkx && \
   chmod +x apkx && \
   printf '#!/usr/bin/env bash\nexec /opt/mobile-docker/bin/python /opt/apkx/apkx "$@"\n' > /usr/local/bin/apkx && \
   chmod +x /usr/local/bin/apkx

#################
###Frida Based###
#################

# Install Fridump (provide wrapper to execute with venv python)
ARG FRIDUMP_REF=3e64ee0b0e3dbd7e1aa295077c9ba0728a2bc68f
RUN mkdir -p /opt/mobile-docker/bin/fridump && \
   curl -fsSL --retry 3 "https://github.com/Nightbringer21/fridump/archive/${FRIDUMP_REF}.tar.gz" | \
      tar -xz --strip-components=1 -C /opt/mobile-docker/bin/fridump && \
   cd /opt/mobile-docker/bin/fridump && \
   chmod +x fridump.py && \
   printf '#!/usr/bin/env bash\nexec /opt/mobile-docker/bin/python /opt/mobile-docker/bin/fridump/fridump.py "$@"\n' > /usr/local/bin/fridump && \
   chmod +x /usr/local/bin/fridump

# Install frida-ios-dump
ARG FRIDA_IOS_DUMP_REF=56e99b2138fc213fa759b3aeb9717a1fb4ec6a59
RUN mkdir -p /opt/frida-ios-dump && \
   curl -fsSL --retry 3 "https://github.com/AloneMonkey/frida-ios-dump/archive/${FRIDA_IOS_DUMP_REF}.tar.gz" | \
      tar -xz --strip-components=1 -C /opt/frida-ios-dump && \
   cd /opt/frida-ios-dump && \
   python3.12 -m venv /opt/frida-ios-dump-venv && \
   /opt/frida-ios-dump-venv/bin/pip install --no-cache-dir \
      -r requirements.txt frida==17.18.0 frida-tools==14.10.4 && \
   chmod +x dump.py && \
   printf '#!/usr/bin/env bash\nexec /opt/frida-ios-dump-venv/bin/python /opt/frida-ios-dump/dump.py "$@"\n' > /usr/local/bin/frida-ios-dump && \
   chmod +x /usr/local/bin/frida-ios-dump


#OK#
# Install Busybox (already included in apt-get above, ensure symlink)
RUN ln -sf /bin/busybox /usr/local/bin/busybox

# Install Python-based tooling in one resolved, version-pinned transaction.
RUN pip install --no-cache-dir \
      frida==17.18.0 \
      frida-tools==14.10.4 \
      objection==1.12.5 \
      apkid==3.1.0 \
      semgrep==1.177.0 \
      apkleaks==2.6.3 \
      angr==9.3.4 \
      unicorn==2.1.4 \
      blint==3.4.0 \
      reflutter==0.8.6 \
      jnitrace==3.3.1

# Keep mitmproxy isolated from the main tooling environment: its pinned
# dependency set conflicts with blint on Python 3.12.
RUN python3.12 -m venv /opt/mitmproxy-venv && \
    /opt/mitmproxy-venv/bin/pip install --no-cache-dir mitmproxy==12.2.3 && \
    ln -sf /opt/mitmproxy-venv/bin/mitmproxy /usr/local/bin/mitmproxy && \
    ln -sf /opt/mitmproxy-venv/bin/mitmdump /usr/local/bin/mitmdump && \
    ln -sf /opt/mitmproxy-venv/bin/mitmweb /usr/local/bin/mitmweb



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

# Install GNU binary utilities. Do not alias objdump as otool: their command-line
# interfaces and Mach-O support are not equivalent.
RUN apt-get update && \
    apt-get install -y --no-install-recommends binutils && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

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


# Automatic BuildKit args are declared late so earlier install layers stay
# cacheable when only smoke-test behavior changes.
ARG BUILDPLATFORM
ARG TARGETPLATFORM

# Fail the image build if an advertised command is missing. Tools that need a
# device or a target are only checked for a valid entry point here.
RUN set -eux; \
    for command in \
      dependency-check nuclei r2 hbc-decompiler hbc-disassembler \
      hermes-dec hermes-dis jadx apktool \
      adb fastboot apksigner aapt uber-apk-signer apkx fridump \
      frida-ios-dump busybox frida frida-ps objection apkid semgrep \
      apkleaks blint reflutter jnitrace mitmproxy jdb nm objdump \
      iproxy ideviceinstaller lldb; \
    do \
      command -v "$command" >/dev/null; \
    done; \
    if [ "$TARGETARCH" = "amd64" ]; then command -v aapt2 >/dev/null; fi; \
    if [ "$BUILDPLATFORM" = "$TARGETPLATFORM" ]; then \
      python -c 'import angr, frida; from angr.state_plugins import unicorn_engine; assert unicorn_engine.unicorn is not None'; \
      frida --version; \
    else \
      python -c 'from importlib.metadata import version; assert version("angr") == "9.3.4"; assert version("frida") == "17.18.0"; assert version("unicorn") == "2.1.4"'; \
    fi; \
    nuclei -version; \
    jadx --version; \
    apktool --version; \
    mitmproxy --version; \
    r2 -v; \
    adb version; \
    jdb -version

# Match the workspace mounted by the documented docker run command.
WORKDIR /workspace

# Default command
CMD ["/bin/zsh"]
