# Branded Wor(l)ds — Flow-Parametrisierung

Dokument für Andreas (Power Automate). Stand: 2026-05-27 (final).

---

## 1. Approval-Buttons (Steven)

Drei Custom Responses in der Approval-Action. Kein Freitext im Browser.

**Wichtig:** Nur zwei davon sind echte Rejects. Der dritte ist **kein Reject**, sondern eigener Status `needs_more_info`.

| # | Button-Label | Outcome | Key | SharePoint `status` |
|---|---|---|---|---|
| 1 | Thematisch aktuell nicht passend | Reject | `reject_topic_mismatch` | `rejected` |
| 2 | Aktuell keine Kapazität | Reject | `reject_no_capacity` | `rejected` |
| 3 | Mehr Kontext nötig | Custom (nicht Reject) | `needs_more_info` | `needs_more_info` |

### Standardtexte an den Gast (Englisch)

Betreff für Rejects: `Branded Wor(l)ds — Update on your application`  
Betreff für Rückfrage: `Branded Wor(l)ds — Additional information needed`

#### reject_topic_mismatch

```
Thank you for your application.

At the moment, the topic does not align closely enough with our current editorial direction and planned episodes.

Best regards,
Steven Baumgaertner & Jeff Solomon
Branded Wor(l)ds
```

#### reject_no_capacity

```
Thank you for your application.

Our current production and recording schedule is fully booked at the moment, so we are unfortunately unable to move forward right now.

Best regards,
Steven Baumgaertner & Jeff Solomon
Branded Wor(l)ds
```

Formulierung bewusst **„at the moment“ / „right now“** — keine endgültige Ablehnung, Tür bleibt offen.

#### needs_more_info (keine Reject-Mail)

```
Thank you for your application.

Before we can continue reviewing your request, we would need a bit more context regarding your topic and intended discussion focus.

Our team will reach out shortly.

Best regards,
Steven Baumgaertner & Jeff Solomon
Branded Wor(l)ds
```

### Flow-Logik (Approval)

```
Approval Response
  → Switch auf responseKey

  reject_topic_mismatch:
    → status = rejected
    → rejectionReason = reject_topic_mismatch
    → Gast-Mail (Template oben)

  reject_no_capacity:
    → status = rejected
    → rejectionReason = reject_no_capacity
    → Gast-Mail (Template oben)

  needs_more_info:
    → status = needs_more_info
    → rejectionReason = null
    → Rückfrage-Mail (Template oben)
    → KEIN rejected-Status, KEINE Reject-Statistik

  Approve:
    → status = approved
    → Slot-Generator + Gast-Mail mit 3 Slot-Buttons (Abschnitt 2 + 3)
```

**Regel:** `needs_more_info` niemals als `rejected` speichern. Sonst verfälschen sich Statistiken und Timelines.

---

## 2. Approve — Terminvorschläge (Parametrisierung)

### Annahmen (Default)

| Parameter | Wert | Beschreibung |
|---|---|---|
| `slotWindowStart` | Montag 00:00, **nächste Woche** | Erster buchbarer Tag |
| `slotWindowEnd` | Freitag 23:59, **übernächste Woche** | Letzter buchbarer Tag |
| `weekdaysOnly` | `true` | Mo–Fr, keine Wochenenden |
| `slotDurationMinutes` | `120` | 2-Stunden-Slots |
| `slotCount` | `3` | Anzahl Vorschläge |
| `slotSpreadRule` | `3 unterschiedliche Tage` | Jeder Vorschlag auf separatem Kalendertag |
| `calendarSource` | Stevens Outlook-Kalender (`booking@` oder Steven) | Freie/busy-Prüfung |
| `timezone` | `Europe/Berlin` | CET/CEST |

### Slot-Generierung (Pseudologik)

```
1. windowStart = nextMonday(today + 7d)   // Start nächste Woche
2. windowEnd   = endOfWeek(windowStart + 7d)  // Ende übernächste Woche
3. candidates = all 2h blocks Mo–Fr in [windowStart, windowEnd]
4. free = candidates WHERE Steven calendar is free
5. pick 3 slots on 3 different dates (earliest first, spread across days)
6. output slotProposal1..3 with ISO8601 start/end + display label
```

### Beispiel-Output in Approve-Mail an Gast

```
Wir freuen uns, Sie als Gast bei Branded Wor(l)ds begrüßen zu dürfen.

Bitte wählen Sie einen der folgenden Termine (je 2 Stunden, per Teams):

Option 1: Dienstag, 03.06.2026 — 10:00–12:00 (CEST)
Option 2: Donnerstag, 05.06.2026 — 14:00–16:00 (CEST)
Option 3: Montag, 09.06.2026 — 09:00–11:00 (CEST)

[Button: Option 1 wählen] [Button: Option 2 wählen] [Button: Option 3 wählen]
```

---

## 3. Flow #2 — Slot-Auswahl per Buttons (nächster Flow)

Gleiches Prinzip wie Reject: **kein Freitext, keine Reply-Mail, nur Buttons.**

Nach Approve erzeugt Flow #1 drei Slots und verschickt eine Gast-Mail mit **drei klickbaren Buttons**. Jeder Button ruft **Flow #2** (eigener HTTP Trigger) mit eindeutiger `slotId` auf.

### Flow-Übersicht

```
Flow #1  Application
  → Approval (Steven)
    → Reject: 3 Custom Buttons → feste Gast-Mail
    → Approve: Slot-Generator → Gast-Mail mit 3 Slot-Buttons

Flow #2  Slot Confirmation (HTTP Trigger)
  → Payload: guestId, slotId, selectedStart, selectedEnd
  → Validierung (Status, Token, Slot noch frei)
  → Outlook-Termin + Teams-Meeting
  → Bestätigungs-Mail an Gast + Steven/Jeff
  → SharePoint: status = scheduled
```

### Button-Labels in der Approve-Mail (Gast)

| Button | `slotId` | Beispiel-Label |
|---|---|---|
| 1 | `slot_1` | Di, 03.06. — 10:00–12:00 Uhr |
| 2 | `slot_2` | Do, 05.06. — 14:00–16:00 Uhr |
| 3 | `slot_3` | Mo, 09.06. — 09:00–11:00 Uhr |

Label = menschenlesbarer Termin. Technisch eindeutig über `slotId` + ISO-Zeiten in der URL oder im Query-String.

### Technische Umsetzung der Buttons

**Empfohlen:** HTML-Action-Buttons in der Outlook-Mail (via „E-Mail senden“ mit HTML-Body):

```html
<a href="{{slotConfirmUrl_1}}" style="...">Di, 03.06. — 10:00–12:00 Uhr</a>
<a href="{{slotConfirmUrl_2}}" style="...">Do, 05.06. — 14:00–16:00 Uhr</a>
<a href="{{slotConfirmUrl_3}}" style="...">Mo, 09.06. — 09:00–11:00 Uhr</a>
```

Jede URL zeigt auf **Flow #2 HTTP Trigger** mit signierten Parametern:

```
POST https://.../workflows/{flow2-id}/triggers/manual/paths/invoke?...
  ?guestId={{guestId}}
  &slotId=slot_1
  &selectedStart=2026-06-03T08:00:00Z
  &selectedEnd=2026-06-03T10:00:00Z
  &sig=...
```

Alternativ: ein gemeinsamer Endpoint, Slot-Daten im JSON-Body per POST-Link (wenn PA das unterstützt) — sonst GET-safe Link mit Query-Parametern und serverseitiger Validierung.

**Wichtig:** Flow #2 braucht **eigenen** `x-api-token`-Check (gleiche SharePoint-Liste oder separater Slot-Token pro `guestId`).

### Flow #2 — HTTP Payload

```json
{
  "guestId": "test-001",
  "slotId": "slot_1",
  "selectedStart": "2026-06-03T08:00:00Z",
  "selectedEnd": "2026-06-03T10:00:00Z",
  "confirmedAt": "2026-05-27T10:00:00Z"
}
```

### Flow #2 — Logik

```
1. Token + guestId + slotId validieren
2. SharePoint: status muss approved sein, Slot noch nicht vergeben
3. Kalender erneut prüfen (Slot noch frei?)
4. Outlook-Termin erstellen (2h, Teams-Meeting)
5. Gast-Mail: „Ihr Termin steht: …“ + Teams-Link
6. Interne Mail: Steven + Jeff (+ Michael)
7. SharePoint: selectedSlotStart, teamsMeetingUrl, status = scheduled
8. HTTP Response 200: „Termin bestätigt“ (optional Bestätigungsseite)
```

### Gast-Erlebnis nach Klick

Minimal: Browser öffnet sich kurz mit „Termin bestätigt — Sie erhalten eine E-Mail.“ (PA Response oder statische Danke-Seite).

Kein leeres Approval-Fenster — Flow #2 ist reine Bestätigung, kein weiterer Dialog.

### Schutz gegen Doppelbuchung

- Erster Klick auf einen Slot → `status = scheduled`
- Weitere Klicks (andere Slots oder Repeat) → Flow #2 bricht ab: „Termin bereits gebucht“

---

## 4. Abgelehnte Alternativen (Slot-Rückmeldung)

### Option B — Antwort per E-Mail

Gast antwortet mit „Option 1“ / „Option 2“ / „Option 3“.

Nachteil: fehleranfällig, Mehrdeutigkeiten, Spam-Risiko. **Nicht empfohlen.**

### Option C — Microsoft Bookings nach Approve

Nachteil: zweites Tool, weniger Kontrolle über exakt 3 Vorschläge. **Nicht empfohlen.**

**Empfehlung v1:** Flow #2 mit **3 Mail-Buttons** (siehe oben).

---

## 5. Statusmodell (SharePoint / intern)

Vier Kern-Status. Keine Soft-Rejects, keine Maybe-States.

| status | Bedeutung | Gast-Mail |
|---|---|---|
| `pending` | Bewerbung eingegangen | Auto-Response (optional) |
| `needs_more_info` | Rückfrage, noch in Prüfung | Rückfrage-Mail |
| `approved` | Zusage, Slot-Buttons versendet | Approve-Mail mit 3 Buttons |
| `rejected` | Final abgelehnt | Reject-Mail (2 Gründe) |
| `scheduled` | Gast hat Slot gewählt | Termin-Bestätigung |
| `completed` | Aufnahme durch | — |

Felder:

```json
{
  "guestId": "string",
  "status": "pending | needs_more_info | approved | rejected | scheduled | completed",
  "reviewedAt": "ISO8601",
  "reviewedBy": "string",
  "rejectionReason": "reject_topic_mismatch | reject_no_capacity | null",
  "slotProposal1Start": "ISO8601",
  "slotProposal2Start": "ISO8601",
  "slotProposal3Start": "ISO8601",
  "selectedSlotStart": "ISO8601",
  "teamsMeetingUrl": "string"
}
```

`rejectionReason` nur bei `status = rejected`. Bei `needs_more_info` immer `null`.

### Status-Transition-Regeln

Nur diese Übergänge sind erlaubt. Jeder Flow prüft den **aktuellen** Status vor dem Schreiben.

```
pending
  → approved
  → rejected
  → needs_more_info

needs_more_info
  → approved
  → rejected

approved
  → scheduled

scheduled
  → completed
```

**Final-Status (keine weiteren Übergänge):**

| Status | Final |
|---|---|
| `rejected` | ja |
| `completed` | ja |

Alle anderen Status dürfen nur entlang der Pfeile oben wechseln. Kein Sprung z.B. von `pending` direkt nach `scheduled` oder von `rejected` zurück nach `approved`.

**Beispiel-Guard in PA:**

```
IF currentStatus = 'pending' AND action = 'approve'  → set approved
IF currentStatus = 'pending' AND action = 'reject_*' → set rejected
IF currentStatus = 'pending' AND action = 'needs_more_info' → set needs_more_info
IF currentStatus = 'needs_more_info' AND action = 'approve' → set approved
IF currentStatus = 'needs_more_info' AND action = 'reject_*' → set rejected
IF currentStatus = 'approved' AND slotConfirmed → set scheduled
IF currentStatus = 'scheduled' AND recordingDone → set completed
ELSE → Flow abbrechen / Fehler loggen
```

---

## 6. Formular-Payload (unverändert)

```json
{
  "guestId": "string",
  "guestName": "string",
  "guestEmail": "string",
  "guestCompany": "string",
  "guestRole": "string",
  "guestBio": "string",
  "guestStory": "string",
  "guestFit": "string",
  "website": "",
  "submittedAt": "ISO8601"
}
```

---

## 7. Security / Token

- `API_TOKEN` wird gegen SharePoint-Liste geprüft
- Bei Leak: SharePoint **und** alle Clients (`.env.local`, später Proxy) gleichzeitig rotieren
- Token und Flow-URL **niemals** ins Frontend

---

## 8. Offene Punkte für Abstimmung

| # | Frage | Vorschlag |
|---|---|---|
| 1 | Welcher Kalender für Frei/busy? | Stevens Outlook |
| 2 | Aufnahme-Dauer fix 2h? | ja (Parametrisierbar) |
| 3 | Uhrzeiten-Band? | z.B. 09:00–17:00 CET |
| 4 | Slot-Auswahl | Flow #2 mit 3 Mail-Buttons |
| 5 | Teams-Meeting auto? | ja, bei Slot-Button-Klick |
| 6 | Danke-Seite nach Slot-Klick? | statische HTML oder PA Response |

---

## 9. Nächste Schritte

1. Andreas: Custom Reject Buttons + Templates (Flow #1)
2. Andreas: Slot-Generator + Approve-Mail mit 3 Buttons (Flow #1)
3. Andreas: Flow #2 Slot Confirmation (HTTP + Token + Outlook + Teams)
4. Michael: Formular anbinden (nach Approve/Reject-Test grün)
5. E2E: Bewerbung → Approve → 3 Slot-Buttons → Termin steht
