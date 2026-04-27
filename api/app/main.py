from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI

from app.config import settings
from app.database import Base, engine
from app.routers import auth, caregiver, health, patients, system


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.database_url.startswith("sqlite"):
        Path("data").mkdir(parents=True, exist_ok=True)
        Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Time2T3 API", version="1.0.0", lifespan=lifespan)

app.include_router(health.router)
app.include_router(auth.router, prefix="/v1")
app.include_router(patients.router, prefix="/v1")
app.include_router(caregiver.router, prefix="/v1")
app.include_router(system.router, prefix="/v1")
