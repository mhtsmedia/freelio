/* Tilkobling til Supabase. Publishable-nøkkelen er laget for å ligge i nettsiden.
   Tilgangsreglene i databasen (supabase/schema.sql) bestemmer hva hver bruker får lese og endre.
   Sett supabaseUrl til '' for å kjøre siden i demo-modus uten database. */
window.FREELIO_CONFIG = {
  supabaseUrl: 'https://hweftjtulzjripkkbdeb.supabase.co',
  supabaseKey: 'sb_publishable_E2sPGFAsmJ4sY8mY-UqgVA_krXARNal',
  // Kart-siden bruker OpenStreetMap. Lim inn en nøkkel fra Google Cloud (Maps JavaScript API) for å bruke Google Maps i stedet.
  // Begrens nøkkelen til nettadressen til nettsiden i Google Cloud. googleMapId er valgfri (Map ID fra Google Cloud).
  googleMapsKey: '',
  googleMapId: ''
};
