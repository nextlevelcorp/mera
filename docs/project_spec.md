4. project_spec.md — Ürün
Bölüm 4, 5 ve 6 birlikte project_spec.md dosyasını oluşturur; notlarının düzenlenmiş ve genişletilmiş halidir. Repoya gireceği için İngilizcedir. Assumption yazan satırlar benim doldurduğum boşluklardır; onaylaman veya düzeltmen gerekir.
4.1 Vision
Mera is a shore-fishing RPG that plays like a relaxed exploration game and resolves like a simulation. The player walks real coastline in a top-down view, picks a spot, rigs tackle for the conditions, and casts. The cast switches to a first-person view over the water, where the bite and the fight happen. What the player learns in the game should hold up on a real shore.
4.2 Who it is for and what it solves
Player
What they want
What existing games give them
Hobby anglers
Their own waters, real species, tackle choices that matter
Arcade timing bars or invented fish
Cozy and collection players
A calm world, a log to fill, steady mastery
Shallow fishing mini-games inside bigger titles
People curious about fishing
A way to learn rigs, bait, timing and reading water without gear
Videos and forums, nothing to practise on
These three segments are assumptions. Phase 0 research tests them and looks for evidence of demand before any gameplay code is written.
4.3 Product goals
1. Retention through mastery. Players return because conditions change daily and skill carries over, not because of timers or pressure mechanics.
2. Teach real fishing. Every outcome can be explained by depth, feeding window, tackle match and line handling.
3. Community knowledge (post-MVP). Aggregate play and player reports show where and when species are caught.
4.4 Design pillars
1. Real places, honestly sourced. Every spot is a real location. Species lists and tips cite a source in the data file, and anything invented is labelled a game-design fill.
2. Realism you can read. Depth, feeding time and line tension decide the outcome. Float, surface rings, depth line and tension bar always show enough to reason about it.
3. A living shore. Everything that moves follows Nature of Code principles: forces, springs, particles, steering agents, oscillation, Perlin noise.
4. Calm, then tense. Walking and waiting are relaxed. The bite and the fight are short and intense, carried by sound and vibration.
5. Collection and mastery. No hypercasual one-tap rounds.
4.5 Core loop
1. Explore the coast top-down and choose a spot (structure, depth, exposure to wind).
2. Read conditions: time of day, wind, water clarity, season.
3. Rig: rod, reel, line, terminal tackle, bait or lure.
4. Cast: the view switches to first person.
5. Wait and read the water: float movement, rings, line behaviour.
6. Bite: nibbles versus a committed take; strike timing matters.
7. Fight: manage tension and drag while the fish runs and tires.
8. Land, identify, log. Earn experience, money and knowledge entries.
9. Upgrade tackle, unlock spots, chase missing species and personal records.
4.6 MVP scope
In the MVP
Not in the MVP
Shore fishing only
Boats, sonar, deep-sea zones
Turkey: 3–5 real spots in one region (assumption)
Worldwide spot coverage
15–25 real species with sourced behaviour (assumption)
Monthly live data updates
Top-down exploration and first-person fishing view
Multiplayer, leaderboards, shared catch map
Wind-driven waves, water clarity, time of day
Accounts, cloud saves, backend
Attribute database for fish, spots, tackle, bait, angler
Monetisation, ads, store builds
English, Turkish, Spanish
Further languages
Local save, debug menu, web build on GitHub Pages
Native iOS and Android builds
4.7 After the MVP
Version
Content
Gate to start
0.1 Vertical slice
One spot, 3–5 species, full cast-to-land loop
Phase 1 approved
0.5 MVP
Scope in 4.6
The slice is fun in playtests
1.0 Release
Native builds, store listing, security audit, full test pass
MVP retention evidence
1.x World
Spots worldwide, researched region by region
Data pipeline proven on Turkey
2.0 Community
Player catch reports, heat maps, collaboration
Backend, privacy and moderation design approved
Ongoing
Monthly research pass on fish status and regulations
Scheduled task after release
4.8 Player funnel (to be measured)
Discover → open the web build → first cast within two minutes → first fish landed → return next day → third spot unlocked → log half complete. Phase 1 sets a target for each step and decides how to measure it without collecting personal data.
5. project_spec.md — Oyun sistemleri ve veri modeli
Bu bölüm "Championship Manager mantığı" isteğini somutlaştırır: her varlık 1–20 ölçeğinde niteliklerle tanımlanır ve sonuç bu niteliklerin eşleşmesinden doğar. Nitelik listeleri başlangıç önerisidir; Faz 2'de kesinleşir.
5.1 Views
• Exploration: top-down 2D, in the spirit of Stardew Valley and Nightshoal. Walking, spot selection, rigging, shop, log.
• Fishing: first-person view over the water from the cast until the fish is landed or lost. It keeps a centred 1280×720 design rectangle and draws backgrounds to the screen edges.
• Fish visibility: the fish is not shown during the wait or the early fight. The player reads it through float, line, rod bend and splashes. It becomes visible only near the shore, at a distance set by water clarity. Thrashing at the surface depends on species and size.
5.2 Simulation systems
System
Inputs
What the player sees
Environment
Time of day, season, wind speed and direction, water clarity, temperature
Light, wave height and direction, how far into the water you can see
Water and waves
Wind vector, shore exposure, depth profile
Wave simulation that grows with wind; clear water shows the near bottom
Presence
Spot, season, time, wind, depth
Which species can be there now
Attraction
Bait or lure, rig depth, presentation versus species preferences
Interest, nibbles, refusals
Bite
Species caution and aggression, hook size versus mouth size
Float dips, rings, a clear take or a tentative one
Fight
Fish strength and stamina; rod power, line strength, drag, angler skill
Tension bar, runs, rod bend, sound, vibration
Landing
Fish size, shore type, tired state
Fish appears near shore; landed or lost at the edge
Progression
Catch log, experience, money
Angler attributes rise, tackle and spots unlock
Motion uses Nature of Code techniques: the line and float as a spring-mass system, fish as steering agents, splashes as particles, wind and current from Perlin noise, swell as oscillation.
5.3 Attribute database
Every record has an id, an English source name, localisation keys, and a source field (URL or citation) or design_fill: true.
Entity
Example attributes (1–20 unless a unit is given)
Species
Strength, stamina, speed, caution, aggression, schooling, preferred depth range (m), temperature range (°C), activity by hour and by season, salinity, mouth size, diet tags, surface thrash, min/max/record length (cm) and weight (kg), rarity
Spot
Coordinates, region, shore type (rock, sand, pier, harbour), depth profile, bottom type, structure, exposure by wind direction, typical clarity, current, access difficulty, pressure, species list with seasonal weights
Rod
Length (m), power, action, casting weight range (g), sensitivity, durability
Reel
Size, drag maximum (kg), retrieve ratio, smoothness, line capacity
Line
Type (mono, braid, fluorocarbon), diameter (mm), breaking strain (kg), stretch, visibility, abrasion resistance
Terminal tackle
Hook size and pattern, float type and buoyancy, sinker weight, leader length
Bait and lure
Type, size, scent, flash, action, durability, target diet tags, effective depth
Angler (player)
Casting distance, casting accuracy, strike timing, fight control, knot strength, patience, species knowledge, spot knowledge
A catch attempt is resolved in stages, each a match between attributes: is the species present, does the presentation reach it, does it commit, does the hook hold, does the tackle survive the fight. Each stage logs its inputs so the result can be explained to the player and checked in tests.
5.4 Data sourcing rules
• Spots come from real map locations. Coordinates, shore type and depth data record where they came from.
• Species biology comes from published references. Local catch patterns come from fishing reports and regional guides, with the source noted.
• Each data source's licence is checked and recorded before its data ships (see section 9).
• Where no source exists, the value is a game-design fill and is labelled as one, in the data and in the in-game log.
• Data is stored in data files (the earlier prototype used fishing_spots.gd). Format and schema validation are decided in phase 2.
5.5 Localisation
English is the source language. Turkish and Spanish ship in the MVP. Species carry scientific name plus local common names per language.
6. project_spec.md — Teknik gereksinimler, test ve yayın kapıları
Teknik kararların senin notlarından alındı; eklediğim kısımlar test, CI ve yayın kapılarıdır.
6.1 Platform and engine
Item
Decision
Engine
Godot 4.4, GDScript. The exact patch version is pinned in the repo and in CI
Design space
1280×720, window/stretch/mode = canvas_items, aspect expand. Wider phones see more of the world
Touch controls
Pinned to the screen corners
First-person view
Centred 1280×720 design rectangle; backgrounds drawn to the edges
Orientation
Landscape only. Portrait shows a "turn your phone" screen (device_guard.gd)
Safe areas
Left to the browser's own insets on the web build
Web
Single-threaded export, deployed to GitHub Pages by CI
Native (planned)
Godot's own iOS and Android exporters
Not used
Capacitor. It wraps the web build, adds a JavaScript layer, and gives up native performance, native ad and store SDKs and Godot's mobile features, with no gain over the built-in exporters
6.2 Architecture principles
• Simulation core (environment, presence, bite, fight) is plain GDScript with no scene dependencies, deterministic under a seed, and testable headless.
• Rendering and input read simulation state; they do not own rules.
• Data layer loads and validates the attribute database at start-up and fails loudly on schema errors.
• One autoload for game state and save; saves are versioned so later builds can migrate them.
• Localisation through Godot's translation system, with a check that every key exists in en, tr and es.
• The MVP has no backend. Nothing in the exported build is secret.
6.3 Performance budget
The water is the main risk: realistic waves and clarity effects must run in a single-threaded web export on a mid-range phone. Phase 2 sets a target frame rate and a test device, and the water shader is prototyped and measured before the art direction is locked.
6.4 Testing
• Automated: unit tests for every simulation stage; data validation tests; a CI job that exports the web build on each pull request.
• Smoke test in the browser: the built game loads, reaches the first cast, and logs no errors.
• Playability: each thread plays the flow it changed and reports what it observed.
• Debug menu for manual testing: jump to any spot; set time, season, wind and clarity; force a bite; choose species and size; grant tackle and money; show simulation inputs on screen. Present in development builds only.
6.5 Repository layout (proposed)
mera/
  CLAUDE.md
  .claude/rules/          # short rule files loaded by every thread
  .env.example            # variable names only, no values
  .github/workflows/      # test, export, deploy to Pages
  docs/
    project_spec.md
    prd.md
    research.md
    architecture.md
    changelog.md
    project_status.md
    reference_docs.md
    release_checklist.md
  game/                   # Godot project
    data/                 # species, spots, tackle, bait
    sim/                  # simulation core
    scenes/
    ui/
    locale/
    tests/
6.6 Release gates
Nothing ships to a store until all four are closed and recorded in docs/release_checklist.md.
1. Full test pass and audit: complete playthrough on target devices, performance check, save migration check, localisation check in three languages.
2. Security audit: dependencies, CI secrets, exported build contents, any network calls; later, the backend and player data.
3. Store and legal procedure: developer accounts, age rating, privacy policy, data-safety forms, attribution and licence notices for map, species and asset sources. Claude lists every required step for the target stores at that time and reports what is missing.
4. Owner sign-off.
6.7 After release
A monthly scheduled research task checks for changes in species status, seasons and local regulations, proposes data updates with sources, and opens a pull request for review.
7. Repo ve araç tarafı
Repo dosyalarını elle yazmana gerek yok; ilk thread aşağıdaki tariflere göre oluşturur ve onayına sunar.
7.1 CLAUDE.md
Kısa tutulur (bir-iki ekran), çünkü her thread'de tamamı okunur. Dört başlık istedin; içerikleri şöyle olmalı:
Başlık
İçerik
Project goal
İki cümlelik vizyon, beş tasarım ilkesi, docs/project_spec.md bağlantısı
Design style guide
Görünümler (top-down / birinci şahıs), 1280×720 tasarım alanı, dokunmatik düzen, renk ve tipografi kararları, GDScript adlandırma kuralları
Constraints & policies
Godot sürümü, tek iş parçacıklı web export, veri kaynak gösterme kuralı, sır yasağı, branch ve PR kuralları, onay gerektiren işler
Documentation
Hangi dosya ne zaman güncellenir; build, test ve export komutları
7.2 Otomatik dokümantasyon
Dosya
Ne tutar
Ne zaman güncellenir
docs/architecture.md
Modüller, veri akışı, alınan mimari kararlar
Yapısal değişiklikte
docs/changelog.md
Sürüm ve build başına değişiklikler
Her birleşen PR'da
docs/project_status.md
Faz, biten ve sıradaki işler, açık riskler
Her kilometre taşında
docs/reference_docs.md
Dış kaynaklar, veri kaynakları ve lisansları
Yeni kaynak eklendiğinde
Kural hem proje talimatlarında hem CLAUDE.md'de yazılıdır. Hook'lar proje thread'lerinde çalışmadığı için bunu bir hook'la zorlayamazsın; güvence olarak CI'da "kod değişti ama changelog değişmedi" kontrolü eklenebilir.
7.3 .env
MVP'de backend olmadığı için oyunun kendisi .env kullanmaz. Web export'a giren her şey herkese açıktır; build içine anahtar konmaz.
• Repoya yalnız .env.example girer (değişken adları, değer yok). .env .gitignore içindedir.
• Thread'lerin ihtiyaç duyduğu değerler Project settings → Environment altında tanımlanır.
• CI'ın ihtiyaç duyduğu değerler GitHub Secrets'ta durur.
• Bugün için gereken tek şey Godot sürüm değişkenidir. İleride backend anahtarları geldikçe eklenir.
7.4 Eklentiler
Bu depoların ve mağaza sayfalarının içeriğini incelemedim; aşağıdaki öneriler adlarına ve bilinen amaçlarına dayanır. Üçüncü taraf bir eklenti thread'lerine talimat ve araç ekler; kurmadan önce kaynağını oku. Listenin tamamını aynı anda kurma: birkaçı kendi iş akışını dayatır ve birbiriyle çakışır.
Eklenti
Öneri
Gerekçe
Code review
İlk günden kur
Her PR için ikinci göz
Playwright
Web build çıkınca kur
Tarayıcıda yükleme, konsol hatası ve ekran görüntüsü testi. Godot tek bir canvas çizdiği için düğme düzeyinde otomasyon sınırlıdır
Karpathy skills
İlk günden kur
Sade, küçük ve doğrulanabilir değişiklik disiplini
feature-dev veya Superpowers veya Compound engineering
Yalnız birini seç
Üçü de planla-uygula-gözden geçir akışı getirir. Birini dene, tutmazsa değiştir
frontend-design
Erteleyebilirsin
Web arayüzleri (HTML/CSS) içindir; Godot UI'ına katkısı dolaylı. Tanıtım sayfası yaparken işe yarar
7.5 Skill'ler
Skill'ler claude.ai hesabında etkinleştirilir; repoya koymak proje thread'lerine taşımaz.
Skill
Öneri
Gerekçe
Game-studios
Faz 2'de değerlendir
Oyun stüdyosu rollerini kapsayan büyük bir paket; 7.4'teki iş akışı eklentisiyle çakışabilir
Founder
Faz 0–1'de kullan
Pazar, PMF ve kapsam tartışmaları için. Listende iki kez yazılı; tek kurulum yeter
Caveman
İsteğe bağlı
Yanıtları kısaltıp token harcamasını azaltır; tasarım tartışmalarında kapalı tut
7.6 MCP bağlantıları
• GitHub: thread'lerin repoyu klonlayıp PR açması Claude GitHub App ile olur (Bölüm 2, adım 2). Issue ve proje panosu gibi işlemler için GitHub bağlayıcısı hesap düzeyinde eklenir.
• Ücretli görsel servisi kullanılmıyor; görsel ve ses kaynakları Bölüm 7.8'de.
• Proje sohbetinin kendisinde bağlayıcı yoktur; bağlayıcı gerektiren işi görev olarak bir thread'e gönder.
7.7 Ajanlar ve slash komutları
Repodaki .claude/agents/ ve .claude/commands/ proje thread'lerinde yüklenmez. Üç rolün karşılığı:
İstediğin rol
Projede karşılığı
Orkestratör
Proje sohbetinin kendisi. Görevleri böler, thread açar, sonuçları raporlar
Project finance
docs/finance.md + aylık zamanlanmış görev. Abonelikleri, mağaza ücretlerini (geliştirici hesapları), araç ve varlık maliyetlerini, ileride gelir modelini izler. Claude muhasebeci değildir; vergi ve şirket konularını bir mali müşavire danış
Security auditor
.claude/rules/security.md kontrol listesi + sürüm öncesi ayrı bir denetim thread'i. Kodu yazan thread kendi işini denetlemez
Bu rolleri gerçek alt ajan olarak istiyorsan iki yol var: ajan tanımlarını kendi eklentin olarak paketleyip Project settings → Plugins'e eklemek, veya ilgili işi proje dışında tek repolu bir bulut oturumunda çalıştırmak (orada .claude/agents/ otomatik yüklenir).
7.8 Ücretsiz görsel ve ses kaynakları
Ücretli bir servis yerine aşağıdaki kaynaklar kullanılır. Her kaynak, kullanıldığı dosyayla birlikte docs/reference_docs.md içinde ad, adres, lisans ve atf metniyle kaydedilir. Lisanslar yayın öncesi tek tek doğrulanır.
Kaynak
Ne için
Lisans
Not
Kenney.nl
2D sprite, arayüz, ikon, bazı ses
CC0
Atf zorunlu değil; yine de kaydet
Poly Haven
Doku, HDRI, bazı modeller
CC0
Su ve gök referansı için
ambientCG
PBR doku: kum, kaya, ıslak zemin
CC0
Kıyı zemini için
OpenGameArt.org
Karmaşık sprite ve müzik
Dosya başına değişir (CC0, CC-BY, GPL)
Her dosyanın lisansını tek tek kontrol et
Freesound.org
Dalga, rüzgar, makara, balık çırpması gibi ses efektleri
Ses başına değişir (CC0, CC-BY)
CC-BY ise kredi sayfası gerekir
Incompetech
Müzik
CC BY 4.0
Oyunda kredi sayfası zorunlu
jsfxr / sfxr
Retro ses efekti üretimi
Açık kaynak
Üretilen sesleri kaydet
Krita
Sprite, boyama, doku çizimi
GPL
GPU gerektirmez; ana çizim aracı
Yerel ComfyUI / Stable Diffusion
Kavram görseli, doku taslagı
Model başına değişir
Güçlü bir GPU gerekir; her modelin ticari kullanım şartını kontrol et
Godot içi araçlar
Su dalgası, parçacık, Perlin gürültüsü (FastNoiseLite), tween, ses çalma, shader
Godot MIT
Ek maliyet yok; plan zaten bunları gerektiriyor
Kredi sayfası oyunun içinde "Credits" ekranında tutulur ve tüm CC-BY kaynakları listeler.
7.9 Diğer konular, teknikler ve ücretsiz kaynaklar
Konu
Kaynak / teknik
Ne için
Dikkat
Balık biyolojisi
FishBase (fishbase.se)
Tür boy, derinlik, sıcaklık, beslenme verisi
Altını yazıp kullanım şartlarını doğrula
Hava ve deniz
Open-Meteo marine ve weather API
Rüzgar, dalga yönü ve yüksekliği, su sıcaklığı
Anahtarsız çalışır; ticari kullanımda ücretli plan gerekebilir, kontrol et
Deniz verisi
Copernicus Marine Service
Ayrıntılı deniz sıcaklığı, akıntı, berraklik
Ücretsiz kayıt gerekir
Harita ve kıyı
OpenStreetMap, Natural Earth
Kıyı çizgisi, yer adları, sınırlar
OSM: ODbL, atf zorunlu; Natural Earth: kamu malı
Av mevzuatı
T.C. Tarım ve Orman Bakanlığı su ürünleri yönetmelikleri
Av dönemleri, minimum boy, yasak alanlar
Oyunda gösterilecekse resmi güncel metinden al; her ay güncelleme taramasına dahil et
Test
GUT (Godot Unit Test) eklentisi
Simülasyon çekirdeğinin headless testleri
Ücretsiz; Playwright ile birlikte
Çeviri
Godot CSV çeviri sistemi
en, tr, es metinleri
Yerleşik, ücretsiz
Yayın
GitHub Pages, GitHub Actions
Web yayını ve CI
Herkese açık repoda Actions ücretsiz; özel repoda aylık dakika sınırı var
Analitik
GoatCounter
Gizlilikçi ziyaretçi sayımı
Kişisel veri toplamadığını doğrula; KVKK ve GDPR
Claude becerileri
frontend-design (tanıtım sayfası), xlsx (tür ve mera tablolarını kontrol), pdf (kaynak raporlarını okuma)
Yardımcı iş akışları
Hesabında etkin olanı kullan; Godot oyununun kendisi için gerekmez
Bu tablo, Bölüm 10'daki veri lisansları ve yayın kapılarıyla birlikte okunmalıdır.
