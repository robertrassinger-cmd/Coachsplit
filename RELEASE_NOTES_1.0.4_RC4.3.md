# CoachSplit 1.0.4 RC4.3

## AutoStart-Zeitbasis

Die sichtbare AutoStart-Countdownanzeige verwendet nun dieselbe zentrale
`CompetitionClock` wie die eigentliche AutoStart-Auslösung.

Vorher:
- AutoStart-Auslösung: kalibrierte Wettkampfzeit
- sichtbarer Countdown: lokale Systemzeit

Dadurch konnte der Countdown um genau den Kalibrierungs-Offset abweichen.

Jetzt:
- Countdown
- AutoStart-Auslösung
- manueller Start
- Messwerterfassung

verwenden dieselbe fachliche Zeitquelle.

Ohne Kalibrierung liefert `CompetitionClock` weiterhin die lokale Systemzeit als
Fallback.
