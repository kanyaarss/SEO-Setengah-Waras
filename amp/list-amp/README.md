# AMP HTML Library — list-amp

This directory contains a curated collection of **ready-to-use AMP HTML templates**.

These templates are not “plug and pray”.
They are meant to be **adapted, aligned, and deployed** with intent.

Every AMP file in this folder requires **manual customization** before use.
Skipping this step is the fastest way to get ignored, filtered, or flagged.

---

## Purpose

The goal of this library is simple:

- Speed up AMP page deployment  
- Maintain structural consistency  
- Reduce rookie mistakes  
- Give you control over AMP behavior, not the other way around  

This is **not** a generator.
This is **a framework for people who know what they’re doing**.

---

## Required Modifications (Mandatory)

Before publishing any AMP HTML from this folder, you **must** review and modify the following elements.

If you don’t — the page is considered **unfinished**.

### 1. TITLE

- Change the `<title>` tag
- Make it relevant to the target page
- Avoid generic or duplicated titles

> AMP does not forgive lazy titles.

---

### 2. META DESCRIPTION

- Update `<meta name="description">`
- Match search intent, not keyword stuffing
- Keep it human-readable

> Meta description is behavioral bait, not decoration.

---

### 3. AMP LINK DESTINATION

- Update the canonical or outbound AMP target
- Ensure the link reflects the correct destination
- Avoid mismatched intent between AMP page and target page

> Broken intent kills trust faster than broken HTML.

---

### 4. BRAND NAME

- Replace all placeholder brand names
- Keep branding consistent across AMP and non-AMP pages
- Do not reuse brands across unrelated assets

> Confused branding is a signal — and not a good one.

---

### 5. IMAGES

- Replace all image assets
- Verify:
  - correct dimensions
  - proper AMP `<amp-img>` usage
  - optimized file size
- Never deploy with placeholder images

> Images are signals. Treat them like one.

---

### 6. SHORTLINK

- Replace all shortlinks with your own
- Verify redirection path and final landing page
- Avoid reused or burned shortlinks

> Shortlinks leak intent. Manage them carefully.

---

## Final Checklist (Before Deploy)

Before pushing any AMP page live, **check again and modify what’s needed**:

- [ ] Title is unique and relevant  
- [ ] Meta description is intentional  
- [ ] AMP link destination is correct  
- [ ] Brand name is accurate  
- [ ] Images are replaced and validated  
- [ ] Shortlinks are clean and functional  

If one of these feels “optional”, you’re doing it wrong.

---

## Notes

- Some templates are intentionally minimal  
- Some structures may look outdated — that’s on purpose  
- Test, observe, log, adjust  

AMP behavior changes.
Your discipline shouldn’t.

---

## Disclaimer

This library is provided for **research and implementation purposes**.

You are responsible for:
- how these templates are used
- where they are deployed
- and what they point to

Understand the system before you try to bend it.

---

Built with a half-sane mindset by **Kanyaars**  
