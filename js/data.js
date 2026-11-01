/* Kategorier og farger. Frilansere og oppdrag hentes fra databasen (se js/cloud.js).
   Freelio starter med foto og video. Hver frilanser har en hovednisje (cat) og flere nisjer (niches). */
window.HDATA = (function () {
  const CATS = [
    { id: 'automotiv', name: 'Automotiv', icon: 'c-automotiv', desc: 'Biler, motorsykler og bilforhandlere' },
    { id: 'bryllup', name: 'Bryllup', icon: 'c-bryllup', desc: 'Foto og film fra hele dagen' },
    { id: 'portrett', name: 'Portrett', icon: 'c-portrett', desc: 'Familie, par og profilbilder' },
    { id: 'event', name: 'Event', icon: 'c-event', desc: 'Fest, konferanse og konsert' },
    { id: 'produkt', name: 'Produkt', icon: 'c-produkt', desc: 'Nettbutikk, mat og reklame' },
    { id: 'eiendom', name: 'Eiendom', icon: 'c-eiendom', desc: 'Bolig, hytte og næringsbygg' },
    { id: 'drone', name: 'Drone', icon: 'c-drone', desc: 'Luftfoto og dronefilm' },
    { id: 'reklamefilm', name: 'Reklamefilm', icon: 'c-reklamefilm', desc: 'Film for bedrifter' },
    { id: 'some', name: 'Sosiale medier', icon: 'c-some', desc: 'Korte filmer og innhold' }
  ];

  const PAL = [
    ['#D9CBBB', '#A99682', '#F4EDE4'], ['#9FB3C2', '#5E7383', '#F2E7D0'], ['#E2D6C8', '#B8A48F', '#FFFFFF'],
    ['#8FA58B', '#556B50', '#F3E7C6'], ['#C7B7D4', '#7E6A90', '#FBEFD9'], ['#BFD1DC', '#7C98A8', '#FFF6E0'],
    ['#D8B7A4', '#9A6C55', '#FFE9CF'], ['#A9B8A0', '#6F8566', '#EFE7D2'], ['#C9C3BA', '#8A847A', '#F7F1E6'],
    ['#2F3A4A', '#1D2430', '#E9C77B'], ['#E6D5C3', '#C29C7A', '#FFFFFF'], ['#B3C7C2', '#6E8D86', '#FDF2DA']
  ];

  // Bare ekte brukere. Frilansere og oppdrag hentes fra databasen.
  const FREELANCERS = [];

  // Oppdrag lagt ut av kunder (oppdragsbørsen)
  const JOBS = [];

  return { CATS, PAL, FREELANCERS, JOBS };
})();
