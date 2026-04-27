from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "sqlite:///./data/time2t3_api.db"
    jwt_secret: str = "dev-change-me-in-production"
    jwt_access_minutes: int = 30
    jwt_refresh_days: int = 7
    jwt_algorithm: str = "HS256"
    # Worker/cron: POST /v1/system/missed-intake-scan с заголовком X-Worker-Key
    worker_api_key: str = ""
    missed_intake_grace_minutes: int = 45
    # Rate limit привязки пациента (попыток в час на одного опекуна)
    caregiver_link_attempts_per_hour: int = 30
    # Лимит чтения кода привязки пациентом (GET invite-code в час)
    patient_invite_code_reads_per_hour: int = 60
    # SMTP для писем опекунам о пропусках (если smtp_host пуст — только in-app)
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from_email: str = ""
    smtp_use_tls: bool = True


settings = Settings()
