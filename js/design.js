/* Velger design for hele nettsiden.
   STANDARD = 'ny' gir det nye designet (css/ny.css og bunnmeny på mobil).
   STANDARD = 'finn' gir et FINN-inspirert design oppå det nye (css/ny.css + css/finn.css, og en egen forside).
   Sett STANDARD = 'gammel' for å gå tilbake til det forrige designet for alle besøkende.
   Hver besøkende kan også bytte selv med ?design=ny, ?design=finn eller ?design=gammel i adressen.
   Valget huskes i nettleseren. */
(function () {
  var STANDARD = 'ny';
  var LOV = { ny: 1, finn: 1, gammel: 1 };
  var d = STANDARD;
  try {
    var q = new URLSearchParams(location.search).get('design');
    if (LOV[q]) localStorage.setItem('freelio:design', q);
    d = localStorage.getItem('freelio:design') || STANDARD;
  } catch (e) {}
  if (!LOV[d]) d = STANDARD;
  document.documentElement.dataset.design = d;
  var css = document.getElementById('ny-css');
  if (css && d === 'gammel') css.disabled = true;
  var finn = document.getElementById('finn-css');
  if (finn && d !== 'finn') finn.disabled = true;
})();
