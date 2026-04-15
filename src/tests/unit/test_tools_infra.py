"""Tests for agent.tools_infra — boto3/kubernetes infrastructure tools."""
import json
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch


def _mock_settings():
    from common.config import Settings
    return Settings(redis_url="redis://localhost", cluster_prefix="gpu-lotto-dev")


class TestResolveRegion:
    def test_alias_seoul(self):
        from agent.tools_infra import _resolve_region
        assert _resolve_region("seoul") == "ap-northeast-2"

    def test_alias_use1(self):
        from agent.tools_infra import _resolve_region
        assert _resolve_region("use1") == "us-east-1"

    def test_full_name_passthrough(self):
        from agent.tools_infra import _resolve_region
        assert _resolve_region("us-west-2") == "us-west-2"

    def test_unknown_passthrough(self):
        from agent.tools_infra import _resolve_region
        assert _resolve_region("eu-west-1") == "eu-west-1"


class TestClusterName:
    def test_seoul(self):
        with patch("agent.tools_infra.get_settings", return_value=_mock_settings()):
            from agent.tools_infra import _cluster_name
            assert _cluster_name("ap-northeast-2") == "gpu-lotto-dev-seoul"

    def test_use1(self):
        with patch("agent.tools_infra.get_settings", return_value=_mock_settings()):
            from agent.tools_infra import _cluster_name
            assert _cluster_name("us-east-1") == "gpu-lotto-dev-use1"


class TestListClusters:
    def test_success(self):
        mock_eks = MagicMock()
        mock_eks.describe_cluster.return_value = {
            "cluster": {
                "version": "1.32",
                "status": "ACTIVE",
                "computeConfig": {"enabled": True, "nodePools": ["system", "general"]},
                "endpoint": "https://ABCDEF1234567890.gr7.ap-northeast-2.eks.amazonaws.com",
            }
        }
        with (
            patch("agent.tools_infra.get_settings", return_value=_mock_settings()),
            patch("agent.tools_infra.boto3.client", return_value=mock_eks),
        ):
            from agent.tools_infra import list_clusters
            result = json.loads(list_clusters())

        assert len(result) == 4
        assert result[0]["status"] == "ACTIVE"
        assert result[0]["auto_mode"] is True

    def test_cluster_error(self):
        mock_eks = MagicMock()
        mock_eks.describe_cluster.side_effect = Exception("Cluster not found")
        with (
            patch("agent.tools_infra.get_settings", return_value=_mock_settings()),
            patch("agent.tools_infra.boto3.client", return_value=mock_eks),
        ):
            from agent.tools_infra import list_clusters
            result = json.loads(list_clusters())

        assert all("error" in item for item in result)


class TestListNodes:
    def test_success(self):
        mock_node = MagicMock()
        mock_node.metadata.name = "ip-10-0-1-100.ec2.internal"
        mock_node.metadata.labels = {
            "node.kubernetes.io/instance-type": "g6.xlarge",
            "topology.kubernetes.io/zone": "us-east-1a",
            "karpenter.sh/capacity-type": "spot",
        }
        cond = MagicMock()
        cond.type = "Ready"
        cond.status = "True"
        mock_node.status.conditions = [cond]
        mock_node.status.capacity = {"cpu": "4", "memory": "16Gi", "nvidia.com/gpu": "1"}

        mock_k8s = MagicMock()
        mock_k8s.list_node.return_value.items = [mock_node]

        with (
            patch("agent.tools_infra.get_settings", return_value=_mock_settings()),
            patch("agent.tools_infra.get_k8s_client", return_value=mock_k8s),
        ):
            from agent.tools_infra import list_nodes
            result = json.loads(list_nodes(region="us-east-1"))

        assert len(result) == 1
        assert result[0]["instance_type"] == "g6.xlarge"
        assert result[0]["gpu"] == "1"
        assert result[0]["capacity_type"] == "spot"

    def test_error_returns_json(self):
        with (
            patch("agent.tools_infra.get_settings", return_value=_mock_settings()),
            patch("agent.tools_infra.get_k8s_client", side_effect=Exception("Connection refused")),
        ):
            from agent.tools_infra import list_nodes
            result = json.loads(list_nodes(region="us-east-1"))

        assert "error" in result


class TestListPods:
    def test_success(self):
        mock_pod = MagicMock()
        mock_pod.metadata.name = "gpu-lotto-api-server-abc123"
        mock_pod.metadata.creation_timestamp = datetime(2025, 4, 10, tzinfo=timezone.utc)
        mock_pod.status.phase = "Running"
        mock_pod.spec.node_name = "ip-10-0-1-100"
        mock_pod.status.pod_ip = "10.0.1.50"
        container_status = MagicMock()
        container_status.restart_count = 0
        mock_pod.status.container_statuses = [container_status]

        mock_k8s = MagicMock()
        mock_k8s.list_namespaced_pod.return_value.items = [mock_pod]

        with (
            patch("agent.tools_infra.get_settings", return_value=_mock_settings()),
            patch("agent.tools_infra.get_k8s_client", return_value=mock_k8s),
        ):
            from agent.tools_infra import list_pods
            result = json.loads(list_pods(region="seoul"))

        assert len(result) == 1
        assert result[0]["status"] == "Running"
        assert result[0]["restarts"] == 0


class TestGetHelmStatus:
    def test_success(self):
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = '[{"name":"gpu-lotto","status":"deployed"}]'
        with patch("subprocess.run", return_value=mock_result):
            from agent.tools_infra import get_helm_status
            result = json.loads(get_helm_status())

        assert result[0]["status"] == "deployed"

    def test_failure(self):
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stderr = "Error: could not find tiller"
        with patch("subprocess.run", return_value=mock_result):
            from agent.tools_infra import get_helm_status
            result = json.loads(get_helm_status())

        assert "error" in result


class TestDescribeRedis:
    def test_success(self):
        mock_ec = MagicMock()
        mock_ec.describe_replication_groups.return_value = {
            "ReplicationGroups": [{
                "ReplicationGroupId": "gpu-lotto-dev",
                "Status": "available",
                "Description": "GPU Lotto Redis",
                "NodeGroups": [{"PrimaryEndpoint": {
                    "Address": "master.gpu-lotto.cache.amazonaws.com",
                    "Port": 6379,
                }}],
                "TransitEncryptionEnabled": True,
                "AtRestEncryptionEnabled": True,
            }]
        }
        with patch("agent.tools_infra.boto3.client", return_value=mock_ec):
            from agent.tools_infra import describe_redis
            result = json.loads(describe_redis())

        assert len(result) == 1
        assert result[0]["status"] == "available"
        assert result[0]["encryption_transit"] is True


class TestGetCostSummary:
    def test_success(self):
        mock_ce = MagicMock()
        mock_ce.get_cost_and_usage.return_value = {
            "ResultsByTime": [{
                "Groups": [
                    {"Keys": ["Amazon Elastic Compute Cloud"], "Metrics": {
                        "UnblendedCost": {"Amount": "42.50"}}},
                    {"Keys": ["Amazon ElastiCache"], "Metrics": {
                        "UnblendedCost": {"Amount": "8.20"}}},
                ]
            }]
        }
        with patch("agent.tools_infra.boto3.client", return_value=mock_ce):
            from agent.tools_infra import get_cost_summary
            result = json.loads(get_cost_summary(days=7))

        assert result["total_usd"] == 50.70
        assert result["by_service"][0]["service"] == "Amazon Elastic Compute Cloud"

    def test_error(self):
        with patch("agent.tools_infra.boto3.client", side_effect=Exception("Access Denied")):
            from agent.tools_infra import get_cost_summary
            result = json.loads(get_cost_summary(days=7))

        assert "error" in result
