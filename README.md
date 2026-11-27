# Holzwacht

**Sammeln. Ausbauen. Die Nacht überleben.**

Holzwacht ist ein kleines 3D-Survival-Spiel für Android (und PC). Es nimmt genau das
Spielprinzip, das man aus den Handy-Werbungen kennt, und macht daraus ein echtes Spiel:
ohne Werbung, ohne Kaufen, ohne Pay-to-Win.

> Das ist ein **erster spielbarer Prototyp**. Alles ist bewusst aus einfachen Formen
> (Klötze, Kugeln, Zylinder) gebaut. Schöne Grafik, Sound und mehr Inhalte kommen später.

## So wird gespielt

| Phase | Was passiert |
|---|---|
| **Tag** (50 Sekunden) | Lauf zu Bäumen und Felsen. Bleibst du daneben stehen, hackst du automatisch Holz bzw. baust Stein ab. |
| **Ausbauen** | Mit Holz und Stein kaufst du rechts: Arbeiter, bessere Axt, bessere Waffe, stärkere Mauer, Türme. |
| **Nacht** | Monster kommen von allen Seiten zu deiner Basis. Du und deine Türme kämpfen automatisch. |
| **Nächster Tag** | Sind alle Monster besiegt, gibt es eine Belohnung und der nächste Tag beginnt. Jede Nacht wird schwerer. |

**Die Upgrades:**

- **Arbeiter anheuern**: läuft selbst zu Bäumen/Felsen und bringt Rohstoffe zur Basis (bis zu 6).
- **Axt verbessern**: du sammelst schneller und ab Stufe 4 mehr pro Schlag.
- **Waffe verbessern**: mehr Schaden und Reichweite für dich *und* deine Türme.
- **Mauer verstärken**: mehr Leben für die Basis, und sie wird dabei komplett repariert.
- **Turm bauen**: schießt nachts automatisch auf Monster (bis zu 6).
- **Nacht jetzt starten**: wenn du bereit bist, musst du nicht warten.

Wird die Basis zerstört, ist das Spiel vorbei. Du selbst wirst nach 5 Sekunden wiederbelebt.
In der Basis heilst du dich langsam.

**Steuerung:**

- Handy: Finger irgendwo auf die **linke Bildschirmhälfte** legen und ziehen (virtueller Joystick).
- PC: **W A S D** oder **Pfeiltasten**. Mit der Maus kannst du in der linken Hälfte auch ziehen wie am Handy.
- Upgrades: Knöpfe rechts antippen bzw. anklicken.

---

## Weg 1: Spiel aufs Handy holen (am einfachsten, nichts installieren)

Bei jedem Hochladen auf GitHub baut GitHub das Spiel automatisch.

1. Öffne das Repository auf GitHub und klicke oben auf **Actions**.
2. Klicke auf den obersten Lauf mit grünem Haken ✅ („Spiel testen und bauen“).
3. Scrolle ganz nach unten zu **Artifacts** und lade **Holzwacht-Android** herunter.
   (Am besten direkt am Handy im Browser, angemeldet bei GitHub.)
4. Die heruntergeladene Datei ist eine ZIP. Öffne sie, darin liegt `Holzwacht.apk`.
5. Tippe auf die APK. Android fragt, ob du Apps aus „unbekannten Quellen“ erlauben willst:
   das einmal für deinen Browser bzw. Dateimanager erlauben.
6. Installieren, fertig. Das Spiel heißt auf dem Handy **Holzwacht**.

Für den PC gibt es dort genauso **Holzwacht-Windows** (ZIP mit `Holzwacht.exe`, einfach starten).

> Warum „unbekannte Quellen“? Die App kommt nicht aus dem Play Store, sondern direkt von dir.
> Das ist bei selbst gebauten Apps normal.

## Weg 2: Am PC mit Godot öffnen und selbst ändern

Das Spiel ist mit der **Godot Engine** gebaut. Godot ist kostenlos, Open Source, klein und
läuft ohne Installation.

1. Lade **Godot 4.3** (die normale Version, *nicht* „.NET“) herunter:
   https://godotengine.org/download/archive/4.3-stable/
2. Lade dieses Projekt herunter: auf GitHub grüner Knopf **Code → Download ZIP**, und entpacken.
   (Oder mit Git klonen, falls du Git benutzt.)
3. Godot starten → **Importieren** → den entpackten Ordner wählen (die Datei `project.godot`) →
   **Importieren & Bearbeiten**.
4. Oben rechts auf den **Play-Knopf ▶** klicken (oder **F5** drücken). Das Spiel startet.

### Direkt aus Godot aufs Handy (für später, optional)

Das braucht einmalig etwas Einrichtung (Android-SDK und Java). Godot erklärt das hier Schritt für Schritt:
https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_android.html (englisch)

Danach kannst du das Handy per USB anschließen und in Godot oben rechts auf das Android-Symbol
klicken. Bis dahin ist Weg 1 viel bequemer.

---

## Wie das Projekt aufgebaut ist

```
project.godot          Projekteinstellungen (Name, Bildschirm, Android-tauglicher Renderer)
export_presets.cfg     Einstellungen zum Bauen für Android und Windows
scenes/main.tscn       Die Startszene (enthält nur das Hauptskript)
scripts/
  main.gd              Herz des Spiels: Welt, Tag/Nacht, Wellen, Rohstoffe, Upgrades
  player.gd            Spielfigur: laufen, sammeln, kämpfen
  worker.gd            Arbeiter: holt selbstständig Rohstoffe
  enemy.gd             Monster der Nacht
  tower.gd             Verteidigungsturm
  projectile.gd        Geschosse
  resource_node.gd     Bäume und Felsen (wachsen nach)
  hud.gd               Bedienoberfläche (Anzeigen und Knöpfe)
  joystick.gd          Touch-Joystick
  util.gd              Helfer für die einfachen 3D-Formen
.github/workflows/     Automatischer Test und Bau auf GitHub
```

Die ganze Welt wird im Code erzeugt. Zahlen wie Kosten, Schaden oder Tageslänge stehen
gut lesbar oben in `scripts/main.gd` und in den Funktionen `get_cost`, `weapon_damage` usw.
Dort kannst du am einfachsten herumprobieren.

**Selbsttest:** GitHub startet das Spiel bei jedem Hochladen eine Minute lang im Zeitraffer
ohne Bildschirm (Option `--smoke`), kauft alle Upgrades einmal und prüft, dass keine
Fehler auftreten. Schlägt das fehl, ist der Lauf unter **Actions** rot.

## Ideen für die nächsten Schritte

- Echte Low-Poly-Modelle statt Klötzen, Sound und Musik
- Spielstand speichern
- Mehr Gegnertypen (schnelle, große Bosse), mehr Rohstoffe (z. B. Eisen, Gold)
- Bauplätze selbst wählen, Fallen, Heiler-Personal
- Karte, die sich mit der Zeit vergrößert
