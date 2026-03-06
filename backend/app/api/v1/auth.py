import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.services import oauth_service

logger = logging.getLogger(__name__)

router = APIRouter()

SUCCESS_HTML = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Music Digger - Connected!</title>
    <style>
        body {{ font-family: -apple-system, sans-serif; background: #1a1a2e; color: #fff;
               display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
        .card {{ text-align: center; padding: 48px; background: #16213e; border-radius: 16px; }}
        .check {{ font-size: 64px; margin-bottom: 16px; }}
        h1 {{ margin: 0 0 8px; font-size: 24px; }}
        p {{ color: #a0a0c0; margin: 0; }}
    </style>
</head>
<body>
    <div class="card">
        <div class="check">&#10004;</div>
        <h1>{platform} Connected!</h1>
        <p>You can close this window and return to the app.</p>
    </div>
</body>
</html>
"""

ERROR_HTML = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Music Digger - Error</title>
    <style>
        body {{ font-family: -apple-system, sans-serif; background: #1a1a2e; color: #fff;
               display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
        .card {{ text-align: center; padding: 48px; background: #16213e; border-radius: 16px; }}
        .icon {{ font-size: 64px; margin-bottom: 16px; }}
        h1 {{ margin: 0 0 8px; font-size: 24px; color: #e74c3c; }}
        p {{ color: #a0a0c0; margin: 0; }}
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">&#10060;</div>
        <h1>Connection Failed</h1>
        <p>{error}</p>
    </div>
</body>
</html>
"""


@router.get("/{platform}/connect")
async def connect_platform(
    platform: str,
    user_id: str = Query(..., description="User ID"),
):
    """Get OAuth authorization URL for a platform."""
    try:
        url = await oauth_service.get_authorize_url(platform, user_id)
        return {"authorize_url": url}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{platform}/callback", response_class=HTMLResponse)
async def oauth_callback(
    platform: str,
    code: str = Query(...),
    state: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    """Handle OAuth callback from provider."""
    try:
        result = await oauth_service.handle_callback(platform, code, state, db)
        return HTMLResponse(SUCCESS_HTML.format(platform=platform.capitalize()))
    except ValueError as e:
        logger.error("OAuth callback error for %s: %s", platform, e)
        return HTMLResponse(ERROR_HTML.format(error=str(e)), status_code=400)
    except Exception as e:
        logger.exception("OAuth callback unexpected error for %s", platform)
        return HTMLResponse(ERROR_HTML.format(error="An unexpected error occurred"), status_code=500)


@router.get("/connections")
async def list_connections(
    user_id: str = Query(..., description="User ID"),
    db: AsyncSession = Depends(get_db),
):
    """List all connected platforms for a user."""
    try:
        connections = await oauth_service.get_connections(user_id, db)
        # Also include unconnected platforms
        connected_platforms = {c["platform"] for c in connections}
        all_platforms = []
        for p in oauth_service.SUPPORTED_PLATFORMS:
            if p in connected_platforms:
                all_platforms.append(next(c for c in connections if c["platform"] == p))
            else:
                all_platforms.append({"platform": p, "connected": False, "display_name": None})
        return {"connections": all_platforms}
    except ValueError:
        return {"connections": [{"platform": p, "connected": False, "display_name": None} for p in oauth_service.SUPPORTED_PLATFORMS]}


@router.delete("/{platform}/disconnect")
async def disconnect_platform(
    platform: str,
    user_id: str = Query(..., description="User ID"),
    db: AsyncSession = Depends(get_db),
):
    """Disconnect a platform."""
    try:
        removed = await oauth_service.disconnect(user_id, platform, db)
        if not removed:
            raise HTTPException(status_code=404, detail="Connection not found")
        return {"message": f"{platform} disconnected"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
