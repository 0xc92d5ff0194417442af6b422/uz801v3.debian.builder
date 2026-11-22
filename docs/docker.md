# Docker build

The Docker image runs the same build as `sudo sh build.sh`. It installs the same host packages on every run.

## Build the image

Run this command from the repository root. The root is the build context, so the image gets the scripts and the `device/` and `lib/` folders:

```sh
sudo docker build -f docker/Dockerfile -t openstick-builder .
```

Do not run the build from the `docker/` folder. Docker then copies only the Dockerfile, and the image has no `build.sh`.

## Run the build

Mount the config file and the `work` folder. The build writes its state there, so a later run can continue from an earlier step:

```sh
sudo docker run --privileged -ti --rm \
  -v "$PWD/config.env:/build/config.env:ro" \
  -v "$PWD/work:/build/work" \
  -v "$PWD/device:/build/device:ro" \
  -v "$PWD/lib:/build/lib:ro" \
  openstick-builder
```

Add build switches after the image name. For example, this command builds only the kernel:

```sh
sudo docker run --privileged -ti --rm ... openstick-builder --only-kernel
```

## Mounts

| Mount | Why |
|---|---|
| `config.env` | Read-only. The image never writes it. |
| `work` | Everything the build writes. This includes the output images in `work/files`, the build log, the root filesystem in `work/rootfs`, its archive `work/rootfs.tgz`, the kernel source, the downloads and the caches. The next runs reuse them. |
| `device` and `lib` | Read-only. Mounting them lets you change the build files without a new image. |

## Loop devices

Step 90 mounts the root image as a loop device. The container needs access to loop devices. The `--privileged` option gives that access.

If step 90 fails with `failed to setup loop device`, check the host:

```sh
losetup -a
losetup -f
```

`losetup -a` lists the loop devices in use. `losetup -f` prints the next free device. If no device is free, detach an unused one with `sudo losetup -d /dev/loopN`.

## Image contents

The image uses `debian:trixie-slim` as its base. It holds the build scripts. Step 10 installs the build tools inside the container, including `debootstrap`, `qemu-user-static`, the cross compilers, `btrfs-progs` and `xfsprogs`.

Every run installs these tools first, even with `--from`. Step 10 runs before the steps you select.
