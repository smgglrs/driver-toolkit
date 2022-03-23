#!/usr/bin/env bash

PULL_SECRET_FILE="${PULL_SECRET_FILE:-/pull-secret}"
echo "Getting pull secret from ${PULL_SECRET_FILE}"

MATRIX_FILE="build-matrix.json"
echo "Generating matrix in ${MATRIX_FILE}"

# Retrieve all the unique kernel versions
KVERS=()
for y in $(seq 8 10); do
    for z in $(seq 0 99); do
	for a in "x86_64"; do
            # Get the release image for the z-stream
	    echo -n "Get the release image for OCP 4.${y}.${z}-${a}."
            IMG=$(oc adm release info --image-for=machine-os-content quay.io/openshift-release-dev/ocp-release:4.${y}.${z}-${a} 2>/dev/null)

            # If the command failed and arch is x86_64, the z-stream doesn't exist and we can stop the loop.
	    # If the command failed and arch is not x86_64, we skip the image lookup.
            if [ $? != 0 ]; then
		echo " Not found."
		if [ "${a}" == "x86_64" ]; then
		    break 2
		else
		    continue
		fi
	    fi
	    echo " Found."

    	    # Get the image info in JSON format, so we can use jq on it
            IMG_INFO=$(oc image info -o json -a ${PULL_SECRET_FILE} ${IMG} 2>/dev/null)

	    # If the command failed, we skip the kernel lookup.
	    [ $? != 0 ] && echo "Image info for OCP 4.${y}.${z}-${a} not available" && continue

	    # Add the kernel version from the image labels to the list of kernels
	    KVER=( $(echo ${IMG_INFO} | jq -r ".config.config.Labels[\"com.coreos.rpm.kernel\"]") )
	    KVERS+=( ${KVER} )
	    echo "Kernel version for OCP 4.${y}.${z}-${a} is ${KVER}."
	done
    done
done

# Remove duplicates from the list of kernels and sort it
IFS=" " read -r -a KVERS <<< "$(tr ' ' '\n' <<< "${KVERS[@]}" | sort -u | tr '\n' ' ')"

# Generate a list of unique kernels without arch
IFS=" " read -r -a KVERS_NOARCH <<< "$(tr ' ' '\n' <<< "${KVERS[@]}" | sed "s/\..[^.]*$//" | sort -u | tr '\n' ' ')"

# Initialize the matrix file
echo -n "{ \"versions\": [" > ${MATRIX_FILE}

# Build the matrix from the list of kernel versions
LAST_KVER_NOARCH=""
COUNT=0
for KVER_NOARCH in ${KVERS_NOARCH[@]}; do
    # Extract RHEL version from the kernel version
    RHEL_VERSION=$(echo ${KVER_NOARCH} | rev | cut -d "." -f 1 | rev | sed -e "s/^el//" -e "s/_/./")

    # Retrieve UBI image digest for RHEL version
    UBI_DIGEST=$(oc image info -o json --filter-by-os "linux/amd64" registry.access.redhat.com/ubi8/ubi:${RHEL_VERSION} | jq .digest)

    # Initialize the arch with "x86_64" which is mandatory
    ARCH="linux/amd64"
    ARCH_TAG="x86_64"

    # Add a comma for all entries but the first one
    [ ${COUNT} -gt 0 ] && echo -n "," >> ${MATRIX_FILE}
    ((COUNT++))

    # Generate the matrix entry for the kernel
    echo -n " { \"rhel\": \"${RHEL_VERSION}\", \"ubi-digest\": ${UBI_DIGEST}, \"kernel\": \"${KVER_NOARCH}\", \"arch\": \"${ARCH}\", \"arch_tag\": \"${ARCH_TAG}\" }" >> ${MATRIX_FILE}
done

# Finalize the matrix file
echo -n " ] }" >> ${MATRIX_FILE}
