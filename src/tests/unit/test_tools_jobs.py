"""Tests for agent.tools_jobs — httpx-based job management tools."""
import json
from unittest.mock import MagicMock, patch


def _mock_settings():
    from common.config import Settings
    return Settings(redis_url="redis://localhost", api_server_url="http://test-api:8000")


def _mock_response(text: str, status_code: int = 200) -> MagicMock:
    resp = MagicMock()
    resp.text = text
    resp.status_code = status_code
    return resp


class TestGetPrices:
    def test_no_filters(self):
        with (
            patch("agent.tools_jobs.get_settings", return_value=_mock_settings()),
            patch("agent.tools_jobs.httpx.get", return_value=_mock_response('[{"price":0.22}]'))
            as mock_get,
        ):
            from agent.tools_jobs import get_prices
            result = get_prices(instance_type="", region="")

        mock_get.assert_called_once_with(
            "http://test-api:8000/api/prices", params={}, timeout=10.0
        )
        assert "0.22" in result

    def test_with_filters(self):
        with (
            patch("agent.tools_jobs.get_settings", return_value=_mock_settings()),
            patch("agent.tools_jobs.httpx.get", return_value=_mock_response("[]")) as mock_get,
        ):
            from agent.tools_jobs import get_prices
            get_prices(instance_type="g6.xlarge", region="us-east-1")

        mock_get.assert_called_once_with(
            "http://test-api:8000/api/prices",
            params={"instance_type": "g6.xlarge", "region": "us-east-1"},
            timeout=10.0,
        )


class TestSubmitJob:
    def test_default_params(self):
        resp_body = json.dumps({"status": "queued", "job_id": "abc-123"})
        with (
            patch("agent.tools_jobs.get_settings", return_value=_mock_settings()),
            patch("agent.tools_jobs.httpx.post", return_value=_mock_response(resp_body))
            as mock_post,
        ):
            from agent.tools_jobs import submit_job
            result = submit_job()

        call_kwargs = mock_post.call_args
        payload = call_kwargs[1]["json"]
        assert payload["instance_type"] == "g6.xlarge"
        assert payload["image"] == "nvidia/cuda:12.0-base"
        assert payload["gpu_count"] == 1
        assert payload["checkpoint_enabled"] is False
        assert "queued" in result

    def test_custom_params(self):
        with (
            patch("agent.tools_jobs.get_settings", return_value=_mock_settings()),
            patch("agent.tools_jobs.httpx.post", return_value=_mock_response('{"status":"ok"}'))
            as mock_post,
        ):
            from agent.tools_jobs import submit_job
            submit_job(
                instance_type="g5.12xlarge",
                image="my-train:v2",
                command="python train.py",
                gpu_count=4,
                checkpoint_enabled=True,
            )

        payload = mock_post.call_args[1]["json"]
        assert payload["instance_type"] == "g5.12xlarge"
        assert payload["image"] == "my-train:v2"
        assert payload["command"] == ["/bin/sh", "-c", "python train.py"]
        assert payload["gpu_count"] == 4
        assert payload["checkpoint_enabled"] is True


class TestGetJobStatus:
    def test_existing_job(self):
        resp = json.dumps({"job_id": "j-1", "status": "running", "region": "us-east-2"})
        with (
            patch("agent.tools_jobs.get_settings", return_value=_mock_settings()),
            patch("agent.tools_jobs.httpx.get", return_value=_mock_response(resp)) as mock_get,
        ):
            from agent.tools_jobs import get_job_status
            result = get_job_status(job_id="j-1")

        mock_get.assert_called_once_with(
            "http://test-api:8000/api/jobs/j-1", timeout=10.0
        )
        assert "running" in result


class TestCancelJob:
    def test_cancel(self):
        with (
            patch("agent.tools_jobs.get_settings", return_value=_mock_settings()),
            patch(
                "agent.tools_jobs.httpx.delete",
                return_value=_mock_response('{"status":"cancelled"}'),
            ) as mock_del,
        ):
            from agent.tools_jobs import cancel_job
            result = cancel_job(job_id="j-2")

        mock_del.assert_called_once_with(
            "http://test-api:8000/api/jobs/j-2", timeout=10.0
        )
        assert "cancelled" in result


class TestListJobs:
    def test_list(self):
        with (
            patch("agent.tools_jobs.get_settings", return_value=_mock_settings()),
            patch("agent.tools_jobs.httpx.get", return_value=_mock_response("[]")) as mock_get,
        ):
            from agent.tools_jobs import list_jobs
            result = list_jobs()

        mock_get.assert_called_once_with(
            "http://test-api:8000/api/admin/jobs", timeout=10.0
        )
        assert result == "[]"


class TestGetStats:
    def test_stats(self):
        resp = json.dumps({"active_jobs": 3, "queue_depth": 5})
        with (
            patch("agent.tools_jobs.get_settings", return_value=_mock_settings()),
            patch("agent.tools_jobs.httpx.get", return_value=_mock_response(resp)) as mock_get,
        ):
            from agent.tools_jobs import get_stats
            result = get_stats()

        mock_get.assert_called_once_with(
            "http://test-api:8000/api/admin/stats", timeout=10.0
        )
        data = json.loads(result)
        assert data["active_jobs"] == 3
