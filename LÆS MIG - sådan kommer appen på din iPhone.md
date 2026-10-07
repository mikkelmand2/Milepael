# Milepæl – sådan kommer appen på din iPhone (gratis)

Appen hedder **Milepæl** på din telefon. Projektfilerne hedder stadig `Projektstyring`, så guiden nedenfor passer.

**TL;DR:** Pak zip-filen ud på din Mac, dobbeltklik på `Projektstyring.xcodeproj`, vælg dit Apple ID som "Team", sæt iPhonen til med kabel, og tryk på ▶. Det koster 0 kr. Med et gratis Apple ID skal du trykke ▶ igen hver 7. dag, ellers vil appen ikke åbne (dine opgaver bliver liggende).

---

## Det skal du bruge
- Din Mac med **Xcode 16 eller nyere** (gratis i App Store).
- Din iPhone med **iOS 18 eller nyere**.
- Et USB-kabel.
- Dit almindelige Apple ID (det, du bruger til App Store).

## Trin for trin

**1. Pak filerne ud**
Dobbeltklik på `projektstyring.zip`. Nu har du en mappe, der hedder `projektstyring`.

**2. Åbn projektet**
Gå ind i mappen og dobbeltklik på **`Projektstyring.xcodeproj`** (det blå ikon). Xcode åbner.
Hvis Xcode spørger, om du stoler på projektet, så tryk **"Trust and Open"**.

**3. Log ind med dit Apple ID i Xcode**
Øverst i menuen: **Xcode → Settings… → Accounts**. Tryk på **+** nederst, vælg **Apple ID**, og log ind.

**4. Vælg dig selv som "Team"**
- Klik på det blå **Projektstyring**-ikon helt øverst i venstre side.
- Klik på **Projektstyring** under "TARGETS" i midten.
- Vælg fanen **Signing & Capabilities**.
- Ved **Team** vælger du **"Dit navn (Personal Team)"**.

> Står der en rød fejl om "Bundle Identifier"? Så ret teksten `dk.mikkel.projektstyring` til noget helt dit eget, fx `dk.mikkelbach.projektstyring`. Det skal bare være unikt.

**5. Sæt iPhonen til**
Sæt iPhonen til Mac'en med kablet, lås telefonen op, og tryk **"Stol på"** på telefonen.

**6. Slå "Udviklertilstand" til på iPhonen (kun første gang)**
På iPhonen: **Indstillinger → Anonymitet & sikkerhed → Udviklertilstand → slå til**. Telefonen genstarter. Tryk **"Slå til"**, når den spørger igen.
(Punktet dukker først op, efter telefonen har været sat til Xcode.)

**7. Vælg din iPhone og tryk ▶**
Øverst i midten af Xcode står der et enhedsnavn. Klik på det og vælg **din iPhone**. Tryk så på den store **▶**-knap øverst til venstre (eller tast ⌘R). Første gang tager det et par minutter.

**8. Stol på dig selv som udvikler (kun første gang)**
Hvis iPhonen siger "Udvikler ikke tillid": gå til **Indstillinger → Generelt → VPN og enhedsadministration**, tryk på dit Apple ID og vælg **"Stol på"**. Tryk ▶ i Xcode igen.

Færdig! Appen ligger nu på din hjemmeskærm som **Milepæl** med det pink flag-ikon. I mørk tilstand får ikonet automatisk en mørk udgave.

## Hver 7. dag
Med et gratis Apple ID udløber appen efter 7 dage. Så sætter du bare telefonen til, åbner projektet og trykker ▶ igen. **Slet ikke appen fra telefonen** – så forsvinder dine opgaver. Når du opdaterer med ▶, bliver de liggende.

Tip: Efter første gang kan du slippe for kablet: **Window → Devices and Simulators** i Xcode, vælg din iPhone, og sæt hak i **"Connect via network"**.

---

## Sådan bruger du appen
| Det vil du | Sådan gør du |
|---|---|
| Ny opgave | Tryk på den runde **+**-knap |
| Lang termin hurtigt | Brug knapperne **+1 uge / +1 md. / +3 mdr. / +6 mdr. / +1 år** |
| Se en opgave | Tryk på kortet (det "zoomer" ind) |
| Underopgave | Inde i opgaven: **Tilføj underopgave** – hver har sin egen termin |
| Sæt flueben | Tryk på cirklen ved underopgaven |
| Ret en underopgave | Tryk på teksten |
| Færdig med opgave | Stryg kortet mod højre |
| Slet opgave | Stryg kortet mod venstre |
| Flere valg | Hold fingeren på kortet |

**Overblik øverst:** Ringen viser din samlede fremdrift, bjælken viser hvor meget dine opgaver haster, og tallene under den (Over tid, I dag, 7 dage, 30 dage, Senere) kan trykkes på for at hoppe direkte til gruppen.

**Indstillinger (tandhjulet øverst til højre):** Vælg Lys, Mørk eller Automatisk tema. Slå visning af mærkater og noter på forsiden til eller fra. Slå påmindelser til eller fra, og vælg tidspunktet.

**Noter og mærkater:** Ligger foldet sammen i "Noter og mærkater", når du opretter en opgave. Brug dem, hvis du vil, eller lad være. Tryk på et mærkat øverst på forsiden for kun at se de opgaver.

**Farverne viser, hvor tæt deadline er:**
🔴 over tid · 🟠 i dag og næste 7 dage · 🟡 næste 30 dage · 🔵 senere · 🟢 færdig

**Påmindelser:** Appen giver dig som standard en notifikation kl. 9:00 tre dage før og på dagen for en opgaves deadline, og dagen før og på dagen for underopgaver. Sig "Tillad", når den spørger første gang.

**Eksempler:** Første gang ligger der tre eksempel-opgaver, så du kan se, hvordan det ser ud. Stryg dem væk, når du er klar.

---

## Hvis det driller
- **"Untrusted Developer"** → se trin 8.
- **Din iPhone står ikke på listen** → lås telefonen op, tryk "Stol på", og tjek trin 6.
- **Rød fejl ved Signing** → se boksen under trin 4.
- **"iOS version too old"** → opdatér iPhonen til iOS 18 eller nyere.

## Deling med dit team senere
Appen gemmer lige nu alt lokalt på din telefon. Datamodellen er bygget, så den kan synkroniseres via iCloud senere (alle opgaver og underopgaver har allerede felter til "tildelt til"). Men deling via iCloud eller TestFlight kræver Apples betalte udviklerprogram (99 USD om året). Det kan vi tage stilling til, hvis appen bliver en succes.

## Logo
Logoet ligger i mappen `Logo`: `Milepael-logo.svg` (kan skaleres uendeligt, fx til en præsentation) og `Milepael-logo-1024.png`. Der er også en mørk udgave (`Milepael-logo-dark.svg`). Begge er allerede lagt ind som app-ikon.

## Kilder
- Apple: [Enabling Developer Mode on a device](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- Apple: [Choosing a Membership (gratis vs. betalt)](https://developer.apple.com/support/compare-memberships/)
- Apple Developer Forums: [How to install on a personal device](https://developer.apple.com/forums/thread/823137)
- Expo docs: [iOS Developer Mode](https://docs.expo.dev/guides/ios-developer-mode/)
