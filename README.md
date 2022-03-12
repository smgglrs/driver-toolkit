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

### Register to Red Hat

The first step is to create a Red Hat account at https://access.redhat.com.
Once connected, we're entitled to Red Hat Developer Subscription for
Individuals, which allows us to register up to 16 machines.

### Create an activation key

Instead of passing our credentials, we can use an activation key that
subscribes the system with Red Hat Subscription Manager and allows us to
install/update packages on the machine. To create the activation key, we open
https://access.redhat.com/management/activation_keys/new and fill the form:

* Name: `driver-toolkit-builder`
* Service Level: `Self Support`
* Auto Attach: `Enabled`
* Subcriptions: `Red Hat Developer Subscription for Individuals`

On the Activation Keys page, note the Organization ID, e.g. `12345678`.

Let's create two files to store the organization id and the activation key
name.

```
echo "12345678" > ${HOME}/.rhsm_org
echo "driver-toolkit-builder" > ${HOME}/.rhsm_activationkey
```

### Manual build of the container image

Below is an example for building a driver toolkit image for the version
`4.18.0-348.2.1.el8_5` of the kernel. We can see that we pass the Red Hat
organization id and the name of the activation key that we created above.

```shell
export RHEL_VERSION=8.4
export KERNEL_VERSION=4.18.0-305.40.1.el8_4
podman build \
    --secret id=RSHM_ORG,src=${HOME}/.rhsm_org \
    --secret id=RSHM_ACTIVATIONKEY,src=${HOME}/.rhsm_activationkey \
    --build-arg ARCH=x86_64 \
    --build-arg RHEL_VERSION=${RHEL_VERSION} \
    --build-arg KERNEL_VERSION=${KERNEL_VERSION}
    --tag quay.io/smgglrs/driver-toolkit:${KERNEL_VERSION} \
    --file Dockerfile .
```

The resulting container image is fairly big at 1.16 GB, due to all the
dependencies pulled during the build. When building driver containers, we
recommend using `driver-toolkit` as a builder image in a multi-stage build and
to copy only the required files to the final image, in order to save storage.

For that image to be usable for further builds, we simply push it to Quay.io.

```shell
podman login quay.io
podman push quay.io/smgglrs/driver-toolkit:${KERNEL_VERSION}
```

## Maintain a library of driver toolkit images

Now that we know how to build a single `driver-toolkit` container image for a
specific kernel version, having a pipeline to build and maintain a library of
images for a variety of kernel versions is sensible. Our library is available
at [quay.io/smgglrs/driver-toolkit](https://quay.io/smgglrs/driver-toolkit).

The first thing to do is to decide what versions of the kernel are relevant?
Because we target OpenShift and RHCOS, we can restrict the list of versions to
the versions shipped in RHCOS images. Since OpenShift 4.8, the RHCOS images
store some RPM versions as labels, among which the kernel RPM. So, we need to
get the labels of the image.

Fortunately, the CoreOS FAQ explains [How do I determine what version of an
RPM is included in an RHCOS release?](https://github.com/openshift/os/blob/master/docs/faq.md#q-how-do-i-determine-what-version-of-an-rpm-is-included-in-an-rhcos-release)
with an example. It happens in two steps: 1) identify the RHCOS image for a
given OpenShift release, 2) get the RHCOS image info. So, we can loop over the
z-stream releases of OpenShift and collect the kernel versions. This can be
done for both `x86_64` and `aarch64` architectures, since OpenShift provides
`aarch64` builds since version 4.9.0.

### Retrieve pull secret

To be able to read the RHCOS image info from any machine, we need to use a
pull secret since it is stored in a restricted repository in the Quay.io
registry, accessible to OpenShift cluster. That pull secret can be
downloaded from [Red Hat Console](https://console.redhat.com/openshift/create/local),
with the account created earlier, by clicking the _Download pull secret_
button. Let's store it in `${HOME}/.pull_secret`.

### Github Actions and build matrix

So, we said that we want to automate the build of driver-toolkit images. A good
option is to use Github Actions to define the pipeline and run it on a daily
schedule. One of the key features of Github Actions is the ability to use a
matrix to run the same job with different parameters, such as the kernel
version.

We have created a script that implements the logic defined earlier to decide
which kernel versions to target: [build-matrix.sh](build-matrix.sh). It will
get all the kernel versions for all z-stream releases since 4.8.0 and
deduplicate the list. For each kernel version, it creates an entry in an
array named `versions` with the RHEL version, the kernel version and the
architectures, which are the build arguments of the Dockerfile. The resulting
matrix is stored in a JSON file. Here is a minimal matrix example:

```json
{
    "versions": [
        {
	    "rhel": "8.4",
	    "kernel": "4.18.0-305.40.1.el8_4",
	    "archs": "linux/amd64,linux/arm64"
        }
    ]
}
```

***Note***: The `archs` are represented in the format expected by the Docker
`build` command. This allows us to perform multi-arch builds and simplify the
distribution of the images.

The script is used in an initialization job to build the matrix that is used
by the main job responsible for building the images. With the matrix strategy,
the jobs will run in parallel for each kernel version, saving time.

***Note***: To import the matrix, we use the `fromJson` function that can read
only a single line JSON string. So, the script doesn't write any new line in
its output. Don't be surprised when you run it locally.

In order to avoid building the same images every day, hence wasting compute
resources, the build job checks whether the target image tag exist in the
repository. It fetches the manifest of the image with `curl --fail`, so that
the return code is not zero when the manifest doesn't exist, in which case, the
next steps are performed.
