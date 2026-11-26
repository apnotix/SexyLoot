# Changelog

## 0.1.29

- Loot window: new option "Fast loot". With auto loot active, everything is picked up at once and the window stays closed. If something does not fit (full bags), the window shows the rest.
- Button labels use a font object, so they no longer stay invisible after a fresh login.
- Bag clean-up: quest-class items that have a vendor price (like the Shredder Operating Manual pages, which keep dropping after the quest) are listed now. Real quest items cannot be sold and stay out.

## 0.1.25

- Loot window: the footer (with "Take all") is brown like the other windows, and there is some space between the title band, the list and the footer.
- Roll buttons: the rim matches the other windows and the icons sit exactly in the middle; the preview in the settings window looks the same.
- "Announce winner": the button shows the channel only when it is not set to automatic.

- Buttons (Take all, Announce winner, disenchant and clean-up buttons) look like those in the SexyEditMode settings window: title band color, gold text, rounded gold border. "Announce winner" no longer shows "(Automatic)" when the channel is automatic.

- Recently looted, loot popup and winner display: the anchor (the rectangle you place and dock to) is now as big as what is shown instead of the largest possible size, so there is no gap when you dock another window to it. The window grows with its content; growing down keeps the top edge in place, growing up keeps the bottom edge (the saved position follows the height).

- Disenchant window "Next up": a cast bar shows the cast time of Disenchant (name and seconds left); idle it is an empty dark bar. The window is a bit taller for it.

- Loot popup: the rows no longer re-sort. New items attach at the bottom (oldest on top), a repeated item keeps its place and only its count grows; if more items arrive than rows fit, the oldest ones at the top drop out first.

- Loot popup: looted gold is its own area at the very top (one line, three with "Show money separately"), above the items, with a small gap in between; new items no longer push it down. The preview shows it the same way.

- Disenchant window "Next up": when nothing is left to disenchant the window closes by itself (skipped items still count as left, then the window stays).

- Disenchant window: the hotkey disenchants right away, also while the list is open (before, the first press only opened the window "Next up"). The window then opens.

- Disenchant window "Next up": hovering the icon, name or labels of the next item shows the item tooltip.

- Disenchant window: the list is grouped by quality (a row with a label per quality and the sum of its value). "Disenchant all" now opens the window "Next up": the next item big with its value, a button that disenchants it (every click one spell, the hotkey does the same), "Skip" (the item stays in the bag and is not offered again in this round; when only skipped items are left, the same button offers them again), a progress bar, the remaining value and "Back to list".

- Settings window: the other windows have their own preview windows with their own logic (free rolls, loot window, group feed, my loot, loot popup, winner display, money, bags hint, disenchant button; new file SamplesMore.lua, Live.lua is gone: needs a full client restart). They are built with the same blocks as the real windows, follow the settings, and every part is clickable. The first settings group ("Look") holds only what changes the preview; behavior, tests and actions sit in a second group ("Behavior").
- New look settings: window opacity, background color and border color for the roll window, winner display, free rolls, loot window, group feed, my loot, money, bags hint and disenchant button (the cards of the loot window follow the opacity). Winner display: glow around the card, labels. Free rolls: rank label, time bar, announce button. Loot window: labels, "Take all" button. Group feed: line spacing. My loot: row height, icons. Loot popup: width, row height, quality stripe. Money: sell value, width, font size, labels. Disenchant button: size. Many more: winner display (icon size, item and name font size, width, gap between the cards, width of the slim cards), free rolls (width, line spacing, check, alternate shading), loot window (width, name size, row spacing, "Take all" button), group feed (outlined text, timestamp color), my loot (width, font size, count), loot popup (icon size, name size, row spacing, count), bags hint (width, icon size, icon, clean-up button). In the roll window "Grow new windows upward" and the maximum list height now sit in the behavior group. The clickable parts of the previews are measured at the real parts (icon, name, labels, buttons, gaps) instead of estimated. Each setting has its own spot in the preview.
- Roll window: many more look settings (card opacity, item name size, armor label, "Binds when picked up", time bar, time left, button labels, check on the best roll, alternate shading, line spacing); the preview follows and each part is clickable.
- Roll window settings: the "Start test roll" button is gone (`/sexyloot test` still works). Turning on "Animations" plays a roll in the preview: the card flies in, the players pick one after another (icon fades in, rolls count up) and the winner lights up (no yellow light streak any more, also not in the real roll window; the rolls count up in the real window as well).
- Settings window: the roll window page shows a live sample in a panel on the right side of the window (window, header, item, time bar, buttons, player list, spacing). Hover a part to outline it, click it to jump to its settings; the sample follows every change. New file Samples.lua: needs a full client restart.
- New checkbox "Hide header" for the roll window, free rolls, loot window, group feed and my loot: the title band disappears and the content moves up.
- Roll window: picks, rolls and the winner now also come from the loot history of the client (like DaylightUI), faster and more reliable than the chat lines. Your own pick shows as soon as the game closes its roll window. The buttons stay clickable while the client has not yet told what you may roll (before, a roll could sometimes not be rolled), and the permissions are read again after 0.4 s and 1.5 s. "All rolls cancelled" closes the open rows.
- Roll buttons: a nicer hover (the surface lightens slightly, thin gold border, brighter text) instead of the square glow.
- Bars (roll timer, free-roll timer) have a glassy gloss like the XP bar, the roll timer has rounded ends (needs the SexyEditMode addon).
- Roll window: the players' picks show as an icon (die, coin, pass) in front of the name instead of a text badge. The expand/collapse icon is gone: a click on the header of an item expands or collapses its list.
- SexyEditMode is now a required dependency (CurseForge installs it automatically).
- Docking: new selection "Alignment" next to the side. Windows docked below or above can line up with the left edge, the center or the right edge of the target; windows docked left or right with the top edge, the center or the bottom edge.
- Loot toast: animations (switched with "Animations" in the roll window settings): new items fly in from the right with a light streak in the quality color, epic and quest items pulse once, repeated items count up, money counts up, rows slide into their new place and glide out to the right when they expire.
- Roll window: animations (can be turned off with "Animations" in the roll window settings): cards slide and fade in and out, grow and shrink smoothly, shift to their new place, player rows glide when the order changes, new picks fade in, rolls count up, the winner gets a light streak (twice if it is you), and the timer bar pulses when time is running out.
- Roll window: the roll buttons always look normal (no dimming); the one you clicked gets a gold border.
- Roll window: the armor class (Cloth, Leather, Mail, Plate) is shown as a badge below the item name; "Binds when picked up" sits next to it.
- Roll window: the Need / Greed / Pass buttons now sit side by side below the progress bar (icon and text) instead of at the top right; the item name uses the full width.
- The disenchant options (rows, quality, protect sets, key for "Disenchant all", reset hidden items) moved from the bag hint to the "Disenchant button" window, where they belong.
- Disenchant: "Disenchant all" has a key, default CTRL + D (change or remove it in the settings window, Disenchant section). While the window is open, every press disenchants the next item of the list (WoW allows one spell per press, an automatic repeat is not possible). The key is shown on the button.
- Minimap button, right click: Edit Mode only for the windows of SexyLoot (the others stay as they are). Needs the SexyEditMode addon.
- Edit Mode: Windows that belong together have tabs at the top of their dialog (rolls: roll window, winner, free rolls, group feed; loot: loot window, my loot, loot toast, money; tools: bag hint, disenchant button). Needs the SexyEditMode addon.
- Edit Mode: The dialogs of the windows now look like the settings window and show only visual options (look, size, position, docking, visibility). Behavior (display times, automatic looting, hotkey, prices, sounds, announce channel, clean-up and disenchant options) is in the settings window (/sem). Without SexyEditMode everything stays in the dialogs.
- Minimap button: left click opens the settings window (SexyEditMode) at the first area of SexyLoot, right click toggles Edit Mode.
- Winner: a sound can be played when you are the winner yourself ("Sound when I win"): game sounds plus the sounds of LibSharedMedia (now embedded). Picking a sound or channel plays it. The volume follows the chosen sound channel, WoW cannot set the volume of a single sound.
- "Gruppenloot-Markierung ab Qualität" ist jetzt eine Auswahl (Grün, Blau, Episch) statt eines Reglers mit Zahlen.
- Ansage-Kanal (Freie Würfe) ist jetzt ein Auswahlfeld mit Beschriftung statt eines Wechsel-Knopfs mit Chatmeldung.
- Hotkey für „Alles nehmen“: Beschriftung und ein Knopf, der die gewählte Taste zeigt (Klick startet die Abfrage, „Taste drücken …“ während des Wartens), daneben ein X zum Entfernen.
- Andocken: Statt zweier Wechsel-Knöpfe mit Chatmeldung gibt es jetzt zwei Auswahlfelder mit Beschriftung: "Andocken an" (Fenster oder "Nicht angedockt") und "Seite" (unten, oben, links, rechts).
- Meldet sich beim neuen Addon SexyEditMode an: Ist es installiert, erscheinen die Fenster von SexyLoot im gemeinsamen Einstellungsfenster (/sem). Ohne das Addon ändert sich nichts.

## 0.1.23

- Blizzards "GroupLootContainer" wird jetzt ebenfalls dauerhaft ausgeblendet; er blockierte nach einem Gruppenloot in der Bildschirmmitte die Maus.
- Neuer Minimap-Knopf: Linksklick öffnet bzw. schließt den Edit Mode. Ausblenden mit `/sl minimap`.
- Gruppenwurf: Die Spalte mit dem Würfelergebnis war zu schmal, eine 100 wurde abgeschnitten. Sie ist jetzt breiter.
- Neue Preisquelle Mastercraft: Auktionspreise aus den gespeicherten Scans von Mastercraft (nach Auctionator, vor TSM). Prüfen mit `/sl price [Item]`.

## 0.1.21

- Loot-Einblendung: Der Geldbetrag steht immer an derselben Stelle (rechts in der Wertspalte wie bei Items); links steht "Geld".
- Beutefenster: Es baut sich von oben nach unten auf. Die Oberkante bleibt an der im Edit Mode gewählten Stelle stehen, statt dass das Fenster mit jeder Zeile nach oben wuchs.
- Positionen: Beim Umstieg auf den neuen Edit-Mode-Dialog wurden die alten Positionen mancher Spieler nicht übernommen und die Fenster standen wieder an der Startposition. Die Übernahme prüft jetzt später erneut und bleibt robust, wenn der Name des Layouts beim Laden noch unbekannt ist; die alten Daten werden nicht mehr gelöscht. Bereits zurückgesetzte Fenster müssen einmal neu platziert werden
- Klicks auf Gegner und Leichen unter SexyLoot-Fenstern: Ein mit "Ausblenden" oder "Im Kampf ausblenden" versteckter Container ist jetzt ganz weg (vorher nur durchsichtig und weiter klickbar), und eine ausblendende Zeile der Loot-Einblendung fängt keine Klicks mehr ab.

## 0.1.20

- Loot-Einblendung, Entzauber-Fenster und Aufräum-Dialog zeigen bei einem Auktionspreis darunter klein auch den normalen Händlerpreis.
- Neu: Entzauber-Fenster (/sl de oder Knopf im Edit Mode). Es listet entzauberbare Waffen und Rüstung in den Taschen (Qualität einstellbar, Ausrüstungssets geschützt); ein Klick auf "Entzaubern" wirkt den Zauber direkt auf das Item. Jede Zeile zeigt den Wert (Auktionspreis eines Preis-Addons in Blau, sonst Händlerpreis). Nur außerhalb des Kampfes bedienbar. Der Knopf "Alle entzaubern" unten zielt immer auf das nächste Item der Liste: Du klickst wiederholt auf dieselbe Stelle, jeder Klick entzaubert ein Item (Blizzard erlaubt nur einen Zauber je Klick). Das Fenster hat eine feste Höhe (Zeilenzahl einstellbar) und wird bei wenigen Items nicht kleiner. Dazu ein Knopf, den du im Edit Mode platzierst und skalierst (Symbol des Zaubers, Anzahl entzauberbarer Items, optional nur sichtbar wenn welche da sind) und der das Fenster öffnet. Selbst hergestellte Items (Berufe) erscheinen jetzt ebenfalls in Loot-Einblendung und "Meine Beute". Items, die sich nicht entzaubern lassen (z. B. die Zauberstäbe des Verzauberers), kannst du per Rechtsklick auf die Zeile dauerhaft ausblenden; im Edit Mode lassen sie sich zurücksetzen. Der Knopf lässt sich ausblenden (Option im Edit Mode). Den Knopf gibt es nur, wenn du Entzaubern kennst (Verzauberkunst). Neuer Befehl /sl price [Item] zeigt, was jedes Preis-Addon für ein Item liefert; Ausrüstung fällt auf den Preis der Basis-ID zurück.
- Neu: Taschen aufräumen. Bei fast vollem Inventar erscheint ein Hinweis; "Aufräumen" oder /sl bags öffnet einen Dialog mit den günstigsten Items (Auktions- oder Händlerpreis), die sich mit Bestätigung wegwerfen lassen. Die Liste scrollt mit dem Mausrad; neue Optionen "Nur Junk anzeigen" und "Berufs-Items ignorieren". Meldet das Spiel beim Looten "Inventar ist voll", öffnet sich der Dialog direkt neben dem Beutefenster (abschaltbar).
- Gewinner-Anzeige: Gewinnt jemand anderes, erscheint statt der großen Karte ein schmaler Toast (Symbol, Gegenstand, Gewinner mit Etiketten, Rahmen in Qualitätsfarbe). Bei deinem eigenen Gewinn bleibt die große Karte mit Schein.

## 0.1.19

- Edit Mode: Oben im Dialog verweisen Knöpfe auf zusammengehörige Fenster (Rollfenster, Gewinner-Anzeige, Freie Würfe, Gruppen-Feed; Beutefenster, Loot-Einblendung, Meine Beute, Geld); ein Klick zeigt deren Einstellungen.
- Neue Option "Preisquelle" (Loot-Einblendung, Zuletzt gelootet, Geld): Verkaufswerte zeigen jetzt den Auktionspreis, wenn Auctionator, TSM, Oribos Exchange oder Auctioneer installiert ist, sonst den Händlerpreis. Umschaltbar auf nur Händlerpreis.
- Loot-Einblendung zeigt jetzt auch gelootetes Geld (Münzsymbol und Betrag; mehrere Beträge innerhalb der Anzeigedauer werden addiert, mit der Option "Geld einzeln anzeigen" bekommt jeder Betrag eine eigene Zeile).
- Neuer Edit-Mode-Dialog im Look der Sexy-Addons mit einklappbaren Abschnitten (Darstellung, Andocken, Position und Größe, Sichtbarkeit) aus der eigenen Bibliothek SexyEditMode; EditModeExpanded entfällt. Einstellungen gelten jetzt für alle Edit-Mode-Layouts gemeinsam. Position und Optionen (Schalter, Regler) aus der alten Bibliothek werden einmalig übernommen; nur die Skalierung beginnt wieder bei 100 %.
- Hintergrund- und Randfarbe lassen sich nicht mehr einstellen: Die Buttons "Hintergrundfarbe wählen", "Randfarbe wählen" und "Farben zurücksetzen" entfallen, gespeicherte Farbwahlen werden nicht mehr benutzt.
- Würfelfenster: Nach dem Wurf zeigt das Item wieder seinen Tooltip (vorher blieb er leer, weil die Roll-ID dann ungültig ist; jetzt gilt der Item-Link)
- Die Fenster haben jetzt denselben Rahmen wie SexyQuestHelper (Tooltip-Rand mit abgerundeten Ecken, gold gefärbt) statt der flachen 2-px-Linie. Hintergrund- und Randfarbe bleiben im Edit Mode einstellbar.

## 0.1.16

- Neuer Look im Stil von SexyQuestHelper für Gewinner-Anzeige, Freie Würfe, Gruppenbeute (Feed), "Zuletzt gelootet", Geld-Rahmen und Loot-Einblendung: dunkelbraune Fläche, 2-px-Goldrand und Titelband mit Badge, farbige Etiketten und ein grüner Aktionsknopf. Auch Rollfenster und Beutefenster haben den neuen Look.
- Rollfenster: ein Fenster "Gruppenwurf" mit Band und Anzahl der Gegenstände, darin je Gegenstand eine Karte. Die Wahl der Spieler steht als Etikett (Bedarf grün, Gier bernstein, Passen grau, "wartet" grau) vor dem Wurf; die Würfelknöpfe haben eine dunkle Fläche. Hintergrund- und Randfarbe gelten jetzt für das ganze Fenster.
- Beutefenster: Band mit Zielname und Anzahl, Zeilen als Karten mit Etikett "Gruppenloot" (blau) oder "Freie Beute" (grau), Fußleiste mit grünem "Alles nehmen"-Knopf.
- Gewinner-Anzeige: eckige Karte mit Band "Gewinner", Symbolrahmen und Schein in Qualitätsfarbe, Wurfart und Ergebnis als Etiketten. Mehrere Karten zeigen ihre Stapelposition im Badge.
- Freie Würfe: Platz als Etikett (Sieger bernsteinfarben), Zeitleiste unter dem Band, grüner Ansage-Knopf.
- "Zuletzt gelootet": Sitzungsdauer als Badge im Band, Gesamtwert in einer Fußleiste.
- Loot-Einblendung: Questitems tragen zusätzlich ein Etikett "Quest".
- Neue Schriften: Marcellus für Titel und Gewinnername, Inter für den übrigen Text (mitgeliefert, SIL Open Font License, Lizenzen in media/fonts). Clients in Russisch, Koreanisch und Chinesisch behalten die Spielschrift.
- Neue Standardfarben (Fläche und Randfarbe) für diese Fenster. Selbst gewählte Farben bleiben erhalten, "Farben zurücksetzen" setzt auf den neuen Standard.

## 0.1.15

- Release-Workflow repariert: Der Packager brach bei jedem Lauf mit "Found future tag" ab, darum wurde nichts gepackt oder hochgeladen. Der Push-Lauf startet den Paketbau jetzt per workflow_dispatch auf dem Tag.

## 0.1.14

- Behoben: Seit dem flachen Look fehlte die Edit-Mode-Vorschau in den meisten Fenstern, und Rollfenster und Freie Würfe lösten Lua-Fehler aus (das Feld "bar" des Panels kollidierte mit der Zeitleiste). Der Balken links heißt jetzt "accent". Ein Fehler in einer Vorschau blockiert die anderen nicht mehr.
- "Zuletzt gelootet": Tooltip über dem Gesamtwert mit Dauer, Anzahl und Wert der gelooteten Items der Sitzung, das teuerste Item sowie Wert und Items pro Stunde (Hochrechnung ab 30 Sekunden). Die Zahlen gelten für die ganze Sitzung, auch für Einträge, die nicht mehr in der Liste stehen.
- "Zuletzt gelootet": Links neben dem Gesamtwert steht die Dauer der Sitzung (seit Login oder dem letzten Leeren der Liste), abschaltbar mit "Sitzungsdauer ausblenden".
- Loot-Einblendung und "Zuletzt gelootet": Questitems tragen ein gelbes Ausrufezeichen am Symbol.
- Neu: Fenster lassen sich aneinander andocken. Im Edit Mode gibt es pro Fenster "Andocken: Ziel wechseln" (schaltet durch Aus und die anderen Fenster) und "Andocken: Seite wechseln" (unten, oben, links, rechts). Das angedockte Fenster wandert mit; wer es im Edit Mode selbst zieht, löst es ab.
- Neuer Look für alle Fenster im Stil der Loot-Einblendung: flache, dunkle, leicht durchsichtige Fläche mit schmalem Balken links (Randfarbe) statt des eckigen Tooltip-Rahmens. Eigene Farben bleiben erhalten, "Farben zurücksetzen" setzt auf den neuen Standard.
- Rollfenster und Beutefenster blenden weich ein.
- Geld-Rahmen: Tooltip mit dem Geld aller Charaktere deines Accounts (nach Geld sortiert, mit Gesamtsumme). Ein Charakter erscheint, sobald du ihn einmal gespielt hast. Neuer Button "Gespeicherte Charaktere zurücksetzen".
- Loot-Einblendung: Mit der Maus über einer Zeile bleibt sie eingeblendet und zeigt den Item-Tooltip (Shift-Klick verlinkt das Item im Chat).
- Neu: Loot-Einblendung (Symbol, Name, Anzahl, Verkaufswert) für gerade gelootete Items. Zeilen blenden nach einstellbarer Zeit aus, gleiche Items werden zusammengezählt (`/sexyloot toast` zum Testen).
- "Zuletzt gelootet": Button "Wachstumsrichtung wechseln (oben/unten)" (Standard: nach oben). Die Einstellung gilt für alle Edit-Mode-Layouts.
- Neu: Kleiner Rahmen "Geld" mit aktuellem Geld und Verkaufswert aller Items in den Taschen (Position und Farben im Edit Mode).

## 0.1.9

- Beutefenster: Geld (und Währung) wird automatisch eingesammelt, abschaltbar mit "Geld nicht automatisch einsammeln". Erkannt über GetLootSlotType, denn LootSlotHasItem meldet auch bei Geld "ja".
- Beutefenster-Hotkey: Das Loslassen anderer Tasten wird nach einem Hotkey-Druck nicht mehr verschluckt (der Charakter lief sonst weiter).
- Gewinner-Anzeige: Abgerundete Karte mit rundem, weichem Schein, abgerundetem Symbol mit Qualitätsring (eigene Texturen in media/, erzeugt mit tools/make_textures.py).
- Gewinner-Anzeige: Pulsierender Schein in Qualitätsfarbe, glühendes Symbol mit Stern, Zierlinie, Ein- und Ausblend-Animation.
- Gewinner-Anzeige: Gewinnen mehrere kurz hintereinander, stehen die Karten untereinander (neueste oben), jede mit eigenem Timer. Neuer Regler "Gleichzeitig angezeigte Gewinner" (1 bis 5, Standard 3).
- Freie Würfe: Schaltfläche "Gewinner ansagen" schreibt den Gewinner in einen einstellbaren Kanal (Automatisch, Sagen, Gruppe, Schlachtzug, Instanz, Gilde, Schreien, Chatkanal-Nummer).
- Neu: Fenster "Freie Würfe" für manuelle /roll-Würfe (z. B. bei Kisten). Ab zwei Würflern erscheint die Liste, der höchste Wurf steht oben. Nach einer einstellbaren Zeit ohne neuen Wurf wird sie geleert und ausgeblendet (`/sexyloot freeroll` zum Testen).
- Rollfenster: Nach dem Wurf zeigt die Leiste einen Countdown bis zum Verschwinden, dazu steht "Schließt in Ns" im Kopf.

## 0.1.8

- Behoben: Bedarf/Gier/Passen reagierten bei echten Würfen nicht, wenn die Zeile vorher als Edit-Mode-Vorschau gedient hatte (altes preview-Flag blieb im Pool stehen). Danach funktionierte auch die Gewinner-Anzeige für diese Zeile nicht.
- Rollfenster: Jede Zeile lässt sich per Klick auf den Kopf ein- und ausklappen (Plus/Minus-Symbol).
- Rollfenster: Bei vielen Items gleichzeitig klappen ältere Zeilen ein, sobald die einstellbare Maximalhöhe überschritten wird (Kurzzeile mit Tooltip). Die Liste ragt nicht mehr aus dem Bildschirm.
- Rollfenster: Neue Darstellung der einzelnen Würfe als Tabelle (Symbol, Name, Wurf rechts, Gewinner golden mit Haken, gedimmtes Passen; ein Ergebnisstreifen erscheint nur, wenn alle gepasst haben).
- Behoben: Das Rollfenster verschwand manchmal, obwohl andere noch würfelten (Cancel-Ereignis nach der eigenen Wahl). Es bleibt jetzt, solange der Wurf läuft.
- Rollfenster: Transmog-Würfe werden unterstützt (der Gier-Button würfelt dann auf Transmog). Gesperrte Buttons zeigen jetzt ihren Tooltip mit dem Grund.
- Behoben: Nach einem Reload fehlten die schon gefallenen Wahlen und Würfe eines laufenden Wurfs. Sie werden jetzt aus der Loot-Historie des Clients geladen, auch die eigene Wahl.
- Beutefenster: Für "Alles nehmen" lässt sich im Edit Mode ein Hotkey festlegen (und wieder entfernen). Er gilt, solange das Beutefenster offen ist. Der Hotkey läuft über einen eigenen Tastatur-Frame, der nur die Hotkey-Taste abfängt und alle anderen Tasten weiterreicht (wie bei Dialogue UI), auch im Kampf (dort geht die Taste zusätzlich ans Spiel, weil sich die Weitergabe im Kampf nicht ändern lässt). Auch Leertaste ist möglich.

## 0.1.7

- Meine Beute: Statt der Zeit steht jetzt der Verkaufswert pro Eintrag da, bei Stapeln für den ganzen Stapel. Die Option "Zeitangabe ausblenden" heißt jetzt "Wert pro Eintrag ausblenden", der Gesamtwert "Gesamtwert ausblenden".
- Behoben: Mitspieler standen beim Würfeln doppelt in der Liste (mit und ohne Realm-Namen, kurzer und langer Name wie "Arak" und "Arak Ragerunner").
- Übersetzung: Deutsch und Englisch. Nicht-deutsche Clients zeigen Englisch, Bedarf/Gier/Passen kommen aus dem Spiel.

## 0.1.5

- Neu: Gewinner-Anzeige mitten auf dem Bildschirm (Größe und Dauer im Edit Mode einstellbar, `/sexyloot winner` zum Testen).
- Rollfenster: Würfe stehen untereinander, sortiert, mit einstellbarer Schriftgröße.
- Rollfenster bleibt nach dem Wurf einstellbar lange stehen (Standard 12 Sekunden).
- Ein laufender Wurf wird nach einem Reload wiederhergestellt.
- Jedes Fenster: Hintergrund- und Randfarbe (mit Deckkraft) per Farbwähler im Edit Mode wählbar, dazu "Farben zurücksetzen".
- Gruppen-Feed: Nachrichten blenden nach einstellbarer Zeit aus (Standard 20 Sekunden, abschaltbar). Scrollen blendet sie wieder ein.
- Gruppen-Feed: Tooltip und Klick gelten nur noch über dem Item-Link, nicht mehr über der ganzen Zeile.
- Gruppen-Feed: Breite und Höhe sind einstellbar (ersetzt den Regler "Sichtbare Zeilen").
- Der Edit-Mode-Rahmen des Rollfensters umfasst jetzt mehrere Zeilen.
- Behoben: Fehler beim Auswerten der Würfe (führender Link `|Hlootroll`).
- Behoben: Eigener Gewinn stand doppelt im Feed ("You" und der eigene Name).

## 0.1.4

- Behoben: Lua-Fehler im Edit Mode und bei `/sexyloot test` auf dem Forever-Client (fehlende Globals `GetItemQualityColor`, `GetItemInfo`, `GetItemInfoInstant`; jetzt Zugriff über `C_Item` mit Fallback).

## 0.1.0

- Erste Version: Rollfenster mit Würfen am Item, Beutefenster, Gruppen-Feed und Liste „Meine Beute“.
- Alle Fenster über den Edit Mode einstellbar (EditModeExpanded-1.0).
