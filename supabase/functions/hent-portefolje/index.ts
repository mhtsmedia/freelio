// Freelio: hent navn, beskrivelse og bilder fra en portefølje på nett.
// Legges inn i Supabase: Edge Functions -> Deploy a new function -> Via Editor.
// Navn: hent-portefolje. Erstatt hele eksempelkoden med denne filen. Funksjonen sjekker selv at
// brukeren er logget inn, så «Verify JWT» kan stå på eller av.
//
// To bruksmåter (POST med JSON):
//   { "url": "https://min-portefolje.no" }   -> { title, description, images: [adresser] }
//   { "image": "https://.../bilde.jpg" }      -> selve bildet (som application/octet-stream)
// Nettsiden laster bildene opp i brukerens egen mappe etterpå, så ingenting lenkes fra andre nettsider.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const UA = "Mozilla/5.0 (compatible; FreelioBot/1.0; +https://mhtsmedia.github.io/freelio/)";
const HTML_MAX = 3 * 1024 * 1024; // 3 MB
const IMAGE_MAX = 15 * 1024 * 1024; // 15 MB
const MAX_IMAGES = 30;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

// ---------- trygg henting: bare vanlige nettsider, aldri interne adresser ----------

const privateV4 = (ip: string) => {
  const p = ip.split(".").map(Number);
  if (p.length !== 4 || p.some((n) => !(n >= 0 && n <= 255))) return true;
  const [a, b] = p;
  return a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127) || a >= 224;
};
const privateV6 = (ip: string) => {
  const s = ip.toLowerCase();
  if (s === "::" || s === "::1") return true;
  if (s.startsWith("::ffff:")) return privateV4(s.slice(7));
  return /^(fc|fd|fe8|fe9|fea|feb|ff)/.test(s);
};

async function checkUrl(raw: string): Promise<URL> {
  let u: URL;
  try { u = new URL(raw); } catch { throw new Error("Ugyldig lenke"); }
  if (u.protocol !== "https:" && u.protocol !== "http:") throw new Error("Lenken må starte med https://");
  if (u.username || u.password) throw new Error("Ugyldig lenke");
  if (u.port && u.port !== "80" && u.port !== "443") throw new Error("Ugyldig lenke");
  const host = u.hostname.replace(/^\[|\]$/g, "");
  if (!host.includes(".") || /(^|\.)(localhost|local|internal)$/i.test(host)) throw new Error("Ugyldig lenke");
  if (/^[\d.]+$/.test(host)) { if (privateV4(host)) throw new Error("Ugyldig lenke"); return u; }
  if (host.includes(":")) { if (privateV6(host)) throw new Error("Ugyldig lenke"); return u; }
  // Navnet slås opp, så det ikke kan peke til en intern adresse. null betyr at oppslag ikke er tilgjengelig.
  const lookup = async (type: "A" | "AAAA") => {
    try { return await Deno.resolveDns(host, type); } catch (e) { return e instanceof Deno.errors.NotFound ? [] : null; }
  };
  const a = await lookup("A"), aaaa = await lookup("AAAA");
  if (a === null || aaaa === null) return u;
  if (!a.length && !aaaa.length) throw new Error("Fant ikke nettsiden");
  if (a.some(privateV4) || aaaa.some(privateV6)) throw new Error("Ugyldig lenke");
  return u;
}

// Henter med tidsfrist og maks størrelse. Videresendinger følges, og hver adresse sjekkes på nytt.
async function safeFetch(raw: string, accept: string, max: number): Promise<{ url: URL; type: string; body: Uint8Array }> {
  let url = await checkUrl(raw);
  for (let hop = 0; hop < 5; hop++) {
    const res = await fetch(url, { redirect: "manual", headers: { "User-Agent": UA, Accept: accept, "Accept-Language": "nb,no;q=0.9,en;q=0.6" }, signal: AbortSignal.timeout(9000) });
    if (res.status >= 300 && res.status < 400 && res.headers.get("location")) {
      url = await checkUrl(new URL(res.headers.get("location")!, url).toString());
      await res.body?.cancel();
      continue;
    }
    if (!res.ok) { await res.body?.cancel(); throw new Error(`Nettsiden svarte med feil (${res.status})`); }
    const len = Number(res.headers.get("content-length") || 0);
    if (len > max) { await res.body?.cancel(); throw new Error("Filen er for stor"); }
    const reader = res.body!.getReader();
    const parts: Uint8Array[] = [];
    let size = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > max) { await reader.cancel(); throw new Error("Filen er for stor"); }
      parts.push(value);
    }
    const body = new Uint8Array(size);
    let at = 0;
    for (const p of parts) { body.set(p, at); at += p.length; }
    return { url, type: (res.headers.get("content-type") || "").toLowerCase(), body };
  }
  throw new Error("For mange videresendinger");
}

// ---------- lesing av siden ----------

const decode = (s: string) =>
  s.replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
const clean = (s: string, max: number) => decode(s).replace(/\s+/g, " ").trim().slice(0, max);
const attr = (tag: string, name: string) => {
  const m = tag.match(new RegExp(`\\s${name}\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))`, "i"));
  return m ? (m[2] ?? m[3] ?? m[4] ?? "") : "";
};

function readPage(html: string, base: URL) {
  const tags = html.match(/<meta\b[^>]*>/gi) || [];
  const meta = (key: string) => {
    for (const t of tags) {
      const k = (attr(t, "property") || attr(t, "name")).toLowerCase();
      if (k === key) return attr(t, "content");
    }
    return "";
  };
  const titleTag = (html.match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [])[1] || "";
  const title = clean(meta("og:site_name") || meta("og:title") || titleTag.split(/\s[|–—-]\s/)[0], 120);
  const description = clean(meta("og:description") || meta("description") || meta("twitter:description"), 1500);

  const found: string[] = [];
  const add = (src: string) => {
    if (!src || src.startsWith("data:")) return;
    try {
      const u = new URL(decode(src.trim()), base);
      if (u.protocol !== "https:" && u.protocol !== "http:") return;
      if (/\.(svg|gif|ico)(\?|$)/i.test(u.pathname)) return;
      if (/(sprite|favicon|icon|logo|pixel|spacer|blank|loader|badge|emoji)/i.test(u.pathname)) return;
      const s = u.toString();
      if (!found.includes(s)) found.push(s);
    } catch { /* ugyldig adresse */ }
  };
  for (const k of ["og:image", "og:image:secure_url", "twitter:image", "twitter:image:src"]) add(meta(k));
  for (const t of html.match(/<img\b[^>]*>/gi) || []) {
    // srcset: ta den største varianten
    const set = attr(t, "srcset") || attr(t, "data-srcset");
    if (set) {
      const best = set.split(",").map((x) => x.trim().split(/\s+/)).filter((x) => x[0])
        .sort((a, b) => (parseFloat(b[1]) || 0) - (parseFloat(a[1]) || 0))[0];
      if (best) { add(best[0]); continue; }
    }
    const w = parseInt(attr(t, "width")), h = parseInt(attr(t, "height"));
    if ((w && w < 200) || (h && h < 200)) continue;
    add(attr(t, "data-src") || attr(t, "data-lazy-src") || attr(t, "data-original") || attr(t, "src"));
  }
  for (const t of html.match(/<link\b[^>]*rel=["']?image_src[^>]*>/gi) || []) add(attr(t, "href"));
  return { title, description, images: found.slice(0, MAX_IMAGES) };
}

// ---------- bare innloggede brukere ----------
// Sjekkes her i tillegg til «Verify JWT», så funksjonen er trygg selv om den bryteren er av.
async function signedIn(req: Request) {
  const auth = req.headers.get("authorization") || "";
  const base = Deno.env.get("SUPABASE_URL");
  const key = req.headers.get("apikey") || Deno.env.get("SUPABASE_ANON_KEY") || "";
  if (!base || !/^Bearer\s+\S+/i.test(auth)) return false;
  const r = await fetch(`${base}/auth/v1/user`, { headers: { Authorization: auth, apikey: key }, signal: AbortSignal.timeout(6000) }).catch(() => null);
  if (!r) return false;
  const user = await r.json().catch(() => null);
  return r.ok && !!(user && user.id);
}

// ---------- svar ----------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Bruk POST" }, 405);
  if (!(await signedIn(req))) return json({ error: "Logg inn for å hente fra porteføljen." }, 401);
  let body: { url?: string; image?: string };
  try { body = await req.json(); } catch { return json({ error: "Ugyldig forespørsel" }, 400); }
  try {
    if (typeof body.image === "string" && body.image.length <= 2000) {
      const r = await safeFetch(body.image, "image/webp,image/jpeg,image/png,image/*;q=0.8", IMAGE_MAX);
      if (!/^image\/(jpeg|png|webp|avif|heic|heif)/.test(r.type)) throw new Error("Lenken er ikke et bilde");
      return new Response(r.body, { headers: { ...CORS, "Content-Type": "application/octet-stream", "X-Image-Type": r.type.split(";")[0], "Access-Control-Expose-Headers": "X-Image-Type" } });
    }
    if (typeof body.url === "string" && body.url.length <= 2000) {
      const r = await safeFetch(body.url, "text/html,application/xhtml+xml", HTML_MAX);
      if (!/html/.test(r.type)) throw new Error("Lenken er ikke en nettside");
      const html = new TextDecoder().decode(r.body);
      return json({ url: r.url.toString(), ...readPage(html, r.url) });
    }
    return json({ error: "Mangler lenke" }, 400);
  } catch (e) {
    const msg = e instanceof Error && e.name !== "TimeoutError" ? e.message : "Nettsiden svarte ikke i tide";
    return json({ error: msg }, 422);
  }
});
