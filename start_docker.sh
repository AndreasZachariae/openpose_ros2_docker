#!/bin/sh
uid=$(eval "id -u")
gid=$(eval "id -g")
docker build --build-arg UID="$uid" --build-arg GID="$gid" -t andreaszachariae/openpose_ros2:dashing .

echo "Run Container"
xhost + local:root
docker run --gpus all --name openpose -it --privileged --net host -e DISPLAY=$DISPLAY --rm andreaszachariae/openpose_ros2:dashing
