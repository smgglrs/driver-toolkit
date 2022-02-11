FROM registry.access.redhat.com/ubi8/ubi:8.5

USER root

ARG RHSM_ORG=''
ARG RHSM_ACTIVATIONKEY=''
ARG KERNEL_VERSION=''
ARG RT_KERNEL_VERSION=''

# Kernel packages needed to build drivers / kmod
RUN rm /etc/rhsm-host \
    && subscription-manager register \
        --name=driver-toolkit-builder \
	--org=${RHSM_ORG} --activationkey=${RHSM_ACTIVATIONKEY} \
    && subscription-manager repos \
        --enable rhel-8-for-x86_64-baseos-rpms \
	--enable rhel-8-for-x86_64-appstream-rpms \
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
        elfutils-libelf-devel kmod binutils kabi-dw kernel-abi-stablelists \
        xz diffutils git make install openssl keyutils $ARCH_DEP_PKGS \
    && dnf clean all \
    && subscription-manager unregister

LABEL io.k8s.description="driver-toolkit is a container with the kernel packages necessary for building driver containers for deploying kernel modules/drivers on OpenShift" \
      name="driver-toolkit" \
      io.openshift.release.operator=true \
      version="0.1"

# Last layer for metadata for mapping the driver-toolkit to a specific kernel version
RUN export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core); \
    export INSTALLED_RT_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-rt-core); \
    echo "{ \"KERNEL_VERSION\": \"${INSTALLED_KERNEL}\", \"RT_KERNEL_VERSION\": \"${INSTALLED_RT_KERNEL}\", \"RHEL_VERSION\": \"${RHEL_VERSION}\" }" > /etc/driver-toolkit-release.json ; \
    echo -e "KERNEL_VERSION=\"${INSTALLED_KERNEL}\"\nRT_KERNEL_VERSION="${INSTALLED_RT_KERNEL}\"\nRHEL_VERSION="${RHEL_VERSION}\"" > /etc/driver-toolkit-release.sh

USER 1001
