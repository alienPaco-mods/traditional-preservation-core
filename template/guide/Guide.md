# Traditional Preservation: __UPPER__
### The Official Player's Guide

> *"TEMPLATE: an epigraph."*

---

## Contents
1. What This Mod Does
2. Quick Start
3. Walkthrough
4. The __STATION__
5. Secrets & Hidden Features
6. Tips
7. Troubleshooting
8. Sandbox Settings
9. Appendix: The Tester's Toolkit

---

## 1. What This Mod Does

TEMPLATE: the problem in vanilla, and the real technique this mod brings back.

---

## 2. Quick Start

| Step | You need | You get |
|---|---|---|
| Build a **__STATION__** | 4 planks, 8 nails, hammer (kept). Carpentry 2 | The station |
| Load it, press **Craft** | Up to 4 Raw __NAME__ Batches | |
| Wait **3 in-game days** (at the best temperature) | | Finished __NAME__ Batches |

---

## 3. Walkthrough

TEMPLATE

---

## 4. The __STATION__

- **Each press of Craft starts its own timer.**
- **Temperature matters.** In open air it follows the day's weather; under an open roof or indoors the average of the
  last ten days (a room is 22 C while the grid is on); in a loft (the top storey) as indoors, plus three tenths of
  whatever that average is above 10 C; in a basement it follows the ground, a month behind the season and two fifths
  as far from 10 C (about 5 C from January to March, 13 C from July to September); by a fire 28 C, banked embers 24 C.

> **Margin note:** TEMPLATE: a real-world note.

---

## 5. Secrets & Hidden Features

TEMPLATE

---

## 6. Tips

TEMPLATE

---

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| The station or recipes don't appear | Check `~/Zomboid/console.txt`. |

---

## 8. Sandbox Settings

| Setting | Default | What it does |
|---|---|---|
| Processing time (days) | 3 | Days a batch takes at the best temperature. |
| Temperature sensitivity | Normal | Off, Forgiving, Normal, Harsh. Off ignores the weather. |

---

## 9. Appendix: The Tester's Toolkit

Copied from `DEVHELP.md`; change both together.

| Command | What it does |
|---|---|
| `__SHORT__.weather()` | Temperature and speed by place. |
| `__SHORT__.here()` | Which kind of place you're standing in. |
| `__SHORT__.age(hours)` | Hours of perfect weather for every station. |
| `__SHORT__.fast(hours)` | Test timer. `__SHORT__.fast()` goes back to the sandbox time. |
| `__SHORT__.give(name, n)` | Spawns `n` of: `"batch"` (a raw batch). `__SHORT__.give()` lists them. |
