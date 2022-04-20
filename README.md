# OpenPose with ROS2 Dashing wrapper
OpenPose Docker from https://hub.docker.com/r/cwaffles/openpose

Fixed to CUDA version 10.1 and cudnn7 on ubuntu 18.04

OpenPose https://github.com/CMU-Perceptual-Computing-Lab/openpose.git

Fixed to commit 254570d

## Requirements:
Docker with nvidia gpu access
https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

## How to start:

Use this script to run the docker with GPU access and XServer display

```bash
#!/bin/sh
uid=$(eval "id -u")
gid=$(eval "id -g")
docker build --build-arg UID="$uid" --build-arg GID="$gid" -t andreaszachariae/openpose_ros2:dashing .

echo "Run Container"
xhost + local:root
docker run --gpus all --name openpose -it --privileged --net host -e DISPLAY=$DISPLAY --rm andreaszachariae/openpose_ros2:dashing
```

## Testing:
```bash
./build/examples/openpose/openpose.bin --video examples/media/video.avi
```