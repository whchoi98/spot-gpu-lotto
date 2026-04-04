"""Build GPU Pod specs for Kubernetes deployment."""
from kubernetes import client


def build_gpu_pod(job_id: str, job: dict) -> client.V1Pod:
    """Build a GPU Pod spec with storage mounts, checkpointing, and GPU scheduling.

    Args:
        job_id: Unique job identifier
        job: Dict with keys: image, command, gpu_type, gpu_count, storage_mode,
             checkpoint_enabled, instance_type, user_id
    """
    storage_mode = job.get("storage_mode", "s3")
    checkpoint_enabled = job.get("checkpoint_enabled", False)
    gpu_type = job.get("gpu_type", "l4")
    gpu_count = job.get("gpu_count", 1)

    # Volume mounts
    volume_mounts = [
        client.V1VolumeMount(name="models", mount_path="/data/models", read_only=True),
        client.V1VolumeMount(name="results", mount_path="/data/results"),
    ]

    # Env vars
    env_vars = [
        client.V1EnvVar(name="RESULT_DIR", value="/data/results"),
        client.V1EnvVar(name="CHECKPOINT_ENABLED", value=str(checkpoint_enabled).lower()),
    ]

    # Storage volumes
    if storage_mode == "fsx":
        volumes = [
            client.V1Volume(
                name="models",
                persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                    claim_name="fsx-lustre-models-pvc"
                ),
            ),
            client.V1Volume(
                name="results",
                persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                    claim_name="fsx-lustre-results-pvc"
                ),
            ),
        ]
    else:  # S3 Mountpoint
        volumes = [
            client.V1Volume(
                name="models",
                persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                    claim_name="s3-models-pvc"
                ),
            ),
            client.V1Volume(
                name="results",
                persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                    claim_name="s3-results-pvc"
                ),
            ),
        ]

    # Checkpoint volume (if enabled)
    if checkpoint_enabled:
        checkpoint_pvc = (
            "fsx-lustre-checkpoints-pvc" if storage_mode == "fsx" else "s3-checkpoints-pvc"
        )
        volumes.append(
            client.V1Volume(
                name="checkpoints",
                persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                    claim_name=checkpoint_pvc
                ),
            )
        )
        volume_mounts.append(
            client.V1VolumeMount(
                name="checkpoints",
                mount_path=f"/data/checkpoints/{job_id}",
            )
        )
        env_vars.append(
            client.V1EnvVar(name="CHECKPOINT_DIR", value=f"/data/checkpoints/{job_id}")
        )

    return client.V1Pod(
        metadata=client.V1ObjectMeta(
            name=f"gpu-job-{job_id[:8]}",
            labels={"app": "gpu-lotto", "job-id": job_id},
        ),
        spec=client.V1PodSpec(
            restart_policy="Never",
            tolerations=[
                client.V1Toleration(
                    key="nvidia.com/gpu", operator="Exists", effect="NoSchedule"
                )
            ],
            volumes=volumes,
            containers=[
                client.V1Container(
                    name="gpu-worker",
                    image=job.get("image", "nvidia/cuda:12.0-base"),
                    command=job.get("command", ["/bin/sh", "-c", "nvidia-smi && sleep 10"]),
                    resources=client.V1ResourceRequirements(
                        limits={"nvidia.com/gpu": str(gpu_count)}
                    ),
                    volume_mounts=volume_mounts,
                    env=env_vars,
                )
            ],
            node_selector={"karpenter.k8s.aws/instance-gpu-name": gpu_type},
        ),
    )
