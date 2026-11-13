from fastapi import FastAPI

from .routers import wallet

app = FastAPI(
    title="SALLAH Backend",
    description="Wallet, commission, and pricing microservices for the SALLAH platform.",
    version="0.1.0",
)

app.include_router(wallet.router)


@app.get("/health")
def health():
    return {"status": "ok"}