# RC6.3.1 – Collaboration Architecture

## Betriebsarten

CoachSplit besitzt keinen getrennten lokalen und kollaborativen Datenkern. Der lokale Ablauf ist immer aktiv. Eine CollaborationSession ergänzt optional Registrierung, Zuweisung und Synchronisation.

## Verbindung und Aufgabe

- `ConnectedHelperDevice` bedeutet: Das Gerät gehört zur Session.
- `CheckpointAssignment` wird serverseitig als aktuelle Zuordnung des Geräts geführt.
- Ein gemeinsames Join-Token verbindet Geräte zunächst unzugeordnet.
- Nur der Administrator darf Zuordnungen ändern.
- Der Server validiert bei jedem TimingEvent die aktuelle Zuordnung.

## Offline-Verhalten

Eine bestätigte Zuweisung wird als lokaler Snapshot in `MultiuserConnection` gespeichert. Der Helfer kann damit bei Netzausfall weiter erfassen. Die endgültige Annahme erfolgt erst bei der serverseitigen Synchronisation.

## Backend-Austauschbarkeit

Flutter kommuniziert ausschließlich über `MultiuserApiClient`, `SyncTransport` und `SyncEngine`. Der derzeitige Node-Speicher ist ein Feldtest-Adapter. Eine spätere Firebase-Implementierung ersetzt Persistenz und Echtzeittransport hinter diesen Grenzen.
