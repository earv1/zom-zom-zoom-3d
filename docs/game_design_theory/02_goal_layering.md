# Goal Layering: Short, Medium, and Long-Term Goals

The single most important structural principle for keeping players engaged across a full session and beyond.

---

## Sid Meier — Interesting Decisions & Layered Goals

**Source:** "Interesting Decisions" — GDC 2012 Keynote
- GDC Vault (free): https://www.gdcvault.com/play/1015756/Interesting
- Write-up: https://www.gamedeveloper.com/design/gdc-2012-sid-meier-on-how-to-see-games-as-sets-of-interesting-decisions
- VentureBeat keynote quotes: https://venturebeat.com/business/quotes-from-sid-meiers-keynote-gdc-speech
- Lessons from Sid Meier: https://www.antoinebuteau.com/lessons-from-sid-meier/

### The Foundational Definition

Meier's original formulation (GDC 1989, revisited 2012):

> **"A game is a series of interesting decisions."**

A decision is **interesting** when it is neither automatic nor random — it sits between "always obvious" and "completely arbitrary."

**Test:** If playtesters always pick option A without thinking, it's too easy. If they pick randomly because they can't tell the difference, it's too arbitrary. Both are design failures.

### Characteristics of an Interesting Decision

- **Tradeoffs** — every option has a real cost
- **Situational context** — the best option changes with game state; "Good decisions are situational"
- **Personal expression** — accommodates different playstyles
- **Meaningful consequences** — the game visibly acknowledges the choice mattered
- **Proper pacing** — "Rapid-fire complex decisions overwhelm; slow simple decisions bore"

### The Three-Layer Goal Framework

> **"Always have short, medium, and long-term goals for the player."**

> *"One of the strengths of Civilization is that it has things happening on multiple levels at once in terms of short-, medium- and long-term events."*

| Layer | Example in Civilization | Decision type |
|---|---|---|
| **Short-term** | Build a chariot (quick, immediate tactical value) | Tactical / reactive |
| **Medium-term** | Strategic positioning, resource management | Operational |
| **Long-term** | Build a Wonder (many turns, enduring structural impact) | Strategic / investment |

The player's task is to **manage near-term goals in a way that makes long-term goals more accessible** — with the two levels in constant productive tension. The prioritization across these layers is itself the interesting decision.

### On What Makes Games Fun

> *"The combination of this wonderful fantasy world and the interesting decisions players make within it really is the sum total of the quality of your game."*

Meier explicitly warns against over-engineering player psychology. His iteration philosophy: *"Probably a third of the things that we try end up getting taken out because they're not fun and interesting enough."* Fun comes from decisions working, not feature accumulation.

---

## Jesse Schell — The Art of Game Design

**Source:** *The Art of Game Design: A Book of Lenses* (3rd ed., Routledge)
- Notes: https://notesbylex.com/the-art-of-game-design-a-book-of-lenses-2nd-edition-by-jesse-schell
- MIT slides: https://seari.mit.edu/documents/presentations/BasicsGameDesign.pdf

### Lens #25: The Lens of Goals

> *"What is the player's true motivation — not just the goals your game has set forth, but the reason the player wants to achieve those goals?"*

This is the distinction between **stated goals** (beat the level) and **underlying motivation** (feel competent, tell a story about myself, socialize).

### Goal Hierarchy Principle

> *"Players should always know what to do next and what they're ultimately working towards."*

- The **short-term goal** provides the immediate action
- The **long-term goal** provides the meaning that makes the action worth taking

Schell maps gaming's core functions onto Maslow's hierarchy: games satisfy belonging (social play), esteem (fair competition and mastery feedback), and self-actualization (creative expression).

---

## Applied Examples: Modern Games

### Hades (Supergiant Games)

**Sources:**
- Greg Kasavin interview: https://www.gamedeveloper.com/design/roguelikes-and-narrative-design-with-i-hades-i-creative-director-greg-kasavin
- GDC Podcast Ep. 16: https://gdconf.com/article/roguelikes-and-narrative-design-with-hades-creative-director-greg-kasavin-gdc-podcast-ep-16/
- Narrative reward analysis: https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death

| Layer | Goal |
|---|---|
| **Immediate** (within-room) | Survive this encounter; use the current boon combination effectively |
| **Session** (within-run) | Reach the surface; pursue specific weapon mastery; manage build synergies |
| **Meta** (cross-run) | Unlock story beats; build character relationships; permanent upgrades; reach the "true ending" |

**Kasavin's key design principle:**

> *"There's nothing more frustrating where you're really engaged with the story, but then you hit a difficulty wall. So we try to build systems into our games that mitigate those moments."*

Every death advances *something* — narrative (new dialogue), meta-currency, or relationship progress. The failure state is never "nothing happened." Death becomes a reward delivery mechanism.

**Narrative reactivity as goal-layer reinforcement:**

> *"Reactivity has always been a goal of our narrative design — to have those moments where you feel the game is paying attention."*

The game observes player state mid-run (low health, specific items) and surfaces contextually-appropriate dialogue, creating personalized short-term acknowledgment — the game *responds* to what you're doing right now.

---

### Slay the Spire

**Sources:**
- Roguelite progression thesis: https://www.theseus.fi/bitstream/handle/10024/881994/Kammonen_Eino.pdf
- Game Rant: https://gamerant.com/roguelite-games-with-best-progression-systems/

| Layer | Goal |
|---|---|
| **Immediate** | Build synergies from card/relic offerings; survive each combat |
| **Session** | Complete the Spire with a specific character; defeat the final boss |
| **Meta** | Unlock additional cards (5 tiers per character); Ascension mode (20 difficulty levels); Daily Challenges |

**Notable anti-compulsion design:** Ascension converts long-term mastery into *more challenge* rather than *more reward*. Skilled players are offered more interesting difficulty, not easier play. This satisfies Lazzaro's Hard Fun and Koster's mastery model without variable ratio reward scheduling.

---

### The Binding of Isaac — McMillen

**Sources:**
- Postmortem: https://www.gamedeveloper.com/business/postmortem-mcmillen-and-himsl-s-i-the-binding-of-isaac-i-
- Design analysis: https://www.kokutech.com/blog/gamedev/design-patterns/unique-mechanics/the-binding-of-isaac

| Layer | Goal |
|---|---|
| **Immediate** | Survive this room |
| **Session** | Survive the full run |
| **Meta** | Unlock all items, complete all challenges, reach the true ending (requires hundreds of runs) |

The sheer number of items with ambiguous interactions was intentional — it built **community-driven discovery**:

> *"The sheer number of collectables, their sometimes ambiguous functions, and the random level generation were intended to build a sense of mystery, one that players would unravel over time, collaborating with one another."*

---

## The Escalating Investment Model

**Source:** https://www.gamedeveloper.com/design/short-vs-long-term-progression-in-game-design and https://game-wisdom.com/critical/short-long-term-progression-game-design

Each layer increases the player's psychological investment in the next:

> *"Combining both short and long-term progression provides the best combination to keep someone engaged."*

Because I spent 20 hours building this character, the long-term goal (see how the story ends) now carries real weight. Short-term goals are the mechanism; the long-term goal is the reason.

---

## Framework for Zom Zom Zoom

Applying Meier's three layers to an arcade racing survival game:

| Layer | Duration | Design questions |
|---|---|---|
| **Short-term** | Seconds to a minute | What is the player deciding *right now*? (ram this enemy? dodge? boost? fire?) — are these interesting decisions with real tradeoffs? |
| **Medium-term** | One run (5–15 min) | What build am I constructing? What weapon synergy am I pursuing? Can I reach the exit? |
| **Long-term** | Multiple runs / sessions | Permanent unlocks? Meta-progression? Narrative discoveries? A "true ending" to work toward? |

The gap between Zom Zom Zoom's current state and this framework: the **long-term layer is currently weak**. The game has excellent moment-to-moment feel and a functional session layer (survive + upgrade), but lacks a compelling meta-progression reason to return across multiple sessions.
