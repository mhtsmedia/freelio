/* Velger design for hele nettsiden.
   STANDARD = 'ny' gir det nye designet (css/ny.css og bunnmeny på mobil).
   Sett STANDARD = 'gammel' for å gå tilbake til det forrige designet for alle besøkende.
   Hver besøkende kan også bytte selv med ?design=gammel eller ?design=ny i adressen. Valget huskes i nettleseren.

   FORSIDE velger forsiden i det nye designet:
   'ny' gir den rolige, FINN-inspirerte forsiden (css/forside.css).
   'original' gir forsiden slik den var før (koden ligger urørt i index.html, i <template id="forside-original">).
   Hver besøkende kan bytte selv med ?forside=original eller ?forside=ny.
   Med det gamle designet (?design=gammel) vises alltid den originale forsiden.

   IKONSIRKLER = true legger en lys sirkel bak kategori-ikonene på den nye forsiden. false gir ikonene uten sirkel.
   Kan prøves med ?sirkler=av eller ?sirkler=pa. */
(function () {
  var STANDARD = 'ny';
  var FORSIDE = 'ny';
  var IKONSIRKLER = true;
  var d = STANDARD, f = FORSIDE, s = IKONSIRKLER ? 'pa' : 'av';
  try {
    var p = new URLSearchParams(location.search);
    var q = p.get('design');
    if (q === 'ny' || q === 'gammel') localStorage.setItem('freelio:design', q);
    d = localStorage.getItem('freelio:design') || STANDARD;
    var qf = p.get('forside');
    if (qf === 'ny' || qf === 'original') localStorage.setItem('freelio:forside', qf);
    f = localStorage.getItem('freelio:forside') || FORSIDE;
    var qs = p.get('sirkler');
    if (qs === 'av' || qs === 'pa') localStorage.setItem('freelio:sirkler', qs);
    s = localStorage.getItem('freelio:sirkler') || s;
  } catch (e) {}
  if (d !== 'ny' && d !== 'gammel') d = STANDARD;
  if (f !== 'ny' && f !== 'original') f = FORSIDE;
  if (d === 'gammel') f = 'original';
  var root = document.documentElement;
  root.dataset.design = d;
  root.dataset.forside = f;
  root.dataset.sirkler = s === 'av' ? 'av' : 'pa';
  var css = document.getElementById('ny-css');
  if (css && d === 'gammel') css.disabled = true;
  var fs = document.getElementById('forside-css');
  if (fs && f !== 'ny') fs.disabled = true;
})();
