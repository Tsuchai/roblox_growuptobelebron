# LeBonBon: Draft & Player Evolution System

## 1. The Two-Round Draft System
Instead of a simple 5-slot board, the Special Event Draft becomes a full 2-Round NBA-style draft.
* **Round 1 (14 Picks):** The "Lottery". Contains elite, NBA-ready players (Pro, All-Star, LeBron).
* **Round 2 (14 Picks):** The "Development Project". Contains raw, unproven talent (Rookie, College).

### Draft Flow:
1. Player pays $2,500 Cash to enter the draft during the 60-second active window.
2. The server randomly assigns them to **Round 1** (e.g., 15% chance) or **Round 2** (e.g., 85% chance).
3. The server generates a 14-player board for that specific round.
4. The player is assigned a random pick number (1-14).

### Monetization (Robux):
* **Jump to Round 1:** If assigned to Round 2, the UI pauses and offers a choice: *Accept Round 2, OR pay Robux to guarantee a Round 1 Lottery ticket.*
* **Steal a Pick:** Within their assigned round, players can pay Robux to steal a pick drafted before them (e.g., if you are Pick #4, you can pay to steal Pick #1). Cost scales based on how high the target pick is.

---

## 2. Player Evolution (Leveling System)
To ensure Round 2 picks remain engaging, players can now level up their shooters organically by leaving them on the court.

### XP & Leveling Mechanics:
* **Gaining XP:** Every time a shooter successfully takes a shot on the court, they gain **1 XP**.
* **Level Cap:** Shooters have a maximum level (e.g., Level 10).
* **Level Thresholds:** XP required to level up increases progressively (e.g., Lvl 2 = 50 XP, Lvl 3 = 150 XP, Lvl 4 = 300 XP).

### Stat Scaling per Level:
When a shooter levels up, their stats permanently increase:
* **Yield Bonus:** +10% base cash per shot per level.
* **Cooldown Reduction:** -0.1s or -5% shot cooldown time per level (they shoot faster).
* **Accuracy/Range:** (Optional) Their specific attribute bonuses slightly increase.

### Tier Differences (Development Curves):
* **Round 2 Prospects (Rookie/College):** Start weak, but require very little XP to level up. They are "fast learners". A fully maxed-out Rookie becomes highly valuable.
* **Round 1 Elites (All-Star/LeBron):** Start incredibly strong, but require massive amounts of XP to level up.

---

## 3. UI/UX Additions
* **Player Tags:** The BillboardGui above shooters will now display their level and XP progress (e.g., `[Lv. 1] Rookie (12/50 XP)`).
* **Level Up Celebration:** When a shooter levels up on the court, a bright particle explosion, a unique sound effect, and floating text ("LEVEL UP!") will play.
* **Expanded Draft Board:** The cinematic Draft UI will be expanded into a 14-slot scrolling frame with Gold styling for Round 1 and Silver styling for Round 2.

---

## 4. The "Blockbuster Trade" System (Replaces Merge)
Instead of a simple "merge 3 to get 1" mechanic, players can now engage in a dynamic NBA-style Trade Machine.

### How it Works:
1. **Trade Value:** Every shooter has a hidden "Trade Value" based on their Tier and Level.
   * *Example:* A Level 1 Rookie = 1 Value. A Level 10 Rookie = 4 Value. A Level 1 College = 5 Value.
2. **Packaging:** The player selects up to 3 unequipped shooters from their inventory to "Offer" in a trade block.
3. **The Offer:** The system calculates the total Trade Value and generates 3 random "Counter-Offers" from NPC GM's.

### Example Offers (Dynamic Generation):
If the player offers 3 College players (Total Value = 15), the system might generate:
* **Offer A (The Safe Bet):** 1 Pro Player + $5,000 Cash.
* **Offer B (The Futures Package):** 1 College Player + 1 "Free Agency Draft Ticket".
* **Offer C (The High Risk):** 1 highly-leveled (Lv. 5) College Player with a rare attribute.

**Draft Ticket Nuance:**
* Trade packages will mostly offer **lower-tier tickets** (like Free Agency Standard/Premium rolls).
* **Super Rare Chance:** A low % chance to roll a "Special Event Draft Ticket" (which bypasses the 5-minute timer).
* **High-Value Guarantee:** If the player packages a very high-tier player (like an All-Star), the chances of receiving a "Special Event Draft Ticket" in the return package increase dramatically.

This completely replaces the boring merge system with an exciting minigame where players feel like real NBA General Managers trying to fleece the system for a blockbuster trade!
