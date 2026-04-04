"""Cross-cluster Kubernetes client manager using Pod Identity."""
import json
import subprocess

from kubernetes import client

from common.config import get_settings
from common.logging import get_logger

log = get_logger("k8s_client")

# Cache K8s API clients per region
_clients: dict[str, client.CoreV1Api] = {}


def _get_eks_token(cluster_name: str, region: str) -> str:
    """Get a short-lived EKS auth token via Pod Identity."""
    result = subprocess.run(
        ["aws", "eks", "get-token", "--cluster-name", cluster_name, "--region", region],
        capture_output=True, text=True, check=True,
    )
    token_data = json.loads(result.stdout)
    return token_data["status"]["token"]


def _get_eks_endpoint(cluster_name: str, region: str) -> tuple[str, str]:
    """Get EKS cluster endpoint and CA data."""
    result = subprocess.run(
        ["aws", "eks", "describe-cluster", "--name", cluster_name, "--region", region,
         "--query", "cluster.{endpoint:endpoint,ca:certificateAuthority.data}"],
        capture_output=True, text=True, check=True,
    )
    data = json.loads(result.stdout)
    return data["endpoint"], data["ca"]


def get_k8s_client(region: str) -> client.CoreV1Api:
    """Get a K8s API client for the given region's EKS cluster."""
    settings = get_settings()

    if settings.k8s_mode == "dry-run":
        log.info("k8s_dry_run_mode", region=region)
        return _create_dry_run_client()

    if region not in _clients:
        cluster_name = f"gpu-lotto-{region}"
        endpoint, ca_data = _get_eks_endpoint(cluster_name, region)
        token = _get_eks_token(cluster_name, region)

        cfg = client.Configuration()
        cfg.host = endpoint
        cfg.api_key = {"BearerToken": token}
        cfg.ssl_ca_cert = _write_ca_cert(ca_data, region)
        _clients[region] = client.CoreV1Api(client.ApiClient(cfg))
        log.info("k8s_client_created", region=region, cluster=cluster_name)

    return _clients[region]


def invalidate_client(region: str) -> None:
    """Remove cached client (e.g., on auth error) so next call creates a fresh one."""
    _clients.pop(region, None)


def _write_ca_cert(ca_data: str, region: str) -> str:
    """Write base64-decoded CA cert to temp file, return path."""
    import base64
    import os
    import tempfile

    cert_bytes = base64.b64decode(ca_data)
    path = os.path.join(tempfile.gettempdir(), f"eks-ca-{region}.pem")
    with open(path, "wb") as f:
        f.write(cert_bytes)
    return path


def _create_dry_run_client() -> client.CoreV1Api:
    """Create a no-op client for local development."""
    cfg = client.Configuration()
    cfg.host = "https://dry-run.local"
    return client.CoreV1Api(client.ApiClient(cfg))
