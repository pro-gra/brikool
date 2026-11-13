"""
BRIKOL — AI Backend (support chat + photo diagnosis), powered by Groq

INSTALL:
    pip install fastapi uvicorn requests python-multipart

RUN:
    $env:GROQ_API_KEY="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"
    python ai_backend.py
    (serves at http://localhost:8001)
"""

import base64
import json
import os
import time

import requests
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

API_KEY = os.environ.get("GROQ_API_KEY")
if not API_KEY:
    raise RuntimeError(
        "GROQ_API_KEY not set. "
        'Run: $env:GROQ_API_KEY="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"'
    )

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
TEXT_MODEL   = "llama-3.3-70b-versatile"
VISION_MODEL = "llama-3.2-90b-vision-preview"

HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

app = FastAPI(title="BRIKOL AI Backend (Groq)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ================================================================
# SYSTEM PROMPT — French only, with full terms & privacy knowledge
# ================================================================
SUPPORT_SYSTEM_PROMPT = """
Tu es l'assistant IA de Brikol.ma, une application marocaine de mise en relation
entre clients et techniciens qualifiés (plomberie, électricité, climatisation,
mécanique auto, électroménager, serrurerie, peinture, et plus).

RÈGLES ABSOLUES :
- Réponds TOUJOURS en français, même si l'utilisateur écrit en arabe ou en darija.
- Sois amical, concis et professionnel.
- Ne communique jamais de prix fixes (les prix sont négociés entre client et technicien).
- Ne donne jamais le statut d'une commande spécifique (tu n'as pas accès à la base de données).
- Pour toute urgence en cours, dis à l'utilisateur d'appuyer sur le bouton
  "🚨 Signaler une urgence" dans sa commande active.
- Pour toute question complexe ou non résolue, invite l'utilisateur à contacter
  le support humain : brikolcontact@gmail.com

COMMENT FONCTIONNE BRIKOL.MA :
1. Le client choisit un service et propose son budget.
2. Les techniciens proches voient la demande et font leurs offres.
3. Le client compare les offres et accepte celle qui lui convient.
4. Le technicien se déplace — la mission commence uniquement après validation
   par un code OTP unique fourni par le client.
5. Après la mission, le client évalue le technicien.

COMMISSION :
- Brikol prélève une commission de 10% sur chaque mission (9,5% pour les entreprises).
- Les 100 premiers techniciens inscrits bénéficient de 0% de commission.
- La commission est déduite du portefeuille du technicien au moment où il se met "En route".

PORTEFEUILLE TECHNICIEN :
- Chaque technicien doit maintenir un solde minimum de 50 MAD pour rester en ligne.
- En dessous de 10 MAD, le compte passe automatiquement hors ligne.
- Le rechargement se fait depuis l'onglet Portefeuille dans l'application.

CONDITIONS D'UTILISATION (résumé) :
- L'application est réservée aux résidents du Maroc.
- Les techniciens doivent être des professionnels qualifiés avec une expérience vérifiable.
- Aucun diplôme n'est requis, mais une expérience professionnelle est obligatoire.
- Les fausses informations entraînent la suspension immédiate du compte.
- Brikol se réserve le droit de suspendre tout compte en cas d'abus, fraude ou comportement inapproprié.
- Les litiges entre clients et techniciens doivent être signalés via le bouton "Signaler un problème".
- Brikol n'est pas responsable de la qualité des travaux effectués, mais intervient en cas de litige signalé.
- L'annulation d'une commande acceptée peut entraîner des pénalités selon les conditions en vigueur.
- Le code OTP est strictement confidentiel — ne le partagez jamais avant l'arrivée du technicien.

POLITIQUE DE CONFIDENTIALITÉ (résumé) :
- Brikol collecte : numéro de téléphone, nom complet, localisation, photo de profil.
- Pour les techniciens : photo CIN (carte d'identité nationale) pour vérification d'identité.
- Les données sont stockées de manière sécurisée via Firebase (Google Cloud).
- Brikol ne vend jamais les données personnelles à des tiers.
- La localisation est utilisée uniquement pour mettre en relation clients et techniciens proches.
- Les utilisateurs peuvent demander la suppression de leur compte en contactant : brikolcontact@gmail.com
- Les photos de problèmes partagées dans l'application sont visibles uniquement par
  le technicien assigné et l'équipe Brikol.

LANCEMENT :
- Brikol.ma est actuellement disponible à Rabat.
- Casablanca, Marrakech et Fès seront disponibles prochainement.

CONTACT SUPPORT :
- Email : brikolcontact@gmail.com
- Pour les urgences en cours : utiliser le bouton "🚨 Signaler une urgence" dans l'app.

Si tu ne sais pas répondre à une question, dis-le honnêtement et invite
l'utilisateur à contacter brikolcontact@gmail.com
"""


def call_groq(messages: list[dict], model: str) -> str:
    body = {"model": model, "messages": messages}
    last_error = None

    for attempt in range(3):
        try:
            response = requests.post(
                GROQ_URL, headers=HEADERS, json=body, timeout=30
            )
            break
        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
            last_error = e
            print(f"Tentative {attempt + 1}/3 échouée : {e}. Nouvelle tentative...")
            time.sleep(1.5 * (attempt + 1))
    else:
        raise RuntimeError(f"Erreur réseau après 3 tentatives : {last_error}")

    if response.status_code != 200:
        raise RuntimeError(f"Groq API {response.status_code} : {response.text}")

    data = response.json()
    try:
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as e:
        raise RuntimeError(f"Réponse Groq inattendue : {data}") from e


# ================================================================
# ENDPOINT 1 — Support Chat
# ================================================================
class SupportChatRequest(BaseModel):
    history: list[dict]  # [{"role": "user"|"assistant", "content": "..."}]
    message: str


class SupportChatResponse(BaseModel):
    reply: str


@app.post("/support-chat", response_model=SupportChatResponse)
def support_chat(payload: SupportChatRequest):
    messages = [{"role": "system", "content": SUPPORT_SYSTEM_PROMPT}]
    messages += [
        {"role": m["role"], "content": m["content"]}
        for m in payload.history
    ]
    messages.append({"role": "user", "content": payload.message})

    try:
        reply_text = call_groq(messages, model=TEXT_MODEL)
        return SupportChatResponse(reply=reply_text)
    except Exception as e:
        import traceback
        print("=" * 60)
        print("ERREUR dans /support-chat :")
        traceback.print_exc()
        print("=" * 60)
        raise HTTPException(
            status_code=500, detail=f"{type(e).__name__}: {e}"
        )


# ================================================================
# ENDPOINT 2 — Photo Diagnosis
# ================================================================
DIAGNOSIS_PROMPT = """
Tu regardes la photo d'un problème technique (voiture, maison ou appareil électroménager) au Maroc.

Réponds UNIQUEMENT avec du JSON valide exactement dans ce format, rien avant ni après,
sans balises markdown :
{
  "category": "nom de la catégorie en français (ex: Plomberie, Électricité, Climatisation, Mécanique auto, Électroménager)",
  "problem_summary": "description courte du problème en une phrase, en français",
  "estimated_price_min": nombre en MAD,
  "estimated_price_max": nombre en MAD,
  "urgency": "faible" ou "moyenne" ou "élevée",
  "confidence_note": "phrase courte indiquant que c'est une estimation approximative uniquement, le prix réel est fixé par le technicien"
}

Si tu ne peux pas identifier clairement le problème sur la photo, mets "Non identifié"
dans category et explique pourquoi dans problem_summary.
"""


class DiagnosisResponse(BaseModel):
    category: str
    problem_summary: str
    estimated_price_min: float
    estimated_price_max: float
    urgency: str
    confidence_note: str


@app.post("/diagnose-photo", response_model=DiagnosisResponse)
async def diagnose_photo(
    file: UploadFile = File(...),
    description: str = Form(""),
):
    image_bytes = await file.read()
    media_type = file.content_type or "image/jpeg"
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    prompt = DIAGNOSIS_PROMPT + (
        f"\n\nDescription du client : {description}" if description else ""
    )

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:{media_type};base64,{image_b64}"
                    },
                },
            ],
        }
    ]

    try:
        raw_text = call_groq(messages, model=VISION_MODEL)
        cleaned = (
            raw_text.strip().replace("```json", "").replace("```", "").strip()
        )
        data = json.loads(cleaned)
        return DiagnosisResponse(**data)
    except Exception as e:
        import traceback
        print("=" * 60)
        print("ERREUR dans /diagnose-photo :")
        traceback.print_exc()
        print("=" * 60)
        raise HTTPException(
            status_code=500, detail=f"{type(e).__name__}: {e}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)