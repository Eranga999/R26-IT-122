// lib/data/sigiriya_knowledge_base.dart
// Knowledge base extracted from Sigiriya_Heritage_Site_Detailed_Guide.pdf

import '../models/location_model.dart';

/// All known locations at Sigiriya from the PDF guide.
/// briefSummary  → shown for mode == "brief"  (≈ 2-3 sentences)
/// detailedInfo  → shown for mode == "detailed" (full explanation)
const List<SigiriyaLocation> kSigiriyaLocations = [
  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'rock_fortress',
    name: 'Sigiriya Rock Fortress',
    emoji: '🏔️',
    tags: ['fortress', 'rock', 'palace', 'history', 'kashyapa', 'UNESCO'],
    imageAssets: [
      'assets/images/Screenshot 2026-05-05 220925.png',
      'assets/images/sigiriya sumit 7.jpg',
      'assets/images/Sigiriya sumit.jpeg',
      'assets/images/Sigiriya sumit2.jpg',
      'assets/images/sigiriya sumit6.jpg',
      'assets/images/sigiriya sumit8.jpg',
    ],
    briefSummary:
        'Sigiriya Rock Fortress is a UNESCO World Heritage Site built by King Kashyapa I '
        '(477–495 AD) on a massive rock rising nearly 200 metres above the plains. '
        'It served as a royal palace and fortified stronghold, showcasing advanced '
        'construction, water systems, and defensive engineering.',
    detailedInfo: '''## Sigiriya Rock Fortress — Full Overview

Sigiriya Rock Fortress is one of the most extraordinary archaeological sites in South Asia, built during the reign of King Kashyapa I (477–495 AD). After seizing power from his father King Dhatusena, Kashyapa chose this massive monolithic rock for its natural defensive advantages and strategic visibility.

### Historical Background
The site had earlier served as a Buddhist monastery, carrying spiritual significance before becoming a royal citadel. After Kashyapa's death in battle against his brother Moggallana, Sigiriya reverted to monastic use and was eventually abandoned.

### Structure & Scale
The rock rises approximately **200 metres (660 feet)** above the surrounding plains. The fortress encompasses an entire planned city complex across several hectares, including:
- Outer and inner moats
- Defensive ramparts and walls
- Water, boulder, and terraced gardens
- Symmetrical urban pathways
- The summit palace complex

### Engineering Highlights
- Rock-cut royal chambers, reservoirs, and storage
- Underground hydraulic channels and pressure-based fountains (still functional in rainy season)
- Symmetrical pools, bathing areas, and advanced drainage
- Spiral staircases, narrow pathways, and the famous Lion Gate

### UNESCO Recognition
Declared a UNESCO World Heritage Site in **1982** for its outstanding universal value, unique combination of architecture, art and engineering, and exceptional preservation of ancient urban planning.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'lion_gate',
    name: 'Lion Gate (Sinhagiri Entrance)',
    emoji: '🦁',
    tags: ['gate', 'entrance', 'lion', 'symbol', 'defense', 'architecture'],
    imageAssets: [
      'assets/images/lions gate 7.jpg',
      'assets/images/lions gate 8.jpg',
      'assets/images/lions-gate 4.jpg',
      'assets/images/lions-gate 6.jpg',
      'assets/images/lions-gate-2.png',
      'assets/images/Screenshot 2026-05-05 213840.png',
    ],
    briefSummary:
        'The Lion Gate is the iconic main entrance to the Sigiriya summit, originally formed '
        'by a colossal lion carved from the rock face. Today only the enormous lion paws '
        'remain, acting as both a ceremonial gateway and a defensive checkpoint.',
    detailedInfo: '''## Lion Gate (Sinhagiri Entrance)

The Lion Gate served as the final and most dramatic gateway to the summit palace of King Kashyapa. More than just an entrance, it fused engineering, art, symbolism, and political messaging.

### Original Structure
The gate took the form of a **colossal lion** constructed at the northern face of the rock. Visitors ascending toward the summit would pass through the open mouth or between the forelegs. Today, only the enormous **lion paws** remain, flanking the staircase — yet they alone convey the awe-inspiring scale of the original monument.

### Symbolism
- "Sinhagiri" literally means **Lion Rock**
- The lion is a longstanding emblem of Sinhalese identity, strength, and kingship
- Entering through the lion's body symbolised entering the domain of an all-powerful ruler

### Defensive Role
- A critical checkpoint at a narrow, elevated section of the ascent
- Guards could easily monitor and restrict entry
- The confined staircase made it difficult for large groups to advance simultaneously

### Craftsmanship
Built using **brick masonry coated with plaster**, once painted in vivid colours. The base and paws are carefully engineered to integrate with the rock face and support the staircase. Remnants of pigment confirm the original bright colouration.

### Legacy
The Lion Gate is one of the most photographed features of Sigiriya. Even in its incomplete state it continues to convey the grandeur of its creators, and visitors still pass between the massive paws on their way to the summit.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'frescoes',
    name: 'Sigiriya Frescoes',
    emoji: '🎨',
    tags: ['art', 'painting', 'fresco', 'maidens', 'culture', 'history'],
    imageAssets: [
      'assets/images/sigiriya-rock11.jpg',
      'assets/images/Sigiri-Apsara-Sigiriya-Frescoes (1).jpg',
      'assets/images/1616829061_wide.jpg',
      'assets/images/Sigiri-Apsara-Sigiriya-Frescoes.jpg',
      'assets/images/Sigiriya-Frescoes-1024x683.jpg',
      'assets/images/2509740_orig.jpg',
    ],
    briefSummary:
        'The Sigiriya Frescoes are 5th-century murals on the western rock face depicting '
        'ethereal "Sigiriya Maidens" — celestial female figures adorned with jewellery. '
        'About 20–25 figures survive from what was originally hundreds, painted using '
        'a fresco-secco technique with vibrant mineral pigments.',
    detailedInfo: '''## Sigiriya Frescoes — Detailed Explanation

The Sigiriya Frescoes are among the most celebrated artistic achievements of ancient Sri Lanka, representing a rare survival of early South Asian mural painting. Located in a sheltered rock pocket on the **western face**, approximately halfway up the ascent.

### Scale & Survival
Originally **hundreds of frescoes** adorned a large section of the rock face. Today approximately **20–25 figures** have survived, still displaying extraordinary skill and technical sophistication.

### The Sigiriya Maidens
The frescoes depict female figures — the "Sigiriya Maidens" or "Cloud Maidens" — shown from the waist up, emerging from cloud-like backgrounds. Scholars debate their identity:
- **Apsaras** (celestial nymphs from Buddhist/Hindu cosmology)
- Royal attendants or court dancers
- Symbolic representations of lightning and rain clouds

### Artistic Technique
- **Fresco-secco** method — pigments applied to dry or slightly damp plaster
- Vibrant colour palette of **red, yellow, green, and white** from natural mineral pigments
- Smooth flowing lines, shading and tonal variation creating three-dimensionality
- Intricate jewellery, semi-transparent garments, and expressive facial features

### Cultural Significance
Positioned along the ascent pathway, the frescoes formed part of a carefully orchestrated visual experience. The nearby **Mirror Wall** would once have reflected these images, doubling their visual impact.

### Conservation
Threats include natural weathering, moisture, sunlight, and historical human interference. Modern conservation restricts access and uses scientific techniques to prevent further deterioration.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'mirror_wall',
    name: 'Mirror Wall',
    emoji: '🪞',
    tags: ['wall', 'inscriptions', 'graffiti', 'poetry', 'language', 'history'],
    imageAssets: [
      'assets/images/SIGIRIYA-FRESCOES-5.jpg',
      'assets/images/Screenshot 2026-05-05 192148.png',
      'assets/images/mirror-wall.jpg',
      'assets/images/Sigiriya-Rock-Fortress-nymphs-1.jpg',
      'assets/images/Sigiriya_052.jpg',
      'assets/images/Screenshot 2026-05-05 191832.png',
    ],
    briefSummary:
        'The Mirror Wall is a highly polished lime-plaster wall that once reflected the '
        'king\'s image like a mirror. From the 6th century onward visitors wrote thousands '
        'of poetic graffiti inscriptions on it — some of the earliest examples of written '
        'Sinhala, making it a priceless linguistic and literary record.',
    detailedInfo: '''## Mirror Wall — Detailed Explanation

Situated along the western face just below the frescoes, the Mirror Wall is a sophisticated architectural and cultural element combining advanced engineering, refined craftsmanship, and an extraordinary historical record.

### Original Reflective Surface
Constructed during King Kashyapa's reign (5th century AD), the wall was polished to a **glass-like finish** using fine lime, sand, and possibly organic binders such as egg white or plant extracts. It could reflect images of people walking alongside it. Even today, portions retain a faint sheen.

### The Inscriptions
Beginning around the **6th century**, visitors began writing graffiti — poems, comments, and personal reflections — in early Sinhala and occasionally other languages. Thousands of inscriptions have been documented, making the wall one of the most important sources of early Sri Lankan literary and linguistic history.

**Why the inscriptions matter:**
1. **Historical record** — direct evidence of how ancient visitors experienced the site and the frescoes
2. **Linguistic treasure** — some of the earliest examples of written Sinhala, capturing language evolution over centuries
3. **Social diversity** — written by monks, officials, soldiers, and ordinary travellers

### Transition of Purpose
What began as a purely visual and aesthetic feature became a **living public record**, transforming from mirror to ancient collective diary over several centuries.

### Conservation Today
Writing on the wall is now **strictly prohibited**. Non-invasive techniques stabilise the surface and prevent further deterioration from moisture, temperature fluctuation, and biological growth.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'water_gardens',
    name: 'Water Gardens',
    emoji: '💧',
    tags: [
      'garden',
      'water',
      'fountains',
      'hydraulics',
      'engineering',
      'landscape',
    ],
    imageAssets: [
      'assets/images/Screenshot 2026-05-05 215101.png',
      'assets/images/Screenshot 2026-05-05 215015.png',
      'assets/images/Screenshot 2026-05-05 214935.png',
      'assets/images/Screenshot 2026-05-05 214850.png',
      'assets/images/water gardens 1.jpg',
      'assets/images/water gardens 2.jpg',
    ],
    briefSummary:
        'The Water Gardens are among the oldest landscaped gardens in the world, located '
        'at the western precinct of Sigiriya. They feature pressure-based fountains still '
        'functional today, interconnected pools, underground channels, and a perfectly '
        'symmetrical east–west layout, demonstrating mastery of hydraulic engineering.',
    detailedInfo: '''## Water Gardens — Detailed Explanation

The Water Gardens represent one of the earliest and most sophisticated examples of landscape architecture and hydraulic engineering in the ancient world. They form the **first major section** encountered by visitors approaching the rock fortress.

### Layout & Symmetry
Organised along a central **east–west axis**, with all pathways, pools, and structures arranged in a balanced and harmonious geometric pattern. This reflects both spatial design mastery and possible cosmological symbolism.

### Hydraulic System
- Water sourced from nearby reservoirs and natural springs
- Distributed through a network of **underground stone-and-clay channels**
- System relies on gravity and pressure differences — no pumps needed

### The Famous Fountains
**Still functional during the rainy season after 1,500+ years.** Water is forced through small openings by pressure from elevated sources and calibrated conduits, creating vertical jets from the ground. This demonstrates a deep understanding of fluid mechanics far ahead of its time.

### Pools & Features
- Large rectangular basins to intimate bathing areas
- Edges lined with finely cut stone or brick with access steps
- Small islands and raised platforms for leisure and social activities
- Stepping stones and narrow walkways controlling access

### Defensive Role
Outer moats and water-filled trenches acted as barriers against potential invaders, forming the **first line of defense** while also enhancing visual appeal.

### Symbolism
Water holds deep significance in South Asian tradition — associated with purity, life, and spiritual renewal. The prominence of water may symbolise these values, reinforcing Sigiriya as more than just a royal residence.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'boulder_gardens',
    name: 'Boulder Gardens',
    emoji: '🪨',
    tags: ['garden', 'boulders', 'monks', 'meditation', 'defense', 'natural'],
    imageAssets: [
      'assets/images/place-2015-06-22-5-Bouldergardens9b6fab71a8b086a7a537b1293325972d.jpg',
      'assets/images/3389125461_95aa098c35_b.jpg',
      'assets/images/sigiriya-boulder-garden-sri-lanka-H9RTKP.jpg',
      'assets/images/srilanka91.jpg',
      'assets/images/ruins-of-king-kassapa-s-palace-in-the-boulder-gard.jpg',
      'assets/images/67063380-sigiriya-boulder-garden-sri-lanka-1.jpg',
    ],
    briefSummary:
        'The Boulder Gardens lie between the Water Gardens and the terraced areas, '
        'using massive natural granite boulders as core design elements. They served '
        'multiple roles — defensive barriers, monk meditation caves, and the location '
        'of the royal Audience Hall carved into a flat rock surface.',
    detailedInfo: '''## Boulder Gardens — Detailed Explanation

Located between the formal Water Gardens and the upper terraced areas, the Boulder Gardens represent a transition from highly symmetrical engineered landscapes to a more organic integration of natural terrain and human design.

### Defining Character
Massive **granite boulders** were NOT removed or extensively reshaped — instead, ancient builders used them as core design elements. Winding pathways create a labyrinth-like environment guiding visitors along a controlled route.

### Defensive Functions
- Irregular boulders created natural barriers slowing or confusing attackers
- Narrow pathways between rocks were easily monitored and blocked
- Elevated boulder tops served as **guard vantage points**
- Some boulders were positioned to be **dislodged and rolled down** onto approaching enemies (archaeological evidence of rolling-stone traps)

### Monastic & Residential Use
Many large rocks contain **drip-ledge caves** — natural or slightly modified shelters used by Buddhist monks **long before** Kashyapa's reign. Drip-ledges (shallow grooves cut into rock above cave entrances) diverted rainwater, keeping interiors dry and habitable for meditation.

Inscriptions near these caves record donations to the monastic community, confirming the site's religious importance predating the royal palace.

### The Audience Hall
A notable feature within the Boulder Gardens — a **large flat rock surface surrounded by carved seating stones**, believed to be where King Kashyapa met officials and conducted administrative affairs. The natural rock acted as a central platform with clear sightlines and natural acoustic properties.

### Environmental Integration
Boulders regulate temperature by providing shade and retaining coolness. Vegetation among rocks creates a microenvironment supporting both human activity and biodiversity — an early form of sustainable design.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'terraced_gardens',
    name: 'Terraced Gardens',
    emoji: '🌿',
    tags: ['garden', 'terraces', 'landscape', 'transition', 'slope'],
    imageAssets: [
      'assets/images/Sigiriya_terraced_gardens_08.jpg',
      'assets/images/sigirya-060.jpg',
      'assets/images/terraced-gardens-of-sigiriya-rock-fortress-in-sri-lanka-2HNJXMT.jpg',
      'assets/images/13102581095_687827e6c3_b.jpg',
      'assets/images/Sigiriya_terraced_gardens.jpg',
      'assets/images/terrance-1-1200x540.jpg',
    ],
    briefSummary:
        'The Terraced Gardens are built directly against the natural slope of the rock, '
        'linking the flat Water Gardens to the rugged Boulder Gardens above. Constructed '
        'with earthen embankments and stone retaining walls, they create a stepped visual '
        'rhythm and a gradual physical transition toward the summit.',
    detailedInfo: '''## Terraced Gardens — Detailed Explanation

The Terraced Gardens form a crucial transitional zone, linking the highly structured Water Gardens to the more rugged Boulder Gardens and the steep ascent toward the summit.

### Construction
Built using **earthen embankments reinforced with stone retaining walls**, creating a stepped formation following the rock's contours. Each level is carefully levelled to provide stable surfaces, preventing soil erosion in a tropical environment prone to heavy rainfall — demonstrating advanced geotechnical knowledge.

### Spatial Experience
Each terrace offers a slightly higher vantage point. This gradual ascent:
- Prepares visitors physically and psychologically for the demanding climb ahead
- Guides movement along defined paths connecting to the Boulder Gardens
- Creates a rhythmic visual pattern contrasting with the flat expanses below and irregular rock above

### Water Management
Although they lack the elaborate fountains and pools of the Water Gardens, the terraces incorporate **channels and drainage pathways** controlling rainwater flow and preventing erosion — integrated into Sigiriya's comprehensive hydraulic system.

### Functional Roles
- Circulation space between complex sections
- Possibly supported ornamental planting or light agriculture
- Defensive complexity — multiple levels visible from above allowing guards to monitor movement, and stepped layout slowing advancing groups

### Symbolism
The gradual ascent through the terraces can be interpreted as a journey from the ordinary world toward a more elevated or sacred realm — a progression from human to royal to divine space.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'summit_palace',
    name: 'Summit Palace',
    emoji: '👑',
    tags: ['palace', 'summit', 'royal', 'kashyapa', 'reservoir', 'panoramic'],
    imageAssets: [
      'assets/images/Screenshot 2026-05-05 201658.png',
      'assets/images/Screenshot 2026-05-05 201521.png',
      'assets/images/Sigiriya_800x520.jpg',
      'assets/images/Top-of-Sigiriya-Rock.jpg',
      'assets/images/Screenshot 2026-05-05 201348.png',
      'assets/images/44931990562_5d1ae592c3_b.jpg',
    ],
    briefSummary:
        'At the very top of the 200-metre rock lies the Summit Palace — King Kashyapa\'s '
        'royal residence. The remains include rock-cut water reservoirs still holding '
        'water today, foundations of royal chambers and audience halls, and a '
        '360-degree panoramic view of the surrounding landscape.',
    detailedInfo: '''## Summit Palace — Detailed Explanation

The Summit Palace sits at the physical and symbolic peak of Sigiriya — approximately **200 metres above the surrounding plains** — and served as the royal residence of King Kashyapa I in the 5th century AD.

### Physical Features
- **Rock-cut water reservoirs** carved directly into the stone, still holding water during rainy season
- Foundations and low walls outlining royal chambers, audience halls, storage areas, and pavilions
- Remnants of lime-based plaster suggesting decorated surfaces
- Open observation areas with **360-degree panoramic views**

### Strategic Importance
The commanding view of surrounding landscape had dual importance:
- **Practical** — early detection of approaching threats across many kilometres
- **Symbolic** — the elevated position reinforced the king's authority as ruler above all others

### Controlled Access
Reaching the summit required navigating through Water Gardens → Boulder Gardens → Terraced Gardens → Lion Gate → final stairways. This multi-layered approach ensured exclusivity, enhanced security, and psychologically reinforced the king's power.

### Environmental Design
At high elevation, the summit is exposed to strong winds, intense sunlight, and temperature variations. Layout and water features were designed to:
- Harness natural airflow for ventilation
- Use water evaporation for cooling
- Optimise building placement to reduce heat exposure

### Cosmological Interpretation
Some scholars suggest the summit symbolises **Mount Meru** (the sacred mountain in Buddhist and Hindu cosmology), positioning the king at the literal and spiritual centre of the universe.

### After Kashyapa
Following his defeat, the palace was abandoned and gradually reclaimed by nature. Archaeological excavations continue to reveal new insights into its layout and daily life.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'cobra_hood_cave',
    name: 'Cobra Hood Cave',
    emoji: '🐍',
    tags: ['cave', 'monks', 'meditation', 'geology', 'spiritual', 'natural'],
    imageAssets: [
      'assets/images/84327677-2732007033752656-8596502584838062080-n.jpg',
      'assets/images/sigiriya-rock-fortress-cobra-hood-cave-sri-lanka-BTYYN6.jpg',
      'assets/images/Cobra-Hood-Cave-Sigiriya-1-.jpg',
      'assets/images/220851f84c9778008f3f4d958ce30ce2-cave-in-cobra.jpg',
      'assets/images/LK94031444-04-E.jpg',
      'assets/images/cobra.jpg',
    ],
    briefSummary:
        'The Cobra Hood Cave is named for its natural rock formation resembling a cobra\'s '
        'expanded hood. Once a Buddhist monk meditation shelter, the cave features '
        'drip-ledges carved to keep it dry and carries powerful spiritual symbolism '
        'evoking the protective Naga (serpent) traditions of South Asian culture.',
    detailedInfo: '''## Cobra Hood Cave — Detailed Explanation

Located within the Boulder Gardens zone, the Cobra Hood Cave derives its name from a natural geological formation — a large granite boulder whose overhanging ledge closely resembles the **expanded hood of a cobra**.

### Geology
Formed from a large granite boulder weathered over time to create an overhanging ledge. The curved downward shape creates the visual impression of a poised cobra, a form carrying strong symbolic associations in South Asian culture.

### Monastic History
**Long before** Sigiriya became a royal palace, this cave was used by Buddhist monks. Evidence:
- **Drip-ledges** — shallow grooves cut above the cave entrance to divert rainwater and keep the interior dry
- Inscriptions in the vicinity recording donations to the monastic community
- Characteristic of ancient monastic sites across Sri Lanka

### Integration into the Royal Complex
Rather than removing the cave, builders incorporated it into the expanded complex. It may have served as:
- A place of quiet retreat or meditation even within the royal context
- Storage or resting areas
- A small shrine

### Spiritual Symbolism
In Buddhist tradition, the **Naga (serpent)** is a protective being. The story of **Mucalinda**, the serpent king who sheltered the Buddha by spreading his hood during a storm, is one of the most well-known. The cave's cobra shape would have evoked this association of **protection, guardianship, and spiritual power** for monks and visitors alike.

### Minimal Intervention Design
The cave required only minor modifications — drip-ledges — to make it usable. This demonstrates an early form of sustainable design where existing natural features are utilised rather than replaced.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'audience_hall',
    name: 'Audience Hall',
    emoji: '🏛️',
    tags: [
      'hall',
      'royal',
      'administrative',
      'seating',
      'governance',
      'boulder',
    ],
    imageAssets: [
      'assets/images/sigiriya-sri-lanka-february-5-2022-audience-hall-at-the-sigiriya-rock-fortress-at-sri-lanka-2PJ2XXW.jpg',
      'assets/images/Screenshot 2026-05-05 202411.png',
      'assets/images/033-Audience-Hall_5399(pp_w568_h378).jpg',
      'assets/images/Screenshot 2026-05-05 202104.png',
      'assets/images/sigiriya-22.jpg',
      'assets/images/sigiriya-rock13.jpg',
    ],
    briefSummary:
        'The Audience Hall is where King Kashyapa conducted royal and administrative '
        'affairs. Unlike conventional halls, it is an open-air rock platform surrounded '
        'by carved stone seats arranged for the court — combining natural geology '
        'with purposeful human design in the Boulder Gardens area.',
    detailedInfo: '''## Audience Hall — Detailed Explanation

The Audience Hall is one of the most compelling examples of how natural rock formations were adapted for royal and administrative purposes at Sigiriya.

### Design
Unlike conventional halls with walls and roofs, the Audience Hall is defined by:
- A **large, flat central rock platform** — possibly slightly modified for an even surface
- **Surrounding smaller stone seats** — evenly spaced and organised, suggesting designated positions for different ranks within the royal court
- **Open-air setting** — connected to the landscape, enhancing its sense of openness and grandeur

### Location & Access
Positioned within the Boulder Gardens along pathways connecting lower gardens to the upper fortress. This **intermediate location** allowed the king to meet visitors, officials, or envoys without granting direct access to the private summit palace — reinforcing hierarchical access within Sigiriya.

### Functions
- Administrative meetings and judicial proceedings
- Ceremonial gatherings and diplomatic interactions
- Larger gatherings than enclosed spaces — open-air design accommodates more participants

### Acoustics & Visibility
The arrangement of seating and natural rock contours may have **amplified sound** and ensured the king's voice carried clearly. The elevated central platform provided clear sightlines essential for formal and ceremonial contexts.

### Symbolism
The use of a natural rock as the central feature suggests stability, strength, and connection to the earth itself. It demonstrates that formal administrative authority did not require elaborate artificial structures — a thoughtfully arranged natural setting could be equally powerful.''',
  ),

  // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'defensive_structures',
    name: 'Defensive Structures',
    emoji: '🛡️',
    tags: [
      'defense',
      'moat',
      'rampart',
      'military',
      'walls',
      'fortress',
      'strategy',
    ],
    imageAssets: [
      'assets/images/Screenshot 2026-05-05 203254.png',
      'assets/images/Screenshot 2026-05-05 203149.png',
      'assets/images/642573cbf5397f001dba9bf1.jpg',
      'assets/images/images (5).jpg',
      'assets/images/Sigiriya_Luftbild_(29781064900).jpg',
      'assets/images/The Mirror Wall.jpg',
    ],
    briefSummary:
        'Sigiriya\'s defensive system is a multi-layered masterpiece combining outer moats, '
        'earthen ramparts, fortified walls, the natural height of the rock, and the '
        'Boulder Gardens\' rolling-stone traps. Every element — gardens, pathways, and '
        'rock formations — contributes to a unified and nearly impregnable defense.',
    detailedInfo: '''## Defensive Structures — Detailed Explanation

Rather than relying on a single wall, Sigiriya was designed as a **multi-layered defensive complex** where natural geography, engineered structures, and psychological deterrents worked together — developed during the reign of King Kashyapa I.

### Layer 1 — Outer Moats
Wide and deep moats surrounding the western entrance. Water continuously filled them, possibly housing **crocodiles** (debated by scholars). Narrow crossing points forced attackers into easily targeted bottlenecks.

### Layer 2 — Ramparts & Fortified Walls
Earthen-and-brick ramparts elevated above the terrain, aligned along the land's contours for maximum coverage. Some areas feature **double-layered defenses** for extra protection at vulnerable zones.

### Layer 3 — Controlled Pathways
The entire layout guides visitors through specific routes. Pathways narrow at critical points, forcing movement in single file or small groups — making rapid large-force advancement impossible.

### Layer 4 — Boulder Gardens
- Natural boulders as obstacles and choke points
- **Rolling-stone mechanisms** — boulders positioned to be dislodged onto attackers
- Elevated rock surfaces as **guard posts** with clear visibility

### Layer 5 — Lion Gate
Final checkpoint before the summit. Narrow, elevated entrance controls all movement through a single point. Structurally and psychologically intimidating.

### Layer 6 — The Rock Itself
Rising **nearly 200 metres**, with ascent limited to a few constructed stairways. Attackers would climb exposed routes under constant observation from above.

### Surveillance & Water Supply
- Panoramic views enable detection of threats from kilometres away
- Internal water reservoirs ensure sustainability during long sieges — cutting off supply was ineffective

### Psychological Warfare
The imposing height, complex pathways, and grandeur of the Lion Gate intimidate and disorient attackers before they reach any critical defense point. The demanding climb weakens enemy forces physically and psychologically.''',
  ),

    // ─────────────────────────────────────────────────────────────────
  SigiriyaLocation(
    id: 'ticket_counter',
    name: 'Ticket Counter',
    emoji: '🎟️',
    tags: ['ticket', 'entrance', 'information', 'visitor', 'entry', 'counter'],
    imageAssets: ['assets/images/Ticket01.jpeg',
      'assets/images/Ticket02.jpeg',
      'assets/images/Ticket03.jpeg',
      'assets/images/Ticket04.jpeg',
      'assets/images/Ticket05.jpeg',
      'assets/images/Ticket06.jpeg',
    ],
    briefSummary:
        'The Ticket Counter is the official entry point for visitors to Sigiriya, '
        'where entrance tickets are purchased before accessing the site. It marks '
        'the beginning of the visitor journey toward the ancient fortress complex.',
    detailedInfo: '''## Ticket Counter — Detailed Explanation

The Ticket Counter serves as the primary entry point for all visitors to Sigiriya Rock Fortress. Before entering the archaeological site, visitors must obtain their official tickets here.

### Location & Role
Positioned near the main entrance area, the counter acts as the **gateway to the entire Sigiriya complex**. All visitors—local and international—are required to pass through this point.

### Functions
- Issuing entrance tickets
- Providing basic visitor information
- Acting as a checkpoint for site access
- Sometimes offering brochures or guidance

### Visitor Experience
The Ticket Counter is typically the **first interaction point** with the site. During peak tourist seasons, queues may form, so early arrival is recommended.

### Practical Tips
- Keep your ticket safe, as it may be checked at multiple points
- Prices may vary for local and foreign visitors
- It’s advisable to carry cash or check available payment methods in advance

### Importance in Site Flow
Although not part of the ancient structure, the Ticket Counter plays a crucial role in **modern site management**, helping regulate visitor flow and preserve the heritage site.''',
  ),

];

/// All location names for the dropdown/search
List<String> get kLocationNames =>
    kSigiriyaLocations.map((l) => l.name).toList();

/// Find a location by name (case-insensitive, partial match)
SigiriyaLocation? findLocation(String query) {
  final q = query.toLowerCase().trim();
  // exact match first
  for (final loc in kSigiriyaLocations) {
    if (loc.name.toLowerCase() == q) return loc;
  }
  // partial match
  for (final loc in kSigiriyaLocations) {
    if (loc.name.toLowerCase().contains(q) ||
        loc.tags.any((t) => t.contains(q))) {
      return loc;
    }
  }
  return null;
}

/// Simple keyword-based similarity (offline RAG retrieval without ML model)
List<SearchResult> searchLocations(String query, {int topK = 3}) {
  final q = query.toLowerCase();
  final words = q.split(RegExp(r'\s+'));

  final results = <SearchResult>[];

  for (final loc in kSigiriyaLocations) {
    double score = 0;
    final searchText = '${loc.name} ${loc.tags.join(' ')} ${loc.briefSummary}'
        .toLowerCase();

    for (final word in words) {
      if (word.length < 3) continue;
      if (loc.name.toLowerCase().contains(word)) score += 3.0;
      if (loc.tags.any((t) => t.contains(word))) score += 2.0;
      if (searchText.contains(word)) score += 1.0;
    }

    if (score > 0) {
      results.add(SearchResult(location: loc, score: score));
    }
  }

  results.sort((a, b) => b.score.compareTo(a.score));
  return results.take(topK).toList();
}
