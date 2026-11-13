/**
 * Brikol.ma — Cloud Functions (Node 24, europe-west1)
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');

initializeApp();
const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

setGlobalOptions({ region: 'europe-west1' });

// ── Stripe ────────────────────────────────────────────────────────────────────
const STRIPE_SECRET_KEY = 'sk_test_51U9fC73VTFFs2Qu4DlwGucgs2pp1SwQKC36tkzhb4TetCtY5um6p6OhfjV1ofr9bdvZ77H3N8YOsVBr7I53SmwAQ00brjCwqNT';
const STRIPE_WEBHOOK_SECRET = 'whsec_0lC6mSUvGLWdkNiUMMaR3gjmYS6fkfud';
const EUR_TO_MAD = 11;

// ── Helpers ───────────────────────────────────────────────────────────────────

async function sendToToken(token, title, body, data = {}) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  } catch (e) {
    console.warn(`send failed (${token.slice(-8)}): ${e.message}`);
  }
}

async function sendToTokens(tokens, title, body, data = {}) {
  const clean = [...new Set(tokens.filter(Boolean))];
  if (!clean.length) return;
  for (let i = 0; i < clean.length; i += 500) {
    const chunk = clean.slice(i, i + 500);
    try {
      const r = await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      console.log(`sent "${title}" ${r.successCount}/${chunk.length}`);
    } catch (e) {
      console.warn(`multicast failed: ${e.message}`);
    }
  }
}

async function getToken(collection, uid) {
  const doc = await db.collection(collection).doc(uid)
    .collection('private').doc('notifications').get();
  return doc.exists ? (doc.data()?.fcmToken || null) : null;
}

async function getAllAdminTokens() {
  const snap = await db.collection('admins').get();
  const tokens = await Promise.all(snap.docs.map(d => getToken('admins', d.id)));
  return tokens.filter(Boolean);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STRIPE: stripeCheckout — onRequest (Web compatible, CORS enabled)
// ═══════════════════════════════════════════════════════════════════════════════

exports.stripeCheckout = onRequest(
  { region: 'europe-west1', cors: true },
  async (req, res) => {
    try {
      // Auth check
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Unauthorized' });
      }
      const token = authHeader.split('Bearer ')[1];
      const decoded = await auth.verifyIdToken(token);
      const techId = decoded.uid;

      const { amountMAD, refCode } = req.body;
      if (!amountMAD || amountMAD < 50) {
        return res.status(400).json({ error: 'Montant minimum: 50 MAD.' });
      }

      const stripe = require('stripe')(STRIPE_SECRET_KEY);
      const amountEUR = Math.ceil((amountMAD / EUR_TO_MAD) * 100);

      const session = await stripe.checkout.sessions.create({
        payment_method_types: ['card'],
        line_items: [{
          price_data: {
            currency: 'eur',
            product_data: { name: `Recharge Brikol.ma — ${amountMAD} MAD` },
            unit_amount: amountEUR,
          },
          quantity: 1,
        }],
        mode: 'payment',
        success_url: 'https://brikool.online/?app=1&payment=success',
        cancel_url: 'https://brikool.online/?app=1&payment=cancelled',
        metadata: { techId, refCode: refCode || '', amountMAD: String(amountMAD) },
      });

      console.log(`Checkout session created: ${session.id} for tech ${techId} — ${amountMAD} MAD`);
      return res.json({ url: session.url });
    } catch (e) {
      console.error('stripeCheckout error:', e.message);
      return res.status(500).json({ error: e.message });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// STRIPE: stripeWebhook — يزيد الرصيد تلقائياً بعد نجاح الدفع
// ═══════════════════════════════════════════════════════════════════════════════

exports.stripeWebhook = onRequest(
  { region: 'europe-west1' },
  async (req, res) => {
    const stripe = require('stripe')(STRIPE_SECRET_KEY);
    const sig = req.headers['stripe-signature'];

    let event;
    try {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      console.error('Webhook signature error:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    if (event.type === 'checkout.session.completed') {
      const session = event.data.object;
      const techId = session.metadata.techId;
      const amountMAD = parseFloat(session.metadata.amountMAD || '0');
      const refCode = session.metadata.refCode || '';

      if (!techId || amountMAD <= 0) {
        console.error('Missing metadata:', session.metadata);
        return res.json({ received: true });
      }

      try {
        await db.collection('technicians').doc(techId).update({
          walletBalance: FieldValue.increment(amountMAD),
        });
        await db.collection('wallet_transactions').add({
          techId,
          amountMAD,
          note: `Recharge carte bancaire — ${amountMAD} MAD`,
          refCode,
          stripeSessionId: session.id,
          method: 'stripe',
          createdAt: FieldValue.serverTimestamp(),
        });
        const token = await getToken('technicians', techId);
        await sendToToken(token, '✅ Recharge réussie !',
          `${amountMAD} MAD ajoutés à votre portefeuille`,
          { type: 'wallet_recharged' });
        console.log(`✅ Wallet recharged: ${techId} +${amountMAD} MAD`);
      } catch (err) {
        console.error('Firestore update failed:', err.message);
        return res.status(500).send('Internal error');
      }
    }

    res.json({ received: true });
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// OTP BRUTE-FORCE PROTECTION
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_OTP_ATTEMPTS = 5;
const LOCK_DURATION_MS = 10 * 60 * 1000;

exports.verifyJobOtp = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Vous devez être connecté.');
    const uid = request.auth.uid;
    const { requestId, otp } = request.data;
    if (!requestId || !otp) throw new HttpsError('invalid-argument', 'requestId et otp sont requis.');

    const requestRef = db.collection('requests').doc(requestId);
    const requestDoc = await requestRef.get();
    if (!requestDoc.exists) throw new HttpsError('not-found', 'Commande introuvable.');

    const data = requestDoc.data();
    if (data.techId !== uid) throw new HttpsError('permission-denied', 'Seul le technicien assigné peut vérifier le code.');
    if (!['accepted', 'en_route'].includes(data.status)) throw new HttpsError('failed-precondition', `Statut invalide: ${data.status}`);

    const otpLockedUntil = data.otpLockedUntil;
    if (otpLockedUntil) {
      const lockedUntilMs = otpLockedUntil.toMillis();
      const now = Date.now();
      if (now < lockedUntilMs) {
        const remainingMinutes = Math.ceil((lockedUntilMs - now) / 60000);
        throw new HttpsError('resource-exhausted', `Code OTP bloqué. Réessayez dans ${remainingMinutes} minute(s).`);
      } else {
        await requestRef.update({ otpAttempts: 0, otpLockedUntil: FieldValue.delete() });
      }
    }

    const currentAttempts = data.otpAttempts || 0;
    if (String(otp).trim() !== String(data.otpCode).trim()) {
      const newAttempts = currentAttempts + 1;
      const remaining = MAX_OTP_ATTEMPTS - newAttempts;
      if (newAttempts >= MAX_OTP_ATTEMPTS) {
        const lockUntil = Timestamp.fromDate(new Date(Date.now() + LOCK_DURATION_MS));
        await requestRef.update({ otpAttempts: newAttempts, otpLockedUntil: lockUntil });
        await db.collection('admin_logs').add({
          action: 'otp_locked', requestId, techId: uid,
          attempts: newAttempts, lockedUntil: lockUntil,
          timestamp: FieldValue.serverTimestamp(),
        });
        throw new HttpsError('resource-exhausted', 'Trop de tentatives. Code OTP bloqué pour 10 minutes.');
      }
      await requestRef.update({ otpAttempts: newAttempts });
      throw new HttpsError('invalid-argument', `Code incorrect. ${remaining} tentative(s) restante(s).`);
    }

    await requestRef.update({
      status: 'in_progress',
      startedAt: FieldValue.serverTimestamp(),
      otpAttempts: FieldValue.delete(),
      otpLockedUntil: FieldValue.delete(),
    });
    return { success: true };
  }
);

// ── validateAndCreateRequest ──────────────────────────────────────────────────

exports.validateAndCreateRequest = onCall(
  { region: 'europe-west1', enforceAppCheck: false },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Vous devez etre connecte.');
    const uid = request.auth.uid;
    const data = request.data;

    const userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data()?.isBanned === true) throw new HttpsError('permission-denied', 'Compte suspendu.');
    const techDoc = await db.collection('technicians').doc(uid).get();
    if (techDoc.exists && techDoc.data()?.isBanned === true) throw new HttpsError('permission-denied', 'Compte suspendu.');

    const oneHourAgo = Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000));
    const recentSnap = await db.collection('requests').where('clientId', '==', uid).where('createdAt', '>', oneHourAgo).get();
    if (recentSnap.size >= 3) throw new HttpsError('resource-exhausted', 'Limite atteinte: maximum 3 commandes par heure.');

    if (!data.scheduledAt) {
      const activeSnap = await db.collection('requests')
        .where('clientId', '==', uid)
        .where('status', 'in', ['pending', 'accepted', 'en_route', 'in_progress']).get();
      if (activeSnap.docs.filter(d => !d.data().scheduledAt).length > 0)
        throw new HttpsError('already-exists', 'Vous avez deja une commande active.');
    }

    const budget = Number(data.budgetMAD);
    if (isNaN(budget) || budget < 10 || budget > 10000) throw new HttpsError('invalid-argument', 'Budget invalide (10-10000 MAD).');
    const serviceType = String(data.serviceType || '');
    if (!serviceType.startsWith('sos_')) throw new HttpsError('invalid-argument', 'Type de service invalide.');
    const description = String(data.description || '').trim();
    if (description.length > 500) throw new HttpsError('invalid-argument', 'Description trop longue (max 500).');
    const lat = Number(data.clientLat);
    const lng = Number(data.clientLng);
    if (isNaN(lat) || isNaN(lng) || lat < 27 || lat > 36 || lng < -14 || lng > -1)
      throw new HttpsError('invalid-argument', 'Localisation invalide (hors Maroc).');

    const commission = parseFloat((budget * 0.15).toFixed(2));
    const otp = String(Math.floor(1000 + Math.random() * 8999));

    const safeDoc = {
      clientId: uid,
      clientName: String(data.clientName || '').trim().slice(0, 100),
      techId: null, serviceType,
      serviceLabel: String(data.serviceLabel || '').trim().slice(0, 100),
      description, status: 'pending',
      budgetMAD: budget, priceQuoteMAD: budget, commissionMAD: commission,
      clientLocation: { latitude: lat, longitude: lng },
      otpCode: otp, otpAttempts: 0,
      clientRating: null, clientReview: null, mediaUrls: [], journal: [],
      scheduledAt: data.scheduledAt || null,
      preferredTechId: data.preferredTechId || null,
      promoCode: data.promoCode || null,
      discountMAD: Number(data.discountMAD) || 0,
      createdAt: FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection('requests').add(safeDoc);
    return { requestId: docRef.id };
  }
);

// ── Ban enforcement ───────────────────────────────────────────────────────────

exports.onUserBanned = onDocumentUpdated('users/{uid}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.isBanned || !after.isBanned) return;
  const uid = event.params.uid;
  try {
    await auth.revokeRefreshTokens(uid);
    await db.collection('admin_logs').add({
      action: 'user_banned', targetUid: uid,
      reason: after.banReason || '', bannedUntil: after.bannedUntil || null,
      timestamp: FieldValue.serverTimestamp(),
    });
  } catch (e) { console.error('revoke failed:', uid, e.message); }
});

exports.onTechnicianBanned = onDocumentUpdated('technicians/{uid}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.isBanned || !after.isBanned) return;
  const uid = event.params.uid;
  try {
    await auth.revokeRefreshTokens(uid);
    await db.collection('admin_logs').add({
      action: 'technician_banned', targetUid: uid,
      reason: after.banReason || '', bannedUntil: after.bannedUntil || null,
      timestamp: FieldValue.serverTimestamp(),
    });
  } catch (e) { console.error('revoke failed:', uid, e.message); }
});

// ── Invoice ───────────────────────────────────────────────────────────────────

exports.getInvoiceUrl = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Non autorise.');
  const { requestId } = request.data;
  if (!requestId) throw new HttpsError('invalid-argument', 'requestId manquant.');
  const doc = await db.collection('requests').doc(requestId).get();
  if (!doc.exists) throw new HttpsError('not-found', 'Commande introuvable.');
  const data = doc.data();
  const uid = request.auth.uid;
  if (data.clientId !== uid && data.techId !== uid) {
    const adminDoc = await db.collection('admins').doc(uid).get();
    if (!adminDoc.exists) throw new HttpsError('permission-denied', 'Acces refuse.');
  }
  const invoicePath = data.invoicePath;
  if (!invoicePath) throw new HttpsError('not-found', 'Facture non disponible.');
  const { getStorage } = require('firebase-admin/storage');
  const [signedUrl] = await getStorage().bucket().file(invoicePath).getSignedUrl({
    action: 'read', expires: Date.now() + 7 * 24 * 60 * 60 * 1000,
  });
  return { url: signedUrl };
});

// ── Notifications ─────────────────────────────────────────────────────────────

exports.onRequestCreated = onDocumentCreated('requests/{requestId}', async (event) => {
  const data = event.data?.data();
  if (!data || data.status !== 'pending') return;
  const skillId = (data.serviceType || '').replace('sos_', '');
  if (!skillId) return;
  const snap = await db.collection('technicians').where('isOnline', '==', true).where('isVerified', '==', true).get();
  const tokenPromises = snap.docs
    .filter(doc => (doc.data().servicesProvided || []).includes(skillId))
    .map(doc => getToken('technicians', doc.id));
  const tokens = (await Promise.all(tokenPromises)).filter(Boolean);
  await sendToTokens(tokens,
    'Nouvelle demande pres de vous',
    `${data.serviceLabel || 'Service'} - ${data.budgetMAD || '?'} MAD`,
    { type: 'new_request', requestId: event.params.requestId });
});

exports.onOfferCreated = onDocumentCreated('requests/{requestId}/offers/{offerId}', async (event) => {
  const offer = event.data?.data();
  if (!offer) return;
  const requestDoc = await db.collection('requests').doc(event.params.requestId).get();
  if (!requestDoc.exists) return;
  const token = await getToken('users', requestDoc.data().clientId);
  const total = (offer.priceMAD || 0) + (offer.transportFeeMAD || 0);
  await sendToToken(token, 'Nouvelle offre recue',
    `${offer.techName || 'Un technicien'} propose ${total} MAD`,
    { type: 'new_offer', requestId: event.params.requestId });
});

const STATUS_EVENTS = {
  en_route:    { side: 'client',     title: 'Votre technicien est en route', body: 'Il arrive bientot' },
  in_progress: { side: 'client',     title: 'Travaux commences',             body: 'Votre technicien est sur place' },
  completed:   { side: 'client',     title: 'Mission terminee !',            body: 'Notez votre experience' },
  cancelled:   { side: 'both',       title: 'Commande annulee',              body: 'Cette commande a ete annulee' },
  accepted:    { side: 'technician', title: 'Commande acceptee',             body: 'Le client vous a choisi' },
};

exports.onRequestStatusChanged = onDocumentUpdated('requests/{requestId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  const entry = STATUS_EVENTS[after.status];
  if (!entry) return;
  const requestId = event.params.requestId;
  if (entry.side === 'client' || entry.side === 'both') {
    const token = await getToken('users', after.clientId);
    await sendToToken(token, entry.title, entry.body, { type: `status_${after.status}`, requestId });
  }
  if ((entry.side === 'technician' || entry.side === 'both') && after.techId) {
    const token = await getToken('technicians', after.techId);
    await sendToToken(token, entry.title, entry.body, { type: `status_${after.status}`, requestId });
  }
});

exports.onSpecialtyChanged = onDocumentUpdated('technicians/{techId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const token = await getToken('technicians', event.params.techId);
  if (!token) return;
  for (const afterSpec of (after.specialties || [])) {
    const beforeSpec = (before.specialties || []).find(s => s.skillId === afterSpec.skillId);
    if (!beforeSpec || beforeSpec.status === afterSpec.status) continue;
    if (afterSpec.status === 'approved') {
      await sendToToken(token, 'Specialite approuvee !',
        `${afterSpec.skillLabel} est maintenant visible aux clients`,
        { type: 'specialty_approved', skillId: afterSpec.skillId });
    } else if (afterSpec.status === 'rejected') {
      await sendToToken(token, 'Specialite refusee',
        `${afterSpec.skillLabel} - voir profil`,
        { type: 'specialty_rejected', skillId: afterSpec.skillId });
    }
  }
});

exports.onWalletChanged = onDocumentUpdated('technicians/{techId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if ((before.walletBalance || 0) >= 50 && (after.walletBalance || 0) < 50) {
    const token = await getToken('technicians', event.params.techId);
    await sendToToken(token, 'Solde insuffisant',
      `Votre solde est de ${(after.walletBalance || 0).toFixed(0)} MAD - rechargez`,
      { type: 'wallet_low' });
  }
});

exports.onReportCreated = onDocumentCreated('reports/{reportId}', async (event) => {
  const report = event.data?.data();
  if (!report) return;
  const tokens = await getAllAdminTokens();
  const isUrgent = report.urgent === true;
  await sendToTokens(tokens,
    isUrgent ? 'URGENCE - action immediate' : 'Nouveau signalement',
    `${report.reason || 'Signalement'} - ${(report.comment || '').slice(0, 80)}`,
    { type: isUrgent ? 'urgent_report' : 'new_report', requestId: event.params.reportId });
});

exports.onTechnicianVerified = onDocumentUpdated('technicians/{techId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const token = await getToken('technicians', event.params.techId);
  if (!before.isVerified && after.isVerified) {
    await sendToToken(token, 'Compte verifie !',
      'Votre profil Brikol.ma est actif - vous pouvez recevoir des commandes',
      { type: 'account_verified' });
  }
  if (!before.isSuspended && after.isSuspended) {
    await sendToToken(token, 'Compte suspendu',
      'Votre compte a ete suspendu. Contactez le support Brikol.',
      { type: 'account_suspended' });
  }
});

const QUOTE_MESSAGES = {
  quoted:      { title: 'Devis recu',       body: (d) => `${d.companyName || 'Une entreprise'} vous a envoye un devis` },
  confirmed:   { title: 'Devis confirme',   body: () => 'Votre devis a ete confirme' },
  in_progress: { title: 'Chantier demarre', body: () => "L'equipe est sur place" },
  completed:   { title: 'Projet termine !', body: () => 'Consultez la facture' },
};

exports.onCompanyQuoteUpdated = onDocumentUpdated('company_quote_requests/{requestId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  const entry = QUOTE_MESSAGES[after.status];
  if (!entry) return;
  const token = await getToken('users', after.clientId);
  await sendToToken(token, entry.title, entry.body(after),
    { type: `quote_${after.status}`, requestId: event.params.requestId });
});