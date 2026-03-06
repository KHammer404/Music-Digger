from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    app_env: str = "development"
    app_debug: bool = True
    app_host: str = "0.0.0.0"
    app_port: int = 8000

    # Database
    database_url: str = "postgresql+asyncpg://musicdigger:musicdigger@localhost:5432/musicdigger"
    database_url_sync: str = "postgresql+psycopg2://musicdigger:musicdigger@localhost:5432/musicdigger"

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Celery
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/2"

    # API Keys
    spotify_client_id: str = ""
    spotify_client_secret: str = ""
    youtube_api_key: str = ""
    youtube_client_id: str = ""
    youtube_client_secret: str = ""
    lastfm_api_key: str = ""
    lastfm_api_secret: str = ""
    niconico_email: str = ""
    niconico_password: str = ""

    # Tidal OAuth
    tidal_client_id: str = ""
    tidal_client_secret: str = ""

    # OAuth
    oauth_redirect_base: str = "http://localhost:8000/api/v1/auth"
    fernet_key: str = ""  # generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
