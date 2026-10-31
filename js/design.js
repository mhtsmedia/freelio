/* Velger design for hele nettsiden.
   STANDARD = 'ny' gir det nye designet (css/ny.css og bunnmeny på mobil).
   Sett STANDARD = 'gammel' for å gå tilbake til det forrige designet for alle besøkende.
   Hver besøkende kan også bytte selv med ?design=gammel eller ?design=ny i adressen. Valget huskes i nettleseren. */
(function () {
  var STANDARD = 'ny';
  var d = STANDARD;
  try {
    var q = new URLSearchParams(location.search).get('design');
    if (q === 'ny' || q === 'gammel') localStorage.setItem('freelio:design', q);
    d = localStorage.getItem('freelio:design') || STANDARD;
  } catch (e) {}
  if (d !== 'ny' && d !== 'gammel') d = STANDARD;
  document.documentElement.dataset.design = d;
  var css = document.getElementById('ny-css');
  if (css && d === 'gammel') css.disabled = true;
})();
