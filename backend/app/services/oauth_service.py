import logging
import secrets
from datetime import datetime, timezone

from cryptography.fernet import Fernet
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.cache.redis_cache import cache_get, cache_set, cache_delete
from app.config import get_settings
from app.models.oauth import OAuthConnection

logger = logging.getLogger(__name__)
settings = get_settings()

SUPPORTED_PLATFORMS = ("spotify", "youtube", "tidal")


def _get_fernet() -> Fernet:
    key = settings.fernet_key
    if not key:
        raise ValueError("FERNET_KEY not configured. Generate one with: python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\"")
    return Fernet(key.encode())


def encrypt_token(token: str) -> str:
    return _get_fernet().encrypt(token.encode()).decode()


def decrypt_token(encrypted: str) -> str:
    return _get_fernet().decrypt(encrypted.encode()).decode()


async def get_authorize_url(platform: str, user_id: str) -> str:
    """Generate OAuth authorization URL and store state in cache."""
    from app.services.oauth_providers import get_provider

    if platform not in SUPPORTED_PLATFORMS:
        raise ValueError(f"Unsupported platform: {platform}")

    provider = get_provider(platform)
    state = secrets.token_urlsafe(32)

    # Store state → user_id mapping (10 min TTL)
    state_data = {"user_id": user_id, "platform": platform}
    # Provider may add extra data (e.g. PKCE code_verifier)
    extra = provider.generate_state_data()
    if extra:
        state_data.update(extra)

    await cache_set(f"oauth_state:{state}", state_data, ttl=600)

    return provider.get_authorize_url(state)


async def handle_callback(platform: str, code: str, state: str, db: AsyncSession) -> dict:
    """Exchange authorization code for tokens and save to DB."""
    from app.services.oauth_providers import get_provider

    # Retrieve and validate state
    state_data = await cache_get(f"oauth_state:{state}")
    if not state_data:
        raise ValueError("Invalid or expired OAuth state")

    if state_data.get("platform") != platform:
        raise ValueError("Platform mismatch in OAuth state")

    await cache_delete(f"oauth_state:{state}")

    provider = get_provider(platform)
    token_data = await provider.exchange_code(code, state_data)

    user_id = state_data["user_id"]

    # Get user profile from platform
    user_info = await provider.get_user_info(token_data["access_token"])

    # Encrypt tokens
    encrypted_access = encrypt_token(token_data["access_token"])
    encrypted_refresh = encrypt_token(token_data["refresh_token"]) if token_data.get("refresh_token") else None

    # Calculate expiry
    expires_at = None
    if token_data.get("expires_in"):
        expires_at = datetime.now(timezone.utc).replace(
            second=datetime.now(timezone.utc).second + token_data["expires_in"]
        )
        from datetime import timedelta
        expires_at = datetime.now(timezone.utc) + timedelta(seconds=token_data["expires_in"])

    # Upsert connection
    import uuid
    uid = uuid.UUID(user_id)

    existing = await db.execute(
        select(OAuthConnection).where(
            OAuthConnection.user_id == uid,
            OAuthConnection.platform == platform,
        )
    )
    conn = existing.scalar_one_or_none()

    if conn:
        conn.access_token = encrypted_access
        conn.refresh_token = encrypted_refresh
        conn.token_expires_at = expires_at
        conn.platform_user_id = user_info.get("id")
        conn.platform_display_name = user_info.get("display_name")
    else:
        conn = OAuthConnection(
            user_id=uid,
            platform=platform,
            access_token=encrypted_access,
            refresh_token=encrypted_refresh,
            token_expires_at=expires_at,
            platform_user_id=user_info.get("id"),
            platform_display_name=user_info.get("display_name"),
        )
        db.add(conn)

    await db.flush()

    return {
        "platform": platform,
        "display_name": user_info.get("display_name"),
        "connected": True,
    }


async def get_valid_token(user_id: str, platform: str, db: AsyncSession) -> str:
    """Get a valid access token, refreshing if expired."""
    import uuid
    from app.services.oauth_providers import get_provider

    uid = uuid.UUID(user_id)
    result = await db.execute(
        select(OAuthConnection).where(
            OAuthConnection.user_id == uid,
            OAuthConnection.platform == platform,
        )
    )
    conn = result.scalar_one_or_none()
    if not conn:
        raise ValueError(f"No {platform} connection for user {user_id}")

    access_token = decrypt_token(conn.access_token)

    # Check if token is expired
    if conn.token_expires_at and conn.token_expires_at < datetime.now(timezone.utc):
        if not conn.refresh_token:
            raise ValueError(f"{platform} token expired and no refresh token available")

        refresh_token = decrypt_token(conn.refresh_token)
        provider = get_provider(platform)
        token_data = await provider.refresh_access_token(refresh_token)

        access_token = token_data["access_token"]
        conn.access_token = encrypt_token(access_token)

        if token_data.get("refresh_token"):
            conn.refresh_token = encrypt_token(token_data["refresh_token"])

        if token_data.get("expires_in"):
            from datetime import timedelta
            conn.token_expires_at = datetime.now(timezone.utc) + timedelta(seconds=token_data["expires_in"])

        await db.flush()
        logger.info("Refreshed %s token for user %s", platform, user_id)

    return access_token


async def get_connections(user_id: str, db: AsyncSession) -> list[dict]:
    """Get all OAuth connections for a user."""
    import uuid
    uid = uuid.UUID(user_id)

    result = await db.execute(
        select(OAuthConnection).where(OAuthConnection.user_id == uid)
    )
    connections = result.scalars().all()

    return [
        {
            "platform": c.platform,
            "display_name": c.platform_display_name,
            "connected": True,
            "connected_at": c.created_at.isoformat() if c.created_at else None,
        }
        for c in connections
    ]


async def disconnect(user_id: str, platform: str, db: AsyncSession) -> bool:
    """Remove an OAuth connection."""
    import uuid
    uid = uuid.UUID(user_id)

    result = await db.execute(
        delete(OAuthConnection).where(
            OAuthConnection.user_id == uid,
            OAuthConnection.platform == platform,
        )
    )
    return result.rowcount > 0
