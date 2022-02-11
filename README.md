# Driver Toolkit

The Driver Toolkit is a container image meant to be used as a base image on
which to build driver containers. The Driver Toolkit image contains the kernel
packages commonly required as dependencies to build or install kernel modules
as well as a few tools needed in driver containers. The version of these
packages will match the kernel version running on the RHCOS nodes in the
corresponding OpenShift release.

Driver containers are container images used for building and deploying
out-of-tree kernel modules and drivers on container OSs like Red Hat Enterprise
Linux CoreOS (RHCOS). Kernel modules and drivers are software libraries running
with a high level of privilege in the operating system kernel. They extend the
kernel functionalities or provide the hardware-specific code required to
control new devices. Examples include hardware devices like FPGAs or GPUs, and
software defined storage (SDS) solutions like Lustre parallel filesystem, which
all require kernel modules on client machines. Driver containers are the first
layer of the software stack used to enable these technologies on Kubernetes.

The list of kernel packages in the Driver Toolkit includes the following and
their dependencies:

* `kernel-core`
* `kernel-devel`
* `kernel-headers`
* `kernel-modules`
* `kernel-modules-extra`

In addition, the Driver Toolkit also includes the corresponding real-time
kernel packages:

* `kernel-rt-core`
* `kernel-rt-devel`
* `kernel-rt-modules`
* `kernel-rt-modules-extra`

The Driver Toolkit also has several tools which are commonly needed to build
and install kernel modules, including:

* `elfutils-libelf-devel`
* ` kmod`
* `binutils`
* `kabi-dw`
* `kernel-abi-stablelists`
* an the dependencies for the above

## Purpose

Prior to the Driver Toolkit's existence, you could install kernel packages in a
pod or build config on OpenShift using entitled builds or by installing from
the kernel RPMs in the hosts machine-os-content. The Driver Toolkit simplifies
the process by removing the entitlement step, and avoids the privileged
operation of accessing the machine-os-content in a pod. The Driver Toolkit can
also be used by partners who have access to pre-released OpenShift versions to
prebuild driver-containers for their hardware devices for future OpenShift
releases.

## How to build a driver toolkit image from Red Hat UBI 8

The first step is to create a Red Hat account at https://access.redhat.com.
Once connected, we're entitled to Red Hat Developer Subscription for
Individuals, which allows us to register up to 16 machines.

Then, we create an activation key at
https://access.redhat.com/management/activation_keys/new:

* Name: `driver-toolkit-builder`
* Service Level: `Self Support`
* Auto Attach: `Enabled`
* Subcriptions: `Red Hat Developer Subscription for Individuals`

On the Activation Keys page, note the Organization ID, e.g. `12345678`.

We can now build the container image.

Below is an example for building a driver toolkit image for the version
`4.18.0-348.2.1.el8_5` of the kernel. We can see that we pass out Red Hat
organization id and the name of the activation key that we created above.

```shell
podman build \
    --build-arg RHSM_ORG=12345678 \
    --build-arg RHSM_ACTIVATIONKEY=driver-toolkit-builder \
    --build-arg KERNEL_VERSION=4.18.0-348.2.1.el8_5 \
    --tag quay.io/fabiendupont/driver-toolkit-ubi8:4.18.0-348.2.1.el8_5 \
    --file Dockerfile .
```

The resulting container image is fairly big, due to all the dependencies pulled
during the build. When building driver containers, we recommend using DTK as
a builder image in a multi-stage build and to copy only the required files to
the final image, in order to save storage.
