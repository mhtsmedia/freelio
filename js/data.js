/* Eksempeldata. Byttes ut med data fra backend (se README).
   Freelio starter med foto og video. Hver frilanser har en hovednisje (cat) og flere nisjer (niches). */
window.HDATA = (function () {
  const CATS = [
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

  // rv: [navn, stjerner, oppdrag og tidspunkt, tekst]
  const FREELANCERS = [
    { id: 'ingrid', name: 'Ingrid Solberg', ini: 'IS', col: '#3D5A80', role: 'Bryllupsfotograf', cat: 'bryllup', niches: ['bryllup', 'portrett'], tags: ['Foto', 'Bryllup', 'Portrett'], area: 'Sandvika', km: 2, mx: 56, my: 40, rating: 4.9, reviews: 64, jobs: 92, from: 6500, unit: '', respH: 2, resp: '2 timer', delD: 14, years: 8, free: true, verified: true, cap: 'Bryllup på Holmen, juni', pal: 0, joined: '2023',
      bio: 'Jeg fotograferer bryllup og portretter med naturlig lys. Rolig stil og lite oppstilling. Jeg reiser i hele Oslo og Viken uten tillegg.',
      pk: [['Vielse', 6500, '2 timer. Vielse og gruppebilder. 80 redigerte bilder.'], ['Halv dag', 9500, '5 timer fra forberedelser til middag. 250 redigerte bilder.'], ['Hel dag', 15000, '10 timer, hele dagen. 500 redigerte bilder og galleri på nett.']],
      sum: 'Kundene trekker frem rolig væremåte, naturlig lys og rask levering. To nevner at hun ble lenger enn avtalt uten ekstra kostnad.',
      rv: [['Kari og Even', 5, 'Bryllup, halv dag · august', 'Hun fikk oss til å slappe av foran kamera. Bildene kom etter 10 dager.'], ['Marte L.', 5, 'Portrett · mai', 'Tydelig avtale på forhånd og akkurat det vi ba om.'], ['Jon P.', 4, 'Vielse · juni', 'Flotte bilder. Litt treg å svare i starten.']] },
    { id: 'sofie', name: 'Sofie Nyhus', ini: 'SN', col: '#7A4E3B', role: 'Portrett- og familiefotograf', cat: 'portrett', niches: ['portrett', 'bryllup'], tags: ['Foto', 'Familie', 'Studio'], area: 'Stabekk', km: 4, mx: 72, my: 30, rating: 4.8, reviews: 37, jobs: 51, from: 2500, unit: '', respH: 1, resp: '1 time', delD: 21, years: 5, free: true, verified: true, cap: 'Familieportrett i studio', pal: 6, joined: '2024',
      bio: 'Varme farger og ekte øyeblikk. Jeg har eget studio på Stabekk og er vant til å fotografere barn.',
      pk: [['Portrett', 2500, '1 time i studio. 15 redigerte bilder.'], ['Familie ute', 3900, '1,5 time på stedet dere velger. 30 redigerte bilder.'], ['Bryllup, halv dag', 8000, '5 timer. 200 redigerte bilder.']],
      sum: 'Kundene skriver at hun svarer raskt og er god med barn. Noen synes leveringstiden er lang i høysesong.',
      rv: [['Emilie B.', 5, 'Familieportrett · april', 'Ungene elsket henne. Nydelige bilder.'], ['Tobias og Lin', 5, 'Bryllup · september', 'Rask på chat og veldig fleksibel.'], ['Anne K.', 4, 'Portrett · mars', 'Fine bilder, men tok tre uker.']] },
    { id: 'maja', name: 'Maja Strand', ini: 'MS', col: '#4F6B3A', role: 'Bryllupsfotograf og videograf', cat: 'bryllup', niches: ['bryllup', 'event'], tags: ['Foto', 'Video', 'Bryllupsfilm'], area: 'Oslo', km: 14, mx: 88, my: 14, rating: 4.9, reviews: 88, jobs: 140, from: 9000, unit: '', respH: 24, resp: '1 dag', delD: 10, years: 11, free: false, verified: true, cap: 'Bryllup i Nordmarka', pal: 3, joined: '2022',
      bio: 'Jeg leverer både foto og film fra samme dag. Mye erfaring med store bryllup og bedriftsarrangement.',
      pk: [['Halv dag foto', 9000, '5 timer. 250 bilder.'], ['Foto og film', 18000, '8 timer. 400 bilder og 3 minutters film.'], ['Hel dag', 22000, '12 timer. Foto, film og drone.']],
      sum: 'Svært erfaren og leverer raskt. Flere nevner at hun er vanskelig å få tak i på kort varsel.',
      rv: [['Ida og Sander', 5, 'Bryllup · juli', 'Filmen fikk alle til å gråte. Verdt hver krone.'], ['Vestby Bygg AS', 5, 'Event · mai', 'Profesjonell fra start til slutt.']] },
    { id: 'henrik', name: 'Henrik Aas', ini: 'HA', col: '#5B5F97', role: 'Event- og bedriftsfotograf', cat: 'event', niches: ['event', 'portrett', 'produkt'], tags: ['Foto', 'Konferanse', 'Ansattbilder'], area: 'Bekkestua', km: 5, mx: 34, my: 24, rating: 4.6, reviews: 21, jobs: 30, from: 3000, unit: '', respH: 3, resp: '3 timer', delD: 5, years: 3, free: true, verified: true, cap: 'Konferanse på Fornebu', pal: 8, joined: '2024',
      bio: 'Eventfoto og ansattbilder for bedrifter. Leverer innen fem dager.',
      pk: [['Ansattbilder', 3000, 'Opptil 10 personer. Bakgrunn medbrakt.'], ['Event 3 timer', 5500, '150 redigerte bilder.'], ['Event hel dag', 9500, '8 timer. 350 redigerte bilder.']],
      sum: 'Rask levering og ryddig. Noen ønsker mer variasjon i bildene.',
      rv: [['Nordvik Eiendom', 5, 'Ansattbilder · juni', 'Effektiv og hyggelig.'], ['Lars M.', 4, 'Event · april', 'Bra bilder, litt like.']] },
    { id: 'jonas', name: 'Jonas Berg', ini: 'JB', col: '#2F3A40', role: 'Videograf og dronepilot', cat: 'reklamefilm', niches: ['reklamefilm', 'drone', 'some'], tags: ['Video', 'Drone', 'Reklame'], area: 'Asker', km: 6, mx: 22, my: 62, rating: 4.8, reviews: 29, jobs: 47, from: 4500, unit: '', respH: 2, resp: '2 timer', delD: 10, years: 6, free: true, verified: true, cap: 'Reklamefilm for padelhall', pal: 9, joined: '2023',
      bio: 'Reklamefilm og dronefilm for bedrifter. Jeg leverer i 16:9 og 9:16. Godkjent dronepilot (A2).',
      pk: [['Dronefilm', 4500, '1 time flyging. 60 sekunder ferdig film.'], ['SoMe-pakke', 7000, '3 korte filmer til sosiale medier.'], ['Reklamefilm', 12000, '30 sekunder. Manus, opptak og klipp.']],
      sum: 'Kundene roser bildeutsnitt og fart i klippen. Én nevner at musikkvalg tok flere runder.',
      rv: [['Sandvika Padel', 5, 'Reklamefilm · mai', 'Filmen ga oss flere bookinger samme uke.'], ['Fjordhotellet', 5, 'Dronefilm · juni', 'Fantastiske bilder fra lufta.']] },
    { id: 'oskar', name: 'Oskar Dahl', ini: 'OD', col: '#6B4F2A', role: 'Eiendomsfotograf og drone', cat: 'eiendom', niches: ['eiendom', 'drone'], tags: ['Foto', 'Bolig', 'Luftfoto'], area: 'Billingstad', km: 7, mx: 44, my: 58, rating: 4.7, reviews: 112, jobs: 310, from: 2900, unit: '', respH: 2, resp: '2 timer', delD: 2, years: 6, free: true, verified: true, cap: 'Enebolig på Høvik', pal: 7, joined: '2022',
      bio: 'Bilder til boligannonser, levert innen 48 timer. Dronebilder og plantegning kan legges til.',
      pk: [['Leilighet', 2900, 'Opptil 20 bilder. Levert innen 48 timer.'], ['Enebolig', 4200, '30 bilder og 5 dronebilder.'], ['Bolig med film', 7500, '30 bilder, dronebilder og 60 sekunders film.']],
      sum: 'Meglerne roser rask levering og jevn kvalitet. Noen ønsker flere kveldsbilder.',
      rv: [['Megler Bærum', 5, 'Enebolig · september', 'Alltid levert til avtalt tid.'], ['Hanne T.', 4, 'Leilighet · mai', 'Fine bilder, men mørkt bad.']] },
    { id: 'line', name: 'Line Myhre', ini: 'LM', col: '#2E6E6A', role: 'Produkt- og matfotograf', cat: 'produkt', niches: ['produkt', 'some'], tags: ['Foto', 'Nettbutikk', 'Mat'], area: 'Lysaker', km: 7, mx: 76, my: 66, rating: 4.9, reviews: 26, jobs: 60, from: 3500, unit: '', respH: 3, resp: '3 timer', delD: 5, years: 9, free: true, verified: true, cap: 'Smykker til nettbutikk', pal: 5, joined: '2023',
      bio: 'Produktbilder til nettbutikk og meny. Eget studio med hvit bakgrunn og lysoppsett.',
      pk: [['10 produkter', 3500, 'Hvit bakgrunn. To vinkler per produkt.'], ['30 produkter', 8500, 'Hvit bakgrunn og 5 bilder i bruk.'], ['Meny og mat', 6000, 'Inntil 15 retter, tatt hos dere.']],
      sum: 'Kundene skriver at bildene øker salget og at hun gir gode råd om oppsett.',
      rv: [['Lys Smykker', 5, 'Produktbilder · august', 'Salget økte merkbart etter nye bilder.']] },
    { id: 'adrian', name: 'Adrian Kvam', ini: 'AK', col: '#8A3B5C', role: 'Bryllupsvideograf', cat: 'bryllup', niches: ['bryllup', 'event'], tags: ['Video', 'Bryllupsfilm', 'Taler'], area: 'Asker', km: 6, mx: 30, my: 44, rating: 5.0, reviews: 19, jobs: 33, from: 12000, unit: '', respH: 4, resp: '4 timer', delD: 30, years: 5, free: true, verified: true, cap: 'Bryllupsfilm på Støtvig', pal: 4, joined: '2024',
      bio: 'Bryllupsfilm med fokus på ekte øyeblikk og god lyd fra taler og løfter.',
      pk: [['Vielse', 12000, '3 minutters film fra vielsen.'], ['Halv dag', 18000, '5 minutters film og hele talene.'], ['Hel dag', 26000, '8 minutters film, taler og en kort film til sosiale medier.']],
      sum: 'Alle omtaler har fem stjerner. Kundene nevner lyden fra talene og at filmen føles personlig.',
      rv: [['Nora og Even', 5, 'Bryllup · august', 'Vi ser filmen hver måned.']] },
    { id: 'thea', name: 'Thea Lund', ini: 'TL', col: '#9A5B2E', role: 'Innholdsprodusent for sosiale medier', cat: 'some', niches: ['some', 'reklamefilm', 'produkt'], tags: ['Video', 'Reels', 'TikTok'], area: 'Sandvika', km: 1, mx: 52, my: 70, rating: 4.8, reviews: 54, jobs: 140, from: 3000, unit: '', respH: 1, resp: '1 time', delD: 4, years: 4, free: true, verified: true, cap: 'Reels for kafé', pal: 11, joined: '2023',
      bio: 'Korte filmer i 9:16 for Instagram og TikTok. Jeg planlegger, filmer og klipper samme uke.',
      pk: [['3 korte filmer', 3000, 'Opptil 20 sekunder hver. Musikk og tekst.'], ['Månedspakke', 9000, '10 filmer i måneden og en plan for innhold.']],
      sum: 'Kundene liker at hun kommer med idéer og leverer raskt.',
      rv: [['Kafé Torget', 5, 'Reels · hele våren', 'Følgerne økte jevnt hver måned.']] },
    { id: 'mats', name: 'Mats Berge', ini: 'MB', col: '#35507A', role: 'Konsert- og eventfotograf', cat: 'event', niches: ['event', 'portrett'], tags: ['Foto', 'Konsert', 'Fest'], area: 'Oslo', km: 12, mx: 82, my: 50, rating: 4.7, reviews: 15, jobs: 22, from: 2500, unit: '', respH: 5, resp: '5 timer', delD: 3, years: 4, free: true, verified: true, cap: 'Konsert på Rockefeller', pal: 1, joined: '2024',
      bio: 'Konsert, utdrikningslag og 50-årslag. Gode bilder i lite lys er min styrke.',
      pk: [['2 timer', 2500, '80 redigerte bilder.'], ['Kveld 4 timer', 4500, '200 redigerte bilder.']],
      sum: 'Kundene liker at han er diskré og får gode bilder i mørke lokaler.',
      rv: [['Lise R.', 5, '50-årslag · mars', 'Fanget stemningen perfekt.']] }
  ];

  // Oppdrag lagt ut av kunder (oppdragsbørsen)
  const JOBS = [
    { id: 'j101', cat: 'event', title: 'Fotograf til 50-årslag', desc: 'Middag for 40 gjester i selskapslokale på Høvik. Ønsker bilder av gjester, taler og stemning. Ca. 3 timer.', budget: 6000, date: '21.11.2026', area: 'Høvik', km: 4, posted: 'i dag', by: 'Tone R.', offers: 3, delivery: '100 redigerte bilder' },
    { id: 'j102', cat: 'some', title: 'Korte filmer til Instagram for bakeri', desc: 'Tre korte filmer fra bakingen tidlig om morgenen. Format 9:16. Vi har musikk selv.', budget: 8000, date: 'Fleksibel', area: 'Sandvika', km: 1, posted: 'i går', by: 'Bakeriet Torget', offers: 2, delivery: '3 filmer à 20 sekunder' },
    { id: 'j103', cat: 'bryllup', title: 'Bryllupsfotograf i juni', desc: 'Vielse i Haslum kirke og middag på hotell i Sandvika. Rundt 70 gjester. Ønsker naturlige bilder.', budget: 14000, date: '13.06.2027', area: 'Bærum', km: 3, posted: 'for 2 dager siden', by: 'Ali og Sara', offers: 5, delivery: '300 redigerte bilder' },
    { id: 'j104', cat: 'eiendom', title: 'Boligbilder til salg av leilighet', desc: '3-roms leilighet på 74 m². Trenger bilder før visning neste uke. Gjerne dronebilde av utsikten.', budget: 4000, date: 'Innen 15.11', area: 'Asker', km: 6, posted: 'i dag', by: 'Martin S.', offers: 1, delivery: '20 bilder og 1 dronebilde' },
    { id: 'j105', cat: 'portrett', title: 'Nye profilbilder til 12 ansatte', desc: 'Enkle portretter på kontoret med lys bakgrunn. Skal brukes på nettside og LinkedIn.', budget: 5000, date: 'Uke 48', area: 'Lysaker', km: 7, posted: 'i dag', by: 'Regnskap1 AS', offers: 4, delivery: '2 bilder per person' },
    { id: 'j106', cat: 'reklamefilm', title: 'Reklamefilm for treningssenter', desc: 'Kort film som viser senteret og stemningen på en gruppetime. Skal brukes i annonser.', budget: 15000, date: 'Desember', area: 'Bekkestua', km: 5, posted: 'for 3 dager siden', by: 'Puls Bekkestua', offers: 2, delivery: '30 sekunder i 16:9 og 9:16' },
    { id: 'j107', cat: 'drone', title: 'Dronefilm av hytte og tomt', desc: 'Hytte ved sjøen som skal leies ut. Ønsker luftfoto og en kort film i godt vær.', budget: 5000, date: 'Fleksibel', area: 'Hurum', km: 22, posted: 'i går', by: 'Jens P.', offers: 3, delivery: '10 bilder og 45 sekunders film' },
    { id: 'j108', cat: 'produkt', title: 'Produktbilder til nettbutikk', desc: '40 produkter, smykker. Hvit bakgrunn og noen bilder i bruk.', budget: 5000, date: 'Innen 01.12', area: 'Oslo', km: 12, posted: 'i dag', by: 'Lys Smykker', offers: 1, delivery: '60 bilder' },
    { id: 'j109', cat: 'bryllup', title: 'Videograf til vielse', desc: 'Liten vielse i tingretten med 15 gjester og middag etterpå. Ønsker en kort film.', budget: 9000, date: '05.12.2026', area: 'Sandvika', km: 1, posted: 'for 4 dager siden', by: 'Hanna og Ole', offers: 2, delivery: '3 minutters film' }
  ];

  return { CATS, PAL, FREELANCERS, JOBS };
})();
