/* Eksempeldata. Byttes ut med data fra backend (se README). */
window.HDATA = (function () {
  const CATS = [
    { id: 'foto', name: 'Foto', icon: 'camera', desc: 'Bryllup, portrett, produkt' },
    { id: 'video', name: 'Video', icon: 'video', desc: 'Reklame, drone, event' },
    { id: 'design', name: 'Design', icon: 'pen', desc: 'Logo, profil, trykk' },
    { id: 'handverk', name: 'Håndverk', icon: 'hammer', desc: 'Snekker, maler, flis' },
    { id: 'musikk', name: 'Musikk', icon: 'music', desc: 'Vielse, fest, DJ' },
    { id: 'dyr', name: 'Dyr', icon: 'paw', desc: 'Hundepass, tur, stell' },
    { id: 'it', name: 'IT og nett', icon: 'code', desc: 'Nettside, app, support' },
    { id: 'undervisning', name: 'Undervisning', icon: 'book', desc: 'Lekser, språk, musikk' }
  ];

  const PAL = [
    ['#D9CBBB', '#A99682', '#F4EDE4'], ['#9FB3C2', '#5E7383', '#F2E7D0'], ['#E2D6C8', '#B8A48F', '#FFFFFF'],
    ['#8FA58B', '#556B50', '#F3E7C6'], ['#C7B7D4', '#7E6A90', '#FBEFD9'], ['#BFD1DC', '#7C98A8', '#FFF6E0'],
    ['#D8B7A4', '#9A6C55', '#FFE9CF'], ['#A9B8A0', '#6F8566', '#EFE7D2'], ['#C9C3BA', '#8A847A', '#F7F1E6'],
    ['#2F3A4A', '#1D2430', '#E9C77B'], ['#E6D5C3', '#C29C7A', '#FFFFFF'], ['#B3C7C2', '#6E8D86', '#FDF2DA']
  ];

  // rv: [navn, stjerner, oppdrag og tidspunkt, tekst]
  const FREELANCERS = [
    { id: 'ingrid', name: 'Ingrid Solberg', ini: 'IS', col: '#3D5A80', role: 'Bryllupsfotograf', cat: 'foto', tags: ['Bryllup', 'Portrett'], area: 'Sandvika', km: 2, mx: 56, my: 40, rating: 4.9, reviews: 64, jobs: 92, from: 6500, unit: '', respH: 2, resp: '2 timer', delD: 14, years: 8, free: true, verified: true, cap: 'Bryllup på Holmen, juni', pal: 0, joined: '2023',
      bio: 'Jeg fotograferer bryllup og portretter med naturlig lys. Rolig stil og lite oppstilling. Jeg reiser i hele Oslo og Viken uten tillegg.',
      pk: [['Vielse', 6500, '2 timer. Vielse og gruppebilder. 80 redigerte bilder.'], ['Halv dag', 9500, '5 timer fra forberedelser til middag. 250 redigerte bilder.'], ['Hel dag', 15000, '10 timer, hele dagen. 500 redigerte bilder og galleri på nett.']],
      sum: 'Kundene trekker frem rolig væremåte, naturlig lys og rask levering. To nevner at hun ble lenger enn avtalt uten ekstra kostnad.',
      rv: [['Kari og Even', 5, 'Bryllup, halv dag · august', 'Hun fikk oss til å slappe av foran kamera. Bildene kom etter 10 dager.'], ['Marte L.', 5, 'Portrett · mai', 'Tydelig avtale på forhånd og akkurat det vi ba om.'], ['Jon P.', 4, 'Vielse · juni', 'Flotte bilder. Litt treg å svare i starten.']] },
    { id: 'sofie', name: 'Sofie Nyhus', ini: 'SN', col: '#7A4E3B', role: 'Bryllup og portrett', cat: 'foto', tags: ['Portrett', 'Familie', 'Bryllup'], area: 'Stabekk', km: 4, mx: 72, my: 30, rating: 4.8, reviews: 37, jobs: 51, from: 2500, unit: '', respH: 1, resp: '1 time', delD: 21, years: 5, free: true, verified: true, cap: 'Familieportrett i studio', pal: 6, joined: '2024',
      bio: 'Varme farger og ekte øyeblikk. Jeg har eget studio på Stabekk og er vant til å fotografere barn.',
      pk: [['Portrett', 2500, '1 time i studio. 15 redigerte bilder.'], ['Halv dag', 8000, '5 timer. 200 redigerte bilder.'], ['Hel dag', 13000, '10 timer. 400 redigerte bilder.']],
      sum: 'Kundene skriver at hun svarer raskt og er god med barn. Noen synes leveringstiden er lang i høysesong.',
      rv: [['Emilie B.', 5, 'Familieportrett · april', 'Ungene elsket henne. Nydelige bilder.'], ['Tobias og Lin', 5, 'Bryllup · september', 'Rask på chat og veldig fleksibel.'], ['Anne K.', 4, 'Portrett · mars', 'Fine bilder, men tok tre uker.']] },
    { id: 'maja', name: 'Maja Strand', ini: 'MS', col: '#4F6B3A', role: 'Foto og video', cat: 'foto', tags: ['Bryllup', 'Film'], area: 'Oslo', km: 14, mx: 88, my: 14, rating: 4.9, reviews: 88, jobs: 140, from: 9000, unit: '', respH: 24, resp: '1 dag', delD: 10, years: 11, free: false, verified: true, cap: 'Bryllup i Nordmarka', pal: 3, joined: '2022',
      bio: 'Jeg leverer både foto og film fra samme dag. Mye erfaring med store bryllup og bedriftsarrangement.',
      pk: [['Halv dag foto', 9000, '5 timer. 250 bilder.'], ['Foto og film', 18000, '8 timer. 400 bilder og 3 minutters film.'], ['Hel dag', 22000, '12 timer. Foto, film og drone.']],
      sum: 'Svært erfaren og leverer raskt. Flere nevner at hun er vanskelig å få tak i på kort varsel.',
      rv: [['Ida og Sander', 5, 'Bryllup · juli', 'Filmen fikk alle til å gråte. Verdt hver krone.'], ['Vestby Bygg AS', 5, 'Event · mai', 'Profesjonell fra start til slutt.']] },
    { id: 'henrik', name: 'Henrik Aas', ini: 'HA', col: '#5B5F97', role: 'Event- og bedriftsfotograf', cat: 'foto', tags: ['Event', 'Bedrift', 'Produkt'], area: 'Bekkestua', km: 5, mx: 34, my: 24, rating: 4.6, reviews: 21, jobs: 30, from: 3000, unit: '', respH: 3, resp: '3 timer', delD: 5, years: 3, free: true, verified: true, cap: 'Konferanse på Fornebu', pal: 8, joined: '2024',
      bio: 'Eventfoto, produktbilder og ansattbilder for bedrifter. Leverer innen fem dager.',
      pk: [['Ansattbilder', 3000, 'Opptil 10 personer. Bakgrunn medbrakt.'], ['Event 3 timer', 5500, '150 redigerte bilder.'], ['Produktfoto', 4000, '20 produkter på hvit bakgrunn.']],
      sum: 'Rask levering og ryddig. Noen ønsker mer variasjon i bildene.',
      rv: [['Nordvik Eiendom', 5, 'Ansattbilder · juni', 'Effektiv og hyggelig.'], ['Lars M.', 4, 'Event · april', 'Bra bilder, litt like.']] },
    { id: 'jonas', name: 'Jonas Berg', ini: 'JB', col: '#2F3A40', role: 'Videograf og dronepilot', cat: 'video', tags: ['Reklame', 'Drone', 'SoMe'], area: 'Asker', km: 6, mx: 22, my: 62, rating: 4.8, reviews: 29, jobs: 47, from: 4500, unit: '', respH: 2, resp: '2 timer', delD: 10, years: 6, free: true, verified: true, cap: 'Reklamefilm for padelhall', pal: 9, joined: '2023',
      bio: 'Reklamefilm og dronefilm for bedrifter. Jeg leverer i 16:9 og 9:16. Godkjent dronepilot (A2).',
      pk: [['Dronefilm', 4500, '1 time flyging. 60 sekunder ferdig film.'], ['SoMe-pakke', 7000, '3 korte filmer til sosiale medier.'], ['Reklamefilm', 12000, '30 sekunder. Manus, opptak og klipp.']],
      sum: 'Kundene roser bildeutsnitt og fart i klippen. Én nevner at musikkvalg tok flere runder.',
      rv: [['Sandvika Padel', 5, 'Reklamefilm · mai', 'Filmen ga oss flere bookinger samme uke.'], ['Fjordhotellet', 5, 'Dronefilm · juni', 'Fantastiske bilder fra lufta.']] },
    { id: 'amira', name: 'Amira Haddad', ini: 'AH', col: '#8A3B5C', role: 'Grafisk designer', cat: 'design', tags: ['Logo', 'Profil', 'Trykk'], area: 'Oslo', km: 11, mx: 82, my: 50, rating: 5.0, reviews: 19, jobs: 33, from: 4000, unit: '', respH: 4, resp: '4 timer', delD: 7, years: 7, free: true, verified: true, cap: 'Logo og profil for kafé', pal: 4, joined: '2024',
      bio: 'Logo, visuell profil og trykksaker for små bedrifter. Jeg forklarer valgene mine, så du forstår hvorfor det fungerer.',
      pk: [['Plakat', 4000, 'Ett design i to formater.'], ['Logo', 6000, '3 skisser og 2 runder med endringer.'], ['Profilpakke', 14000, 'Logo, farger, fonter og maler.']],
      sum: 'Alle omtaler har fem stjerner. Kundene liker at hun forklarer valgene sine.',
      rv: [['Kafé Lille Bærum', 5, 'Profilpakke · mars', 'Hun forsto oss fra første møte.']] },
    { id: 'erik', name: 'Erik Lunde', ini: 'EL', col: '#6B4F2A', role: 'Snekker', cat: 'handverk', tags: ['Terrasse', 'Kjøkken', 'Småjobber'], area: 'Bærum', km: 3, mx: 44, my: 58, rating: 4.7, reviews: 42, jobs: 120, from: 650, unit: '/t', respH: 6, resp: '6 timer', delD: 14, years: 15, free: false, verified: true, cap: 'Terrasse i royalimpregnert', pal: 7, joined: '2022',
      bio: 'Terrasser, kjøkken og små oppdrag. Gratis befaring i Bærum og Asker. Registrert i Brønnøysundregistrene.',
      pk: [['Timepris', 650, 'Per time. Materialer kommer i tillegg.'], ['Liten jobb', 2600, 'Opptil 4 timer. Hyller, lister, dører.'], ['Terrasse 20 m²', 38000, 'Inkludert materialer. Endelig pris etter befaring.']],
      sum: 'Solid håndverk og ryddig etter seg. Noen opplevde at oppstart ble utsatt.',
      rv: [['Hege S.', 5, 'Terrasse · juni', 'Holdt pris og tid. Anbefales.'], ['Petter N.', 4, 'Kjøkken · februar', 'Godt arbeid, startet en uke senere enn avtalt.']] },
    { id: 'nora', name: 'Nora Vik', ini: 'NV', col: '#2E6E6A', role: 'Pianist og vokalist', cat: 'musikk', tags: ['Vielse', 'Middag', 'Minnestund'], area: 'Høvik', km: 4, mx: 30, my: 44, rating: 4.9, reviews: 26, jobs: 60, from: 3500, unit: '', respH: 3, resp: '3 timer', delD: 0, years: 9, free: true, verified: true, cap: 'Vielse i Haslum kirke', pal: 5, joined: '2023',
      bio: 'Musikk til vielse, middag og minnestund. Eget lydanlegg.',
      pk: [['Vielse', 3500, '3 sanger etter ønske.'], ['Middag 2 timer', 6000, 'Piano og vokal. Lydanlegg inkludert.']],
      sum: 'Kundene skriver at hun er godt forberedt og leser stemningen i rommet.',
      rv: [['Siri og Ola', 5, 'Vielse · august', 'Alle snakket om musikken etterpå.']] },
    { id: 'leo', name: 'Leo Karlsen', ini: 'LK', col: '#9A5B2E', role: 'Hundepasser', cat: 'dyr', tags: ['Tur', 'Dagpass', 'Overnatting'], area: 'Sandvika', km: 1, mx: 52, my: 70, rating: 4.8, reviews: 54, jobs: 200, from: 250, unit: '/tur', respH: 1, resp: '1 time', delD: 0, years: 4, free: true, verified: true, cap: 'Morgentur i Kadettangen', pal: 11, joined: '2023',
      bio: 'Turer, dagpass og overnatting. Politiattest og kurs i førstehjelp for hund.',
      pk: [['Tur 30 min', 250, 'Du får bilde fra turen.'], ['Dagspass', 600, '08 til 16 hjemme hos meg.'], ['Overnatting', 900, 'Per natt. Maks to hunder om gangen.']],
      sum: 'Pålitelig og sender alltid bilder. Hundene blir glade når han kommer.',
      rv: [['Mira og Bamse', 5, 'Turer · hele våren', 'Bamse elsker Leo.']] },
    { id: 'sindre', name: 'Sindre Holm', ini: 'SH', col: '#35507A', role: 'Nettsideutvikler', cat: 'it', tags: ['Nettside', 'Nettbutikk', 'SEO'], area: 'Lysaker', km: 7, mx: 76, my: 66, rating: 4.7, reviews: 15, jobs: 22, from: 8000, unit: '', respH: 5, resp: '5 timer', delD: 21, years: 6, free: true, verified: true, cap: 'Nettside for frisørsalong', pal: 1, joined: '2024',
      bio: 'Raske nettsider for små bedrifter. Du får opplæring, så du kan oppdatere selv.',
      pk: [['Enkel nettside', 8000, 'Opptil 5 sider. Mobilvennlig.'], ['Nettbutikk', 25000, 'Opptil 50 produkter og betaling med Vipps.']],
      sum: 'Kundene liker opplæringen og at sidene laster raskt.',
      rv: [['Salong Klipp', 5, 'Nettside · mars', 'Vi fikk flere bookinger på nett med en gang.']] },
    { id: 'hanna', name: 'Hanna Lie', ini: 'HL', col: '#6A4C8C', role: 'Mattelærer', cat: 'undervisning', tags: ['Matte', 'Leksehjelp', 'Eksamen'], area: 'Bekkestua', km: 5, mx: 38, my: 18, rating: 4.9, reviews: 31, jobs: 85, from: 450, unit: '/t', respH: 2, resp: '2 timer', delD: 0, years: 4, free: true, verified: true, cap: 'Eksamensforberedelse R1', pal: 10, joined: '2023',
      bio: 'Leksehjelp og eksamensforberedelse i matte for ungdomsskole og videregående. Lektor med politiattest.',
      pk: [['1 time', 450, 'Hjemme hos deg eller digitalt.'], ['Klippekort 10 timer', 4000, 'Fast tid hver uke.']],
      sum: 'Elevene sier hun forklarer på en ny måte når de står fast.',
      rv: [['Foreldre til Ella', 5, 'Leksehjelp · høst', 'Ella gikk fra 3 til 5 på et halvt år.']] }
  ];

  // Oppdrag lagt ut av andre kunder (oppdragsbørsen)
  const JOBS = [
    { id: 'j101', cat: 'foto', title: 'Fotograf til 50-årslag', desc: 'Middag for 40 gjester i selskapslokale på Høvik. Ønsker bilder av gjester, taler og stemning. Ca. 3 timer.', budget: 6000, date: '21.11.2026', area: 'Høvik', km: 4, posted: 'i dag', by: 'Tone R.', offers: 3, delivery: '100 redigerte bilder' },
    { id: 'j102', cat: 'video', title: 'Kort film til Instagram for bakeri', desc: 'Tre korte filmer fra bakingen tidlig om morgenen. Format 9:16. Vi har musikk selv.', budget: 8000, date: 'Fleksibel', area: 'Sandvika', km: 1, posted: 'i går', by: 'Bakeriet Torget', offers: 2, delivery: '3 filmer à 20 sekunder' },
    { id: 'j103', cat: 'handverk', title: 'Montere kjøkken fra IKEA', desc: 'Kjøkken er levert og står i esker. Ca. 4 meter benk og høyskap. Vann og strøm er klart.', budget: 15000, date: 'Uke 48', area: 'Stabekk', km: 4, posted: 'for 2 dager siden', by: 'Ali H.', offers: 5, delivery: 'Ferdig montert kjøkken' },
    { id: 'j104', cat: 'design', title: 'Logo til ny frisørsalong', desc: 'Moderne og enkel logo. Skal brukes på skilt, Instagram og visittkort.', budget: 7000, date: 'Innen 15.12', area: 'Asker', km: 6, posted: 'i dag', by: 'Salong Nord', offers: 1, delivery: 'Logo i alle formater' },
    { id: 'j105', cat: 'dyr', title: 'Hundelufter mandag til fredag', desc: 'Labrador på 3 år trenger tur midt på dagen, ca. 45 minutter.', budget: 1500, date: 'Fra 01.12', area: 'Sandvika', km: 1, posted: 'i dag', by: 'Kristin M.', offers: 4, delivery: '5 turer per uke' },
    { id: 'j106', cat: 'musikk', title: 'Musiker til julebord', desc: 'Julebord for 30 ansatte. Ønsker rolig musikk under middagen, ca. 2 timer.', budget: 7000, date: '11.12.2026', area: 'Lysaker', km: 7, posted: 'for 3 dager siden', by: 'Regnskap1 AS', offers: 2, delivery: '2 timer livemusikk' },
    { id: 'j107', cat: 'it', title: 'Oppdatere nettside og koble til booking', desc: 'Har en gammel WordPress-side. Trenger ny forside og bookingsystem.', budget: 12000, date: 'Fleksibel', area: 'Bekkestua', km: 5, posted: 'i går', by: 'Fysio Bekkestua', offers: 3, delivery: 'Ny forside og booking' },
    { id: 'j108', cat: 'undervisning', title: 'Leksehjelp i matte, 10. trinn', desc: 'To timer i uka frem til eksamen. Gjerne hjemme hos oss.', budget: 900, date: 'Fra neste uke', area: 'Høvik', km: 4, posted: 'for 4 dager siden', by: 'Jens P.', offers: 2, delivery: '2 timer per uke' },
    { id: 'j109', cat: 'foto', title: 'Produktbilder til nettbutikk', desc: '40 produkter, smykker. Hvit bakgrunn og noen bilder i bruk.', budget: 5000, date: 'Innen 01.12', area: 'Oslo', km: 12, posted: 'i dag', by: 'Lys Smykker', offers: 1, delivery: '60 bilder' }
  ];

  return { CATS, PAL, FREELANCERS, JOBS };
})();
