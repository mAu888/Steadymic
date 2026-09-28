---
paths:
  - "**/*.xcstrings"
---

# German localization

German translations do not address the user directly, neither informally (du, dir, dich, dein) nor formally (Sie, Ihnen, Ihr).
String catalogs have no formality variant, and macOS has no du/Sie preference, so no single choice matches every user.

Phrase German strings impersonally instead:

- Passive voice: "%@ wurde ausgewählt" instead of "Du hast %@ ausgewählt".
- Nominalization: "Die Auswahl eines Eingangs im Menü …" instead of "Wenn du im Menü einen Eingang auswählst …".
- Infinitive for instructions: "Steadymic im Ordner „Programme“ öffnen." instead of "Öffne Steadymic …".
- Questions without a pronoun: "Gefällt die App?" instead of "Gefällt dir die App?".

The lowercase "sie" meaning "it" or "they" is fine.
