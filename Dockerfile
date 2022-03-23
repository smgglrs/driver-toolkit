ARG RHEL_VERSION=''
ARG BASE_DIGEST=''

FROM registry.access.redhat.com/ubi8/ubi@${BASE_DIGEST}

ARG RHEL_VERSION=''
ARG BASE_DIGEST=''
ARG KERNEL_VERSION=''
ARG RT_KERNEL_VERSION=''

USER root

COPY ./rhsm-register /usr/local/bin/rhsm-register

# Kernel packages needed to build drivers / kmod
RUN --mount=type=secret,id=RHSM_ORG \
    --mount=type=secret,id=RHSM_ACTIVATIONKEY \
    rm /etc/rhsm-host \
    && /usr/local/bin/rhsm-register \
    && subscription-manager repos \
        --enable rhel-8-for-$(arch)-baseos-rpms \
        --enable rhel-8-for-$(arch)-appstream-rpms \
        --enable=rhel-8-for-$(arch)-baseos-eus-rpms \
    && echo "${RHEL_VERSION}" > /etc/dnf/vars/releasever \
    && dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save \
    && dnf -y install \
        kernel-core${KERNEL_VERSION:+-}${KERNEL_VERSION} \
        kernel-devel${KERNEL_VERSION:+-}${KERNEL_VERSION} \
        kernel-headers${KERNEL_VERSION:+-}${KERNEL_VERSION} \
        kernel-modules${KERNEL_VERSION:+-}${KERNEL_VERSION} \
        kernel-modules-extra${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    && export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core) \
    && GCC_VERSION=$(cat /lib/modules/${INSTALLED_KERNEL}/config | grep -Eo "Compiler: gcc \(GCC\) ([0-9\.]+)" | grep -Eo "([0-9\.]+)") \
    && if [ $(arch) == "x86_64" ] || [ $(arch) == "aarch64" ]; then ARCH_DEP_PKGS="mokutil"; fi \
    && dnf -y install gcc-${GCC_VERSION} || dnf -y install gcc \
    && dnf -y install elfutils-libelf-devel kmod binutils kabi-dw kernel-abi-stablelists \
        xz diffutils git make openssl keyutils rpm-build pinentry jq ${ARCH_DEP_PKGS} \
    && dnf clean all \
    && subscription-manager unregister \
    && useradd -u 1001 -m -s /bin/bash builder

LABEL io.k8s.description="Driver Toolkit provides the packages required to build driver containers for a specific version of RHEL 8 kernel" \
      io.k8s.display-name="Driver Toolkit" \
      org.opencontainers.image.base.name="registry.access.redhat.com/ubi8/ubi:${RHEL_VERSION}" \
      org.opencontainers.image.base.digest="${BASE_DIGEST}" \
      org.opencontainers.image.source="https://github.com/smgglrs/driver-toolkit" \
      org.opencontainers.image.vendor="Smgglrs" \
      org.opencontainers.image.title="Driver Toolkit" \
      org.opencontainers.image.description="Driver Toolkit provides the packages required to build driver containers for a specific version of RHEL 8 kernel" \
      name="driver-toolkit" \
      vendor="Smgglrs" \
      version="${KERNEL_VERSION}"

# Last layer for metadata for mapping the driver-toolkit to a specific kernel version
RUN export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core); \
    export INSTALLED_RT_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-rt-core); \
    echo "{ \"KERNEL_VERSION\": \"${INSTALLED_KERNEL}\", \"RT_KERNEL_VERSION\": \"${INSTALLED_RT_KERNEL}\", \"RHEL_VERSION\": \"${RHEL_VERSION}\" }" > /etc/driver-toolkit-release.json ; \
    echo -e "KERNEL_VERSION=\"${INSTALLED_KERNEL}\"\nRT_KERNEL_VERSION=\"${INSTALLED_RT_KERNEL}\"\nRHEL_VERSION=\"${RHEL_VERSION}\"" > /etc/driver-toolkit-release.sh

USER builder
