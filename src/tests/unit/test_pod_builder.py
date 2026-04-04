import pytest
from dispatcher.pod_builder import build_gpu_pod


def test_basic_s3_pod():
    pod = build_gpu_pod("abc12345-6789", {"image": "my-ml:latest", "storage_mode": "s3"})
    assert pod.metadata.name == "gpu-job-abc12345"
    assert pod.metadata.labels["job-id"] == "abc12345-6789"
    spec = pod.spec
    assert spec.restart_policy == "Never"
    assert spec.node_selector["karpenter.k8s.aws/instance-gpu-name"] == "l4"
    # S3 PVCs
    vol_names = [v.name for v in spec.volumes]
    assert "models" in vol_names
    assert "results" in vol_names
    assert spec.volumes[0].persistent_volume_claim.claim_name == "s3-models-pvc"
    # GPU limits
    container = spec.containers[0]
    assert container.resources.limits["nvidia.com/gpu"] == "1"
    # No checkpoint volume
    assert "checkpoints" not in vol_names


def test_fsx_pod():
    pod = build_gpu_pod("fsx-test-1234", {"storage_mode": "fsx", "gpu_type": "l40s"})
    spec = pod.spec
    assert spec.volumes[0].persistent_volume_claim.claim_name == "fsx-lustre-models-pvc"
    assert spec.volumes[1].persistent_volume_claim.claim_name == "fsx-lustre-results-pvc"
    assert spec.node_selector["karpenter.k8s.aws/instance-gpu-name"] == "l40s"


def test_checkpoint_enabled():
    job_id = "ckpt-test-9999"
    pod = build_gpu_pod(job_id, {
        "storage_mode": "s3",
        "checkpoint_enabled": True,
    })
    spec = pod.spec
    vol_names = [v.name for v in spec.volumes]
    assert "checkpoints" in vol_names
    ckpt_vol = [v for v in spec.volumes if v.name == "checkpoints"][0]
    assert ckpt_vol.persistent_volume_claim.claim_name == "s3-checkpoints-pvc"
    # Volume mount
    mounts = {m.name: m for m in spec.containers[0].volume_mounts}
    assert f"/data/checkpoints/{job_id}" == mounts["checkpoints"].mount_path
    # Env vars
    envs = {e.name: e.value for e in spec.containers[0].env}
    assert envs["CHECKPOINT_DIR"] == f"/data/checkpoints/{job_id}"
    assert envs["CHECKPOINT_ENABLED"] == "true"
    assert envs["RESULT_DIR"] == "/data/results"


def test_checkpoint_disabled_env():
    pod = build_gpu_pod("no-ckpt-1234", {"checkpoint_enabled": False})
    envs = {e.name: e.value for e in pod.spec.containers[0].env}
    assert envs["CHECKPOINT_ENABLED"] == "false"
    assert "CHECKPOINT_DIR" not in envs


def test_multi_gpu():
    pod = build_gpu_pod("multi-gpu-1234", {
        "gpu_count": 4,
        "gpu_type": "a10g",
    })
    container = pod.spec.containers[0]
    assert container.resources.limits["nvidia.com/gpu"] == "4"
    assert pod.spec.node_selector["karpenter.k8s.aws/instance-gpu-name"] == "a10g"


def test_custom_command():
    pod = build_gpu_pod("cmd-test-1234", {
        "image": "train:v2",
        "command": ["python", "train.py", "--epochs", "10"],
    })
    container = pod.spec.containers[0]
    assert container.image == "train:v2"
    assert container.command == ["python", "train.py", "--epochs", "10"]


def test_toleration():
    pod = build_gpu_pod("tol-test-1234", {})
    tol = pod.spec.tolerations[0]
    assert tol.key == "nvidia.com/gpu"
    assert tol.operator == "Exists"
    assert tol.effect == "NoSchedule"
