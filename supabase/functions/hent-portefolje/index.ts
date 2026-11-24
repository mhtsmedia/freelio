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
const SCAN_MAX = 512 * 1024; // bare de første 512 kB av siden leses etter navn, beskrivelse og bilder

// Feil vi kaster selv, med tekst som er trygg å vise. Andre feil (nettverk, DNS, interne adresser) får en
// generell melding, så svaret aldri forteller noe om nettverket funksjonen kjører i.
class UserError extends Error {}

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
  try { u = new URL(raw); } catch { throw new UserError("Ugyldig lenke"); }
  if (u.protocol !== "https:" && u.protocol !== "http:") throw new UserError("Lenken må starte med https://");
  if (u.username || u.password) throw new UserError("Ugyldig lenke");
  if (u.port && u.port !== "80" && u.port !== "443") throw new UserError("Ugyldig lenke");
  const host = u.hostname.replace(/^\[|\]$/g, "");
  if (!host.includes(".") || /(^|\.)(localhost|local|internal)$/i.test(host)) throw new UserError("Ugyldig lenke");
  if (/^[\d.]+$/.test(host)) { if (privateV4(host)) throw new UserError("Ugyldig lenke"); return u; }
  if (host.includes(":")) { if (privateV6(host)) throw new UserError("Ugyldig lenke"); return u; }
  // Navnet slås opp, så det ikke kan peke til en intern adresse. null betyr at oppslag ikke er tilgjengelig.
  const lookup = async (type: "A" | "AAAA") => {
    try { return await Deno.resolveDns(host, type); } catch (e) { return e instanceof Deno.errors.NotFound ? [] : null; }
  };
  const a = await lookup("A"), aaaa = await lookup("AAAA");
  if (a === null || aaaa === null) return u;
  if (!a.length && !aaaa.length) throw new UserError("Fant ikke nettsiden");
  if (a.some(privateV4) || aaaa.some(privateV6)) throw new UserError("Ugyldig lenke");
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
    if (!res.ok) { await res.body?.cancel(); throw new UserError(`Nettsiden svarte med feil (${res.status})`); }
    const len = Number(res.headers.get("content-length") || 0);
    if (len > max) { await res.body?.cancel(); throw new UserError("Filen er for stor"); }
    const reader = res.body!.getReader();
    const parts: Uint8Array[] = [];
    let size = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > max) { await reader.cancel(); throw new UserError("Filen er for stor"); }
      parts.push(value);
    }
    const body = new Uint8Array(size);
    let at = 0;
    for (const p of parts) { body.set(p, at); at += p.length; }
    return { url, type: (res.headers.get("content-type") || "").toLowerCase(), body };
  }
  throw new UserError("For mange videresendinger");
}

// ---------- lesing av siden ----------

const decode = (s: string) =>
  s.replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
const clean = (s: string, max: number) => decode(s).replace(/\s+/g, " ").trim().slice(0, max);
const attr = (tag: string, name: string) => {
  const m = tag.slice(0, 4000).match(new RegExp(`\\s${name}\\s{0,5}=\\s{0,5}("([^"]{0,3000})"|'([^']{0,3000})'|([^\\s>]{1,3000}))`, "i"));
  return m ? (m[2] ?? m[3] ?? m[4] ?? "") : "";
};

// Finner <navn ...>-tagger i én gjennomgang av teksten, uten regex som kan henge. En side som er laget for å få
// regex-motoren til å bruke all tiden sin (ReDoS, for eksempel 600 000 «<meta» uten «>»), kan da ikke stoppe funksjonen.
const tagsOf = (html: string, name: string, max: number) => {
  const out: string[] = [];
  const parts = html.split("<");
  for (let i = 1; i < parts.length && out.length < max; i++) {
    const p = parts[i];
    if (p.slice(0, name.length).toLowerCase() !== name || !/[\s/>]/.test(p.charAt(name.length))) continue;
    const end = p.indexOf(">");
    if (end > 0 && end <= 4000) out.push("<" + p.slice(0, end + 1));
  }
  return out;
};
const titleOf = (html: string) => {
  const low = html.toLowerCase();
  const a = low.indexOf("<title");
  const b = a < 0 ? -1 : low.indexOf(">", a);
  const c = b < 0 ? -1 : low.indexOf("</title", b);
  return c > b && c - b <= 500 ? html.slice(b + 1, c) : "";
};

function readPage(page: string, base: URL) {
  // Bare starten av siden leses (der head og de første bildene ligger)
  const html = page.slice(0, SCAN_MAX);
  const tags = tagsOf(html, "meta", 300);
  const meta = (key: string) => {
    for (const t of tags) {
      const k = (attr(t, "property") || attr(t, "name")).toLowerCase();
      if (k === key) return attr(t, "content");
    }
    return "";
  };
  const titleTag = titleOf(html);
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
  for (const t of tagsOf(html, "img", 400)) {
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
  for (const t of tagsOf(html, "link", 300)) if (/rel=["']?image_src/i.test(t)) add(attr(t, "href"));
  return { title, description, images: found.slice(0, MAX_IMAGES) };
}

// ---------- bare innloggede brukere ----------
// Sjekkes her i tillegg til «Verify JWT», så funksjonen er trygg selv om den bryteren er av.
async function signedIn(req: Request) {
  const auth = req.headers.get("authorization") || "";
  const base = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY") || req.headers.get("apikey") || "";
  if (!base || !/^Bearer\s+\S+/i.test(auth)) return false;
  const r = await fetch(`${base}/auth/v1/user`, { headers: { Authorization: auth, apikey: key }, signal: AbortSignal.timeout(6000) }).catch(() => null);
  if (!r) return false;
  const user = await r.json().catch(() => null);
  return r.ok && !!(user && user.id);
}

// ---------- fartsgrense per bruker ----------
// Databasen teller hentingene (database/sjekkliste.sql, portfolio_fetch_allowed): høyst 30 sider og 300 bilder
// i timen per bruker, så funksjonen ikke kan brukes til å hente tusenvis av sider eller som mellomtjener.
// Er SQL-filen ikke kjørt ennå, slipper alt gjennom som før.
async function allowed(req: Request, kind: "side" | "bilde") {
  const base = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY") || req.headers.get("apikey") || "";
  const r = await fetch(`${base}/rest/v1/rpc/portfolio_fetch_allowed`, {
    method: "POST",
    headers: { Authorization: req.headers.get("authorization") || "", apikey: key, "Content-Type": "application/json" },
    body: JSON.stringify({ p_kind: kind }),
    signal: AbortSignal.timeout(6000),
  }).catch(() => null);
  if (!r || r.status === 404) return true;
  return (await r.json().catch(() => true)) !== false;
}

// ---------- svar ----------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Bruk POST" }, 405);
  if (!(await signedIn(req))) return json({ error: "Logg inn for å hente fra porteføljen." }, 401);
  let body: { url?: string; image?: string };
  try { body = await req.json(); } catch { return json({ error: "Ugyldig forespørsel" }, 400); }
  if (!(await allowed(req, typeof body.image === "string" ? "bilde" : "side"))) {
    return json({ error: "Du har hentet mye på kort tid. Vent en time og prøv igjen." }, 429);
  }
  try {
    if (typeof body.image === "string" && body.image.length <= 2000) {
      const r = await safeFetch(body.image, "image/webp,image/jpeg,image/png,image/*;q=0.8", IMAGE_MAX);
      if (!/^image\/(jpeg|png|webp|avif|heic|heif)/.test(r.type)) throw new UserError("Lenken er ikke et bilde");
      return new Response(r.body, { headers: { ...CORS, "Content-Type": "application/octet-stream", "X-Image-Type": r.type.split(";")[0], "Access-Control-Expose-Headers": "X-Image-Type" } });
    }
    if (typeof body.url === "string" && body.url.length <= 2000) {
      const r = await safeFetch(body.url, "text/html,application/xhtml+xml", HTML_MAX);
      if (!/html/.test(r.type)) throw new UserError("Lenken er ikke en nettside");
      const html = new TextDecoder().decode(r.body);
      return json({ url: r.url.toString(), ...readPage(html, r.url) });
    }
    return json({ error: "Mangler lenke" }, 400);
  } catch (e) {
    const timeout = e instanceof Error && (e.name === "TimeoutError" || e.name === "AbortError");
    const msg = e instanceof UserError ? e.message : timeout ? "Nettsiden svarte ikke i tide" : "Kunne ikke hente nettsiden. Sjekk lenken og prøv igjen.";
    if (!(e instanceof UserError) && !timeout) console.error("hent-portefolje", e);
    return json({ error: msg }, 422);
  }
});
