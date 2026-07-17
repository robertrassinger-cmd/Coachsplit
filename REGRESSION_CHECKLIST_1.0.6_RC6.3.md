# Regression und Zwei-Handy-Test RC6.3

1. Node-Sync-Server auf einem Rechner im selben WLAN starten.
2. Auf Handy A den bestehenden Bewerb öffnen und „Diesen Bewerb freigeben“ wählen.
3. Ziel-Code notieren.
4. Auf Handy B Serveradresse und Ziel-Code eingeben und beitreten.
5. Prüfen, dass Handy B nur den Zielmesspunkt erfassen kann.
6. Auf Handy A an einem anderen Messpunkt erfassen; innerhalb weniger Sekunden muss die Messung auf B erscheinen.
7. WLAN auf B ausschalten, mehrere Zielmessungen erfassen und Browser neu öffnen.
8. WLAN einschalten; offene Messungen müssen übertragen werden.
9. Dieselbe Event-ID erneut übertragen; es darf kein Duplikat entstehen.
10. Einen Start-Event mit Zieltoken senden; der Server muss ihn ablehnen.
11. Einzelgeräteablauf vollständig prüfen: Setup, Start, Erfassen, Ergebnis, Export, Archiv, Neustart.
