"""Infrastructure management tools — boto3/kubernetes for EKS and AWS resources.

Natural-language management of EKS clusters, nodes, pods, and AWS infrastructure.
"""
import json
from datetime import datetime, timedelta, timezone

import boto3
from strands import tool

from common.config import get_settings
from common.k8s_client import get_k8s_client

CLUSTER_REGIONS = {
    "seoul": "ap-northeast-2",
    "ap-northeast-2": "ap-northeast-2",
    "use1": "us-east-1",
    "us-east-1": "us-east-1",
    "use2": "us-east-2",
    "us-east-2": "us-east-2",
    "usw2": "us-west-2",
    "us-west-2": "us-west-2",
}


def _resolve_region(region: str) -> str:
    """Resolve region alias to full AWS region name."""
    return CLUSTER_REGIONS.get(region.lower(), region)


def _cluster_name(region: str) -> str:
    """Get cluster name for a region."""
    settings = get_settings()
    short = {
        "ap-northeast-2": "seoul",
        "us-east-1": "use1",
        "us-east-2": "use2",
        "us-west-2": "usw2",
    }
    return f"{settings.cluster_prefix}-{short.get(region, region)}"


@tool
def list_clusters() -> str:
    """List all GPU Spot Lotto EKS clusters across all regions with status, version, and mode.

    Returns:
        JSON array of cluster summaries for Seoul, us-east-1, us-east-2, us-west-2.
    """
    results = []
    for region in ["ap-northeast-2", "us-east-1", "us-east-2", "us-west-2"]:
        try:
            eks = boto3.client("eks", region_name=region)
            name = _cluster_name(region)
            cluster = eks.describe_cluster(name=name)["cluster"]
            compute = cluster.get("computeConfig", {})
            results.append({
                "name": name,
                "region": region,
                "version": cluster["version"],
                "status": cluster["status"],
                "auto_mode": compute.get("enabled", False),
                "node_pools": compute.get("nodePools", []),
                "endpoint": cluster["endpoint"][:50] + "...",
            })
        except Exception as e:
            results.append({"region": region, "error": str(e)})
    return json.dumps(results, indent=2)


@tool
def list_nodes(region: str) -> str:
    """List all nodes in an EKS cluster with status, instance type, and zone.

    Args:
        region: AWS region or alias (e.g. "seoul", "us-east-1", "use1").

    Returns:
        JSON array of node summaries with name, status, instance type, zone, and capacity.
    """
    region = _resolve_region(region)
    try:
        k8s = get_k8s_client(region)
        nodes = k8s.list_node()
        results = []
        for node in nodes.items:
            labels = node.metadata.labels or {}
            conditions = {c.type: c.status for c in (node.status.conditions or [])}
            results.append({
                "name": node.metadata.name,
                "ready": conditions.get("Ready", "Unknown"),
                "instance_type": labels.get("node.kubernetes.io/instance-type", "unknown"),
                "zone": labels.get("topology.kubernetes.io/zone", "unknown"),
                "capacity_type": labels.get(
                    "karpenter.sh/capacity-type",
                    labels.get("eks.amazonaws.com/capacityType", "unknown"),
                ),
                "cpu": str(node.status.capacity.get("cpu", "?")),
                "memory": str(node.status.capacity.get("memory", "?")),
                "gpu": str(node.status.capacity.get("nvidia.com/gpu", "0")),
            })
        return json.dumps(results, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e), "region": region})


@tool
def list_pods(region: str, namespace: str = "gpu-lotto") -> str:
    """List pods in an EKS cluster namespace with status, node, and restarts.

    Args:
        region: AWS region or alias (e.g. "seoul", "us-east-1").
        namespace: Kubernetes namespace (default: "gpu-lotto").

    Returns:
        JSON array of pod summaries with name, status, node, restarts, and age.
    """
    region = _resolve_region(region)
    try:
        k8s = get_k8s_client(region)
        pods = k8s.list_namespaced_pod(namespace=namespace)
        results = []
        for pod in pods.items:
            containers = pod.status.container_statuses or []
            restarts = sum(c.restart_count for c in containers)
            age = ""
            if pod.metadata.creation_timestamp:
                delta = datetime.now(timezone.utc) - pod.metadata.creation_timestamp
                age = f"{delta.days}d{delta.seconds // 3600}h"
            results.append({
                "name": pod.metadata.name,
                "status": pod.status.phase,
                "node": pod.spec.node_name or "Pending",
                "restarts": restarts,
                "age": age,
                "ip": pod.status.pod_ip or "N/A",
            })
        return json.dumps(results, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e), "region": region, "namespace": namespace})


@tool
def describe_nodepool(region: str) -> str:
    """Get Karpenter NodePool status and configuration for an EKS cluster.

    Args:
        region: AWS region or alias (e.g. "seoul", "us-east-1").

    Returns:
        JSON with NodePool details including instance types, capacity limits, and disruption policy.
    """
    region = _resolve_region(region)
    try:
        k8s = get_k8s_client(region)
        # List NodePool CRDs
        api = k8s.ApiClient()
        from kubernetes.client import CustomObjectsApi
        custom = CustomObjectsApi(api)
        pools = custom.list_cluster_custom_object(
            group="karpenter.sh", version="v1", plural="nodepools"
        )
        results = []
        for pool in pools.get("items", []):
            spec = pool.get("spec", {})
            tmpl = spec.get("template", {}).get("spec", {})
            reqs = tmpl.get("requirements", [])
            results.append({
                "name": pool["metadata"]["name"],
                "requirements": reqs,
                "limits": spec.get("limits", {}),
                "disruption": spec.get("disruption", {}),
            })
        return json.dumps(results, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e), "region": region})


@tool
def get_helm_status() -> str:
    """Get Helm release status for gpu-lotto chart in Seoul cluster.

    Returns:
        JSON with release name, status, chart version, and app version.
    """
    try:
        import subprocess
        result = subprocess.run(
            ["helm", "list", "-n", "gpu-lotto", "-o", "json"],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode == 0:
            return result.stdout
        return json.dumps({"error": result.stderr})
    except Exception as e:
        return json.dumps({"error": str(e)})


@tool
def describe_redis() -> str:
    """Get ElastiCache Redis cluster status, endpoint, and configuration.

    Returns:
        JSON with Redis cluster details including status, engine version, node type, and endpoint.
    """
    try:
        ec = boto3.client("elasticache", region_name="ap-northeast-2")
        groups = ec.describe_replication_groups()
        results = []
        for rg in groups["ReplicationGroups"]:
            endpoint = rg.get("NodeGroups", [{}])[0].get("PrimaryEndpoint", {})
            results.append({
                "id": rg["ReplicationGroupId"],
                "status": rg["Status"],
                "description": rg.get("Description", ""),
                "engine": "redis",
                "endpoint": endpoint.get("Address", "N/A"),
                "port": endpoint.get("Port", 6379),
                "encryption_transit": rg.get("TransitEncryptionEnabled", False),
                "encryption_at_rest": rg.get("AtRestEncryptionEnabled", False),
            })
        return json.dumps(results, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e)})


@tool
def get_cost_summary(days: int = 7) -> str:
    """Get AWS cost summary for recent days grouped by service.

    Args:
        days: Number of days to look back (default: 7).

    Returns:
        JSON with cost breakdown by AWS service for the specified period.
    """
    try:
        ce = boto3.client("ce", region_name="us-east-1")
        end = datetime.now(timezone.utc).date()
        start = end - timedelta(days=days)
        result = ce.get_cost_and_usage(
            TimePeriod={"Start": str(start), "End": str(end)},
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
            GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
        )
        services = {}
        for day in result["ResultsByTime"]:
            for group in day["Groups"]:
                svc = group["Keys"][0]
                amt = float(group["Metrics"]["UnblendedCost"]["Amount"])
                services[svc] = services.get(svc, 0) + amt
        summary = sorted(
            [{"service": k, "cost_usd": round(v, 2)} for k, v in services.items()],
            key=lambda x: x["cost_usd"],
            reverse=True,
        )
        total = sum(s["cost_usd"] for s in summary)
        return json.dumps({"period_days": days, "total_usd": round(total, 2),
                           "by_service": summary[:15]}, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e)})
