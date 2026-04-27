from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "sqlite:///./data/time2t3_api.db"
    jwt_secret: str = "dev-change-me-in-production"
    jwt_access_minutes: int = 30
    jwt_refresh_days: int = 7
    jwt_algorithm: str = "HS256"


settings = Settings()
