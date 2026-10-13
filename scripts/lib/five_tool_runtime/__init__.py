"""Independent runtime primitives for the five-tool stack."""

from .runtime import (
    HOST_PROJECTIONS,
    MANIFEST_SCHEMA,
    TOOL_DEFINITIONS,
    canonical_manifest_path,
    ensure_manifest,
    global_toolstack_home,
    inspect_manifest,
    launch_argv,
    launch_spec,
    load_manifest,
    merged_environment,
    repair_manifest,
    validate_manifest,
)
from .projections import (
    mcp_server_entries,
    opencode_plugin_reference,
    pi_server_entries,
    project_host,
    validate_projection,
)

__all__ = [
    "HOST_PROJECTIONS",
    "MANIFEST_SCHEMA",
    "TOOL_DEFINITIONS",
    "canonical_manifest_path",
    "ensure_manifest",
    "global_toolstack_home",
    "inspect_manifest",
    "launch_spec",
    "launch_argv",
    "load_manifest",
    "merged_environment",
    "repair_manifest",
    "validate_manifest",
    "mcp_server_entries",
    "opencode_plugin_reference",
    "pi_server_entries",
    "project_host",
    "validate_projection",
]
