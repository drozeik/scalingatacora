# Bewertungsfunktionen für decisionSupport

English version: [FUNCTIONS.md](FUNCTIONS.md)

Diese 16 Funktionen zeigen, wie das Ergebnis einer Entscheidungsanalyse von Wahlen abhängt, die Daten nicht entscheiden: welche Wirkungen zählen, womit verglichen wird, für wen berichtet wird, wie Gruppen gegeneinander gewichtet werden und wessen Entscheidung neue Information dient.
Man braucht nur das Ergebnis einer Monte-Carlo-Simulation, etwa von `decisionSupport::mcSimulation()`, mit einer Ausgabespalte je Gruppe und Option.
Man bekommt kleine Tabellen: welche Option unter der gewählten Bewertung vorn liegt, wer dabei verliert und was zusätzliche Information wert wäre.

<span id="questions"></span>
## Welche Frage beantwortet welche Funktion?

| Frage | Funktion | Was herauskommt |
|---|---|---|
| Wie komme ich von der Simulation zu Gruppen und Optionen? | [`nb_from_mc()`](#ref-nb-from-mc) | je Gruppe eine Tabelle: Ziehungen × Optionen |
| Was bringt jede Option jeder Gruppe, und wie oft verliert eine Gruppe? | [`nb_summary()`](#ref-nb-summary) | Mittel, Gewinn- und Verlustanteil, eigene beste Option |
| Wie berichte ich für einen Haushalt oder für alle Frauen zusammen? | [`reporting_units()`](#ref-reporting-units) | neue Berichtseinheiten aus Gruppen |
| Wie halte ich Geld und Stunden getrennt? | [`nb_array()`](#ref-nb-array) | ein Objekt mit getrennten Ergebnisgrößen |
| Dürfen Gewinne einer Gruppe Verluste einer anderen aufwiegen? | [`w_utilitarian()`](#ref-w-utilitarian) | Regel: gewichtetes Mittel |
| Soll nur die am schlechtesten gestellte Gruppe zählen? | [`w_maximin()`](#ref-w-maximin) | Regel: kleinster Gruppenwert |
| Sollen Verluste stärker zählen als Gewinne? | [`w_prioritarian()`](#ref-w-prioritarian) | Regel mit gewählter Gewichtung der Verluste |
| Wie stark soll Ungleichheit zwischen Gruppen zählen? | [`w_atkinson()`](#ref-w-atkinson) | Regel mit gewählter Ungleichheitsaversion |
| Darf eine Gruppe unter eine Grenze fallen? | [`w_constrained()`](#ref-w-constrained) | Regel, die solche Optionen ausschließt |
| Was ergibt die Regel in jeder einzelnen Ziehung? | [`welfare_draws()`](#ref-welfare-draws) | Regelwerte: Ziehungen × Optionen |
| Welche Option ist im Mittel die beste, und was wäre Information wert? | [`voi_partition()`](#ref-voi-partition) | beste Option, EVPI, Wert getrennter Entscheidungen |
| Bringen getrennte Entscheidungen mehr als Information? | [`voh_index()`](#ref-voh-index) | ein Verhältnis |
| Wer verliert, obwohl das Gesamtergebnis positiv ist? | [`marginalisation_count()`](#ref-marginalisation-count) | Anteil verdeckter Verluste, gesamt und je Gruppe |
| Ändert sich die beste Option, wenn ich anders gewichte? | [`fairness_screen()`](#ref-fairness-screen) | eine Zeile je Regel |
| Ändert sich das Ergebnis, wenn ich mit etwas anderem vergleiche? | [`baseline_pair()`](#ref-baseline-pair) | beide Referenzen nebeneinander |
| Wie viel der Wirkung muss ankommen? | [`fidelity_threshold()`](#ref-fidelity-threshold) | kleinster ausreichender Anteil je Option |

Die Funktionen zeigen, wie ein Ergebnis von einer Wahl abhängt.
Welche Regel richtig ist, sagen sie nicht.

<span id="glossary"></span>
## Wörter, die hier vorkommen

| Wort | Bedeutung |
|---|---|
| Ziehung (draw) | eine mögliche Welt aus der Simulation; im Code eine Zeile. |
| Option (option) | eine der Handlungsmöglichkeiten; im Code eine Spalte. |
| Gruppe (group) | wessen Ergebnis getrennt geführt wird, etwa Frauen oder Haushalte. |
| Nettovorteil (net benefit) | Ergebnis mit der Option minus Ergebnis in der Referenz. |
| Referenz (reference condition) | womit verglichen wird, etwa der heutige Zustand. |
| Systemgrenze (system boundary) | welche Wirkungen und wessen Konten mitzählen. |
| Gruppenanteile (group shares) | wie stark jede Gruppe in ein gemeinsames Urteil eingeht; im Code `p`. |
| Regel (rule, fairness criterion) | wie die Gruppenwerte einer Ziehung zu einer Zahl werden; im Code `W`. |
| Regelwert (rule value) | diese eine Zahl für eine Ziehung und eine Option. |
| Erwartungswert (expected value) | das Mittel über alle Ziehungen. |
| Informationswert, EVPI (value of information) | was es im Mittel brächte, vor der Entscheidung zu wissen, welche Ziehung eintritt. |
| Getrennte Entscheidungen, Profil (differentiated decisions, profile) | jede Gruppe darf eine andere Option bekommen; ein Profil ist eine solche Zuteilung. |
| Akteursdifferenzierter Informationswert (actor-differentiated value of information) | wessen Entscheidung neue Information dient: EVPI je Gruppe oder bei getrennten Entscheidungen. |
| Berichtseinheit (reporting unit) | für wen eine Zahl berichtet wird: eine Person, ein Haushalt, alle Frauen zusammen. |
| Verdeckter Verlust (hidden loss) | die gemeinsame Zahl ist positiv, aber eine Gruppe verliert. |
| Mindestgrenze (floor) | ein Wert, unter den keine Gruppe fallen darf. |
| Umsetzungstreue (fidelity) | welcher Anteil der geplanten Wirkung tatsächlich ankommt. |

<span id="functions"></span>
## Funktionsübersicht

Jeder Eintrag folgt dem Aufbau der Hilfeseiten von decisionSupport: Beschreibung, Aufruf, Argumente, Rückgabe.
Die Funktionen arbeiten nach der Simulation: Sie ordnen und bewerten Nettovorteile, die das Modell schon berechnet hat.
Welche Konten, Einheiten und Referenz gelten, legt deshalb das Modell fest.

<span id="shared-arguments"></span>
### Gemeinsame Argumente

Die Angaben in den Klammern eines Aufrufs heißen in R Argumente.
Vier kehren immer wieder:

| Argument | Was man übergibt | Worauf achten |
|---|---|---|
| `nb_list`, im Beispiel `nb` | eine benannte Liste mit je einer Matrix pro Gruppe: Ziehungen in Zeilen, Optionen in Spalten | Alle Gruppen brauchen dieselben Optionen und dieselben Ziehungen in derselben Reihenfolge. Ein Aufruf bewertet eine Ergebnisgröße. |
| `p` | die Gruppenanteile, möglichst mit Gruppennamen | Die Funktionen ordnen benannte Anteile zu und teilen durch ihre Summe. |
| `W` | eine Regel, etwa `w_utilitarian()` | Die Regel macht aus den Gruppenwerten einer Ziehung eine Zahl. |
| `rules` | eine benannte Liste von Regeln | Jede Regel wird für sich ausgewertet. |

`p`, `W` und `rules` haben keinen Standardwert: Diese Wahl trifft immer, wer die Analyse macht.
Steht im Aufruf `= Wert`, hat ein Argument einen Standardwert und kann wegfallen.
Ein Aufruf wie `w_utilitarian()` erstellt zunächst nur eine Regel; anwenden wird sie erst die Analysefunktion.

<span id="ref-nb-from-mc"></span>
### nb_from_mc(): Simulationsspalten übernehmen

```r
nb_from_mc(mc, pattern, groups, options, attributes = NULL)
```

**Beschreibung.** Ordnet die Ausgabespalten eines `mcSimulation()`-Ergebnisses nach Gruppen und Optionen; bewertet wird hier nichts.
Das ist der Einstieg direkt nach dem Modelllauf.

**Argumente.** `mc`: das Simulationsergebnis mit `$y` oder direkt seine Ausgabetabelle.
`pattern`: das Namensmuster der Spalten, etwa `"NB_{group}_{option}_V1"`.
`groups`, `options`: die Codes der Gruppen und Optionen; tragen sie Namen, werden diese zu Bezeichnungen im Ergebnis.
`attributes`: nur für mehrere Ergebnisgrößen; dann braucht das Muster auch `{attribute}`.

**Rückgabe.** Je Gruppe eine Matrix, mit `attributes` ein Array mit einer dritten Dimension für die Ergebnisgrößen.
Die Reihenfolge in `options` entscheidet bei exaktem Gleichstand.

<span id="ref-nb-summary"></span>
### nb_summary(): Ergebnisse je Gruppe zusammenfassen

```r
nb_summary(nb_list)
```

**Beschreibung.** Zeigt für jede Gruppe, was jede Option im Mittel bringt, wie oft die Gruppe gewinnt oder verliert und welche Option sie selbst wählen würde.
Eine gemeinsame Regel ist nicht beteiligt.

**Argumente.** Nur `nb_list`.

**Rückgabe.** Eine Tabelle mit `unit`, `option`, `mean`, `p_gain`, `p_loss`, `preferred` und `EVPI`.
`preferred` und `EVPI` gehören zur ganzen Entscheidung einer Gruppe und stehen deshalb in jeder ihrer Zeilen; man darf sie nicht über Zeilen addieren.

<span id="ref-reporting-units"></span>
### reporting_units(): eine Berichtseinheit bilden

```r
reporting_units(nb_list, units)
```

**Beschreibung.** Fasst Gruppen zu einer Berichtseinheit zusammen, etwa zu einem Haushalt oder zu allen Frauen.
Die Koeffizienten stehen sichtbar im Aufruf, damit ein Mittel je Person nicht mit einer Summe je Haushalt verwechselt wird.

**Argumente.** `nb_list`: Gruppenmatrizen oder Gruppenarrays.
`units`: eine benannte Liste von Koeffizientenvektoren mit Gruppennamen, etwa `list(total = c(women = 1, men = 1))`; sie werden nicht normiert.

**Rückgabe.** Eine Liste in derselben Form, benannt nach den neuen Einheiten, zum Beispiel für `nb_summary()`.
Verschiedene Ergebnisgrößen bleiben getrennt.

<span id="ref-nb-array"></span>
### nb_array(): Ergebnisgrößen getrennt aufbewahren

```r
nb_array(...)
```

**Beschreibung.** Hält mehrere Ergebnisgrößen einer Gruppe, etwa Geld und Stunden, in einem Objekt auseinander.
Es rechnet nicht zwischen ihnen um und gewichtet nichts.

**Argumente.** Beliebig viele benannte Matrizen mit denselben Ziehungen und Optionen, etwa `nb_array(money = money_matrix, hours = hours_matrix)`, oder eine benannte Liste davon.

**Rückgabe.** Ein Array: Ziehung × Option × Ergebnisgröße, zum Beispiel für `baseline_pair()` und `reporting_units()`.
Zum Bewerten wählt man eine Ergebnisgröße als Matrix aus.

<span id="ref-w-utilitarian"></span>
### w_utilitarian(): Gruppenwerte gewichtet mitteln

```r
w_utilitarian()
```

**Beschreibung.** Die Regel multipliziert jeden Gruppenwert mit dem Gruppenanteil und addiert.
Gewinne einer Gruppe können so Verluste einer anderen aufwiegen; deshalb gehört eine Verlustprüfung wie `marginalisation_count()` dazu.

**Argumente.** Keine; die Gruppenanteile folgen im Analyseaufruf, etwa in `voi_partition(nb, p, W)`.

**Rückgabe.** Eine Regel `W(nb, p)`: eine Funktion, die für eine Ziehung und eine Option eine Zahl liefert.

<span id="ref-w-maximin"></span>
### w_maximin(): auf die am schlechtesten gestellte Gruppe achten

```r
w_maximin()
```

**Beschreibung.** Die Regel nimmt in jeder Ziehung den kleinsten Gruppenwert.
Ob dabei Veränderungen oder erreichte Niveaus verglichen werden, entscheiden die Eingaben.

**Argumente.** Keine; die Regel nimmt `p` entgegen, verwendet es aber nicht.
Auch eine Gruppe mit Anteil null zählt für das Minimum.

**Rückgabe.** Eine Regel; die Analyse mittelt danach die Minima der Ziehungen, nicht umgekehrt.

<span id="ref-w-prioritarian"></span>
### w_prioritarian(): Verluste stärker zählen lassen

```r
w_prioritarian(u)
```

**Beschreibung.** Die Regel verändert zuerst jeden Gruppenwert mit einer gewählten Funktion `u` und bildet dann das gewichtete Mittel.
So lässt sich etwa festlegen, dass Verluste doppelt zählen; welche Gewichtung angemessen ist, entscheidet nicht die Funktion.

**Argumente.** `u`: eine Funktion, die mit dem Gruppenwert steigt, etwa `function(z) ifelse(z < 0, 2 * z, z)`.
Sollen schlechtere Ergebnisse Vorrang haben, ist sie konkav.

**Rückgabe.** Eine Regel mit einer umgerechneten Bewertung; ihre Informationswerte sind deshalb nicht ohne Weiteres als Geldbeträge vergleichbar.

<span id="ref-w-atkinson"></span>
### w_atkinson(): Ungleichheit ausdrücklich gewichten

```r
w_atkinson(eps, offset = 0)
```

**Beschreibung.** Die Regel bildet den gleich verteilten Gegenwert nach Atkinson: den Betrag, der, an alle Gruppen gleich verteilt, ebenso gut bewertet würde.
Mit `eps` wählt man, wie stark Ungleichheit zählt.

**Argumente.** `eps`: die Ungleichheitsaversion, null oder größer; immer angeben.
`offset`: eine Zahl, die vor der Bewertung zu jedem Gruppenwert addiert und danach wieder abgezogen wird; alle Gruppenwerte plus Offset müssen größer als null sein.
Der Offset gehört zur Bewertungswahl; `eps = 1` und `offset = 10` im Beispiel sind keine Vorgabe für andere Modelle.

**Rückgabe.** Eine Regel: bei `eps = 1` mit dem geometrischen Mittel, sonst mit dem Potenzmittel.
Liegt ein verschobener Wert nicht über null, warnt sie und liefert `NA`.

<span id="ref-w-constrained"></span>
### w_constrained(): eine Mindestgrenze für jede Gruppe setzen

```r
w_constrained(min_group_nb = 0)
```

**Beschreibung.** Die Regel prüft vor der utilitaristischen Bewertung, ob jede Gruppe eine Grenze erreicht, etwa „keine Gruppe unter ihrem Status quo“.
Sie schützt Gruppen auch dann, wenn die gemeinsame Zahl positiv wäre.

**Argumente.** `min_group_nb`: die Mindestgrenze für alle Gruppen, Standard 0; auch eine Gruppe mit Anteil null wird geprüft.

**Rückgabe.** Eine Regel: bei eingehaltener Grenze das gewichtete Mittel, sonst `-Inf` als Marke für „ausgeschlossen“.
`-Inf` ist kein Geldbetrag; die Grenze liest man getrennt von monetären Informationswerten.

<span id="ref-welfare-draws"></span>
### welfare_draws(): Regelwerte je Ziehung berechnen

```r
welfare_draws(nb_list, p, W)
```

**Beschreibung.** Wendet eine Regel auf die Gruppenwerte jeder Ziehung und Option an.
Das ist der gemeinsame Rechenkern aller Analysefunktionen.

**Argumente.** Wie unter [Gemeinsame Argumente](#shared-arguments).

**Rückgabe.** Eine Matrix mit Ziehungen in Zeilen und Optionen in Spalten: Die Gruppen sind schon gemeinsam bewertet, über die Ziehungen ist noch nicht gemittelt.

<span id="ref-voi-partition"></span>
### voi_partition(): Entscheidung, Information und getrennte Entscheidungen bewerten

```r
voi_partition(nb_list, p, W, differentiated = FALSE,
              profiles = NULL, max_profiles = 1e5)
```

**Beschreibung.** Bestimmt die Option mit dem höchsten Erwartungswert und den Wert perfekter Information (EVPI).
Mit `differentiated = TRUE` prüft sie zusätzlich, was getrennte Entscheidungen für die Gruppen brächten.

**Argumente.** `differentiated = FALSE`: eine Option für alle Gruppen; `TRUE`: jede Gruppe darf eine eigene Option bekommen.
`profiles`: Sind nur bestimmte Zuteilungen möglich, stehen sie in einer Matrix, eine Zeile je erlaubtem Profil und eine Spalte je Gruppe; `NULL` erlaubt alle.
`max_profiles` begrenzt die Zahl der geprüften Profile und bleibt meist unverändert.

**Rückgabe.** Eine Liste mit der besten gemeinsamen Option `d_star`, den Erwartungswerten `criterion`, dem Anteil gewonnener Ziehungen `p_ahead`, `A`, `C` und `EVPI = C - A`.
Mit `differentiated = TRUE` kommen `B`, `D`, ihre Differenzen und das beste feste Profil `planner_profile` hinzu; „Preferred option“ im Ausdruck bleibt die gemeinsame Option.

<span id="ref-voh-index"></span>
### voh_index(): getrennte Entscheidungen und Information ins Verhältnis setzen

```r
voh_index(x, tol = .Machine$double.eps^0.5)
```

**Beschreibung.** Setzt den Wert getrennter Entscheidungen beim heutigen Wissen ins Verhältnis zum EVPI einer gemeinsamen Entscheidung.
Das ist eine Einordnung nach `voi_partition()`, keine neue Rechnung.

**Argumente.** `x`: das Ergebnis von `voi_partition(..., differentiated = TRUE)`; `tol` ist eine technische Toleranz, die man normalerweise weglässt.

**Rückgabe.** Die Zahl `(B - A) / (C - A)`, ein Verhältnis und keine Wahrscheinlichkeit.
Ist der Nenner null oder nicht endlich, kommt `NA` mit einer Begründung im Attribut `reason`.

<span id="ref-marginalisation-count"></span>
### marginalisation_count(): verdeckte Verluste zählen

```r
marginalisation_count(nb_list, p, W, d_star = NULL)
```

**Beschreibung.** Zählt die Ziehungen, in denen die gemeinsame Zahl positiv ist, aber mindestens eine Gruppe verliert.
Das zeigt, was ein positives Gesamturteil verdeckt.

**Argumente.** `d_star`: die zu prüfende Option als Name oder Spaltennummer; `NULL` prüft die Option, die die Regel bevorzugt.

**Rückgabe.** Eine Liste mit dem Anteil an allen Ziehungen `share`, den Anteilen je Gruppe `by_group` und der geprüften Option `d_star`.
Gezählt wird streng mit `> 0` und `< 0`, ohne Rundungstoleranz.

<span id="ref-fairness-screen"></span>
### fairness_screen(): Regeln nebeneinander vergleichen

```r
fairness_screen(nb_list, p, rules)
```

**Beschreibung.** Wiederholt Entscheidung, Informationswert und Verlustprüfung für jede gewählte Regel.
So wird sichtbar, wie das Ergebnis von der Bewertung abhängt; eine Rangfolge der Regeln bildet die Funktion nicht.

**Argumente.** `rules`: eine benannte Liste der zu vergleichenden Regeln.

**Rückgabe.** Eine Liste mit der Tabelle `table` (eine Zeile je Regel), den Erwartungswerten aller Optionen unter allen Regeln `scores`, den Zwischenergebnissen `partitions` und der kleinsten paarweisen Rangkorrelation nach Spearman `rank_correlation`.
Die Verlustanteile in `table` gelten für die Option, die die jeweilige Regel bevorzugt.

<span id="ref-baseline-pair"></span>
### baseline_pair(): zwei Referenzen vergleichen

```r
baseline_pair(model, references, p, rules, units = NULL)
```

**Beschreibung.** Vergleicht Nettovorteile unter zwei ausdrücklich angegebenen Referenzen, etwa zwei Bewertungen derselben freigewordenen Stunde.
Die Funktion zeigt, ob sich Zahlen oder Empfehlungen ändern; Referenzwerte erfindet sie nicht.

**Argumente.** `model`: eine kleine Funktion, die für eine Referenz die schon gegen sie gerechneten Nettovorteile liefert.
`references`: eine benannte Liste mit genau zwei Referenzangaben.
`units`: optional zusätzliche Berichtseinheiten wie bei `reporting_units()`; bewertet werden weiterhin die Gruppen.

**Rückgabe.** Eine Liste mit `outcomes` (Mittel, Gewinnanteile und Differenzen) und `rules` (Empfehlung, EVPI und Wechsel `flip` je Regel und Referenz).
Die Modellfunktion wird genau zweimal aufgerufen; beide Ergebnisse brauchen dieselben Ziehungen und dieselbe Form.

<span id="ref-fidelity-threshold"></span>
### fidelity_threshold(): den kleinsten ausreichenden Anteil suchen

```r
fidelity_threshold(nb_list, p, W, tol = 1e-9)
```

**Beschreibung.** Sucht, welcher Anteil der Nettowirkung einer Option mindestens ankommen muss, damit sie die beste unveränderte Alternative erreicht.
Skaliert wird die ganze Nettowirkung, nicht ein einzelner Bestandteil einer Maßnahme.

**Argumente.** `tol`: die Genauigkeit des gesuchten Anteils; normalerweise weglassen.
Die Mindestgrenze eignet sich hier nicht; die Voraussetzung der Suche steht in [Schritt 9](#step-9).

**Rückgabe.** Eine Tabelle mit Option, Wert bei voller Wirkung `value`, bestem Alternativwert `best_other`, Kennzeichen `recommended` und Untergrenze `f_star`.
`NA` heißt: Kein Anteil zwischen null und eins reicht.

<span id="printing"></span>
### Ergebnisse ausgeben

Die Ergebnisse von `voi_partition()`, `fairness_screen()`, `baseline_pair()`, `marginalisation_count()` und `fidelity_threshold()` haben je eine `print()`-Methode:

```r
print(x, digits = 4, ...)
```

`digits` ist die Zahl der gezeigten Nachkommastellen; `print()` rechnet nichts neu und verändert keine gespeicherte Zahl.
Die übrigen Hilfsfunktionen in `R/`, etwa die Eingabeprüfungen in `R/utils.R`, ruft man nicht selbst auf.
`mcSimulation()` und `multi_EVPI()` gehören zu decisionSupport, nicht zu diesen 16 Funktionen.

<span id="step-by-step"></span>
## Schritt für Schritt

Ein erfundenes Beispiel führt durch alle Funktionen.
Man kann sich `dX` und `dY` als zwei Maßnahmen in einem Dorf vorstellen und `d0` als „nichts ändern“; Frauen und Männer sind zwei Gruppen.
Die Zahlen sind erfunden, keine Atacora-Daten, in Geldeinheiten angegeben und von Hand nachrechenbar.

Zum Mitrechnen lädt man die Funktionen einmal im Projektordner:

```r
source("load.R")
```

[`examples/step_by_step.R`](examples/step_by_step.R) enthält alle elf Schritte als Skript zum Ausführen.
Die Ausschnitte aus `R/` zeigen die tragenden Zeilen einer Funktion; interne Namen darin wie `nb_list` oder `rule_by_draw` ruft man nicht selbst auf.

<span id="example-data"></span>
### Die drei Dinge, die man kennen muss

```r
nb <- list(women = cbind(d0 = 0, dX = c(10, 8, 6, 0), dY = c(1, 2, 1, 2)),
           men   = cbind(d0 = 0, dX = c(2, 0, -4, 2), dY = c(4, 2, 3, 3)))
p <- c(women = 0.5, men = 0.5)
W <- w_utilitarian()
```

`nb` enthält die Nettovorteile: `nb$men[3, "dX"]` ist der Wert der Männer in Ziehung 3 unter `dX`, nämlich −4 Geldeinheiten; `p` enthält die Gruppenanteile.
`W` ist eine Regel: Sie bekommt die Gruppenwerte einer Ziehung und einer Option und gibt genau eine Zahl zurück.
Deshalb kann jede Analysefunktion mit jeder Regel arbeiten.

| Zeichen in den Gleichungen | in R |
|---|---|
| Ziehung $s$ | eine Zeile |
| Option $d$ | eine Spalte |
| Gruppe $g$ | ein Element der Liste |
| $NB_g(d,\theta_s)$ | `nb[[g]][s, d]` |
| $W(NB(d,\theta_s);p)$ | `W(groups[s, ], p)` |
| $\mathbb{E}_\theta$, der Erwartungswert | `mean()` oder `colMeans()` |
| $\mathbf{1}[\ldots]$, die Indikatorfunktion | ein logischer Ausdruck; R zählt `TRUE` als 1 und `FALSE` als 0 |
| $\arg\max$ | `which.max()`; bei exaktem Gleichstand gewinnt der erste Eintrag |

$\theta_s$ steht für die unsicheren Eingaben der Ziehung $s$.
Die Zeilen müssen in allen Gruppen dieselben Ziehungen in derselben Reihenfolge sein; gleiche Abmessungen der Matrizen beweisen das nicht.
Die Funktionen ziehen keine Zufallszahlen, mischen keine Zeilen und entfernen keine fehlenden Werte.

<span id="step-1"></span>
### Schritt 1: Die Eingaben lesen

**Frage.** Was steht in den Daten, und wie liest man sie in R? **Hinein:** `nb`, `p` und `W`. **Heraus:** die Werte einzelner Ziehungen.

1. `c(10, 8, 6, 0)` reiht vier Zahlen aneinander, eine je Ziehung. Eine Zeile ist kein Jahr: Sie enthält schon den Nettovorteil über den ganzen betrachteten Zeitraum.
2. `cbind()` stellt solche Zahlenreihen als Spalten nebeneinander. `d0 = 0` wiederholt die Null in allen vier Zeilen: „Nichts ändern“ hat gegenüber sich selbst den Nettovorteil null.
3. `list(women = ..., men = ...)` hält die beiden Matrizen getrennt. Die Gruppennamen sind frei gewählt; die Funktionen kennen keine Gruppe beim Namen.
4. `p` gibt jeder Gruppe das Gewicht 0,5. Das sind keine Wahrscheinlichkeiten der Ziehungen; die vier Ziehungen zählen beim Mitteln gleich.
5. `W <- w_utilitarian()` erzeugt eine Funktion, noch kein Ergebnis. Erst `W(c(6, -4), p)` wendet sie auf zwei Gruppenwerte an und ergibt 1.

| Ziehung | women: d0 | women: dX | women: dY | men: d0 | men: dX | men: dY |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 10 | 1 | 0 | 2 | 4 |
| 2 | 0 | 8 | 2 | 0 | 0 | 2 |
| 3 | 0 | 6 | 1 | 0 | −4 | 3 |
| 4 | 0 | 0 | 2 | 0 | 2 | 3 |
| Mittel | 0 | 6 | 1,5 | 0 | 0 | 3 |

Drei Zugriffe reichen zum Lesen:

```r
nb$men                 # The complete matrix for men.
nb[["men"]][3, "dX"]   # Row 3, column dX: -4.
nb$men[, "dX"]         # All rows of dX: 2, 0, -4, 2.
```

Vor dem Komma steht die Zeile, dahinter die Spalte; eine leere Stelle heißt „alle“.
`nb[["men"]]` und `nb$men` wählen dasselbe Element; steht der Gruppenname in einer Variablen `g`, schreibt man `nb[[g]]`.
Die Gruppenwerte müssen zur gemeinsamen Bewertung passen, etwa Geld je Person über denselben Zeitraum.
Verschiedene Einheiten werden nicht vergleichbar, nur weil sie in einer Liste stehen.

<span id="core"></span>
## Der Rechenkern: erst bewerten, dann mitteln

In `R/welfare_draws.R` stehen die zwei tragenden Zeilen:

<!-- from R/welfare_draws.R -->
```r
# Each column of 'groups' is NB_g(d, theta_1), ..., NB_g(d, theta_S).
groups <- do.call(cbind, lapply(nb_list, function(x) x[, d]))
# A row is the vector NB(d, theta_s); apply W BEFORE taking a mean.
value[, d] <- rule_by_draw(groups, p, W)
```

`lapply()` nimmt aus jeder Gruppenmatrix dieselbe Optionsspalte; `do.call(cbind, ...)` stellt diese Spalten nebeneinander, eine Spalte je Gruppe und eine Zeile je Ziehung.
`rule_by_draw()` ruft dann für jede Zeile `W(groups[s, ], p)` auf und verlangt genau eine Zahl zurück.
Das Ergebnis `value` hat wieder Ziehungen in Zeilen und Optionen in Spalten.

<!-- eq-value -->
**Gleichung A1 (`eq-value`).** In Worten: Jede Option wird in jeder Ziehung mit der gewählten Regel bewertet, dann wird über die Ziehungen gemittelt; vorn liegt die Option mit dem höchsten Mittel.

```math
V(d) = \mathbb{E}_\theta\, W\big(NB(d,\theta);\,p\big),
\qquad
d^{*} = \arg\max_{d \in D}\, V(d).
```

$V(d)$ ist `colMeans(value)[d]`, $W$ ist die Regel `W` und $p$ der Vektor `p`.
Die Option mit dem größten Wert in `colMeans(value)` heißt im Ergebnis `d_star`.

<span id="step-2"></span>
### Schritt 2: Eine Spalte durch den Rechenkern verfolgen

**Frage.** Wie wird aus dem Gewinn der Frauen und dem Verlust der Männer eine Zahl? **Hinein:** die beiden Spalten von `dX`. **Heraus:** ein Regelwert je Ziehung, dann ihr Mittel.

```r
groups_dX <- cbind(women = nb$women[, "dX"], men = nb$men[, "dX"])
groups_dX[3, ]                  # women = 6, men = -4
p * groups_dX[3, ]              # 3, -2
sum(p * groups_dX[3, ])         # 1
```

Das ist die utilitaristische Rechnung für eine Ziehung: erst die beiden Gruppenwerte gewichten, dann addieren.
Dieselbe Rechnung für jede Zeile:

```r
apply(groups_dX, 1, W, p = p)   # 6, 4, 1, 1
mean(c(6, 4, 1, 1))            # 3
```

`apply(..., 1, ...)` arbeitet zeilenweise; die Funktion selbst nutzt `vapply()` für denselben Rechengang, weil dort „eine Zahl je Zeile“ ausdrücklich geprüft wird.
Für alle Optionen liefert `welfare_draws()`:

```r
value <- welfare_draws(nb, p, W)
colMeans(value)
# d0 = 0; dX = 3; dY = 2.25
```

| Ziehung | d0 | dX | dY |
|---|---:|---:|---:|
| 1 | 0 | 6 | 2,5 |
| 2 | 0 | 4 | 2 |
| 3 | 0 | 1 | 2 |
| 4 | 0 | 1 | 2,5 |
| Mittel | 0 | 3 | 2,25 |

`value` enthält die vier Zeilen; die Zeile „Mittel“ entsteht erst mit `colMeans(value)`.
Im Mittel bringt `dX` also 3 Geldeinheiten je Person, `dY` 2,25.

Warum die Reihenfolge zählt, zeigt Maximin für `dX`: Die kleinsten Gruppenwerte je Ziehung sind 2, 0, −4 und 0; ihr Mittel ist −0,5.
Das Minimum der Gruppenmittel wäre dagegen `min(6, 0) = 0`; das beantwortet eine andere Frage, und die Funktionen verwenden es nicht.

<span id="rules"></span>
## Regeln: dieselbe kleine Schnittstelle

Die fünf Regeln in `R/welfare_functions.R` liefern jeweils eine Funktion `(nb, p)`.

<!-- eq-rules -->
**Gleichung A2 (`eq-rules`).** In Worten: Die utilitaristische Regel bildet das gewichtete Mittel der Gruppenwerte, Maximin nimmt den kleinsten Gruppenwert, und die prioritäre Regel lässt Verluste mit dem Faktor $\lambda$ zählen, bevor sie mittelt.

```math
\begin{aligned}
W_{\text{util}}(NB) &= \sum_{g} p_g\, NB_g ,
\qquad
W_{\text{maximin}}(NB) = \min_{g}\, NB_g ,\\
W_{\text{prior}}(NB) &= \sum_{g} p_g\, \varphi_\lambda(NB_g),
\qquad
\varphi_\lambda(z) =
\begin{cases}
z & \text{if } z \ge 0,\\
\lambda z & \text{if } z < 0 .
\end{cases}
\end{aligned}
```

<!-- eq-rules-ext -->
**Gleichung A3 (`eq-rules-ext`).** In Worten: Atkinson verschiebt alle Gruppenwerte um k, bildet ein Potenzmittel, bei $\varepsilon = 1$ das geometrische Mittel, und zieht k wieder ab.
Die Mindestgrenze bewertet utilitaristisch, setzt aber minus unendlich, sobald eine Gruppe unter m liegt.

```math
\begin{aligned}
W_{\text{Atk}}(NB) &=
\begin{cases}
\Big(\sum_{g} p_g\, x_g^{\,1-\varepsilon}\Big)^{1/(1-\varepsilon)} - k & \text{if } \varepsilon \ne 1,\\
\exp\Big(\sum_{g} p_g \ln x_g\Big) - k & \text{if } \varepsilon = 1,
\end{cases}
\qquad x_g = NB_g + k ,\\
W_{\text{floor}}(NB) &=
\begin{cases}
\sum_{g} p_g\, NB_g & \text{if } \min_g NB_g \ge m,\\
-\infty & \text{otherwise.}
\end{cases}
\end{aligned}
```

| Regel | in R | Was man selbst wählt |
|---|---|---|
| Utilitaristisch | `sum(p * nb)` | die Gruppenanteile $p$ im Analyseaufruf |
| Maximin | `min(nb)` | nur die Regel; Anteile zählen nicht |
| Prioritär | `sum(p * u(nb))` | die Funktion `u`; „Verluste doppelt“ heißt $\lambda = 2$ |
| Atkinson | `x <- nb + offset`, dann Potenzmittel oder geometrisches Mittel, minus `offset` | `eps` ($\varepsilon$) und `offset` ($k$) |
| Mindestgrenze | `-Inf`, wenn eine Gruppe unter der Grenze liegt, sonst `sum(p * nb)` | die Grenze `min_group_nb` ($m$), Standard 0 |

Bei Atkinson muss jeder verschobene Wert `nb + offset` größer als null sein; sonst gibt es eine Warnung und `NA`, und die Regel passt den Offset nicht selbst an.
Der Offset macht negative Nettovorteile rechenbar, verändert aber auch die Bewertung; er gehört zur Wahl der Regel.
Wer eine Regel direkt aufruft, etwa `w_utilitarian()(c(10, -2), c(0.5, 0.5))`, übergibt schon normierte Anteile; die Analysefunktionen normieren selbst.
Für Maximin und die Mindestgrenze zählt auch eine Gruppe mit Anteil null.

<span id="step-3"></span>
### Schritt 3: Dieselbe Ziehung mit verschiedenen Regeln bewerten

**Frage.** Wie stark hängt das Urteil über eine Ziehung von der Regel ab? **Hinein:** Ziehung 3 von `dX`, Frauen +6 und Männer −4. **Heraus:** fünf verschiedene Regelwerte für dieselben Daten.

| Regel | Rechnung für diese zwei Werte | Ergebnis |
|---|---|---:|
| Utilitaristisch | `0.5 * 6 + 0.5 * (-4)` | 1 |
| Maximin | `min(6, -4)` | −4 |
| Prioritär, Verluste doppelt | `0.5 * 6 + 0.5 * (-8)` | −1 |
| Atkinson, $\varepsilon = 1$, Offset 10 | `exp(0.5 * log(16) + 0.5 * log(6)) - 10` | etwa −0,202 |
| Mindestgrenze 0 | die Männer liegen unter 0 | $-\infty$, ausgeschlossen |

```r
loss_twice <- function(z) ifelse(z < 0, 2 * z, z)
rules <- list(utilitarian = w_utilitarian(),
              maximin = w_maximin(),
              prioritarian = w_prioritarian(loss_twice))
rules$prioritarian(c(6, -4), p)  # -1
w_atkinson(eps = 1, offset = 10)(c(6, -4), p)  # About -0.202
w_constrained()(c(6, -4), p)     # -Inf
```

`function(z)` definiert eine kleine Rechenvorschrift; `ifelse()` verdoppelt jeden negativen Wert.
`w_prioritarian(loss_twice)` merkt sich diese Vorschrift und liefert die Regel; `rules$prioritarian` ist also eine Funktion, die Klammern dahinter führen sie aus.
Eine Liste von Regeln erlaubt denselben Ablauf mehrmals, ohne den Analysecode zu wiederholen.

Atkinson rechnet in vier Schritten: 10 addieren (16 und 6), die Logarithmen gewichtet mitteln, mit `exp()` zurückrechnen und 10 wieder abziehen.
Die Mindestgrenze prüft jede Gruppe; `-Inf` ist eine Marke für „ausgeschlossen“, kein sehr großer Geldverlust.
Hat eine Option diese Marke in nur einer Ziehung, ist auch ihr Mittel `-Inf`.
Im Atacora-Screen steht die Mindestgrenze deshalb als eigene Zulässigkeitsprüfung.

<span id="information"></span>
## Informationswert: warum die Reihenfolge von Mittel und Maximum zählt

In `R/voi_partition.R` stehen die tragenden Zeilen:

<!-- from R/voi_partition.R -->
```r
criterion <- colMeans(value)            # V(d) = (1/S) sum_s U[s,d]
d <- best_option(criterion)             # d* = argmax_d V(d)
A <- max(criterion)                     # max AFTER averaging: today's choice
C <- mean(apply(value, 1L, max))         # max BEFORE averaging: perfect information
ahead <- apply(value, 1L, best_option)
EVPI <- C - A                          # information changes the order of max and mean
```

`A` wählt die Option mit dem höchsten Mittel: eine feste Entscheidung mit dem heutigen Wissen.
`apply(value, 1L, max)` nimmt dagegen in jeder Ziehung die beste Option.
Ihr Mittel ist `C`, der Wert von Entscheidungen mit perfekter Information; die Differenz ist der EVPI.

<!-- eq-voi -->
**Gleichung A4 (`eq-voi`).** In Worten: A ist der beste Erwartungswert einer Option für alle, C das Mittel der jeweils besten Option je Ziehung.
B und D sind dasselbe, wenn jede Gruppe eine eigene Option bekommen darf.

```math
\begin{aligned}
A &= \max_{d}\; \mathbb{E}_\theta\, W\big(NB(d,\theta)\big),\\
B &= \max_{(d_1,\dots,d_G)}\; \mathbb{E}_\theta\, W\big(NB_1(d_1,\theta),\dots,NB_G(d_G,\theta)\big),\\
C &= \mathbb{E}_\theta\, \max_{d}\; W\big(NB(d,\theta)\big),\\
D &= \mathbb{E}_\theta\, W\Big(\max_{d} NB_1(d,\theta),\dots,\max_{d} NB_G(d,\theta)\Big).
\end{aligned}
```

`A`, `B`, `C` und `D` heißen im Ergebnis von `voi_partition()` genauso.
Das Maximum über Mittelwerte ist `max(colMeans(value))`, das Mittel über Maxima ist `mean(apply(value, 1L, max))`.

Ist jede Option durch die Mindestgrenze ausgeschlossen, ist `d_star` gleich `NA`: Es gibt keine Empfehlung, und die formalen Werte $-\infty$ sind kein Forschungsbudget in Geld.

<span id="step-4"></span>
### Schritt 4: Eine gemeinsame Entscheidung und ihren EVPI berechnen

**Frage.** Welche Option ist im Mittel die beste, und was brächte es, vorher zu wissen, welche Ziehung eintritt? **Hinein:** `nb`, `p` und `W`. **Heraus:** die beste Option, `A`, `C` und der EVPI.

```r
joint <- voi_partition(nb, p, W)
joint$criterion  # d0 = 0; dX = 3; dY = 2.25
joint$d_star     # "dX"
joint$EVPI       # 0.625
```

1. **Heute entscheiden.** Die Mittel sind 0, 3 und 2,25. Ihr Maximum ist `A = 3`: Wer sich jetzt festlegt, wählt `dX`.
2. **Mit perfekter Information entscheiden.** In den Ziehungen 1 und 2 gewinnt `dX`, in 3 und 4 gewinnt `dY`. Die erreichbaren Werte sind 6, 4, 2 und 2,5; ihr Mittel ist `C = 3.625`.
3. **Den Unterschied berechnen.** `C - A = 0.625` Geldeinheiten je Person: Das ist der EVPI, in der Einheit des Regelwerts. Probe: Wer heute `dX` wählt, verpasst je Ziehung 0, 0, 1 und 1,5; auch deren Mittel ist 0,625.
4. **Die Häufigkeit getrennt lesen.** `joint$p_ahead = 0.5`, weil `dX` in zwei von vier Ziehungen vorn liegt. Eine Option kann den höchsten Erwartungswert haben, ohne in den meisten Ziehungen zu gewinnen. Bei exaktem Gleichstand zählt die zuerst genannte Option; `p_ahead` ist deshalb keine Wahrscheinlichkeit, strikt vorn zu liegen.

<span id="step-5"></span>
### Schritt 5: Getrennte Entscheidungen zulassen

**Frage.** Was wäre erreichbar, wenn Frauen und Männer verschiedene Optionen bekommen dürften? **Hinein:** dieselben Daten und `differentiated = TRUE`. **Heraus:** `B`, `D` und ihr Verhältnis zum EVPI.

```r
split <- voi_partition(nb, p, W, differentiated = TRUE)
split$B             # 4.5
split$D             # 4.75
voh_index(split)    # 2.4
```

„Getrennt“ heißt: Frauen und Männer dürfen verschiedene Optionen bekommen, nicht nur getrennt berichtet werden; das muss in der Wirklichkeit möglich sein.
Im Atacora-Modell gibt es getrennte Entscheidungen deshalb nur für Haushaltstypen: Eine Maschine kann nicht für denselben Haushalt zugleich da sein und fehlen.

Bei drei Optionen und zwei Gruppen gibt es neun Profile.
Ohne neue Information ist `women = dX, men = dY` das beste: Seine Werte sind 7, 5, 4,5 und 1,5, also `B = 4.5`.
Mit perfekter Information darf das Profil je Ziehung wechseln; in der vierten Ziehung bekommt dann auch die Frau `dY`, und es entstehen 7, 5, 4,5 und 2,5, also `D = 4.75`.

| Frage | Rechnung | Ergebnis |
|---|---|---:|
| Was bringen getrennte Entscheidungen schon heute? | `B - A = 4.5 - 3` | 1,5 |
| Was bringt Information zusätzlich, wenn schon getrennt entschieden wird? | `D - B = 4.75 - 4.5` | 0,25 |
| Was bringen getrennte Entscheidungen bei perfekter Information? | `D - C = 4.75 - 3.625` | 1,125 |
| Wie groß ist der erste Wert im Verhältnis zum EVPI? | `(B - A) / (C - A)` | 2,4 |

2,4 ist ein Verhältnis, das 2,4-Fache, und keine Wahrscheinlichkeit.
Zum Nachrechnen hilft `A + (B - A) + (D - B) = C + (D - C) = D`.

Sind nur bestimmte Profile möglich, gibt man sie ausdrücklich an:

```r
allowed <- rbind(c("d0", "d0"), c("dX", "dX"), c("dY", "dY"),
                 c("dX", "d0"), c("d0", "dX"))
colnames(allowed) <- c("women", "men")
restricted <- voi_partition(nb, p, W, differentiated = TRUE, profiles = allowed)
```

Nun fehlen unter anderem `dX/dY` und `dY/dX`.
Mit dieser kleineren Auswahl sind `B = 3` und `D = 3.875`; in Ziehung 3 ist dann `dX/d0` mit dem Wert 3 am besten.
Die Daten sind gleich geblieben, geändert haben sich die erlaubten Entscheidungen; Optionsmenge und erlaubte Profile gehören deshalb zu jedem Informationswert.

<!-- eq-voi-profiles -->
**Gleichung A5 (`eq-voi-profiles`).** In Worten: Bei beschränkten Profilen werden B und D nur über die erlaubten Profile gebildet, und in jeder Ziehung zählt das beste erlaubte Profil.

```math
B = \max_{r \in R}\; \mathbb{E}_\theta\, W\big(NB(r,\theta)\big),
\qquad
D = \mathbb{E}_\theta\, \max_{r \in R}\; W\big(NB(r,\theta)\big).
```

$r$ ist eine Zeile von `profiles`, $R$ die ganze Matrix.
Die Funktion bewertet jedes erlaubte Profil in jeder Ziehung; `pmax()` führt den besten Wert je Ziehung fort.

`voh_index()` liefert `NA` mit Begründung, wenn der Nenner `C - A` null oder nicht endlich ist.
Bei beschränkten Profilen sind `B - A` und `D - C` nur dann sicher null oder größer, wenn jede gemeinsame Option auch als Profil erlaubt bleibt; negative Differenzen werden nicht auf null gesetzt.

**Für eigene Regeln.** Ohne beschränkte Profile nutzt die Funktion eine Abkürzung: Jede Gruppe nimmt ihr eigenes Maximum.
Das ist richtig, wenn gilt: Geht es einer Gruppe besser und keiner schlechter, darf die gemeinsame Zahl nicht sinken.
Das gilt für alle fünf mitgelieferten Regeln.

<span id="hidden-losses"></span>
## Verdeckte Verluste und Vergleich der Regeln

`marginalisation_count()` in `R/fairness_screen.R` zählt mit drei Zeilen:

<!-- from R/fairness_screen.R -->
```r
below <- do.call(cbind, lapply(nb_list, function(x) x[, d] < 0))
gain <- value[, d] > 0                   # W(NB(d, theta_s)) > 0
hidden <- gain & rowSums(below) > 0      # AND min_g NB_g(d, theta_s) < 0
```

`rowSums(below) > 0` heißt: Mindestens eine Gruppe verliert in dieser Ziehung.
`&` verlangt zugleich einen positiven Regelwert.
Das Mittel dieser `TRUE`/`FALSE`-Werte, `mean(hidden)`, ist der Anteil solcher Ziehungen; `colMeans(gain & below)` gibt ihn je Gruppe.

<!-- eq-marginalisation -->
**Gleichung A6 (`eq-marginalisation`).** In Worten: M ist der Anteil der Ziehungen, in denen die geprüfte Option gemeinsam positiv bewertet wird und zugleich mindestens eine Gruppe verliert.

```math
M = \frac{1}{S} \sum_{s=1}^{S}
\mathbf{1}\Big[\, W\big(NB(d^{*},\theta_s)\big) > 0 \;\wedge\; \min_{g}\, NB_g(d^{*},\theta_s) < 0 \,\Big].
```

$S$ ist die Zahl der Ziehungen.
Die geprüfte Option heißt im Ergebnis `d_star`, und die Klammer mit der 1 ist der logische Wert `hidden`.

`fairness_screen(nb, p, rules)` wiederholt diese Prüfung für jede Regel: `$table` berichtet je Regel die bevorzugte Option, ihren EVPI, ihren Anteil gewonnener Ziehungen und die Verlustanteile; `$scores` enthält alle Optionen unter allen Regeln.
`$rank_correlation` ist die kleinste paarweise Rangkorrelation nach Spearman; lässt sie sich nicht berechnen, steht dort `NA`.
Die Verlustanteile gelten für die Option, die die jeweilige Regel bevorzugt; für eine andere Option gibt man `d_star` an.
Eine automatische Auswahl „aller ethischen Regeln“ oder eine voreingestellte Gewichtung gibt es nicht.

<span id="step-6"></span>
### Schritt 6: Einen verdeckten Verlust Zeile für Zeile erkennen

**Frage.** Wer verliert, obwohl das Gesamtergebnis positiv ist? **Hinein:** `nb`, `p`, `W` und die Option `dX`. **Heraus:** der Anteil der Ziehungen mit verdecktem Verlust, gesamt und je Gruppe.

```r
hidden <- marginalisation_count(nb, p, W, d_star = "dX")
```

| Ziehung | Regelwert von dX | Frauen < 0? | Männer < 0? | positiv und ein Verlust? |
|---|---:|---|---|---|
| 1 | 6 | FALSE | FALSE | FALSE |
| 2 | 4 | FALSE | FALSE | FALSE |
| 3 | 1 | FALSE | TRUE | TRUE |
| 4 | 1 | FALSE | FALSE | FALSE |

Nur in Ziehung 3 sieht das gemeinsame Ergebnis positiv aus, obwohl eine Gruppe verliert.
`mean(c(FALSE, FALSE, TRUE, FALSE))` ist 0,25: ein verdeckter Verlust in einem Viertel aller Ziehungen, nicht nur der positiven.
Ohne die Bedingung „positiv“ erhält man die Verlustanteile von `nb_summary()`.

```r
screen <- fairness_screen(nb, p, rules)
screen$table
screen$scores
```

Die utilitaristische und die prioritäre Regel wählen hier `dX`, Maximin wählt `dY`.
Die EVPI sind 0,625, 1,125 und 0,25, die verdeckten Verluste 25 %, 0 % und 0 %.
Unter der prioritären Regel verliert der Mann weiterhin in 25 % der Ziehungen; der gemeinsame Regelwert ist dort aber negativ, der Verlust also nicht verdeckt.
Welche Regel richtig ist, sagt das Ergebnis nicht.

**Für eigene Regeln.** Die Funktionen vergleichen streng mit `< 0` und `> 0`.
Ein Rundungsrest knapp unter null zählt deshalb als Verlust.
Wo das Modell eigentlich eine exakte Null liefert, muss man das beim Lesen erklären.

<span id="units"></span>
## Berichtseinheiten

In `R/reporting_units.R` ist eine Berichtseinheit eine gewichtete Summe ganzer Matrizen:

<!-- from R/reporting_units.R -->
```r
terms <- Map(function(x, coefficient) coefficient * x,
              nb_list[names(coefficients)], coefficients)
Reduce(`+`, terms)
```

`Map()` multipliziert jede gewählte Gruppe mit ihrem Koeffizienten, `Reduce()` addiert die Matrizen Feld für Feld.
Die Koeffizienten werden nicht normiert: `(1, 1)` ergibt eine Summe, `(0.5, 0.5)` ein Mittel.

<!-- eq-units -->
**Gleichung A7 (`eq-units`).** In Worten: Der Wert einer Berichtseinheit ist die Summe der Gruppenwerte, jeder mal einem gewählten Koeffizienten.

```math
NB_k(d,\theta) = \sum_{g} c_{kg}\, NB_g(d,\theta).
```

$c_{kg}$ ist der Eintrag für die Gruppe $g$ im Koeffizientenvektor der Einheit $k$, etwa `c(women = 1, men = 1)` für `total`.

`nb_summary(nb)` zeigt je Gruppe Mittel, Gewinn- und Verlustanteil, die eigene beste Option und den eigenen EVPI, ohne gemeinsame Regel.
Der EVPI steht in jeder Optionszeile einer Gruppe, gehört aber zur ganzen Entscheidung dieser Gruppe; man darf ihn nicht über Zeilen addieren.

<span id="step-7"></span>
### Schritt 7: Eine Berichtseinheit bilden, ohne sie mit einer Regel zu verwechseln

**Frage.** Wie berichte ich für Frau und Mann zusammen statt je Person? **Hinein:** `nb` und die Koeffizienten. **Heraus:** die neue Einheit `total` und je Gruppe die eigene Entscheidung.

```r
units <- reporting_units(nb, list(total = c(women = 1, men = 1)))
units$total[, "dX"]                # 12, 8, 2, 2
mean(units$total[, "dX"])          # 6
nb_summary(nb)
```

1. Der Koeffizient 1 übernimmt jede Gruppenmatrix unverändert.
2. Die Matrizen werden Feld für Feld addiert, in Ziehung 3 unter `dX` also `6 + (-4) = 2`.
3. Das Mittel der vier Summen ist 6 Geldeinheiten für Frau und Mann zusammen. Die utilitaristische Bewertung mit den Anteilen 0,5 und 0,5 ergab 3 Geldeinheiten je Person. Summe und gewichtetes Mittel haben verschiedene Skalen, auch wenn die Rangfolge hier gleich bleibt.

`reporting_units()` beantwortet: In welcher Einheit berichte ich? `W` beantwortet: Wie bewerte ich die Gruppen gemeinsam?
Bei der utilitaristischen Regel sehen beide Rechnungen ähnlich aus, Bedeutung und Normierung unterscheiden sich aber.
Im Atacora-Modell rechnet etwa die Zahl der Huller je Haushalt einen Betrag je Huller in einen Beitrag je Haushalt um.

Die eigene Entscheidung der Frauen ist `dX` mit einem EVPI von 0,5, die der Männer `dY` mit EVPI 0.
Diese Werte darf man nicht ungewichtet zum gemeinsamen EVPI von 0,625 addieren.
Ihr gewichtetes Mittel, `0.5 * 0.5 + 0.5 * 0 = 0.25`, ist bei getrennten Entscheidungen und linearer Gewichtung genau `D - B` aus Schritt 5.

Mehrere Ergebnisgrößen hält `nb_array()` nebeneinander:

```r
hours <- cbind(d0 = 0, dX = c(2, 3, 1, 0), dY = c(1, 1, 1, 1))
measured <- nb_array(money = nb$women, hours = hours)
measured[3, "dX", "money"]        # 6
measured[3, "dX", "hours"]        # 1
```

Die Stunden sind weitere erfundene Werte; der dritte Index wählt die Ergebnisgröße.
Gerechnet wird weder `6 + 1` noch ein Geldwert der Stunde; zum Bewerten wählt man eine Ergebnisgröße als Matrix.

<span id="references"></span>
## Referenzen vergleichen

`baseline_pair()` in `R/baseline_pair.R` bekommt eine kleine Funktion, die zu jeder Referenz die passenden Nettovorteile liefert, und ruft sie genau zweimal auf.
Sie erfindet keinen Referenzwert und zieht keine Referenz ein zweites Mal ab.

<!-- eq-reference -->
**Gleichung A8 (`eq-reference`).** In Worten: Der Nettovorteil ist das Ergebnis mit der Option minus das Ergebnis ohne Änderung, beide unter derselben Referenz.

```math
NB_g(d,\theta;\,r) = Y_g(d,\theta;\,r) - Y_g(d_0,\theta;\,r),
```

$Y_g$ ist das Ergebnis der Gruppe im Modell, $d_0$ die Option „nichts ändern“ und $r$ eine der zwei Angaben in `references`.
Die Differenz rechnet das Modell; `baseline_pair()` bekommt sie fertig.

`$outcomes` zeigt beide Mittel, beide Gewinnanteile und ihre Differenz; `$rules` zeigt je Referenz und Regel die Empfehlung und den EVPI.
`flip` ist `TRUE`, wenn die Empfehlung wechselt; ist eine Empfehlung nicht definiert, steht dort `NA`; mehrere Ergebnisgrößen werden getrennt bewertet.

<span id="step-8"></span>
### Schritt 8: Genau die Referenz ändern, die man untersuchen möchte

**Frage.** Ändert sich die Empfehlung, wenn man mit etwas anderem vergleicht? **Hinein:** eine Modellfunktion und zwei Referenzangaben. **Heraus:** Empfehlung und EVPI unter beiden Referenzen.

Diese Demonstration verändert nur die schon berechneten Nettovorteile der Frauen unter `dX`; sie ist kein Modell der Wirklichkeit:

```r
example_model <- function(adjustment) {
  result <- nb
  result$women[, "dX"] <- result$women[, "dX"] - adjustment
  result
}
pair <- baseline_pair(example_model,
  references = list(first = 0, second = 3), p = p,
  rules = list(utilitarian = W))
pair$rules
```

1. `baseline_pair()` übergibt zuerst 0, dann 3 an `example_model()`.
2. Unter der ersten Referenz bleibt der Erwartungswert von `dX` bei 3. Unter der zweiten sinkt er um `0.5 * 3 = 1.5` auf 1,5.
3. `dY` bleibt in beiden Fällen bei 2,25. Die Empfehlung wechselt deshalb von `dX` zu `dY`; `flip` ist `TRUE`.
4. In `pair$outcomes` sinkt das Mittel der Frauen für `dX` von 6 auf 3, also `difference = -3`. Das ist eine Differenz von Ergebnissen, kein weiterer Abzug in der Entscheidung.

Im Atacora-Screen liefert `function(s) nb(c("G", "H"), s)` die vom Modell schon berechneten Spalten für `V1` und `PREF`; die andere Bewertung der Zeit steckt in diesen Spalten.
Bleibt `flip = FALSE`, heißt das nur: Dieselbe Option wurde gewählt.
Mittel, Informationswerte oder Verluste können sich trotzdem ändern.

<span id="fidelity"></span>
## Umsetzungstreue: wie viel der Wirkung ankommen muss

`fidelity_threshold()` in `R/fidelity_threshold.R` skaliert nur die gerade geprüfte Option mit einem Anteil f; die Alternativen behalten ihre volle Wirkung.
`mean(rule_by_draw(f * groups, p, W))` ist der Wert der Option beim Anteil f.

<!-- eq-fidelity -->
**Gleichung A9 (`eq-fidelity`).** In Worten: Man multipliziert die Nettowirkung der Option mit f, bewertet und mittelt.
Gesucht ist das kleinste f zwischen 0 und 1, bei dem die Option die beste Alternative mit voller Wirkung erreicht.

```math
V_d(f) = \mathbb{E}_\theta\, W\big(f \cdot NB(d,\theta)\big),
\qquad
f^{*}_d = \min\Big\{ f \in [0,1] : V_d(f) \ge \max_{e \ne d} V_e(1) \Big\}.
```

$V_d(f)$ ist der Wert der Option beim Anteil $f$.
Die rechte Seite der Ungleichung ist die Spalte `best_other`, das gesuchte kleinste $f$ die Spalte `f_star`.

Gleichstand genügt für die Ungleichung, auch wenn bei der Auswahl eine früher genannte Option gewinnt.
Die Suche geht so vor:

1. Erfüllt schon f = 0 die Ungleichung, ist `f_star` null.
2. Erfüllt f = 1 sie, halbiert eine Intervallsuche den Abstand, bis die Genauigkeit `tol` erreicht ist.
3. Sonst sucht die Funktion ein inneres Maximum. Erreicht auch dieses die Alternative nicht, ist das Ergebnis `NA`; sonst sucht sie die erste Überschreitung zwischen null und diesem Maximum.

Ein kleinerer Anteil ist nicht immer schlechter: Gewinnt eine Gruppe und verliert eine andere, kann Atkinson ein inneres Maximum haben.
Dann ist `f_star` nur der Anfang eines ausreichenden Bereichs, keine Zusage für alle größeren Anteile.
Auch eine insgesamt negative Option kann bei f = 0 den Status quo gerade erreichen.
`value`, `best_other` und `recommended` liest man deshalb mit `f_star` zusammen.

<span id="step-9"></span>
### Schritt 9: Einen Schwellenwert von Hand finden

**Frage.** Wie viel der Wirkung von `dX` muss ankommen, damit `dX` vorn bleibt? **Hinein:** `nb`, `p` und `W`. **Heraus:** je Option der kleinste ausreichende Anteil.

```r
fidelity <- fidelity_threshold(nb, p, W)
fidelity
```

Für `dX` ist die beste andere Option `dY` mit dem Wert 2,25.
Unter der utilitaristischen Regel ist der Wert von `dX` beim Anteil f gleich `3 * f`.
Gesucht ist also `3 * f >= 2.25`, das heißt f ab 0,75.

| Anteil f | Wert von dX | beste Alternative | erfüllt? |
|---|---:|---:|---|
| 0 | 0 | 2,25 | nein |
| 0,5 | 1,5 | 2,25 | nein |
| 0,75 | 2,25 | 2,25 | ja |
| 1 | 3 | 2,25 | ja |

Die Suche prüft zuerst die Ränder.
Weil 0 nicht genügt und 1 genügt, halbiert sie das Intervall: erst 0,5, dann 0,75, dann weitere Zwischenpunkte bis zur geforderten Genauigkeit.
Eine eigene Formel wie `2.25 / 3` braucht sie nicht; so funktioniert sie auch mit den anderen Regeln.

Für `dY` ist dagegen die volle Alternative `dX` mit 3 der Maßstab.
Selbst bei f = 1 kommt `dY` nur auf 2,25.
Das Ergebnis ist `NA`: Kein Anteil zwischen 0 und 1 reicht, und `NA` heißt hier nicht null.

Bei einer schädlichen Option kann `f_star = 0` herauskommen: Wird die ganze Wirkung auf null skaliert, verschwindet auch der Schaden.
Das ist eine Aussage über die Ungleichung, keine Empfehlung, eine Maßnahme ohne Wirkung umzusetzen.
Ebenso verspricht ein Atkinson-Schwellenwert bei einem inneren Maximum nicht, dass alle größeren Anteile reichen.

Diese Funktion skaliert die ganze Nettowirkung einer Option.
Wer einzelne Bestandteile einer Maßnahme getrennt variieren will, braucht einen eigenen Modelllauf, im Atacora-Fall in `atacora_DA_axes_full.R`.

**Für eigene Regeln.** Die Suche setzt voraus, dass $V_d(f)$ zwischen 0 und 1 endlich, stetig und konkav ist.
Das gilt für die utilitaristische Regel, Maximin, die prioritäre Regel mit einem Verlustfaktor von mindestens 1 und Atkinson im positiven Bereich.
Bei einer eigenen Transformation muss man das selbst prüfen; die Mindestgrenze mit `-Inf` eignet sich nicht.
`tol` ist die absolute Genauigkeit von f.

<span id="decisionsupport"></span>
## Anschluss an decisionSupport

`nb_from_mc()` in `R/nb_from_mc.R` liest `mc$y`, so wie `mcSimulation()` es liefert.
Ein Spaltenmuster, die Gruppen und die Optionen reichen.
`decisionSupport::multi_EVPI()` misst einen anderen Informationswert als `voi_partition()`; [Schritt 11](#step-11) zeigt den Unterschied.

<span id="step-10"></span>
### Schritt 10: Die Simulation anschließen

**Frage.** Wie kommen die Ergebnisse eines echten Modells in diese Form? **Hinein:** das Ergebnis von `mcSimulation()`. **Heraus:** dieselbe Liste von Gruppenmatrizen wie `nb`.

```r
people <- nb_from_mc(simulation_results, "NB_{group}_{option}_V1",
                     groups = c("G", "H"),
                     options = c("sq", "out", "up_std", "up_inc", "deep"))
```

1. Die Ausgabetabelle liegt in `simulation_results$y`. Gruppen und Optionen ergeben die Spaltennamen, etwa `NB_G_out_V1`.
2. Die fünf Spalten von G werden zur ersten Matrix, die fünf von H zur zweiten.
3. `people` hat dieselbe Form wie `nb`; hier hat jede Matrix 10 000 Zeilen und fünf Spalten.
4. Danach funktionieren dieselben Aufrufe wie oben. Gruppenanteile und Regeln legt man für den Fall ausdrücklich fest.

`options` bestimmt zugleich die Reihenfolge der Optionen und damit, wer bei exaktem Gleichstand gewinnt.
`attributes` braucht man für eine einzelne Ergebnisgröße nicht.

<span id="step-11"></span>
### Schritt 11: Vollständigen und partiellen Informationswert auseinanderhalten

**Frage.** Was genau misst ein Informationswert? **Hinein:** dieselben Daten mit weniger Optionen. **Heraus:** ein anderer EVPI.

`voi_partition()` nutzt alle angegebenen Optionen.
Es fragt, was perfekte Kenntnis der unsicheren Eingaben für diese Entscheidung wert wäre.
`multi_EVPI()` bildet dagegen für ein bestimmtes Optionspaar die Differenz und schätzt den Wert der Information über einzelne Eingaben; beide Werte darf man nicht gleichsetzen.

<!-- eq-evppi -->
**Gleichung A10 (`eq-evppi`).** In Worten: Der partielle Informationswert einer Eingabe j ist, was man im Mittel gewänne, wenn man vor der Wahl zwischen zwei Optionen nur diese eine Eingabe kennen würde.

```math
\mathrm{EVPI}_j = \mathbb{E}_{\theta_j}\Big[\max\big(\mathbb{E}(\Delta \mid \theta_j),\,0\big)\Big] - \max\big(\mathbb{E}\,\Delta,\,0\big).
```

$\Delta$ ist der Unterschied der zwei Optionen je Ziehung, in `examples/partial_information.R` die Spalte `comparison`.
$\theta_j$ ist die Eingabe $j$; `multi_EVPI()` rechnet diesen Wert für jede Eingabe.

Unser Beispiel zeigt, wie stark die Optionsmenge zählt:

```r
only_X <- lapply(nb, function(x) x[, c("d0", "dX"), drop = FALSE])
voi_partition(only_X, p, W)$EVPI  # 0
voi_partition(nb, p, W)$EVPI      # 0.625
```

`dX` schlägt `d0` in jeder Ziehung.
Sind nur diese zwei Optionen erlaubt, ändert Information die Entscheidung nie.
Erst `dY` schafft Ziehungen, in denen man anders entscheiden möchte.
Ein EVPI von null für ein Optionspaar passt deshalb zu einem positiven EVPI für alle Optionen.
Zu jedem Informationswert gehören Ergebnisgröße, Optionsmenge und Umfang der Information.

[`examples/partial_information.R`](examples/partial_information.R) verbindet beides: Es bildet ein ausdrücklich benanntes Optionspaar, ruft `multi_EVPI()` auf und berichtet, wie oft eine ausgelassene Option besser wäre.

<span id="full-run"></span>
## Vollständiger Durchlauf

Dieses Skript wendet alle 16 Funktionen auf die vier Beispielziehungen an.
Es läuft für sich aus dem Projektordner und steht auch in [`examples/complete_analysis.R`](examples/complete_analysis.R).
Die sechs Spalten in `mc$y` bilden die bekannte Tabelle nach; `nb_from_mc()` ordnet sie Gruppen und Optionen zu; die Stunden am Ende sind eigene erfundene Werte.

```r
# Run from the project root. Four invented draws, not Atacora data.
source("load.R")
mc <- list(y = data.frame(
  NB_women_d0 = 0, NB_women_dX = c(10, 8, 6, 0), NB_women_dY = c(1, 2, 1, 2),
  NB_men_d0 = 0, NB_men_dX = c(2, 0, -4, 2), NB_men_dY = c(4, 2, 3, 3)))
nb <- nb_from_mc(mc, "NB_{group}_{option}",
                 groups = c("women", "men"), options = c("d0", "dX", "dY"))
p <- c(women = 0.5, men = 0.5)
rules <- list(utilitarian = w_utilitarian(), maximin = w_maximin(),
  prioritarian = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)),
  atkinson_1 = w_atkinson(eps = 1, offset = 10),
  atkinson_2 = w_atkinson(eps = 2, offset = 10))

print(nb_summary(nb))
print(welfare_draws(nb, p, W = rules$utilitarian))
units <- reporting_units(nb, units = list(total = c(women = 1, men = 1)))
print(nb_summary(units))
joint <- voi_partition(nb, p, W = rules$utilitarian)
print(joint)
split <- voi_partition(nb, p, W = rules$utilitarian, differentiated = TRUE)
print(split)
print(voh_index(split))
print(marginalisation_count(nb, p, W = rules$utilitarian))
print(fairness_screen(nb, p, rules))
print(welfare_draws(nb, p, W = w_constrained(min_group_nb = 0)))
print(fidelity_threshold(nb, p, W = rules$utilitarian))

reference_model <- function(adjustment) {
  result <- nb
  result$women[, "dX"] <- result$women[, "dX"] - adjustment
  result
}
references <- baseline_pair(reference_model,
  references = list(first = 0, second = 3), p = p,
  rules = list(utilitarian = rules$utilitarian))
print(references)
measured <- nb_array(money = nb$women,
  hours = cbind(d0 = 0, dX = c(2, 3, 1, 0), dY = c(1, 1, 1, 1)))
print(measured)
```

Die folgenden Blöcke zeigen, was R bei diesem Skript ausgibt; die `print()`-Methoden runden auf vier Nachkommastellen.
Feldnamen und Ausgabetexte bleiben englisch, wie die Funktionen sie liefern.

**Ausgabe 1: nb_summary(nb)**
```text
   unit option mean p_gain p_loss preferred EVPI
1 women     d0  0.0   0.00   0.00        dX  0.5
2 women     dX  6.0   0.75   0.00        dX  0.5
3 women     dY  1.5   1.00   0.00        dX  0.5
4   men     d0  0.0   0.00   0.00        dY  0.0
5   men     dX  0.0   0.50   0.25        dY  0.0
6   men     dY  3.0   1.00   0.00        dY  0.0
```

`mean` ist das Mittel, `p_gain` und `p_loss` sind die Anteile der Ziehungen mit Gewinn und Verlust, `preferred` und `EVPI` die eigene Entscheidung jeder Gruppe ([Schritt 7](#step-7)).
Frauen bevorzugen `dX`, Männer `dY`; bei `dX` verlieren die Männer in einer von vier Ziehungen, obwohl ihr Mittel null ist.

**Ausgabe 2: welfare_draws()**
```text
     d0 dX  dY
[1,]  0  6 2.5
[2,]  0  4 2.0
[3,]  0  1 2.0
[4,]  0  1 2.5
```

Die Zeilen sind die vier Ziehungen, die Zahlen utilitaristische Regelwerte ([Schritt 2](#step-2)).
In Zeile 3 ist der Wert von `dX` positiv, obwohl die Männer dort −4 erhalten.

**Ausgabe 3: reporting_units() und nb_summary()**
```text
   unit option mean p_gain p_loss preferred EVPI
1 total     d0  0.0      0      0        dX 1.25
2 total     dX  6.0      1      0        dX 1.25
3 total     dY  4.5      1      0        dX 1.25
```

Mit Koeffizient 1 für beide Gruppen ist `total` die Summe: Mittel und EVPI sind doppelt so groß wie die utilitaristischen Werte mit den Anteilen 0,5 und 0,5 ([Schritt 7](#step-7)).
`p_loss = 0` bei `dX` heißt nur, dass die Summe nie negativ ist; der Verlust der Männer in Ziehung 3 bleibt bestehen.

**Ausgabe 4: voi_partition()**
```text
Preferred option: dX 
    A     C  EVPI 
3.000 3.625 0.625 
```

`Preferred option` ist die beste gemeinsame Option, `A` ihr Wert heute, `C` der Wert mit perfekter Information und `EVPI` die Differenz ([Schritt 4](#step-4)).
Weitere Werte wie `joint$criterion` und `joint$p_ahead` stehen im Objekt.

**Ausgabe 5: voi_partition(differentiated = TRUE)**
```text
Preferred option: dX 
         A          B          C          D       EVPI VoH_static   EVPI_sub    VoH_dyn 
     3.000      4.500      3.625      4.750      0.625      1.500      0.250      1.125 
women   men 
 "dX"  "dY" 
```

Die erste Zeile nennt weiterhin die beste gemeinsame Option, die letzte das beste getrennte Profil: Frauen `dX`, Männer `dY` ([Schritt 5](#step-5)).
`VoH_static`, `EVPI_sub` und `VoH_dyn` sind `B - A`, `D - B` und `D - C`.

**Ausgabe 6: voh_index()**
```text
[1] 2.4
```

`[1]` kennzeichnet nur das erste Element.
2,4 heißt: Getrennte Entscheidungen bringen heute das 2,4-Fache des gemeinsamen EVPI ([Schritt 5](#step-5)); das ist weder ein Prozentwert noch eine Wahrscheinlichkeit.

**Ausgabe 7: marginalisation_count()**
```text
Hidden-loss share for dX : 0.25 
 group share
 women  0.00
   men  0.25
```

Ohne `d_star` prüft die Funktion die Option, die die Regel bevorzugt, hier `dX`.
In 25 % aller Ziehungen ist ihr gemeinsamer Wert positiv, während eine Gruppe verliert; betroffen sind nur die Männer ([Schritt 6](#step-6)).

**Ausgabe 8: fairness_screen()**
```text
         rule option p_ahead   EVPI p_group_loses p_hidden_loss
  utilitarian     dX    0.50 0.6250          0.25          0.25
      maximin     dY    0.75 0.2500          0.00          0.00
 prioritarian     dX    0.50 1.1250          0.25          0.00
   atkinson_1     dX    0.50 0.9240          0.25          0.00
   atkinson_2     dY    0.50 0.8843          0.00          0.00
```

Jede Zeile nennt eine Regel und ihre bevorzugte Option; `p_group_loses` zählt jeden Gruppenverlust bei dieser Option, `p_hidden_loss` nur die verdeckten ([Schritt 6](#step-6)).
Prioritär und Atkinson mit $\varepsilon = 1$ bleiben bei `dX`: Die Männer verlieren weiter in 25 % der Ziehungen, nur ist der Verlust dort nicht verdeckt.
Die Atkinson-Zeilen gelten für den gewählten Offset 10, und die EVPI sind in der jeweiligen Regel gemessen, also keine vergleichbaren Geldbeträge.

**Ausgabe 9: welfare_draws() mit w_constrained()**
```text
     d0   dX  dY
[1,]  0    6 2.5
[2,]  0    4 2.0
[3,]  0 -Inf 2.0
[4,]  0    1 2.5
```

`-Inf` bei `dX` in Zeile 3 zeigt, dass die Männer dort unter die Grenze null fallen ([Schritt 3](#step-3)).
Die Forderung, dass keine Gruppe in irgendeiner Ziehung verliert, schließt `dX` deshalb aus, `d0` und `dY` erfüllen sie; aus der Marke folgt kein Geldbetrag und kein Forschungsbudget.

**Ausgabe 10: fidelity_threshold()**
```text
 option value best_other recommended f_star
     d0  0.00       3.00       FALSE     NA
     dX  3.00       2.25        TRUE   0.75
     dY  2.25       3.00       FALSE     NA
```

`value` ist der Wert bei voller Wirkung, `best_other` die beste Alternative mit voller Wirkung ([Schritt 9](#step-9)).
`dX` braucht 75 % seiner Wirkung, um `dY` zu erreichen; für `d0` und `dY` reicht kein Anteil, deshalb `NA`.

**Ausgabe 11: baseline_pair()**
```text
        rule outcome reference option p_ahead  EVPI flip
 utilitarian      nb     first     dX     0.5 0.625 TRUE
 utilitarian      nb    second     dY     0.5 0.625 TRUE
```

Unter der zweiten Referenz sind von den Werten der Frauen unter `dX` 3 Geldeinheiten abgezogen; die Empfehlung wechselt von `dX` zu `dY`, daher `flip = TRUE` ([Schritt 8](#step-8)).
Der EVPI bleibt hier zufällig gleich; ein Wechsel der Empfehlung verlangt keinen Wechsel des EVPI.
`outcome = nb` ist der Name der einzigen Ergebnisgröße; die Mittel je Gruppe stehen in `references$outcomes`.

**Ausgabe 12: nb_array()**
```text
, , money

     d0 dX dY
[1,]  0 10  1
[2,]  0  8  2
[3,]  0  6  1
[4,]  0  0  2

, , hours

     d0 dX dY
[1,]  0  2  1
[2,]  0  3  1
[3,]  0  1  1
[4,]  0  0  1

```

`, , money` und `, , hours` sind die zwei getrennten Ebenen des Arrays ([Schritt 7](#step-7)).
In Ziehung 3 unter `dX` stehen 6 Geldeinheiten und 1 Stunde, nicht der Wert 7.

Damit sind alle 16 Funktionen verwendet.
`mcSimulation()` und `multi_EVPI()` laufen hier nicht: Die Ausgabetabelle ist vorgegeben und hat keine unsicheren Eingaben, über die eine partielle Informationsanalyse etwas sagen könnte.

<span id="atacora"></span>
## Von den vier Ziehungen zu einem echten Modell: der Atacora-Screen

`atacora_DA_axes.R` wendet dieselben Funktionen auf das Atacora-Modell an (`atacora_DA_model.R`).
Das Modell vergleicht für die Fonio-Verarbeitung im Atacora, Nordbenin, fünf Optionen: `sq` nichts ändern, `out` Verarbeitungsmaschinen, `up_std` und `up_inc` einen nationalen Fonio-Plan mit zwei Regeln für die Betreibermarge und `deep` eine Ernährungskampagne.
Konten gibt es für den Produzentenhaushalt (G), die Frauen darin (Wg), bezahlte Huller (H), den Maschinenbetreiber (O) und die Kommune (`comm`).
Der Screen liest die 10 000 gespeicherten Ziehungen, die `atacora_DA_run.R` schreibt, hat unter 100 Zeilen und schreibt keine Dateien.
Er gibt keine Empfehlung für Atacora: Jedes Ergebnis gilt unter den Annahmen der Eingabetabelle.

```r
source("atacora_DA_axes.R")
screen$fairness                # which rule prefers which option
screen$designs                 # up_std against up_inc, not against the status quo
screen$references$outcomes     # every group under both reference conditions
screen$floor                   # which options leave no group worse off in any draw
screen$hidden$out              # aggregate gain while a group loses
screen$heterogeneity           # differentiated decisions for household types
```

Das ganze Skript:

```r
# FIVE AXES + FIDELITY. Run from the project root; results are in 'screen'.

# Uses the existing 10,000 draws (seed 20260927); no new simulation or file writes.
source("load.R", local = TRUE)
if (!file.exists("outputs/v9/simulation_results.rds"))
  stop("Run atacora_DA_run.R first (about 25 minutes); it writes outputs/v9/simulation_results.rds.", call. = FALSE)
simulation_results <- readRDS("outputs/v9/simulation_results.rds")
options <- c("sq", "out", "up_std", "up_inc", "deep")
nb <- function(groups, setting = "V1", prefix = "NB")
  nb_from_mc(simulation_results, paste0(prefix, "_{group}_{option}_", setting), groups, options)

# State the case's valuation choices once. K is fixed in the input table.

K <- unique(simulation_results$x$hullers_per_producer_hh)
stopifnot(length(K) == 1L, is.finite(K), K > 0)
p <- c(G = 1, H = K) / (1 + K)
p_women <- c(Wg = 1, H = K) / (1 + K)
status_quo_cash <- median(simulation_results$y$NPV_G_cash_sq)
largest_loss <- -min(unlist(lapply(c("V0", "V1", "PREF"), function(s) nb(c("G", "H"), s))))
offset <- if (largest_loss < status_quo_cash) status_quo_cash else
  ceiling((largest_loss + 1) / 1e5) * 1e5  # FCFA: status quo median, or next 100,000 above the largest loss
rules <- list(utilitarian = w_utilitarian(),
  prioritarian = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)),
  atkinson_0.5 = w_atkinson(0.5, offset), atkinson_1 = w_atkinson(1, offset),
  atkinson_2 = w_atkinson(2, offset), maximin = w_maximin())


# 1. SYSTEM BOUNDARY: totals per producer household; K converts H/person to H/HH.
# Operator O is already per household; it is not treated as another person.
boundary_units <- list(G = c(G = 1), GH = c(G = 1, H = K), GHO = c(G = 1, H = K, O = 1))
boundary <- lapply(c(V0 = "V0", V1 = "V1"), function(s)
  nb_summary(reporting_units(nb(c("G", "H", "O"), s), boundary_units)))

# 2. REFERENCE: both valuations come from the SAME simulated states of the world.
references <- baseline_pair(function(s) nb(c("G", "H"), s),
  references = list(behaviour = "V1", preference = "PREF"), p = p, rules = rules)

# 3. REPORTING UNIT: retain separate accounts alongside the pooled women's mean.
women <- nb(c("Wg", "H"))
units <- nb_summary(c(nb(c("G", "Wg", "H")),
  reporting_units(women, list(women_pooled = p_women))))
hidden <- lapply(options[-1L], function(d)
  marginalisation_count(women, p_women, w_utilitarian(), d_star = d))
names(hidden) <- options[-1L]

# 4. FAIRNESS: compare all options AND the two plan designs explicitly (H2).
people <- nb(c("G", "H"))
fairness <- fairness_screen(people, p, rules)
designs <- fairness_screen(lapply(people, function(x) x[, c("up_std", "up_inc")]), p, rules)
floor_by_group <- nb_summary(nb(c("G", "Wg", "H")))[, c("unit", "option", "p_loss")]
floor <- data.frame(option = options, admissible = vapply(options, function(d)
  all(floor_by_group$p_loss[floor_by_group$option == d] == 0), logical(1)))
# The floor is an admissibility check on EVERY group; no floor ranking or floor EVPI.

# 5. INFORMATION: each actor's own decision, and a common decision for the commune.
information <- lapply(c(V0 = "V0", V1 = "V1", PREF = "PREF"), function(s)
  unique(nb_summary(nb(c("Wg", "H", "G", "comm"), s))[, c("unit", "preferred", "EVPI")]))
# Different decisions are possible for household TYPES, not for household members.
types <- nb(c("self", "hire"), prefix = "NBc")
share_hire <- simulation_results$x$hiring_hh_share
types <- Map(function(x, share) share * x, types, list(1 - share_hire, share_hire))
allowed <- rbind(c("sq", "sq"), c("out", "sq"), c("sq", "out"), c("out", "out"),
  c("up_std", "up_std"), c("up_inc", "up_inc"), c("deep", "deep"))
colnames(allowed) <- c("self", "hire")
# Shares are already in each draw: sum contributions to get FCFA per household.
heterogeneity <- voi_partition(types, p = c(1, 1), W = function(nb, p) sum(nb),
  differentiated = TRUE, profiles = allowed)
heterogeneity_ratio <- voh_index(heterogeneity)

# ACROSS DIRECTIONS: scalar effect fidelity; component-specific delivery needs a rerun.
fidelity <- fidelity_threshold(nb("comm"), p = 1, W = w_utilitarian())
screen <- list(settings = list(seed = 20260927, draws = nrow(simulation_results$y),
  K = K, p = p, atkinson_offset = offset, rules = names(rules)), boundary = boundary,
  references = references, units = units, hidden = hidden, fairness = fairness,
  designs = designs, floor_by_group = floor_by_group, floor = floor,
  information = information, heterogeneity = heterogeneity,
  heterogeneity_ratio = heterogeneity_ratio, fidelity = fidelity)
print(screen$fairness)
```

**Einstellungen.** `K` ist die Zahl der bezahlten Huller je Produzentenhaushalt; sie steht fest in der Eingabetabelle.
`p` gewichtet einen Haushalt und seine `K` Huller wie Personen.
Der Atkinson-Offset ist der Median des Status-quo-Geldes eines Haushalts, außer ein Verlust reicht so weit; dann sind es die nächsten 100 000 FCFA über dem größten Verlust.

**1. Systemgrenze.** Drei Grenzen: nur der Haushalt (G), dazu die Huller (G + K·H) und dazu der Betreiber (G + K·H + O).
`reporting_units()` addiert die Konten mit diesen Koeffizienten.
Die Systemgrenze ist eine Modellentscheidung, keine Funktion: Was in ein Konto eingeht, legen die Gleichungen A11 und A12 im Modell fest.

<!-- eq-money -->
**Gleichung A11 (`eq-money`).** In Worten: Der Nettovorteil eines Produzentenhaushalts ist sein Geld plus die gesparte Arbeitszeit, bewertet mit dem Stundenlohn, plus die zu Hause gegessene Menge, bewertet mit dem Preis.

```math
NB_G = y_G + \omega_W\, w_h\, t_G + \kappa\, p_f\, c_G ,
```

$y_G$ ist das Geld, also Verkauf minus Gebühren plus Marge (`G_cash` im Modell), $t_G$ sind die gesparten Stunden, $w_h$ ist der Stundenlohn (`wage_h`), $c_G$ sind die zu Hause gegessenen Kilogramm und $p_f$ ihr Preis (`p` im Modell).
$\omega_W$ und $\kappa$ sind die Gewichte der Einstellungen V0, V1 und PREF; alle Bestandteile sind schon diskontiert, und `G_time` und `G_kg` enthalten Lohn und Preis bereits.

<!-- eq-boundary -->
**Gleichung A12 (`eq-boundary`).** In Worten: Die Kommune zählt je Produzentenhaushalt den Haushalt, seine K bezahlten Huller und den Betreiber zusammen.

```math
NB_{\text{comm}} = NB_G + K\, NB_H + NB_O ,
```

$NB_H$ gilt je Huller und wird mit $K$ zum Beitrag je Haushalt; der Betreiber $NB_O$ ist schon je Haushalt gerechnet.
`boundary_units$GHO` im Screen ist genau diese Summe; Wg steckt in G und wird nicht noch einmal addiert.

**2. Referenz.** `baseline_pair()` vergleicht die Verhaltensreferenz (V1) mit der Präferenzreferenz (PREF).
Beide kommen aus denselben Ziehungen; sie unterscheiden sich darin, wie die freigewordene Zeit bewertet wird.

**3. Berichtseinheit.** Die Frauen in Produzentenhaushalten (Wg) und die Huller (H) werden einmal getrennt und einmal gepoolt als `women_pooled` berichtet.
`marginalisation_count()` sucht für jede Option nach verdeckten Verlusten in der gepoolten Zahl.

**4. Regel.** Sechs Regeln für alle Optionen und eigens für die zwei Varianten des Plans.
Die Mindestgrenze ist hier eine Zulässigkeitsprüfung: Zulässig ist eine Option, wenn keine Gruppe in irgendeiner Ziehung verliert.

**5. Informationswert.** Der EVPI steht je Akteur (Wg, H, G, Kommune) unter V0, V1 und PREF.
Getrennte Entscheidungen gibt es nur für Haushaltstypen (`self`, `hire`), nicht für Mitglieder eines Haushalts; die erlaubten Profile stehen in `allowed`.
Die Beiträge der Typen sind schon mit ihrem Anteil je Ziehung gewichtet; die Summenregel berichtet deshalb FCFA je Produzentenhaushalt.

**Über alle Richtungen: Umsetzungstreue.** `fidelity_threshold()` skaliert die ganze Nettowirkung jeder Option für die Kommune.
Bestandteile einer Maßnahme getrennt zu variieren braucht einen neuen Modelllauf.
