# RC6 – Weg zum Zwei-Handy-Betrieb

## RC6.1 Repository Consolidation

Produktive Persistenzgrenzen:

- `CompetitionRepository`: Bewerbsstruktur und Archiv-Snapshots
- `TimingEventRepository`: append-only Messereignisse

Sembast ist eine Infrastrukturentscheidung und darf außerhalb der Implementierungen nicht sichtbar werden.

## RC6.2 Offline Sync Foundation

Als nächstes folgen Geräteidentität, Sync-Zustände, ausgehende Warteschlange und idempotenter Import. Der Vertrag bleibt transportneutral.

## RC6.3 Two-Phone Vertical Slice

Zwei Geräte arbeiten an derselben Session: ein Gerät am Start, ein Gerät am Ziel. Lokales Speichern bleibt immer der erste Schritt.
