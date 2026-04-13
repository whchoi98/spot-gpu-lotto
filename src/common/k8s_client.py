"""Cross-cluster Kubernetes client manager using Pod Identity."""
import json
import subprocess
import time

from kubernetes import client

from common.config import get_settings
from common.logging import get_logger

log = get_logger("k8s_client")

# EKS tokens expire after ~15 min; refresh at 10 min to avoid edge failures
_TOKEN_TTL_SECONDS = 600

# Cache K8s API clients per region with creation timestamp
_clients: dict[str, client.CoreV1Api] = {}
_client_created_at: dict[str, float] = {}


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


_REGION_SHORT = {
    "us-east-1": "use1",
    "us-east-2": "use2",
    "us-west-2": "usw2",
    "ap-northeast-2": "seoul",
}


def _is_token_expired(region: str) -> bool:
    """Check if the cached client's token has exceeded the TTL."""
    created = _client_created_at.get(region)
    if created is None:
        return True
    return (time.monotonic() - created) > _TOKEN_TTL_SECONDS


def get_k8s_client(region: str) -> client.CoreV1Api:
    """Get a K8s API client for the given region's EKS cluster.

    Automatically refreshes the client when the EKS auth token approaches
    expiry (~10 min TTL, tokens last ~15 min).
    """
    settings = get_settings()

    if settings.k8s_mode == "dry-run":
        log.info("k8s_dry_run_mode", region=region)
        return _create_dry_run_client()

    if region not in _clients or _is_token_expired(region):
        if region in _clients:
            log.info("k8s_token_expired_refreshing", region=region)
        short = _REGION_SHORT.get(region)
        if short is None:
            raise ValueError(
                f"Unsupported region '{region}'. "
                f"Add it to _REGION_SHORT in k8s_client.py. "
                f"Known regions: {list(_REGION_SHORT.keys())}"
            )
        cluster_name = f"{settings.cluster_prefix}-{short}"
        endpoint, ca_data = _get_eks_endpoint(cluster_name, region)
        token = _get_eks_token(cluster_name, region)

        cfg = client.Configuration()
        cfg.host = endpoint
        cfg.api_key["authorization"] = token
        cfg.api_key_prefix["authorization"] = "Bearer"
        cfg.ssl_ca_cert = _write_ca_cert(ca_data, region)
        _clients[region] = client.CoreV1Api(client.ApiClient(cfg))
        _client_created_at[region] = time.monotonic()
        log.info("k8s_client_created", region=region, cluster=cluster_name)

    return _clients[region]


def invalidate_client(region: str) -> None:
    """Remove cached client (e.g., on auth error) so next call creates a fresh one."""
    _clients.pop(region, None)
    _client_created_at.pop(region, None)


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
