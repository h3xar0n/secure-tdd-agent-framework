"""Approved security helper functions and validation routines."""

import os
from urllib.parse import urlparse
from typing import Set, Optional


def resolve_safe_path(base_dir: str, user_path: str) -> str:
    """Canonicalize and verify that a user-supplied path stays strictly within base_dir.
    
    Raises:
        ValueError: If user_path attempts directory traversal or escapes base_dir.
    """
    if not user_path or not isinstance(user_path, str):
        raise ValueError("Invalid filename or path")
    
    # Strip dangerous characters and resolve canonical paths
    clean_name = os.path.basename(user_path) if not user_path.startswith("/") else user_path
    canonical_base = os.path.realpath(base_dir)
    target_path = os.path.realpath(os.path.join(canonical_base, user_path.lstrip("/")))
    
    # Strict prefix check with directory separator to prevent partial prefix match
    expected_prefix = canonical_base if canonical_base.endswith(os.sep) else canonical_base + os.sep
    if not target_path.startswith(expected_prefix) and target_path != canonical_base:
        raise ValueError(f"Path traversal detected: {user_path} escapes {base_dir}")
        
    return target_path


def safe_redirect(url: str, allowed_hosts: Optional[Set[str]] = None) -> str:
    """Validate that a redirect target URL is safe and points to an allowed host or relative path.
    
    Raises:
        ValueError: If url is an external or untrusted redirect target.
    """
    if not url or not isinstance(url, str):
        raise ValueError("Invalid redirect URL")
        
    parsed = urlparse(url)
    
    # Relative path is safe if it starts with / and not // (protocol relative)
    if not parsed.netloc:
        if url.startswith("/") and not url.startswith("//"):
            return url
        raise ValueError(f"Invalid relative redirect: {url}")
        
    # If absolute, netloc must be in allowed_hosts
    if allowed_hosts and parsed.netloc in allowed_hosts:
        return url
        
    raise ValueError(f"Untrusted redirect host: {parsed.netloc}")


def validate_username(username: str) -> str:
    """Validate username against strict alphanumeric allow-list.
    
    Raises:
        ValueError: If username contains invalid characters or illegal length.
    """
    if not username or not isinstance(username, str):
        raise ValueError("Username cannot be empty")
        
    username = username.strip()
    if not (3 <= len(username) <= 32):
        raise ValueError("Username must be between 3 and 32 characters")
        
    if not username.isalnum():
        raise ValueError("Username must be alphanumeric")
        
    return username
