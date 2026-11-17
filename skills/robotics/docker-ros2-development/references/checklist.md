# Docker ROS2 Deployment Checklist

1. **Multi-stage build** -- Separate dev, build, and runtime stages so production images contain no compilers or build tools
1. **Non-root user** -- Create a dedicated `rosuser` with only the group memberships needed (video, dialout) instead of privileged mode
1. **DDS configuration** -- Ship a `cyclonedds.xml` or `fastdds.xml` with explicit peer lists if not using host networking
1. **Health checks** -- Every service has a health check that verifies the node is running and publishing on expected topics
1. **Resource limits** -- Set `mem_limit`, `cpus`, and GPU reservations for each service to prevent resource starvation
1. **Restart policy** -- Use `restart: unless-stopped` for all services and `restart: always` for critical drivers and watchdogs
1. **Log management** -- Configure Docker logging driver (json-file with max-size/max-file) to prevent disk exhaustion from ROS2 log output
1. **Environment injection** -- Use `.env` files or orchestrator secrets for `ROS_DOMAIN_ID`, DDS config paths, and device mappings rather than hardcoding
1. **Shared memory** -- Set `shm_size` to at least 256 MB (512 MB for image topics) and configure DDS shared memory transport for high-bandwidth topics
1. **Device stability** -- Use udev rules on the host to create stable `/dev/robot/*` symlinks and reference those in compose device mappings
1. **Image versioning** -- Tag images with both `latest` and a commit SHA or semantic version; never deploy unversioned `latest` to production
1. **Backup and rollback** -- Keep the previous image version available so a failed deployment can be rolled back by reverting the image tag
