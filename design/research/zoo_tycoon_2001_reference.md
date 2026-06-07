# Zoo Tycoon (2001) — Reference Dossier

Reference research for the Godot-based Zoo Tycoon project. Compiled from
Wikipedia, the GameFAQs strategy guide by Steven W. Carter (the most
mechanically detailed extant source), the Giant Bomb design retrospective by
Mark Hill ("gamer_152"), the Game Developer postmortem of Blue Fang Games, the
zooТycoon.fandom wiki, and various retrospectives. Cited inline.

This document covers only the **2001 PC release** plus its two official
expansion packs (Dinosaur Digs, Marine Mania) and the Complete Collection
re-release — it does not cover Zoo Tycoon 2 (2004), the Xbox reboot (2013), or
Planet Zoo (2019), except in passing.

---

## 1. Release & history

### Studio and pedigree
- **Developer:** Blue Fang Games, LLC (Waltham, Massachusetts; founded 1998).
- **Founders:** Adam Levesque and John Wheeler, both ex–Papyrus Design Group
  (the NASCAR Racing series). CEO Hank Howie joined to run the studio.
  ([Wikipedia: Blue Fang Games](https://en.wikipedia.org/wiki/Blue_Fang_Games))
- **Publisher:** Microsoft Game Studios. Microsoft signed Blue Fang in **fall
  of 2000** after the team had been workshopping the concept since fall 1999.
  ([Wikipedia: Zoo Tycoon (2001 video game)](https://en.wikipedia.org/wiki/Zoo_Tycoon_(2001_video_game)))

### From "Airport Tycoon" to zoos
- The studio initially pitched an airport-management sim. Howie killed it on
  the grounds that "compared to places like theme parks, airports are not
  'fun'." He then used reverse psychology on engineer John Wheeler — letting
  Wheeler think the zoo idea was his own — to secure buy-in. This is "Lesson
  1" of the team's published postmortem.
  ([Game Developer: 6 lessons from the making of Zoo Tycoon](https://www.gamedeveloper.com/business/six-lessons-from-the-making-of-zoo-tycoon))
- Research trips: artists, animators, and devs visited Boston-area zoos and
  flew a team out to the San Francisco Zoo. The team explicitly traded
  educational accuracy for fun where the two conflicted (e.g., Marine Mania
  dolphins do unrealistic stage tricks).

### Release & SKUs
- **PC release: October 17, 2001** (Windows and Macintosh).
- **Dinosaur Digs expansion:** May 19, 2002. First expansion.
- **Marine Mania expansion:** October 17, 2002 (one-year anniversary).
- **Zoo Tycoon: Complete Collection:** bundled base game + Dinosaur Digs +
  Marine Mania + Endangered Species Theme Pack. Became the canonical SKU.
- Free **downloadable content** drops between 2001 and ~2004 added 12 bonus
  animals via the official Microsoft site (placed in the game's `Updates`
  directory as `.ztd` files).
  ([Wikipedia: Zoo Tycoon (2001 video game)](https://en.wikipedia.org/wiki/Zoo_Tycoon_(2001_video_game)))

### Reception
- Metacritic **68/100** across 18 reviews; GameRankings ~68.7%. PC Gamer US
  gave 48% (the most savage outlier); Computer Games Magazine 4.5/5.
- Awards: **Bologna New Media Prize (2002)**, Parents' Choice Foundation
  Gold (2003), AIAS Computer Family Game of the Year (2004), Scholastic
  Parent & Child Teacher's Pick (2004), Children's Software Revue All Star
  (2004).

### Commercial impact
- **1 million copies** within 12 months of launch.
- **2.5 million** globally by October 2003 (3 million counting expansions).
- US: 1.1 million units / **$28.2 million revenue** by August 2006.
- Charted as **8th best-selling PC game of 2002**, 11th of 2003; Complete
  Collection charted top-20 every year from 2004 through 2006.
- Franchise total: **4 million+** copies by July 2004.
- Gold-certified in the UK and DACH region.
  ([Wikipedia: Zoo Tycoon (2001 video game)](https://en.wikipedia.org/wiki/Zoo_Tycoon_(2001_video_game)))

### Why it was influential
The Giant Bomb retrospective by Mark Hill places Zoo Tycoon as a synthesis
node: it inherited freeform path/object placement from **RollerCoaster
Tycoon (1999)** / Theme Park (1994) and applied it to the zoo-management
subject matter that **DinoPark Tycoon (1993)**, SimPark (1996), and SimSafari
(1998) had pioneered but never fully delivered. The breakthrough was
letting players hand-author every exhibit — pen shape, individual terrain
tiles, individual trees and rocks — rather than placing prefab attractions.
Hill argues this is what put Zoo Tycoon "head and shoulders above so many of
its peers" and made each player's zoo visibly unique.
([Giant Bomb: Menagerie](https://www.giantbomb.com/profile/gamer_152/blog/menagerie-an-analysis-of-zoo-tycoon-2001-and-its-e/121109/))

The Thumbsticks retrospective calls it "the animal management sim that
pioneered the genre" — directly upstream of Zoo Tycoon 2, the 2013 Xbox
reboot, and Planet Zoo. ([Thumbsticks](https://www.thumbsticks.com/zoo-tycoon-pioneered-animal-management-sim/))

---

## 2. Core gameplay loop

The minute-to-minute loop:

1. **Place an exhibit fence** — drawing a closed polygon on the tile grid.
2. **Paint terrain inside** — savannah / coniferous / rainforest / saltwater /
   freshwater / snow / grass / sand / dirt / brown stone / gray stone, plus
   elevation via the "cliff" tool.
3. **Drop in trees, bushes, rocks (large or small), and a shelter** matching
   the target species' preferences.
4. **Purchase an animal** from the adoption menu and place it in the pen.
5. **Hire a zookeeper** and assign it to that exhibit so it gets fed and
   cleaned.
6. **Build paths** from the entrance past the exhibit so guests can view it.
7. **Repeat** for several species; intersperse food stands, drink stands,
   bathrooms, benches, and decorations along the paths.
8. **Monitor** the rolling notifications: animal unhappy? fence broken?
   guest hungry? trash piling up? Adjust.
9. **Spend research dollars** to unlock new animals, shelters, toys, and
   staff education.
10. **At month-end**, accept your settlement, raise ticket prices, expand.

The game runs on a **continuous in-game clock** (months/years) but is
pausable; guests and animals act in real-time. There are time-warp speeds.

Three modes:
- **Tutorial** — guided first build.
- **Scenario** — 12 + expansion scenarios, win-or-lose, time-limited,
  starting conditions vary. Scenarios are gated — clearing one unlocks
  later ones.
- **Freeform** — player picks map size, starting money, no objectives, no
  fail state. Catalog is partially locked at start; the rest is unlocked via
  the research system.

The two-axis happiness loop is the heart of the design: **animal happiness →
guest happiness → ticket and concession revenue → research/expansion →
better animals → higher attendance**. Mark Hill's analysis stresses that
the game gives "no brownie points for lining your pockets at the expense of
anyone's happiness" — a pure-profit playstyle is mechanically punished
because mistreated animals trigger guest outrage and supplier embargoes.
([Giant Bomb](https://www.giantbomb.com/profile/gamer_152/blog/menagerie-an-analysis-of-zoo-tycoon-2001-and-its-e/121109/))

---

## 3. Exhibits & animals

### Exhibit construction model

- The world is a **square tile grid** (also described as a "lattice" of
  grid squares). Animals only care about **number of grid squares**, not
  shape — so the strategy guide explicitly recommends square pens to minimize
  fence costs.
- Fences are placed on **tile edges**, which (as Hill notes) enables a
  Dinosaur Digs exploit: putting two parallel fence segments on adjacent
  tile edges to double-wall a T. rex pen.
- A pen has a computed **suitability rating (0–101)** displayed in its
  info panel. 100 is the realistic max; 101 is achievable only on
  oversized pens with size that is a multiple of 100.
  ([GameFAQs guide — swcarter](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545))

### What suitability is made of

The exhibit info panel checks each animal's spec against the actual pen:

- **Density** — square footage per animal. Camels and chimps are 15–20
  sq/animal; lions/tigers ~35; rhinos and gorillas ~50; **Tyrannosaurus
  rex is 200**, Apatosaurus 250. Multiply density by number of animals to
  get minimum pen size.
- **Terrain mix** — per species, expressed as percentages. Example:
  Grizzly bear wants 60% coniferous, 30% deciduous, 10% freshwater. Lion:
  savannah-dominant. Polar bear: 50% snow / 50% saltwater. Mismatch drops
  suitability.
- **Foliage percentage** — a target % of squares containing the
  preferred plant type. Grizzly wants ~20% pine; Bengal tiger 20%
  rainforest fern; chimpanzee 20% rainforest bushes; African lion ~12%
  acacia. The plant must be of an accepted species (most animals accept
  2–3 substitutes).
- **Rocks percentage** — separate from foliage. A subtlety: **rocks
  count by grid-square quadrant, not full square**. A 1% rocks target on a
  50-square exhibit means filling half a square. Players can swap large
  rocks for small rocks to fine-tune percentages.
- **Shelter** — almost every species wants exactly one shelter object,
  with strong type preferences (rock cave, wood shelter, lean-to, stable,
  burrow, concrete shelter, snowy cave, etc.). Many shelters must be
  researched to unlock.
- **Elevated terrain** — for mountain species (bighorn sheep, ibex,
  markhor, mountain lion, snow leopard, panda), a target % of tiles must be
  raised N notches using the "cliff" or single-square hill tool. This is
  the **only** part of suitability where placement matters; the rest is
  percentage-aggregated regardless of arrangement.
- **Special features** — climbing trees for cats, monkey bars for primates
  ("if you don't give chimps monkey bars right away, their happiness drops
  to zero"), rock formations for highland/snow species, ice floes /
  rafts for marine animals.
- **Companionship** — most species want pairs or small groups. Hyenas,
  flamingoes, gemsbok, etc. want 3–15; lions 2–3; T. rex is the headline
  exception (1 per exhibit, strictly).
  ([GameFAQs guide — swcarter](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545))

### Animal attributes (data-driven from the species file)

Every species has hidden numerical attributes that drive AI:

- **Attractiveness** (~5–100, sometimes 150+) — how much guests pay attention.
  Bison: 10. Bengal tiger: 50. Polar bear: 50. Snow leopard: 55.
  Giant panda: 90. White Bengal tiger: 70. Velociraptor: 100.
  **Tyrannosaurus rex: 100**. Marine mammals are higher still: dolphin 160,
  beluga 150, great white shark 150.
- **Shyness** (0–100) — skittishness around guests; lower = more skittish.
  Drives flee responses and visual hiding in shelters.
- **Strength** — fence-break stat. Compared against fence strength; if
  animal strength > fence strength, the animal breaks out. Bison: 50.
  Asian elephant: 56. T. rex: **301**. Spinosaurus: 325. Apatosaurus: 325.
  Most prey species are 0 — they cannot break fences regardless.
- **Jumps / Climbs flags** — control which fence styles are valid.
  Climbing-capable animals require non-climbable fences (concrete,
  plexiglass, iron rail) — chain-link/post-and-rail/rock fail. Jumpers
  require "high" fence variants.

### Fence catalog

**Zoo Tycoon high fences** (cost / climbable / jumpable / strength /
happiness M/W/B/G):
- Chain-link 70 / yes / no / 200 / 1/1/1/1
- Concrete 200 / no / no / 300 / 2/2/2/2
- Concrete-and-chain 150 / no / no / 275 / 3/3/2/2
- Iron rail 180 / no / no / 290 / 3/2/3/2
- Plexiglass 150 / no / no / 270 / 3/3/3/3
- Post-and-rail 90 / yes / no / 250 / 2/2/2/2
- Rock (windowed/solid) 150 / yes / no / 280
- Wood slat 110 / yes / no / 240
- Stick pole 75 / yes / no / 225

**Low** variants are roughly half cost but **all jumpable** — only useful
for non-jumpers (most savannah herbivores, bison, hippo, etc.).

**Dinosaur Digs** fences are dramatically stronger and pricier:
- Concrete-and-iron-bar 240 / strength 440
- Reinforced concrete 225 / 460
- Reinforced concrete + glass 225 / 420
- **Electrified iron bar** 350 / 400 — required for top-tier carnivores
  (Allosaurus, Spinosaurus, T. rex) **but only if the exhibit is at the
  default elevation**. Lowering the pen floor two notches eliminates the
  fence-strength requirement entirely (a known exploit).
- Electrified chain-link 300 / 480

**Marine Mania** fences are decorative for above-ground tanks (concrete
edge + glass, angled railing + glass, Atlantean, etc.) at ~125–175
each — strength is implicit in tank walls.

Fences **decay** in strength over time, requiring maintenance worker patrol.
A decayed fence on a strong-enough animal = escape. The Dinosaur Digs
expansion makes this central.

### Animal roster

The strategy guide enumerates animals grouped by **biome**, which is also
the in-game adoption browser's categorization. Base Zoo Tycoon ships **~48
species**, organized roughly as:

- **Coniferous:** Gray wolf, Grizzly bear, Siberian tiger.
- **Deciduous:** Black bear, Moose, Unicorn (Xanadu cheat).
- **Desert:** Dromedary camel, Gemsbok.
- **Grassland:** American bison.
- **Highland:** American bighorn sheep, Asian black bear (DLC), Giant
  panda (researched), Ibex, Llama (DLC), Markhor, Mountain lion (DLC),
  Snow leopard (researched).
- **Rainforest:** Asian elephant (DLC), Bengal tiger, Black leopard
  (researched), Bongo (DLC), Chimpanzee, Clouded leopard, Giant anteater,
  Jaguar, Lowland gorilla (researched), Mandrill, Okapi (researched),
  White Bengal tiger (researched).
- **Saltwater:** California sea lion, Saltwater crocodile.
- **Savannah:** African buffalo, African elephant, African lion, African
  warthog, African wild dog, Black rhinoceros, Blackbuck (DLC), Cheetah,
  Common wildebeest, Giraffe, Greater flamingo, Hippopotamus, Leopard,
  Olive baboon, Ostrich, Plains zebra, Red kangaroo, Spotted hyena,
  Thomson's gazelle, **Triceratops (Cretaceous Corral cheat)**.
- **Tundra/Snow:** Arctic wolf, Emperor penguin, Magnet (DLC reskinned
  polar bear — a real polar bear from the Maryland Zoo, added after winning
  Microsoft's "Best Zoo Animal" promo in December 2001), Polar bear,
  Reindeer (DLC), **Yeti (DLC)**.

**Dinosaur Digs adds ~20** (Coelophysis, Herrerasaurus, Plateosaurus,
Allosaurus, Apatosaurus, Camptosaurus, Caudipteryx, Kentrosaurus,
Plesiosaurus, Stegosaurus, Ankylosaurus, Deinosuchus, Gallimimus,
Iguanodon, Lambeosaurus, Spinosaurus, Styracosaurus, Triceratops DD
version, T. rex, Velociraptor + Ice Age: Giant ground sloth, Giant
tortoise, Saber-toothed cat, Wooly mammoth, Wooly rhino).

**Marine Mania adds ~25** (Atlantic swordfish, Beluga, Bluefin tuna,
Bottlenose dolphin, Elephant seal, Giant Pacific octopus, Giant squid,
Giant barracuda, Great white shark, Green moray eel, Green sea turtle,
Hammerhead shark, Harbor porpoise, Humpback whale, Lion's mane jelly,
Manta ray, **Mermaid** — purchased by placing a mermaid statue in a tank,
Narwhal, Orca, Pacific walrus, Shortfin mako shark, Southern sea otter,
Sperm whale, Tiger shark, West Indian manatee).

**Endangered Species Theme Pack** adds another ~12, including mythical
Bigfoot and Loch Ness Monster.
([GameFAQs guide — swcarter](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545),
[Wikipedia](https://en.wikipedia.org/wiki/Zoo_Tycoon_(2001_video_game)))

### Breeding
- Animals breed automatically when a male and female of the same species
  share a sufficiently large, sufficiently suitable exhibit and are well
  fed. Several scenarios are explicitly about breeding (e.g., "Breeding
  Giant Pandas," "Breeding the T. Rex" — the latter unlocks Deinosuchus
  on completion).
- Animals show a per-species **min/max comfortable group size**. Below
  min, suitability drops (loneliness penalty). Above max, the pen rejects
  more animals.

### Escapes
- Triggered when fence strength < animal strength, when a low fence faces a
  jumper/climber, or when an unrepaired fence decays past threshold.
- Escaped predators in Dinosaur Digs **will attack and eat guests**; in the
  base game, escaped animals scare guests rather than killing them.
- A **rescue team** can be dispatched to recapture. Players also commonly
  exploit lowered-floor exhibits or wide moats (because guests and most
  animals refuse to cross water by default).
  ([Giant Bomb](https://www.giantbomb.com/profile/gamer_152/blog/menagerie-an-analysis-of-zoo-tycoon-2001-and-its-e/121109/))

### Marine tank specifics (Marine Mania)
- First **3D exhibits** in the game. Tanks are above-ground with
  adjustable height, which sets water depth. Each marine species lists
  density as `A x B` where B is **minimum depth in tiles**.
- "Combo exhibits" attach a land segment to a tank for amphibious
  species (otters, walruses, sea lions, elephant seals) — these are cheaper
  than pure tanks.
- Tanks need either a **water filter** ($350/month upkeep) or
  marine-specialist cleaning to stay sanitary.
- **Show tanks** are special tanks connected to an exhibit tank via a
  shared height; surround them with **grandstands** (placed **exactly one
  tile away** from the show tank — closer or farther and guests won't
  enter) to stage paid shows where the marine specialist directs animals
  to perform tricks the player picks from a list.

---

## 4. Guests / visitors

### Needs system

Guests have four numeric meters (the strategy guide labels them
hunger/thirst/bathroom/energy). Every food/drink/restroom building has a
positive value for the need it satisfies and **negative values for the
needs it pushes** (e.g., a Burger Stand: hunger +100, thirst −10, bathroom 0,
energy +10 — i.e., it makes them thirsty). A **Restaurant** ($2200, $500
upkeep) satisfies all four needs at once (+200/+200/+200/+200, cap 12) and
generates no trash — the GameFAQs guide flatly states "restaurants are
your friend" and suggests skipping food stands, benches, and trash cans
entirely once you can afford restaurants. ([GameFAQs guide](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545))

Guests are not a single archetype — the game tracks four guest types:
**Man / Woman / Boy / Girl**, with separate view-happiness deltas per
building. E.g., Ice Cream Stand: M0/W0/**B+10**/**G+10** (kids love it,
adults don't care from a distance). Carousel: M+10/W+10/B+20/G+20.
Japanese Garden: M+25/W+25/B+10/G+10 (the strongest pure-aesthetic
building). Compost Building: −25 across the board (it stinks).

### Decision-making
- Guests enter with a **75 starting happiness rating** (per the guide;
  used as a deliberate floor that the player must beat).
- They wander paths and **stop at exhibits within a 10-square viewing
  distance**. The guide explicitly recommends making exhibits no deeper than
  10 tiles — animals farther back are simply not visible to guests.
- They tip ("donate") into a per-exhibit donation box based on how much
  they enjoyed the exhibit (animal attractiveness × animal happiness +
  building/decoration adjacency).
- They spend on entrance ticket, concessions, gift shops, attractions
  (carousel, elephant ride, animal theater, photo booth, swim shack, boat
  rental, etc.), tour-guide tips, and donations.
- If needs spike or they can't find a relevant building, they get angry,
  then leave; very angry guests **vomit** when they pass animal waste,
  litter, or the Compost Building (which has a known stink radius). Every
  guest in the zoo also vomits on **January 1st** as a hidden holiday gag
  with no happiness penalty.
  ([Guest and Staff AI in Zoo Tycoon — zksnotes](https://zksnotes.blogspot.com/p/guest-and-staff-ai-in-zoo-tycoon.html))

### Ticket-price bracketing
The admission price is bucketed, not continuous. Guests perceive the
brackets `$0–19` (cheap), `$20–29` (normal), `$30–49` (high), `$50–99`
(very high). Within a bracket the value doesn't change perceived value;
the optimal early-game move (per the guide) is to drop to **$19** at
scenario start, then raise to **$29** once attendance is healthy.
([GameFAQs guide](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545))

### Pathing
- Guests pathfind on a paths-only graph. They will path around blocked
  exhibit gates, but get progressively angrier the longer they're blocked.
- Drowning: a guest in water for 30–40 seconds (e.g., chased into a moat by
  an escaped predator) triggers a red warning, then drowns after another
  5–10 seconds. Staff cannot swim.
- **Decorative "staff-only" fences** allow staff but block guests — used to
  build service corridors behind exhibits.
- The Marine Mania **Shark Tunnel** is a paid one-way tube guests enter to
  walk through a tank.
  ([zksnotes — Guest and Staff AI](https://zksnotes.blogspot.com/p/guest-and-staff-ai-in-zoo-tycoon.html))

---

## 5. Staff

Base game staff (and DD/MM additions):

### Zookeeper
- Feeds animals, cleans waste, treats sickness, runs animal toys.
- Must be **manually assigned to specific exhibits** via a click-target
  flow on their info panel. One zookeeper can cover several exhibits but
  the guide recommends **no more than three** "and only if they're low
  maintenance," with exhibit gates clustered for short walks.
- Education research (the "Hank Howie" cheat unlocks all training tiers)
  speeds them up.

### Maintenance Worker
- Sweeps and cleans (paths and food courts), empties trash bins, repairs
  fences. Assignment is by task type (checkbox list of jobs), **not by
  exhibit**. This is the single biggest source of Dinosaur Digs frustration
  — the AI can't prioritize a corroded T. rex fence over a chain-link patch
  on the wolf pen.
- Sub-checkbox: **"Sweep and clean zoo"** — must be **disabled** in
  Marine Mania if you use combo tanks, because workers otherwise "clean" the
  fish food right out of tanks while animals are performing in show tanks.
  ([GameFAQs guide](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545))

### Tour Guide
- Walks paths and recites animal trivia. Guests can opt to follow and
  receive a small happiness bonus.
- Tour guides are assigned to **any animal exhibit** (including dinos and
  marine), unlike zookeepers/scientists/marine specialists which are
  type-locked.

### Scientist (Dinosaur Digs only)
- Replaces zookeeper for dinosaur exhibits. Also incubates dinosaur eggs
  (every DD species hatches from an egg event).
- Has a dedicated research track for T. rex care.

### Marine Specialist (Marine Mania only)
- Cleans tanks (alternative to the $350/mo filter), feeds marine animals,
  conducts shows on show tanks.
- Has unique gate access — Marine Mania ships a "stage door" fence type
  that lets specialists through but blocks guests.

### Pay rhythm
- Staff salaries hit the books on **hire** and on the **1st of each
  month**. Strategy: never hire on the 31st; survive the first month of
  scenarios with zero hires if possible (scientists excepted).
  ([GameFAQs guide](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545))

### Idle behavior
Idle staff bias toward "walking to the right of the zoo entrance." This is
a known AI quirk that strategy guides recommend planning service buildings
around. ([zksnotes — Guest and Staff AI](https://zksnotes.blogspot.com/p/guest-and-staff-ai-in-zoo-tycoon.html))

---

## 6. Economy & progression

### Income sources
- **Admission tickets** — bracketed (see §4).
- **Concession sales** — burgers, hot dogs, pizza, drinks, snacks.
- **Donation boxes** — one per exhibit; tipped by guests in proportion to
  enjoyment (the "Microsoft" exhibit-name cheat doubles donations).
- **Gift shops and gift stands** — sell merchandise (with M/W/B/G visit
  values; adult $8 / child $15 on a Gift Shop).
- **Attractions** — Animal Theater ($1300 build, $50 upkeep, adult $12 /
  child $8 visit), Carousel ($800, kids $12), Elephant Ride, Petting Zoo
  ($700, child $15), Bouncy Ride, Dino Slide, Stego Putt, Tree Swing
  (Dinosaur Digs); Dolphin Ride, Swim Shack ("almost as much as
  restaurants" in profit per the guide), Shark Tunnel, Boat Rental,
  Photo Booth, Ring Toss (Marine Mania).
- **Compost Building** — the guide's first move on every map: drop a
  compost building in the corner. It has **no upkeep**, and converts every
  pile of animal waste in the zoo into **$50 each** (or **$100 each** in
  Dinosaur Digs). It also stinks (−25 view happiness across all guest
  types) so it must be far from paths.
- **Awards** — periodic milestone bonuses for things like a 100-suitability
  exhibit, multi-species variety, animal happiness, etc. The Burkitsville
  starter scenario notes a $15,000 exhibit-design award for the first
  great pen, plus a $10,000 emergency injection whenever the player's
  cash drops below $1000 in that scenario.

### Costs
- Staff salaries (monthly).
- Building upkeep (monthly, per the price tables in the guide).
- Animal purchase (one-time; researched animals more expensive).
- Animal food / vet care (rolled into zookeeper labor).
- Building purchase + demolition (refunds partial cost).
- Tank filters ($350/mo).
- Research investments (lump sums).

### Research / unlock system
- Catalog items marked `(+)` in the strategy guide are **researched**, not
  bought — they appear locked until the player invests cash in a research
  topic. Examples: rock cave shelter, panda rock cave, gorilla climbing
  bars, cat climbing tree, large lean-to, large concrete shelter, dawn
  redwood trees, club moss shrubs, horsetails, plus the headliner
  animals: Giant Panda, Snow Leopard, Lowland Gorilla, Okapi, White Bengal
  Tiger, Black Leopard, Apatosaurus, Spinosaurus, T. rex, Velociraptor,
  Humpback Whale, Narwhal, Great White Shark, Mako Shark, Plesiosaurus,
  Kentrosaurus, Ankylosaurus.
- The expansion packs add **animal house** buildings (Aviary, Insect
  House, Primate House, Reptile House, Pteranodon House, Lepospondyl
  House, Crustacean House, Tropical Aquarium) which house smaller animals
  in a building footprint rather than a fenced pen; their occupants
  (spiders, lemurs, snakes, angelfish, etc.) are also research-gated.
- Staff education (zookeeper/scientist training tiers) is its own research
  track.

### Scenarios vs freeform
- **12 base scenarios** + 4 Dinosaur Digs + 5 Marine Mania (the guide
  walks all of them). The 12 are gated into Tutorial → Intermediate →
  Advanced → Very Advanced bands. Cheating: name a guest "Akiyama" to
  unlock all scenarios.
- Sample scenario: **Revitalize Burkitsville Zoo** — 12-month time
  limit; achieve zoo rating 50, average animal happiness 75, at least 8
  species displayed. Starting condition: pre-existing crummy exhibits with
  Bengal tiger, black rhino, 2 gemsbok, 2 chimps. Tutorial scenario
  template — bulldoze everything, replan with restaurants, hit the
  happiness threshold.
- Advanced scenario examples: Island Zoo, African Savannah Zoo, Mountain
  Zoo, Tropical Rainforest Zoo, Paradise Island, Breeding Giant Pandas,
  Dinosaur Island Research Lab, Breeding the T. Rex (unlocks Deinosuchus),
  Marine Conservation, Save the Zoo, Giant Marine Park, Super Zoo, Aquatic
  Show Park (unlocks the Fancy Grandstand), Shark World (unlocks the Photo
  Booth).
- **Win conditions** are objective lists with a time limit (typically
  12–60 months): zoo rating thresholds, animal happiness averages, exhibit
  suitability targets, species counts, breeding counts.
- **Loss conditions** are bankruptcy (cash falls below zero with no
  income to recover) or running out the scenario clock without meeting
  objectives.
- **Freeform** has no fail state — the player chooses a map (island,
  savannah, mountain, rainforest, etc. — biome-specific maps with native
  terrain pre-painted), starting cash, and plays indefinitely. Research
  still applies.
  ([GameFAQs guide — swcarter](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545))

---

## 7. Buildings & infrastructure

Selected build prices from the guide (all cost / upkeep / capacity):

### Food and drink (base game)
- Burger Stand $250 / $50 / cap 3
- Hot Dog Stand $175 / $50 / cap 2
- Ice Cream Stand $125 / $50 / cap 2 (children love it)
- Pizza Stand $325 / $50 / cap 6
- Snack Machine $50 / $10 / cap 1
- Drink Stand $250 / $50 / cap 4
- Drink Machine $50 / $10 / cap 1
- Restaurant $2200 / $500 / cap 12 — **fills all four needs**.

### Restrooms
- Bathroom $120 / $50 / cap 2
- Family Bathroom $250 / $50 / cap 8

### Attractions & happiness
- Animal Theater $1300 / $50 / cap 12 (adult $12, child $8)
- Carousel $800 / $100 / cap 12 (kids $12)
- Elephant Ride $1200 / $50 / cap 2 (kids $20!)
- Petting Zoo $700 / $100 / cap 4 (child $15)
- Japanese Garden $1900 / $50 / cap 4 — view happiness +25/+25/+10/+10,
  adult $30 visit — the single best aesthetic building in the catalog.
- Gift Shop $600 / $200 / cap 12 (adult $8 / child $15)
- Gift Stand $125 / $50 / cap 1
- Compost Building $1500 / $0 — see §6.

### Marine Mania attractions
- Boat Rental Shack $200 / $75 / cap 25
- Swim Shack $200 / $75 / **cap 1000** (giant capacity, adult $15 — top
  revenue per square foot; makes guests tired so place near restaurants)
- Shark Tunnel $500 / $100 / cap 24
- Dolphin Ride $450 / $50 / cap 2 (adult $15)
- Grandstand $120 / $15 / cap 12 (placed exactly one tile from a show tank)

### Paths & scenery
- Path styles include dirt, asphalt, cobblestone, red brick, plus
  decorative low brick walls. The guide recommends cobblestone or red
  brick for the guest happiness bonus, flanked by low red brick walls.
- A "yellow brick path" exists as an Easter egg (place a lion + Bengal
  tiger + grizzly in a single exhibit).
- Scenery: fountains, statues, flower beds, topiary, lamp posts, benches,
  trash cans, zoo maps. Most provide small guest happiness boosts.
- "Observation paths" trick (guide): leave 4-tile gaps between exhibits,
  use the middle two for the path, reserve outer two for later
  "observation paths" to relieve crowded exhibits.

### Animal houses
Building-based small-animal exhibits (each houses one mini-species at a
time, researched):
- Aviary $1600 (Africa, Raptors)
- Insect House $600 (Spiders)
- Primate House $1100 (Primates, Lemurs)
- Reptile House $950 (Snakes)
- Crustacean House $1500 (Horseshoe, Spider)
- Tropical Aquarium $1100 (Angelfish, Blue Tang)
- Pteranodon House $2000 (Ramphorhyncus, Dimorphodon)
- Lepospondyl House $1000 (Karaurus, Diplocaulus)

---

## 8. UI / controls

- **Camera:** fixed-angle **isometric** ("2.5D"), tile-aligned, with
  rotation/zoom limited by Y2K-era tech. Marine Mania introduces height
  changes that give the camera its first taste of real verticality.
- **Build mode** is modal: click a category icon (Fences, Paths,
  Foliage, Rocks, Buildings, Animals, Scenery, Staff), pick a sub-item,
  drag/click on the world. ESC cancels a partial draw without spending an
  undo. Undo is single-step.
- **Exhibit info panel** is the heart of the UX: shows occupants,
  suitability rating, the "zookeeper recommendations" list (text
  suggestions like "needs more rainforest fern," "wants larger group,"
  "wants a wood shelter"), donation income, and animal-by-animal happiness
  with smiley/frowny face icons.
- Hill notes the recommendations are **only meaningful up to ~90% animal
  happiness** — above that, the game stops telling you what's wrong and
  expects you to tune percentages by trial and error, which he flags as one
  of the design's pain points: "the game accuses you of being an imperfect
  manager when really, it's taking away the management tools."
  ([Giant Bomb](https://www.giantbomb.com/profile/gamer_152/blog/menagerie-an-analysis-of-zoo-tycoon-2001-and-its-e/121109/))
- **Hotkeys** noted by the guide:
  - `Ctrl-B` toggle buildings (DD/MM only)
  - `Ctrl-G` toggle grid lines
  - `Ctrl-F` toggle foliage
  - `Ctrl-V` toggle guests (DD/MM only)
- **Smiley/frowny mood bubbles** float above every animal and guest in
  real time. This was a Blue Fang programmer's frustrated suggestion that
  became "the solution to the game's engagement problem" — Lesson 3 of
  the postmortem ("Great ideas can come from anywhere"). ([Game Developer postmortem](https://www.gamedeveloper.com/business/six-lessons-from-the-making-of-zoo-tycoon))
- **Tutorial text** was written by CEO Hank Howie himself in a comedic
  voice that Microsoft loved enough to keep — Lesson 4 ("If you're asked
  to help, help").

### Cheats / Easter eggs (rename a guest)
A surprising amount of game state is exposed via guest-name cheats — a
useful design tell for "what does the dev team consider its admin
interface?":
- **Akiyama** — unlock all scenarios.
- **Andrew Binder** — research all animal shelters and programs.
- **Hank Howie** — research all staff education topics.
- **John Wheeler** — unlock all animal shelters.
- **Lou Catanzaro** — unlock all animal toys.
- **Steve Serafino** — unlock all endangered animals.
- **Russell C** — break all fences (sandbox stress test).
- **Zeta Psi** — make half your guests vomit (no cleanup needed).
- **Alfred H** — birds appear, guests panic (Hitchcock reference).
- **Mr. Blue / Brown / Orange / Pink / White / Blonde** — recolor
  guests and buildings (Reservoir Dogs reference).

Exhibit-name cheats:
- **Blue Fang** — double attraction income.
- **Microsoft** — double donations.
- **Cretaceous Corral** — unlock Triceratops in the base game.
- **Xanadu** — unlock the Unicorn.

---

## 9. Expansions

### Dinosaur Digs (May 19, 2002)
- **+26 prehistoric species + 1 mythical** (Triceratops alt-version,
  Yeti via Tundra, dinos across Triassic / Jurassic / Cretaceous, plus
  Ice Age megafauna).
- **Scientist staff** replaces zookeeper for dinosaur exhibits.
- **Dinosaur eggs** — every dino hatches from an egg event after
  scientist-led incubation, creating a "headline" arrival moment.
- **Electric fences** — required to contain top-tier predators (or
  bypassed by lowering exhibit floor two notches, a known trick).
- **Escape mechanics escalate** — strong carnivores ram non-electric
  fences down, weakened electric fences also break, escapees actively
  hunt and eat guests. Aquatic dinos can swim moats.
- **T. rex research track** — a dedicated multi-step research chain
  unlocks T. rex shelters and toys. Hill criticizes this as flattening
  the late game's variety (everything funnels back to one species) but
  praises its dramatic weight.
- **New buildings:** Bronto Burger, Mammoth Cones, Dinosaur Cinema
  ($2000 / cap 30 — the largest theater in the game), Dinosaur Gift Shop,
  Bouncy Ride, Dino Slide, Stego Putt mini-golf, Tree Swing, Pteranodon
  House, Lepospondyl House (amphibians).
- **Maintenance AI does not prioritize dinosaur fences** — Hill identifies
  this as the expansion's central design flaw and explains the
  community's "double-wall" workaround.

### Marine Mania (October 17, 2002)
- **+25 aquatic species** including mythical Mermaid.
- **3D tanks** — above-ground tanks with adjustable height (= depth);
  game's first real verticality.
- **Combo exhibits** — water tank + land segment for amphibious
  species; cheaper than pure tanks.
- **Marine Specialist** staff role.
- **Water filters** ($350/mo upkeep) as an automation alternative to
  marine-specialist cleaning.
- **Show tanks + grandstands** — the expansion's headline feature.
  Connect a show tank to one or more exhibit tanks via shared height,
  drop grandstands exactly one tile from the show tank, pick tricks from
  a list, and your marine specialist runs scheduled shows. Multiple
  exhibit tanks connected to one show tank cause species to alternate.
- **+10 scenarios** including Oceans of the World, Save the Marine
  Animals, Free Admission, Aquatic Show Park, Shark World, Marine
  Conservation, Save the Zoo, Giant Marine Park, Super Zoo.
- **New attractions:** Swim Shack (cap 1000!), Shark Tunnel, Dolphin
  Ride, Boat Rental, Photo Booth, Ring Toss, Orca Bouncy Ride.
- **New buildings:** Lobby's Restaurant, Kneemo's Subs, Polly's Popcorn,
  Sea Dawgs, Crushed Ice, Aquatic Restroom, Crustacean House, Tropical
  Aquarium.
- **New fences** include Atlantean DLC theme.

Hill's critique: the shows are designed to cycle every few minutes, so
the spectacle that worked in DD (rare, terrifying) becomes routine
("compelling for so long") in MM, and tanks visually homogenize as
"medium blue voids."
([Giant Bomb — Menagerie](https://www.giantbomb.com/profile/gamer_152/blog/menagerie-an-analysis-of-zoo-tycoon-2001-and-its-e/121109/))

---

## 10. Design lessons — what reviewers and retrospectives identified

### The "secret sauce" (what made it click)

1. **Hand-authored exhibits as the core fantasy.** Hill: "It's that we get
   to design those exhibits instead of just plonking down prefab
   attractions which makes Zoo Tycoon stand head and shoulders above so
   many of its peers." Every tile of terrain, every tree, every rock,
   every animal's name is under player control. No two zoos look alike.
2. **Decorative objects with mechanical teeth.** In most sims of the era,
   "scenery" was cosmetic. Zoo Tycoon weaponizes scenery: animals
   respond to it (suitability), guests respond to it (view happiness),
   so beautifying the zoo and engineering it are the **same action**.
   This solved a chronic management-sim tension: aesthetic players and
   optimization players are doing the same work.
3. **Tight nested feedback loops.** Animal happiness → guest happiness →
   revenue → expansion → more animals. No isolated meta-loop; everything
   feeds back into everything in two clicks.
4. **Real-time mood bubbles** — the smiley/frowny face system gave
   instant per-animal, per-guest feedback. Originated from a programmer's
   frustration that the team didn't know how to communicate satisfaction
   state without UI overload.
5. **"You can't profiteer your way to victory."** Mistreated animals →
   outraged guests → supplier embargoes → bankruptcy. Profit and ethical
   care are aligned, which is rare in a tycoon game and makes the fantasy
   feel wholesome rather than mercenary.
6. **The model-kit appeal.** Hill compares it to building a model
   railway: the satisfaction is the diorama itself, not the optimization.
   Zoo Tycoon shines because the diorama can be detailed, the inhabitants
   animate naturally, and the variety of biomes lets you build a
   "pageant of flora and fauna."
7. **Educational halo without nagging.** Animal facts via tour guides,
   biome-accurate terrain requirements, parental approval awards —
   Microsoft marketed it as suitable for kids and the design supported
   that without lecturing.
8. **Time-warp test.** The Blue Fang team's published success criterion
   for a tycoon game (Lesson 5): if a playtester loses all sense of time,
   you've got it.

### Common criticisms

1. **Recommendations dry up above 90% happiness.** Above the threshold,
   the player guesses percentages by trial and error. Hill calls this the
   game "taking away the management tools" right when management gets
   hardest.
2. **Maintenance worker AI is dumb.** Cannot be assigned per-exhibit,
   prioritizes the wrong fences, gets caught in trivial-task loops.
   Forces players to either babysit, drop wide moats, or double-wall.
3. **Path-following AI gets stuck.** Reviewers cited guests taking
   inefficient or stuck routes around blocked gates — and the longer
   they're blocked, the angrier they get, which can spiral.
4. **Late-game homogenization.** Once you've nailed the suitability
   formula, every exhibit becomes a copy-paste template (square pen,
   correct terrain mix, correct foliage %, correct shelter).
5. **Dinosaur Digs forces game-system thinking.** The escape exploits
   needed to keep dinos contained "take you out of the headspace of a
   zoo director" — Hill's words — and into thinking about AI and pathing
   as systems to game.
6. **Marine Mania tanks all look alike.** Three-dimensional but visually
   homogenous; shows cycle too fast to retain novelty.
7. **Animal naming is algorithmic.** "Giraffe 4" rather than a
   personality-bearing name; Hill notes this is "a little cold."

### Lessons from the developer postmortem

Blue Fang's published 6-lesson postmortem (Game Developer):
1. **Credit doesn't matter; getting the right call made does.** Howie
   pretended Wheeler invented zoos to dodge a fight over Airport Tycoon.
2. **Resolve design disputes with data.** Microsoft's playtest data
   convinced Levesque the animal-attack mechanic was a winner.
3. **Listen to junior staff.** A programmer's offhand smiley/frowny
   comment became the mood-bubble system.
4. **Volunteer outside your role.** The CEO wrote the tutorial.
5. **The time-warp effect is the success metric.** When you play your
   own game and forget to eat lunch, it works.
6. **Ship the vision.** On time, on budget, no compromise.
([Game Developer — 6 lessons](https://www.gamedeveloper.com/business/six-lessons-from-the-making-of-zoo-tycoon))

---

## Appendix A — Pricing reference (selected)

| Item                       | Cost  | Upkeep | Cap  | Notes |
|----------------------------|-------|--------|------|-------|
| Burger Stand               | 250   | 50     | 3    | hunger +100, thirst −10 |
| Pizza Stand                | 325   | 50     | 6    | high hunger |
| Snack Machine              | 50    | 10     | 1    | low impact |
| Drink Stand                | 250   | 50     | 4    | thirst +100, bath −20 |
| Drink Machine              | 50    | 10     | 1    | low impact |
| Bathroom                   | 120   | 50     | 2    | view happiness −5 all |
| Family Bathroom            | 250   | 50     | 8    | no penalty |
| Restaurant                 | 2200  | 500    | 12   | all four needs +200 |
| Gift Shop                  | 600   | 200    | 12   | adult $8 child $15 |
| Compost Building           | 1500  | 0      | -    | $50/poo, view −25 |
| Carousel                   | 800   | 100    | 12   | kids $12 |
| Petting Zoo                | 700   | 100    | 4    | child $15 |
| Animal Theater             | 1300  | 50     | 12   | adult $12 child $8 |
| Japanese Garden            | 1900  | 50     | 4    | best aesthetics, adult $30 |
| Elephant Ride              | 1200  | 50     | 2    | kids $20 |
| Aviary                     | 1600  | 0      | 12   | research-gated |
| Primate House              | 1100  | 0      | 8    | research-gated |
| Reptile House              | 950   | 0      | 6    | research-gated |
| Insect House               | 600   | 0      | 4    | research-gated |
| Dinosaur Cinema (DD)       | 2000  | 150    | 30   | biggest theater |
| Pteranodon House (DD)      | 2000  | 0      | 12   | DD aviary equivalent |
| Swim Shack (MM)            | 200   | 75     | 1000 | top revenue/sqft |
| Shark Tunnel (MM)          | 500   | 100    | 24   | paid one-way path |
| Lobby's Restaurant (MM)    | 2000  | 350    | 12   | MM restaurant |
| Grandstand (MM)            | 120   | 15     | 12   | place 1 tile from show tank |

## Appendix B — Selected species stat snapshot

| Species              | Density | Terrain                                              | Foliage % | Atk | Shy | Str |
|----------------------|---------|------------------------------------------------------|-----------|-----|-----|-----|
| Gray wolf            | 35      | 50% conif / 25% grass / 20% decid / 5% freshwater    | 14% spruce | 10 | 20 | 0 |
| Grizzly bear         | 50      | 60% conif / 30% decid / 10% freshwater               | 20% pine   | 35 | 20 | 40 |
| African lion         | (sav.)  | savannah-dominant                                    | acacia     | (high) | – | (mid) |
| Bengal tiger         | 35      | 70% rainforest / 15% grass / 10% fresh / 5% dirt     | 20% fern   | 50 | 30 | 0 |
| White Bengal tiger   | 35      | as Bengal                                            | 13% fern   | 70 | 30 | 0 |
| Chimpanzee           | 15      | 85% rainforest / 10% grass / 5% dirt                 | 20% bushes | 15 | 30 | 0 |
| Lowland gorilla      | 20      | 70% rainforest / 20% grass / 10% dirt                | 15% bushes | 25 | 20 | 30 |
| Giant panda          | 20      | 80% conif / 8% grass / 5% gray stone / 5% snow / 2% fw | 13% birch | 90 | 10 | 15 |
| Snow leopard         | 35      | 60% snow / 30% gray stone / 10% brown stone          | 5% pine    | 55 | 10 | 0 |
| African elephant     | (sav.)  | savannah                                             | savanna grass | (high) | – | (high) |
| Polar bear           | 35      | 50% snow / 50% saltwater                             | 0%         | 50 | 20 | 0 |
| Emperor penguin      | 15      | 60% saltwater / 40% snow                             | 0%         | 15 | 30 | 0 |
| Yeti (DLC)           | 85      | 90% snow / 10% gray stone                            | 0%         | 90 | 15 | 79 |
| Tyrannosaurus rex    | 200     | 60% grass / 25% gray stone / 10% decid / 5% fw       | 5% broadleaf | 100 | 30 | 301 |
| Velociraptor         | 80      | 85% conif / 10% grass / 5% fw                        | 6% redwood | 100 | 30 | 185 |
| Spinosaurus          | 100     | 65% conif / 25% grass / 5% dirt / 5% fw              | 8% redwood | 90 | 30 | 325 |
| Apatosaurus          | 250     | 75% decid / 10% dirt / 10% fw / 5% grass             | 8% magnolia | 95 | 20 | 325 |
| Bottlenose dolphin   | 20×5    | tank, depth 5                                        | 20% barnacles | 160 | 100 | – |
| Orca                 | 90×8    | tank, depth 8                                        | 8% barnacles | 120 | 100 | – |
| Great white shark    | 40×3    | tank, depth 3                                        | 18% barnacles | 150 | 35 | – |
| West Indian manatee  | 20×3    | tank, depth 3                                        | 20% sea grass | 95 | 25 | – |

(All from the swcarter strategy guide, Feb 2003 revision.)

---

## Sources

- [Wikipedia — Zoo Tycoon (2001 video game)](https://en.wikipedia.org/wiki/Zoo_Tycoon_(2001_video_game))
- [Wikipedia — Blue Fang Games](https://en.wikipedia.org/wiki/Blue_Fang_Games)
- [Wikipedia — Zoo Tycoon: Marine Mania](https://en.wikipedia.org/wiki/Zoo_Tycoon:_Marine_Mania)
- [GameFAQs strategy guide by Steven W. Carter (swcarter), Feb 2003](https://gamefaqs.gamespot.com/pc/472139-zoo-tycoon-2001/faqs/19545)
- [Giant Bomb — "Menagerie: An Analysis of Zoo Tycoon (2001) and Its Expansions" by gamer_152 / Mark Hill](https://www.giantbomb.com/profile/gamer_152/blog/menagerie-an-analysis-of-zoo-tycoon-2001-and-its-e/121109/)
- [Game Developer — "Six lessons from the making of Zoo Tycoon"](https://www.gamedeveloper.com/business/six-lessons-from-the-making-of-zoo-tycoon)
- [zksnotes — Guest and Staff AI in Zoo Tycoon](https://zksnotes.blogspot.com/p/guest-and-staff-ai-in-zoo-tycoon.html)
- [Zoo Tycoon Wiki (Fandom) — Zoo Tycoon](https://zootycoon.fandom.com/wiki/Zoo_Tycoon)
- [Zoo Tycoon Wiki (Fandom) — Zoo Tycoon: Dinosaur Digs](https://zootycoon.fandom.com/wiki/Zoo_Tycoon:_Dinosaur_Digs)
- [Zoo Tycoon Wiki (Fandom) — Zoo Tycoon: Marine Mania](https://zootycoon.fandom.com/wiki/Zoo_Tycoon:_Marine_Mania)
- [Zoo Tycoon Wiki (Fandom) — Animal Needs](https://zootycoon.fandom.com/wiki/Animal_Needs)
- [Zoo Tycoon Wiki (Fandom) — Zookeeper](https://zootycoon.fandom.com/wiki/Zookeeper)
- [Zoo Tycoon Wiki (Fandom) — Tour Guide](https://zootycoon.fandom.com/wiki/Tour_Guide)
- [Zoo Tycoon Wiki (Fandom) — Marine Specialist](https://zootycoon.fandom.com/wiki/Marine_Specialist)
- [Zoo Tycoon Wiki (Fandom) — Guest](https://zootycoon.fandom.com/wiki/Guest)
- [HandWiki — Software:Zoo Tycoon (2001 video game)](https://handwiki.org/wiki/Software:Zoo_Tycoon_(2001_video_game))
- [Thumbsticks — How Zoo Tycoon pioneered the animal management sim](https://www.thumbsticks.com/zoo-tycoon-pioneered-animal-management-sim/)
- [Retroheadz — Zoo Tycoon (2001) PC Retro Review](https://www.retroheadz.com/retro-games/zoo-tycoon-2001-review/)
- [Merry-Go-Round Magazine — Zoo Tycoon retrospective](https://merrygoroundmagazine.com/zoo-tycoon-2/)
- [Legacy of Games — Zoo Tycoon (2001)](https://legacyofgames.com/2025/05/26/zoo-tycoon-2001/)
- [The Cutting Room Floor — Zoo Tycoon](https://tcrf.net/Zoo_Tycoon)
- [Manualmachine — Zoo Tycoon Complete Collection user manual](https://manualmachine.com/gamespc/zootycooncompletecollection/1118249-user-manual/) (referenced; not fetched directly due to 403)
