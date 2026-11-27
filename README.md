# Hofküche

**Ernten. Backen. Verkaufen. Ausbauen.**

Hofküche ist ein 3D-Aufbauspiel fürs Handy (Hochformat). Es nimmt genau das Spielprinzip aus
den Handy-Werbungen (Feld abernten, Maschinen füttern, Kunden bedienen, Geld auf Bodenfelder
bringen) und macht daraus ein echtes Spiel: ohne Werbung, ohne Kaufen, ohne Pay-to-Win.

> Das ist ein **spielbarer Prototyp**. Ofen, Herd, Theke, Autos und Deko sind fertige
> 3D-Modelle (siehe „Grafik“ unten), Figuren, Feld und Bodenfelder sind im Code gebaut.
> Sound und mehr Inhalte kommen später.

## So wird gespielt

1. **Ernten:** Lauf durchs Weizenfeld. Die Säcke stapeln sich vor dir.
2. **Backen:** Stell dich in den **weißen Rahmen** vor dem Ofen, der Weizen wird abgegeben.
   Die Pizzen laufen übers Band und landen im **grünen Rahmen**: dort abholen.
3. **Verkaufen:** Leg die Pizzen auf die Theke (weißer Rahmen) und stell dich an die **Kasse**.
   Die Autos an der Straße werden bedient und bezahlen.
4. **Geld einsammeln:** Lauf über den Geldstapel.
5. **Ausbauen:** Stell dich auf ein **Bezahlfeld** auf dem Boden. Das Geld fließt hinein,
   und wenn es voll ist, wird das Upgrade gebaut.

Es gibt keine Hilfetexte: das Spiel erklärt sich durch die Rahmen am Boden von selbst.

### Was man freischalten kann

| Bezahlfeld | Wirkung | Stufen |
|---|---|---|
| Größerer Korb | Du trägst mehr (Personal auch etwas mehr) | 10 |
| Feld vergrößern | Mehr Weizenreihen | 3 |
| Erntehelfer | Erntet selbst und füttert die Maschinen | 4 |
| Ofen schneller | Pizzen sind schneller fertig | 10 |
| Kassierer | Bedient die Kunden, du musst nicht mehr an der Kasse stehen | 1 |
| Kellner | Bringt das Essen von den Maschinen zur Theke | 3 |
| Werbeschild | Mehr und größere Bestellungen | 5 |
| **Nudelmaschine** | Neues Produkt: Kunden bestellen jetzt auch Nudeln (teurer) | 1 |
| Nudeln schneller | Nudelmaschine arbeitet schneller | 10 |
| Bessere Zutaten | Alles bringt 25 % mehr Geld pro Stufe | 10 |
| Erntemaschine | Du erntest einen breiteren Streifen | 3 |
| **Neuer Standort** | Neuanfang, aber dauerhaft doppelte Einnahmen | immer wieder |

Neue Bezahlfelder erscheinen erst, wenn die vorherigen gekauft sind. So gibt es immer
ein nächstes Ziel. Der **neue Standort** sorgt dafür, dass man lange spielen kann: Jeder
Umzug verdoppelt deine Einnahmen dauerhaft, und jeder Standort sieht etwas anders aus.

Der Spielstand wird automatisch gespeichert. Unten links gibt es einen **Neustart**-Knopf
(zweimal tippen), der den Spielstand löscht.

**Steuerung:**

- Handy: Finger irgendwo auf den Bildschirm legen und ziehen.
- PC: **W A S D** oder **Pfeiltasten**, oder mit gedrückter Maustaste ziehen.

---

## Weg 1: Spiel aufs Handy holen (am einfachsten, nichts installieren)

Bei jedem Hochladen auf GitHub baut GitHub das Spiel automatisch.

1. Öffne das Repository auf GitHub und klicke oben auf **Actions**.
2. Klicke auf den obersten Lauf mit grünem Haken („Spiel testen und bauen“).
3. Scrolle nach unten zu **Artifacts** und lade **Hofkueche-Android** herunter.
   (Am besten direkt am Handy im Browser, angemeldet bei GitHub.)
4. Die heruntergeladene Datei ist eine ZIP. Öffne sie, darin liegt `Hofkueche.apk`.
5. Tippe auf die APK. Android fragt, ob du Apps aus „unbekannten Quellen“ erlauben willst:
   das einmal für deinen Browser bzw. Dateimanager erlauben.
6. Installieren, fertig.

Für den PC gibt es dort genauso **Hofkueche-Windows** (ZIP mit `Hofkueche.exe`, einfach starten).

> Warum „unbekannte Quellen“? Die App kommt nicht aus dem Play Store, sondern direkt von dir.
> Das ist bei selbst gebauten Apps normal.

## Weg 2: Am PC mit Godot öffnen und selbst ändern

Das Spiel ist mit der **Godot Engine** gebaut. Godot ist kostenlos, Open Source und läuft
ohne Installation.

1. Lade **Godot 4.3** (die normale Version, *nicht* „.NET“) herunter:
   https://godotengine.org/download/archive/4.3-stable/
2. Lade dieses Projekt herunter: auf GitHub grüner Knopf **Code → Download ZIP**, und entpacken.
3. Godot starten → **Importieren** → die Datei `project.godot` im entpackten Ordner wählen →
   **Importieren & Bearbeiten**.
4. Oben rechts auf **▶** klicken (oder **F5**). Das Spiel startet.

Direkt aus Godot aufs Handy spielen geht auch, braucht aber einmalig Android-SDK und Java:
https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_android.html (englisch).
Bis dahin ist Weg 1 viel bequemer.

---

## Wie das Projekt aufgebaut ist

```
project.godot          Projekteinstellungen (Name, Hochformat, Android-tauglicher Renderer)
export_presets.cfg     Einstellungen zum Bauen für Android und Windows
scenes/main.tscn       Die Startszene (enthält nur das Hauptskript)
scripts/
  main.gd              Herz des Spiels: Welt, Upgrades, Kunden, Anleitung, Speichern
  carrier.gd           Grundlage für alle Figuren, die Dinge tragen
  player.gd            Deine Spielfigur
  helper.gd            Personal: Erntehelfer, Kellner, Kassierer
  field.gd             Weizenfeld (wächst nach)
  station.gd           Maschinen: Pizzaofen, Nudelmaschine
  counter.gd           Theke und Kasse
  customer.gd          Kunden im Auto
  money_pile.gd        Geldstapel
  pay_tile.gd          Bezahlfelder auf dem Boden
  pile.gd              Sichtbare Stapel (Pizzen, Geld, Säcke)
  hud.gd, joystick.gd  Anzeige und Touch-Steuerung
  util.gd              Helfer für die einfachen 3D-Formen
.github/workflows/     Automatischer Test und Bau auf GitHub
```

Alle Preise, Kosten und Stufen stehen gut lesbar oben in `scripts/main.gd` in der Tabelle
`UPGRADES` und bei `BASE_PRICE`. Dort kann man am einfachsten am Spielgefühl drehen.

**Selbsttest:** GitHub startet das Spiel bei jedem Hochladen im Zeitraffer ohne Bildschirm
(Option `--smoke`). Die Figur erntet, alle Upgrades werden gekauft, und das Personal muss
selbstständig Essen verkaufen. Klappt das nicht, ist der Lauf unter **Actions** rot.

## Grafik

Die fertigen 3D-Modelle stammen aus den kostenlosen **KayKit**-Paketen von Kay Lousberg
(Restaurant Bits, City Builder Bits, Furniture Bits), Lizenz **CC0** (frei nutzbar, auch kommerziell).
Sie liegen in `assets/kaykit/`. Der Workflow `.github/workflows/assets.yml` lädt sie bei Bedarf neu.

## Ideen für die nächsten Schritte

- Weitere Produktketten pro Standort: Tomatenfeld → Soße, Kühe → Käse, Getränke …
- Offline-Einnahmen: Personal arbeitet weiter, während das Spiel zu ist
- Aufgaben und Erfolge, Kunden mit Sonderwünschen und Trinkgeld
- Eigene Figuren-Modelle, Sound, Musik
