-- Neuigkeiten für das gemeinsame Fenster (SexyEditMode, /sem news). Neueste Version zuerst.
-- Eintrag: { deutscher Titel, deutscher Text, englischer Titel, englischer Text }
local SEM = LibStub and LibStub("SexyEditMode-1.0", true)
if not (SEM and SEM.RegisterNews) then return end

SEM:RegisterNews("SexyLoot", {
	color = { 0.79, 0.64, 0.35 },
	{ v = "0.1.30",
		{ "Sitzung", "Die Sitzung in „Zuletzt gelootet“ übersteht /reload: Liste, Beute und Dauer bleiben erhalten. Bei einem neuen Login oder Charakterwechsel beginnt eine neue.",
		  "Session", "The session in \"Recently looted\" survives /reload: list, loot and duration stay. A new login or a character switch starts a new one." },
		{ "Geld", "Der Tooltip mit deinen Charakteren am Geld-Rahmen hat eine kleinere Schrift und zeigt den Gewinn heute und gestern für den ganzen Account (grün Plus, rot Minus).",
		  "Money", "The tooltip with your characters at the money frame uses a smaller font and shows the profit today and yesterday for the whole account (green plus, red minus)." },
	},
	{ v = "0.1.29",
		{ "Schnell plündern", "Neue Option im Beutefenster: Bei Auto-Loot wird sofort alles genommen, das Fenster bleibt zu. Passt etwas nicht mehr hinein (volle Taschen), zeigt das Fenster den Rest.",
		  "Fast loot", "New option in the loot window: with auto loot everything is picked up at once and the window stays closed. If something does not fit (full bags), the window shows the rest." },
		{ "Aufräumen", "Questitems mit Händlerpreis (z. B. die Shredder-Anleitungen, die auch nach der Quest weiter droppen) stehen jetzt in der Liste. Echte Questgegenstände ohne Preis bleiben außen vor.",
		  "Clean-up", "Quest-class items with a vendor price (like the Shredder Operating Manual pages that keep dropping after the quest) are listed now. Real quest items without a price stay out." },
		{ "Knöpfe", "Die Beschriftung der Knöpfe bleibt nach einem frischen Login nicht mehr unsichtbar.",
		  "Buttons", "Button labels no longer stay invisible after a fresh login." },
	},
	{ v = "0.1.25",
		{ "Aussehen", "Beute-Fenster mit braunem Fuß und Abstand zwischen Titel, Liste und Fuß. Die Würfel-Knöpfe haben den Rand der anderen Fenster, ihre Symbole sitzen genau in der Mitte. „Gewinner melden“ nennt den Kanal nur, wenn er nicht automatisch ist.",
		  "Look", "The loot window has a brown footer and space between title, list and footer. The roll buttons have the rim of the other windows and their icons sit exactly in the middle. \"Announce winner\" only names the channel when it is not automatic." },
		{ "Entzaubern", "Die Liste ist nach Qualität gruppiert. „Alle entzaubern“ öffnet das Fenster „Als Nächstes“ mit Überspringen, Zauberbalken und Item-Tooltip. Die Taste entzaubert sofort, und das Fenster schließt sich, wenn nichts mehr übrig ist.",
		  "Disenchant", "The list is grouped by quality. \"Disenchant all\" opens the \"Next up\" window with Skip, a cast bar and the item tooltip. The hotkey disenchants right away, and the window closes when nothing is left." },
		{ "Loot-Popup", "Das Gold steht oben als eigener Bereich, neue Items hängen unten an, nichts sortiert sich mehr um.",
		  "Loot popup", "Looted gold is its own area on top, new items attach at the bottom, nothing re-sorts anymore." },
		{ "Fenstergröße", "Zuletzt gelootet, Loot-Popup und Gewinneranzeige wachsen mit ihrem Inhalt. Beim Andocken bleibt keine Lücke mehr.",
		  "Window size", "Recently looted, loot popup and winner display grow with their content. No gap is left when docking." },
		{ "Einstellungen", "Eigene Vorschau je Fenster und viele neue Einstellungen für Aussehen, Deckkraft, Farben und Schriften.",
		  "Settings", "Own preview for every window and many new settings for look, opacity, colors and fonts." },
	},
})
