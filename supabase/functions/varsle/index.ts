// Freelio: push-varsler om nye tilbud og nye meldinger.
// Legges inn i Supabase: Edge Functions -> Deploy a new function -> Via Editor. Navn: varsle.
// Erstatt hele eksempelkoden med denne filen, og slå AV «Verify JWT» (databasen kaller funksjonen).
//
// Funksjonen kan ikke misbrukes til å sende falske varsler: den sender bare om tilbud og meldinger som
// finnes i databasen, er nye (under 10 minutter gamle) og ikke er varslet før. Teksten hentes fra databasen.
//
// Secrets (Edge Functions -> Secrets): VAPID_PUBLIC_KEY og VAPID_PRIVATE_KEY (fra VAPID-nokler.txt).
// SUPABASE_URL og SUPABASE_SERVICE_ROLE_KEY finnes automatisk i alle Supabase-funksjoner.
// Databasen kaller funksjonen med { "type": "offer" | "message", "id": "<uuid>" } (database/push.sql),
// og { "type": "bug", "id": <tall> } når noen melder en feil. Det varselet går til alle admin (database/feil-varsel.sql).
// Nettsiden kan også be om et testvarsel til din egen enhet: { "type": "test" } med innloggingen din.
//
// Krypteringen følger standarden for Web Push (RFC 8291, aes128gcm) og VAPID (RFC 8292), og bruker bare
// den innebygde WebCrypto, så funksjonen trenger ingen biblioteker.

const SITE = "https://mhtsmedia.github.io/freelio/";
const FRESH_MS = 10 * 60 * 1000;
const env = (k) => ((globalThis.Deno && Deno.env.get(k)) || "");
// En nøkkel fra Secrets. Tåler at den er limt inn som «NAVN=verdi», også flere linjer på en gang
// (da plukkes linjen med riktig navn ut), og mellomrom eller anførselstegn rundt.
export const secret = (k, raw = env(k), others = [env("VAPID_PUBLIC_KEY"), env("VAPID_PRIVATE_KEY")]) => {
  const pick = (val) => {
    for (const line of String(val || "").trim().split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*["']?([^"'\s]+)["']?\s*$/);
      if (m && m[1] === k) return m[2];
    }
    return "";
  };
  const v = String(raw || "").trim();
  // Først i sin egen verdi, så i de andre VAPID-verdiene (hvis begge linjene ble limt inn i samme felt)
  return pick(v) || others.map(pick).find(Boolean) || v.replace(/^["']|["']$/g, "");
};
// Formen på en nøkkel til feilsøking: lengde og antall linjer, aldri innholdet
const shape = (k) => { const v = env(k); return `${k.replace("VAPID_", "").toLowerCase()} ${v.length} tegn/${v ? v.split(/\r?\n/).length : 0} linjer`; };

// ---------- hjelpere ----------
export const b64u = (u8) => btoa(String.fromCharCode(...u8)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
export const unb64u = (s) => {
  s = String(s).replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
};
const cat = (...parts) => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
};
const txt = (s) => new TextEncoder().encode(s);
const zero = new Uint8Array([0]);
const pubJwk = (raw) => ({ kty: "EC", crv: "P-256", x: b64u(raw.slice(1, 33)), y: b64u(raw.slice(33, 65)) });

// ---------- kryptering av innholdet (RFC 8291) ----------
const hkdf = async (salt, ikm, info, len) =>
  new Uint8Array(await crypto.subtle.deriveBits({ name: "HKDF", hash: "SHA-256", salt, info },
    await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]), len * 8));

// plain: innholdet. uaPublic og authSecret: fra mottakerens abonnement (p256dh og auth).
// test: { keys, salt } brukes bare for å sjekke mot eksempelet i standarden.
export async function encryptPayload(plain, uaPublic, authSecret, test) {
  const ua = await crypto.subtle.importKey("raw", uaPublic, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const as = test ? test.keys : await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]);
  const asPublic = new Uint8Array(await crypto.subtle.exportKey("raw", as.publicKey));
  const salt = test ? test.salt : crypto.getRandomValues(new Uint8Array(16));
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: ua }, as.privateKey, 256));
  const ikm = await hkdf(authSecret, ecdh, cat(txt("WebPush: info"), zero, uaPublic, asPublic), 32);
  const cek = await hkdf(salt, ikm, cat(txt("Content-Encoding: aes128gcm"), zero), 16);
  const nonce = await hkdf(salt, ikm, cat(txt("Content-Encoding: nonce"), zero), 12);
  const key = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  const data = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, cat(plain, new Uint8Array([2]))));
  const header = new Uint8Array(21);
  header.set(salt, 0);
  new DataView(header.buffer).setUint32(16, 4096);
  header[20] = asPublic.length;
  return cat(header, asPublic, data);
}

// ---------- VAPID: viser push-tjenesten at varselet kommer fra Freelio (RFC 8292) ----------
// Den hemmelige nøkkelen lastes som PKCS8 (standardformatet for en P-256-nøkkel), som alle kjøremotorer
// leser likt. JWK brukes bare som reserve.
const PKCS8_HEAD = new Uint8Array([0x30, 0x81, 0x87, 0x02, 0x01, 0x00, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x04, 0x6d, 0x30, 0x6b, 0x02, 0x01, 0x01, 0x04, 0x20]);
const PKCS8_MID = new Uint8Array([0xa1, 0x44, 0x03, 0x42, 0x00]);
export async function vapidKey(publicKey, privateKey) {
  const pub = unb64u(publicKey), d = unb64u(privateKey);
  if (pub.length !== 65 || d.length !== 32) throw new Error(`VAPID-nøklene har feil lengde (${pub.length} og ${d.length} byte; ${shape("VAPID_PUBLIC_KEY")}, ${shape("VAPID_PRIVATE_KEY")}). Sjekk Secrets.`);
  try {
    return await crypto.subtle.importKey("pkcs8", cat(PKCS8_HEAD, d, PKCS8_MID, pub), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  } catch (e) {
    console.warn("VAPID pkcs8", e && e.message);
    return await crypto.subtle.importKey("jwk", { ...pubJwk(pub), d: privateKey }, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  }
}
export async function vapidAuth(endpoint, publicKey, privateKey, subject) {
  const head = b64u(txt(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const claims = b64u(txt(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: subject })));
  const key = await vapidKey(publicKey, privateKey);
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, txt(head + "." + claims)));
  return `vapid t=${head}.${claims}.${b64u(sig)}, k=${publicKey}`;
}

// Bare de kjente push-tjenestene (Google, Mozilla, Apple, Microsoft). Ingen andre adresser kalles.
const PUSH_HOSTS = /^https:\/\/(fcm\.googleapis\.com|android\.googleapis\.com|([a-z0-9-]+\.)*push\.services\.mozilla\.com|([a-z0-9-]+\.)*push\.apple\.com|([a-z0-9-]+\.)*notify\.windows\.com)\//;

async function sendPush(sub, note) {
  if (!PUSH_HOSTS.test(sub.endpoint)) return 400;
  const body = await encryptPayload(txt(JSON.stringify(note)), unb64u(sub.p256dh), unb64u(sub.auth));
  const r = await fetch(sub.endpoint, {
    method: "POST",
    headers: {
      Authorization: await vapidAuth(sub.endpoint, secret("VAPID_PUBLIC_KEY"), secret("VAPID_PRIVATE_KEY"), env("VAPID_SUBJECT") || SITE),
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      TTL: "86400",
      Urgency: "high",
    },
    body,
  });
  await r.body?.cancel();
  return r.status;
}

// ---------- databasen (med service role, bare inne i funksjonen) ----------
async function db(path, init = {}) {
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  const r = await fetch(`${env("SUPABASE_URL")}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", ...(init.headers || {}) },
  });
  if (r.status === 409) return { conflict: true };
  if (!r.ok) throw new Error(`Database ${r.status}: ${(await r.text()).slice(0, 200)}`);
  const t = await r.text();
  return t ? JSON.parse(t) : null;
}
const one = async (path) => ((await db(path)) || [])[0] || null;
const fresh = (iso) => Date.now() - Date.parse(iso) < FRESH_MS;
const kr = (n) => { try { return new Intl.NumberFormat("nb-NO").format(n) + " kr"; } catch { return n + " kr"; } };
const cut = (s, n) => (String(s || "").length > n ? String(s).slice(0, n - 1) + "…" : String(s || ""));
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// Finner mottakerne og teksten i varselet. Gir null hvis det ikke skal varsles.
async function build(type, id) {
  if (type === "bug") {
    const r = await one(`bug_reports?id=eq.${id}&select=id,kind,what,created_at`);
    if (!r || !fresh(r.created_at)) return null;
    const admins = ((await db("admins?select=user_id")) || []).map((a) => a.user_id);
    if (!admins.length) return null;
    const label = { liten: "Småting", "virker-ikke": "Virker ikke", stopper: "Stopper" }[r.kind] || "Feil";
    return { to: admins, note: { title: `Ny feilmelding: ${label}`, body: cut(r.what, 140), url: `${SITE}meld-feil.html#admin`, tag: "feil-" + r.id } };
  }
  if (type === "offer") {
    const o = await one(`offers?id=eq.${id}&select=id,job_id,freelancer_id,price,created_at`);
    if (!o || !fresh(o.created_at)) return null;
    const j = await one(`jobs?id=eq.${o.job_id}&select=id,owner_id,status,data`);
    if (!j || !j.owner_id) return null;
    const f = await one(`freelancers?id=eq.${encodeURIComponent(o.freelancer_id)}&select=data`);
    return {
      to: j.owner_id,
      note: { title: `Nytt tilbud på «${cut(j.data?.title || "oppdraget ditt", 60)}»`, body: `${cut(f?.data?.name || "En frilanser", 40)} tilbyr ${kr(o.price)}`, url: `${SITE}annonse.html?id=${j.id}`, tag: "tilbud-" + j.id },
    };
  }
  if (type === "message") {
    const m = await one(`messages?id=eq.${id}&select=id,customer_id,freelancer_id,sender,text,created_at`);
    if (!m || m.sender === "system" || !fresh(m.created_at)) return null;
    const f = await one(`freelancers?id=eq.${encodeURIComponent(m.freelancer_id)}&select=user_id,data`);
    if (m.sender === "customer") {
      if (!f || !f.user_id) return null;
      const p = await one(`profiles?id=eq.${m.customer_id}&select=name`);
      return { to: f.user_id, note: { title: cut(p?.name || "Ny melding", 40), body: cut(m.text, 140), url: `${SITE}meldinger.html?med=${encodeURIComponent("c:" + m.customer_id)}`, tag: "melding-" + m.customer_id + "-" + m.freelancer_id } };
    }
    return { to: m.customer_id, note: { title: cut(f?.data?.name || "Ny melding", 40), body: cut(m.text, 140), url: `${SITE}meldinger.html?med=${encodeURIComponent(m.freelancer_id)}`, tag: "melding-" + m.customer_id + "-" + m.freelancer_id } };
  }
  return null;
}

// Testvarsel: bare til den som er logget inn, sjekket mot Supabase Auth
async function buildTest(req) {
  const r = await fetch(`${env("SUPABASE_URL")}/auth/v1/user`, { headers: { apikey: env("SUPABASE_SERVICE_ROLE_KEY"), Authorization: req.headers.get("Authorization") || "" } });
  if (!r.ok) return null;
  const u = await r.json();
  if (!u || !u.id) return null;
  return { to: u.id, note: { title: "Varsler er på", body: "Slik ser det ut når du får et nytt tilbud eller en ny melding på Freelio.", url: SITE + "min-side.html?vis=varsler", tag: "test" } };
}

// Selve funksjonen. Eksportert, så den kan testes uten Supabase.
export async function handle(req) {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Bruk POST" }, 405);
  let input;
  try { input = await req.json(); } catch { return json({ error: "Ugyldig JSON" }, 400); }
  const type = input?.type, id = String(input?.id || "");
  const okId = type === "bug" ? /^\d{1,18}$/.test(id) : UUID.test(id);
  if (!(type === "test" || (["offer", "message", "bug"].includes(type) && okId))) return json({ error: "Ugyldig forespørsel" }, 400);
  try {
    let b;
    if (type === "test") {
      b = await buildTest(req);
      if (!b) return json({ error: "Logg inn først" }, 401);
    } else {
      b = await build(type, id);
      if (!b) return json({ sent: 0, skipped: "ikke ny" });
      // Hver hendelse varsles bare én gang
      const log = await db("push_log", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ kind: type, ref: id }) });
      if (log && log.conflict) return json({ sent: 0, skipped: "allerede varslet" });
    }
    const to = [].concat(b.to).filter((x) => UUID.test(String(x)));
    if (!to.length) return json({ sent: 0, skipped: "ingen mottaker" });
    const subs = (await db(`push_subscriptions?user_id=in.(${to.join(",")})&select=id,endpoint,p256dh,auth`)) || [];
    let sent = 0;
    for (const s of subs) {
      try {
        const status = await sendPush(s, b.note);
        if (status === 404 || status === 410) await db(`push_subscriptions?id=eq.${s.id}`, { method: "DELETE" }); // enheten har sluttet å ta imot
        else if (status < 300) sent++;
      } catch (e) {
        console.error("push", e);
      }
    }
    return json({ sent, devices: subs.length });
  } catch (e) {
    console.error(e);
    return json({ error: "Kunne ikke sende varsel" }, 500);
  }
}

if (globalThis.Deno?.serve) Deno.serve(handle);
