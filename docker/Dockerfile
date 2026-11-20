# Image that runs the OpenStick build. The output files appear in ./work/files on the host.
#
# Build the image from the repository root (the build context):
#   docker build -f docker/Dockerfile -t openstick-builder .
#
# Arguments after the image name go to build.sh, for example:
#
#   docker run --privileged --rm \
#     -v "$PWD/config.env:/build/config.env:ro" \
#     -v "$PWD/work/files:/build/work/files" \
#     openstick-builder --only-kernel
#
#   docker run --privileged --rm \
#     -v "$PWD/my.env:/build/my.env:ro" \
#     -v "$PWD/work/files:/build/work/files" \
#     openstick-builder --config /build/my.env
#
# Keep downloads and caches between runs, so each run does not fetch them again:
#   work/cache       kernel source, ccache, base rootfs tarball
#   work/downloads   Qualcomm firmware zip (step 40)
#   work/src         submodule checkouts (step 15)
# Add these to the docker run command:
#   -v "$PWD/work/cache:/build/work/cache" \
#   -v "$PWD/work/downloads:/build/work/downloads" \
#   -v "$PWD/work/src:/build/work/src"
#
# The build reads these from the image copy. To use edits made on the host
# without rebuilding the image, add these read-only mounts:
#   -v "$PWD/device:/build/device:ro" \
#   -v "$PWD/lib:/build/lib:ro"
#
# --privileged is needed for mount, chroot and binfmt. qemu-aarch64 must be
# registered on the host kernel first, for example:
#   docker run --privileged --rm tonistiigi/binfmt --install arm64

FROM debian:trixie-slim

# git is needed by step 15 (submodules) and e2fsprogs by step 90 (mkfs).
# The step 10 packages are installed here too, so each run only fetches updates.
# Step 10 still runs at build time.
COPY lib/steps/10-install-build-deps.sh /tmp/deps.sh
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates e2fsprogs git \
    && KERNEL_SOURCE=build sh /tmp/deps.sh \
    && rm -rf /var/lib/apt/lists/* /tmp/deps.sh

WORKDIR /build
COPY . /build

ENTRYPOINT ["sh", "build.sh"]
