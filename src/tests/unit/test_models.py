from common.models import JobRecord, JobRequest, JobStatus, PriceEntry, TemplateEntry


def test_job_request_defaults():
    req = JobRequest(user_id="user1", image="my-ml:latest")
    assert req.instance_type == "g6.xlarge"
    assert req.gpu_count == 1
    assert req.storage_mode == "s3"
    assert req.checkpoint_enabled is False
    assert req.command == ["/bin/sh", "-c", "nvidia-smi && sleep 60"]
    assert req.webhook_url is None


def test_job_request_full():
    req = JobRequest(
        user_id="user1",
        image="train:v2",
        instance_type="g6e.xlarge",
        gpu_count=1,
        gpu_type="l40s",
        storage_mode="fsx",
        checkpoint_enabled=True,
        command=["python", "train.py"],
        webhook_url="https://hooks.slack.com/xxx",
    )
    assert req.storage_mode == "fsx"
    assert req.checkpoint_enabled is True


def test_job_status_values():
    assert JobStatus.QUEUED == "queued"
    assert JobStatus.RUNNING == "running"
    assert JobStatus.SUCCEEDED == "succeeded"
    assert JobStatus.FAILED == "failed"
    assert JobStatus.CANCELLING == "cancelling"
    assert JobStatus.CANCELLED == "cancelled"


def test_job_record_to_redis():
    rec = JobRecord(
        job_id="abc-123",
        user_id="user1",
        region="us-east-2",
        status=JobStatus.RUNNING,
        pod_name="gpu-job-abc12345",
        instance_type="g6.xlarge",
        created_at=1700000000,
    )
    d = rec.to_redis()
    assert d["job_id"] == "abc-123"
    assert d["status"] == "running"
    assert d["created_at"] == "1700000000"


def test_job_record_from_redis():
    data = {
        "job_id": "abc-123",
        "user_id": "user1",
        "region": "us-east-2",
        "status": "running",
        "pod_name": "gpu-job-abc12345",
        "instance_type": "g6.xlarge",
        "created_at": "1700000000",
    }
    rec = JobRecord.from_redis(data)
    assert rec.job_id == "abc-123"
    assert rec.status == JobStatus.RUNNING
    assert rec.created_at == 1700000000


def test_price_entry():
    p = PriceEntry(region="us-east-2", instance_type="g6.xlarge", price=0.2261)
    assert p.redis_key == "us-east-2:g6.xlarge"


def test_template_entry():
    t = TemplateEntry(
        name="Quick Inference",
        image="my-model:latest",
        instance_type="g6.xlarge",
        gpu_count=1,
        storage_mode="s3",
        checkpoint_enabled=False,
        command=["python", "infer.py"],
    )
    j = t.model_dump_json()
    t2 = TemplateEntry.model_validate_json(j)
    assert t2.name == "Quick Inference"
