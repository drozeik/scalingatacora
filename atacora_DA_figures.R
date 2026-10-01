#  ------------------------------------------------------------------------
#  VISUALISATION - Atacora case model v9
#  Built like "VISUALISATION FOR THE PRESENTATION" of the walnut template (walnut_DA_model_v6_final.R):
#  one palette and one theme baked into every figure, flying bars for every distribution,
#  plot_distributions(), plot_evpi() and plot_pls() of decisionSupport where the template uses them,
#  panels composed with patchwork.
#  Reads simulation_results (or outputs/v9/simulation_results.rds) and outputs/v9/axes_results.rds.
#  Writes outputs/v9/figures/: F1_core_en, F1_core_de, F2_shifts (one panel per test, handoff v9 section 9)
#  and supplement/S1-S9, each as SVG with editable text and as PNG at 300 dpi, 180 mm wide, base size 9 pt.
#  ------------------------------------------------------------------------
library(ggplot2); library(patchwork); library(decisionSupport)
if (!exists("simulation_results")) simulation_results <- readRDS("outputs/v9/simulation_results.rds")
res <- readRDS("outputs/v9/axes_results.rds")
FIG <- "outputs/v9/figures"; SUP <- file.path(FIG, "supplement")
dir.create(SUP, recursive = TRUE, showWarnings = FALSE)
OPTIONS <- c("sq", "out", "up_std", "up_inc", "deep")
Y <- simulation_results$y



# ============================ ONE PALETTE, ONE THEME ==========================
# Directions as in the template's option colours: status quo warm grey (the template's "Baseline"),
# out petrol, up navy (the inclusive rule lighter), deep an ochre that stands apart from both.
PAL <- c(sq = "#B7A99A", out = "#2FA79B", up_std = "#12324A", up_inc = "#7C96B3", deep = "#C8962E")
LAB <- c(sq = "status quo", out = "out: equipment", up_std = "up: plan, standard rule",
         up_inc = "up: plan, inclusive rule", deep = "deep: awareness")
POS <- "#2FA79B"; NEG <- "#C0504D"                                                  # better / worse than the status quo
INK <- "#12324A"; GRID <- "grey88"
STATUS_COL <- c(L = "#2E7D46", W = "#7B5493", T = "#D2691E", B = "#2B62A0", P = "#8D99A5", id = "#333333")

theme_v8 <- theme_minimal(base_size = 9) +
  theme(
    plot.title       = element_text(face = "bold", size = 10, colour = INK, margin = margin(b = 2)),
    plot.subtitle    = element_text(size = 7.5, colour = "grey35", margin = margin(b = 6)),
    axis.title       = element_text(size = 8, colour = INK),
    axis.text        = element_text(size = 7.5, colour = "grey20"),
    legend.title     = element_text(size = 7.5, face = "bold", colour = INK),
    legend.text      = element_text(size = 7.5),
    legend.position  = "bottom",
    strip.text       = element_text(size = 8, face = "bold", colour = INK),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
    plot.margin      = margin(6, 8, 6, 6)
  )
theme_set(theme_v8)

k_fcfa <- function(x) format(round(x / 1000, 1), big.mark = ",", trim = TRUE)       # axis labels in 1000 FCFA

save_fig <- function(p, file, height, width = 180){                                 # SVG with editable text + PNG 300 dpi
  ggsave(paste0(file, ".svg"), p, width = width, height = height, units = "mm",
         device = function(filename, ...) svglite::svglite(filename, ..., fix_text_size = FALSE))
  ggsave(paste0(file, ".png"), p, width = width, height = height, units = "mm", dpi = 300, bg = "white")
}

# flying bars of the template: whisker 1-99 % with end caps, box 10-90 %, white median, diamond = mean
fb_stats <- function(v, row, fill){
  q <- unname(quantile(v, c(.01, .10, .50, .90, .99)))
  data.frame(row = row, fill = fill, p01 = q[1], p10 = q[2], p50 = q[3], mean = mean(v),
             p90 = q[4], p99 = q[5], p_pos = mean(v > 0))
}
flying_bars <- function(d, fill_values, xlab, title = NULL, subtitle = NULL, cap = 0.16, h = 0.30){
  d$y <- rev(seq_len(nrow(d)))                                                      # first row on top
  ggplot(d) +
    geom_vline(xintercept = 0, colour = "grey55", linewidth = .4) +
    geom_segment(aes(x = p01, xend = p99, y = y, yend = y), colour = "grey45", linewidth = .45) +
    geom_segment(aes(x = p01, xend = p01, y = y - cap, yend = y + cap), colour = "grey45", linewidth = .45) +
    geom_segment(aes(x = p99, xend = p99, y = y - cap, yend = y + cap), colour = "grey45", linewidth = .45) +
    geom_rect(aes(xmin = p10, xmax = p90, ymin = y - h, ymax = y + h, fill = fill), colour = INK, linewidth = .3, alpha = .92) +
    geom_segment(aes(x = p50, xend = p50, y = y - h, yend = y + h), colour = "white", linewidth = .8) +
    geom_point(aes(x = mean, y = y), shape = 23, size = 2.2, fill = "white", colour = INK, stroke = .7) +
    geom_text(aes(x = max(p99) + 0.04 * diff(range(c(p01, p99))), y = y, label = sprintf("%.0f %% > 0", 100 * p_pos)),
              hjust = 0, size = 2.4, colour = "grey25") +
    scale_fill_manual(values = fill_values, guide = "none") +
    scale_x_continuous(labels = k_fcfa, expand = expansion(mult = c(.04, .25))) +
    scale_y_continuous(breaks = d$y, labels = d$row, expand = expansion(add = .5)) +
    labs(x = xlab, y = NULL, title = title, subtitle = subtitle) +
    theme(panel.grid.major.y = element_blank())
}
FB_NOTE <- "Box 10-90 %, whisker 1-99 %, white line median, diamond mean."



# ============================ F1 - THE CORE (structure, no numbers) ===========
# Visual language of the project's impact-pathway diagrams: coloured lanes for out, up and deep
# on the left, the shared core in the middle, the accounts with the two household types and the hullers on
# the right; the reference band on top; edges with code and sign, coloured by the status of their size.
# Circled numbers mark where each axis acts; F marks the delivery edges (fidelity).
f1_text <- list(
  en = list(title = "Atacora model v9 · the thin core",
            subtitle = "Edge = code and sign · colour = where the size of the edge comes from · no numbers",
            ref = "② Reference: what a change is measured against",
            ref_b = "behaviour (V1): unpaid work at replacement cost; hullers' own fallback, at most their wage",
            ref_p = "preference (PREF): every freed hour at the value of an hour of off-farm work",
            ref_a = "perception-informed: locally stated aims -- more fonio eaten, less drudgery, a future outside farming, higher income (workshop; Mausch; Ballogou)",
            ref_h = "historical (greyed out): share of the grain eaten at home in the 2011 survey (Ballogou et al. 2014)",
            aims = c(H = "\u25c6 aims: less drudgery · future off-farm · income", Wg = "\u25c6 aims: less drudgery · future off-farm",
                     G = "\u25c6 aims: more fonio eaten · income"),
            lanes = c(out = "out · processing equipment", up = "up · national fonio plan", deep = "deep · public awareness"),
            core = "Shared core · one producer household of the commune",
            acc = c("③ Accounts", "per person · per household · commune"),
            obj = c("Workshop objectives:", "income · nutrition · processing · social inclusion"),
            notm = "not modelled: equity (prices) · ecology",
            frame = "① system boundary: whose accounts, which objectives",
            legend = c(L = "L literature", W = "W workshop / Dataverse", T = "T transferred", B = "B ask BOLDER",
                       P = "P prior, set by us", id = "accounting identity"),
            nodes = c(out = "Machines installed\n(capacity)", up = "Plan after a lag:\nmachines co-financed;\nrule names the operator",
                      deep = "Households reached,\neffect decays", Q = "Paddy per\nhousehold", m = "Machine share\nof the paddy",
                      hand = "Hand hulling\nunpaid | paid", grain = "Hulled grain", use = "Eaten at home\n| sold",
                      money = "Money: sales, fees,\nwages, margin", hours = "Hours of\nhand hulling",
                      G = "Producer household G\ntype self | type hire", Wg = "Its women Wg\n(hulling time)",
                      H = "Paid hullers H", O = "Operator O\n(out only)",
                      rules = "④ Rules over persons: utilitarian · prioritarian\n· Atkinson · maximin; the floor constrains",
                      voi = "⑤ Value of information: EVPI per account\nand over household types (value of heterogeneity)"),
            fid = "F = delivery edge (fidelity)"),
  de = list(title = "Atacora-Modell v9 · der dünne Kern",
            subtitle = "Kante = Code und Vorzeichen · Farbe = woher die Größe der Kante kommt · keine Zahlen",
            ref = "② Referenz: woran eine Veränderung gemessen wird",
            ref_b = "Verhalten (V1): unbezahlte Arbeit zu Ersatzkosten; Lohnschälerinnen: ihr Ausweichen, höchstens ihr Lohn",
            ref_p = "Präferenz (PREF): jede frei werdende Stunde zum Stundenwert einer Arbeit außerhalb der Landwirtschaft",
            ref_a = "wahrnehmungsinformiert: lokal genannte Ziele -- mehr Fonio essen, weniger Mühsal, Zukunft außerhalb der Landwirtschaft, mehr Einkommen (Workshop; Mausch; Ballogou)",
            ref_h = "historisch (ausgegraut): Anteil des Korns, der im Haushalt gegessen wird, Erhebung 2011 (Ballogou et al. 2014)",
            aims = c(H = "\u25c6 Ziele: weniger Mühsal · Zukunft außerhalb · Einkommen", Wg = "\u25c6 Ziele: weniger Mühsal · Zukunft außerhalb",
                     G = "\u25c6 Ziele: mehr Fonio essen · Einkommen"),
            lanes = c(out = "out · Schälmaschinen", up = "up · nationaler Fonio-Plan", deep = "deep · Öffentlichkeitsarbeit"),
            core = "Gemeinsamer Kern · ein Erzeugerhaushalt der Kommune",
            acc = c("③ Konten", "je Person · je Haushalt · Kommune"),
            obj = c("Workshopziele:", "Einkommen · Ernährung · Verarbeitung · Teilhabe"),
            notm = "nicht modelliert: Gerechtigkeit (Preise) · Ökologie",
            frame = "① Systemgrenze: wessen Konten, welche Ziele",
            legend = c(L = "L Literatur", W = "W Workshop / Dataverse", T = "T übertragen", B = "B bei BOLDER anfragen",
                       P = "P Prior, von uns gesetzt", id = "Buchungsidentität"),
            nodes = c(out = "Maschinen installiert\n(Kapazität)", up = "Plan nach Verzögerung:\nMaschinen mitfinanziert;\nRegel nennt Betreiber",
                      deep = "Haushalte erreicht,\nWirkung klingt ab", Q = "Paddy je\nHaushalt", m = "Maschinenanteil\nam Paddy",
                      hand = "Handschälen\nunbezahlt | bezahlt", grain = "Geschältes Korn", use = "Im Haushalt gegessen\n| verkauft",
                      money = "Geld: Verkauf, Gebühren,\nLöhne, Marge", hours = "Stunden\nHandschälen",
                      G = "Erzeugerhaushalt G\nTyp self | Typ hire", Wg = "Seine Frauen Wg\n(Schälzeit)",
                      H = "Lohnschälerinnen H", O = "Betreiber O\n(nur out)",
                      rules = "④ Regeln über Personen: utilitaristisch · prioritär\n· Atkinson · Maximin; die Untergrenze schränkt ein",
                      voi = "⑤ Informationswert: EVPI je Konto\nund über Haushaltstypen (Wert der Heterogenität)"),
            fid = "F = Lieferkante (Fidelity)")
)

draw_F1 <- function(lang){
  tx <- f1_text[[lang]]
  lane_fill <- c(out = "#E3F3F1", up = "#E3E8EF", deep = "#F7EEDD")
  lane_line <- c(out = "#8FCFC7", up = "#9AAAC0", deep = "#E0C48F")
  nodes <- data.frame(                                                              # 14 nodes + the rules and the information box = 16, mm
    id = c("out", "up", "deep", "Q", "m", "grain", "hand", "hours", "use", "money", "H", "Wg", "G", "O"),
    x  = c(25, 25, 25, 66, 104, 66, 104, 104, 66, 96, 151, 151, 151, 151),
    y  = c(82, 54, 27, 91, 84, 60, 70, 56, 48, 30, 84, 70, 52, 38),
    w  = c(32, 34, 32, 20, 24, 18, 26, 22, 26, 32, 38, 38, 38, 38),
    h  = c(9, 12, 9, 7, 8, 7, 8, 8, 8, 8, 7, 8, 9, 8))
  nodes$fill <- ifelse(nodes$id %in% c("H", "Wg", "G"), "#F3E9E4", ifelse(nodes$id == "O", "#EEEEEE", "white"))
  nodes$label <- tx$nodes[nodes$id]
  edges <- data.frame(                                                              # explicit routes: start, end, code, status, fidelity mark
    x0 = c(41, 42, 42, 41, 76, 104, 92, 104, 117, 66, 79, 79, 112, 112, 112, 115, 115),
    y0 = c(82, 57, 48, 29.5, 90, 80, 81, 66, 70, 56.5, 46, 49, 32, 30, 33.5, 57, 58.5),
    x1 = c(92, 92, 80, 53, 92, 104, 75, 104, 112, 66, 84, 132, 132, 132, 132, 132, 132),
    y1 = c(83.5, 81, 31, 45, 86, 74, 62.5, 60, 34, 52, 34, 51.5, 48.5, 37, 81, 68, 82),
    code = c("O1 +  O2 −", "U1  U2 +", "U3", "D1 +  D2 +", "Q1", "P1 −", "P3 ±", "L1 L2",
             "M2 M3 M4", "S1", "M1 +", "S1 + (κ)", "", "", "", "L1 +", "L2 +"),
    lx = c(58, 51, 60, 45, 84, 108.5, 85, 108.5, 119.5, 70, 85.5, 90, NA, NA, NA, 127, 124.5),
    ly = c(85.5, 61.6, 39.8, 34.5, 90.5, 77, 73.5, 63, 43, 54.3, 40.5, 49.3, NA, NA, NA, 64.5, 74.5),
    status = c("P", "T", "P", "T", "P", "id", "L", "L", "B", "P", "W", "P", "id", "id", "id", "L", "L"),
    fid = c(TRUE, TRUE, FALSE, TRUE, rep(FALSE, 13)),
    curv = c(0, 0, 0, 0, 0, 0, 0, 0, -0.3, 0, 0, 0, 0, 0, 0, 0, 0))
  fid_xy <- data.frame(x = c(50, 45, 44.5), y = c(80.2, 56.2, 38))                   # where the F marks sit on the delivery edges
  arrow_ <- arrow(length = unit(1.4, "mm"), type = "closed")
  ggplot() +
    # reference band (axis 2)
    annotate("rect", xmin = 3, xmax = 177, ymin = 102, ymax = 124.5, fill = "#FBF6E3", colour = "#D9C98A", linewidth = .4) +
    annotate("text", x = 6, y = 121.4, label = tx$ref, hjust = 0, fontface = "bold", size = 2.8, colour = INK) +
    annotate("text", x = 6, y = 117.4, label = paste("\u25cf", tx$ref_b), hjust = 0, size = 2.35, colour = "grey20") +
    annotate("text", x = 6, y = 113.7, label = paste("\u25cb", tx$ref_p), hjust = 0, size = 2.35, colour = "grey20") +
    annotate("text", x = 6, y = 110.0, label = paste("\u25c6", tx$ref_a), hjust = 0, size = 2.35, colour = "#9A6E1E") +
    annotate("text", x = 6, y = 106.0, label = paste("##", tx$ref_h), hjust = 0, size = 2.2, colour = "grey60", fontface = "italic") +
    # lanes of the three directions
    annotate("rect", xmin = 3, xmax = 48, ymin = c(72, 42, 14), ymax = c(99, 70, 40),
             fill = lane_fill, colour = lane_line, linewidth = .4) +
    annotate("text", x = 5, y = c(96.6, 67.6, 37.6), label = tx$lanes, hjust = 0, fontface = "bold", size = 2.5,
             colour = c(PAL[["out"]], PAL[["up_std"]], "#9A6E1E")) +
    # the shared core
    annotate("rect", xmin = 51, xmax = 122, ymin = 14, ymax = 99, fill = "#F2F3F5", colour = "#B8C1CB", linewidth = .4) +
    annotate("text", x = 53, y = 96.6, label = tx$core, hjust = 0, fontface = "bold", size = 2.4, colour = "grey30") +
    # accounts (axis 3) inside the system boundary (axis 1), with the workshop objectives
    annotate("rect", xmin = 125, xmax = 177, ymin = 16, ymax = 99, fill = NA, colour = INK, linewidth = .5, linetype = "22") +
    annotate("text", x = 127, y = 96.4, label = tx$acc[1], hjust = 0, fontface = "bold", size = 2.5, colour = INK) +
    annotate("text", x = 127, y = 92.8, label = tx$acc[2], hjust = 0, size = 2.2, colour = INK) +
    annotate("text", x = 151, y = c(29.5, 26.2), label = tx$obj, size = 2.05, colour = "grey15") +
    annotate("text", x = 151, y = 22.4, label = tx$notm, size = 2.05, colour = "grey45", fontface = "italic") +
    annotate("text", x = 151, y = 18.2, label = tx$frame, size = 1.95, colour = INK, fontface = "italic") +
    # edges, coloured by where their size comes from
    lapply(which(edges$curv != 0), function(i)                                      # geom_curve() takes one curvature per layer
      geom_curve(data = edges[i, ], aes(x = x0, y = y0, xend = x1, yend = y1, colour = status),
                 curvature = edges$curv[i], linewidth = .5, arrow = arrow_)) +
    geom_segment(data = edges[edges$curv == 0, ], aes(x = x0, y = y0, xend = x1, yend = y1, colour = status),
                 linewidth = .5, arrow = arrow_) +
    geom_label(data = edges[nzchar(edges$code), ], aes(x = lx, y = ly, label = code, colour = status),
               size = 2.05, linewidth = 0, fill = "white", label.padding = unit(0.5, "mm"), show.legend = FALSE) +
    geom_label(data = fid_xy, aes(x = x, y = y), label = "F", size = 2.1, fontface = "bold",
               colour = "white", fill = NEG, linewidth = 0, label.padding = unit(0.45, "mm")) +
    # nodes
    geom_tile(data = nodes, aes(x = x, y = y, width = w, height = h), fill = nodes$fill, colour = "grey30", linewidth = .35) +
    geom_text(data = nodes, aes(x = x, y = y, label = label), size = 2.25, lineheight = .9, colour = "grey10") +
    annotate("text", x = 151, y = c(78.9, 64.5, 46.0), label = tx$aims[c("H", "Wg", "G")], size = 1.75, colour = "#9A6E1E") +
    # rules (axis 4) below the accounts, value of information (axis 5) below the core
    annotate("segment", x = 151, xend = 151, y = 16, yend = 11, colour = INK, linewidth = .4, arrow = arrow_) +
    annotate("label", x = 151, y = 7.6, label = tx$nodes[["rules"]], size = 2.05, linewidth = .3, fill = "white",
             colour = INK, label.padding = unit(0.9, "mm"), lineheight = .9) +
    annotate("label", x = 86.5, y = 7, label = tx$nodes[["voi"]], size = 2.1, linewidth = .3, fill = "white",
             colour = INK, label.padding = unit(0.9, "mm"), lineheight = .9) +
    annotate("text", x = 4, y = 7, label = tx$fid, hjust = 0, size = 2.1, colour = NEG, fontface = "bold") +
    scale_colour_manual(values = STATUS_COL, breaks = names(tx$legend), labels = tx$legend, name = NULL, drop = FALSE) +
    coord_fixed(xlim = c(0, 180), ylim = c(1, 126), expand = FALSE) +
    labs(title = tx$title, subtitle = tx$subtitle) +
    theme_void(base_size = 9) +
    theme(plot.title = element_text(face = "bold", size = 10, colour = INK, margin = margin(b = 2)),
          plot.subtitle = element_text(size = 7.5, colour = "grey35", margin = margin(b = 2)),
          legend.position = "bottom", legend.text = element_text(size = 7), legend.key.width = unit(6, "mm"),
          plot.background = element_rect(fill = "white", colour = NA), plot.margin = margin(6, 6, 6, 6)) +
    guides(colour = guide_legend(nrow = 2, override.aes = list(linewidth = 1)))
}
for (lang in c("en", "de")) save_fig(draw_F1(lang), file.path(FIG, paste0("F1_core_", lang)), height = 151)



# ============================ F2 - ONE PANEL PER TEST (3 x 2) =================
# One flat patchwork (no nested layouts, so that the legend and the axis labels keep their room): (a) T1, (b) H3
# with its money strip, (c) T3/T2, (d) H2 with the floor strip, (e) T5, (f) T6.

# (a) T1a/T1b: how women's hulling time is valued -- expected value of the producer household per option
lines_G <- res$T1$lines_G                                                           # a = E[cash + kg] (kappa = 1), b = E[time value]
omega <- seq(0, 3, by = 0.01)
d_a <- do.call(rbind, lapply(OPTIONS, function(o) data.frame(option = o, omega = omega,
                                                            value = lines_G$a1[[o]] + omega * lines_G$b[[o]])))
best_a <- tapply(seq_len(nrow(d_a)), d_a$omega, function(i) d_a$option[i][which.max(d_a$value[i])])
sw_a <- which(best_a[-1] != best_a[-length(best_a)])
sw_pts <- data.frame(omega = omega[sw_a + 1], option = best_a[sw_a + 1])
sw_pts$value <- lines_G$a1[sw_pts$option] + sw_pts$omega * lines_G$b[sw_pts$option]
wq <- res$T1$w_off_quantiles
y_top <- max(d_a$value); y_bot <- min(d_a$value)
p_a <- ggplot(d_a, aes(omega, value, colour = option)) +
  annotate("rect", xmin = min(wq[[1]], 3), xmax = min(wq[[3]], 3), ymin = -Inf, ymax = Inf, fill = "#FBF6E3") +
  annotate("text", x = 2.95, y = y_bot, label = sprintf("preference: off-farm value\n/ wage, 5-95 %% (to %.1f)", wq[[3]]),
           hjust = 1, vjust = 0, size = 2.1, colour = "grey35", lineheight = .9) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = .4) +
  geom_vline(xintercept = c(0, 1), colour = INK, linewidth = .35, linetype = "22") +
  annotate("text", x = c(0.05, 1.05), y = y_top, label = c("hours unvalued", "replacement cost"),
           angle = 90, hjust = 1, vjust = 1, size = 2.1, colour = INK) +
  geom_line(linewidth = .8) +
  geom_point(data = sw_pts, size = 1.8, colour = INK) +
  geom_label(data = sw_pts, aes(label = sprintf("ω* = %.2f", omega)), colour = INK, size = 2.1,
             vjust = -0.5, linewidth = 0, fill = "white", label.padding = unit(0.4, "mm")) +
  scale_colour_manual(values = PAL, breaks = OPTIONS, labels = LAB, name = NULL) +
  scale_y_continuous(labels = k_fcfa) +
  labs(title = "(a) Valuing women's hulling time (T1)",
       subtitle = "Producer household; kg eaten at market price (κ = 1)",
       x = "ω: saved hour, multiples of the hulling wage",
       y = "Expected value vs status quo (1000 FCFA)") +
  guides(colour = guide_legend(nrow = 1)) +
  theme(legend.text = element_text(size = 7), legend.key.width = unit(5, "mm"))

# (b) H3: progress towards the aims people stated -- one row per aim and account, one dot per option (mean) with
#     its 10-90 % line; left of 0 further away, right of 0 closer. Next to it the same options in money (V0, V1).
aims_b <- res$T1$aims
ROWS_B <- c("more fonio eaten|G" = "more eaten · household", "less drudgery|Wg" = "less drudgery · women",
            "less drudgery|H" = "less drudgery · hullers", "a future outside farming|Wg" = "off-farm future · women",
            "a future outside farming|H" = "off-farm future · hullers", "higher income|G" = "income · household",
            "higher income|H" = "income · hullers")
DODGE <- c(out = .27, up_std = .09, up_inc = -.09, deep = -.27)
aims_b$key <- paste(aims_b$aim, aims_b$account, sep = "|")
d_b <- aims_b[aims_b$option != "sq" & aims_b$key %in% names(ROWS_B), ]
d_b$y <- (length(ROWS_B) + 1 - match(d_b$key, names(ROWS_B))) + DODGE[d_b$option]
p_b1 <- ggplot(d_b) +
  geom_vline(xintercept = 0, colour = "grey45", linewidth = .4) +
  geom_segment(aes(x = q10, xend = q90, y = y, yend = y, colour = option), linewidth = .5, alpha = .8) +
  geom_point(aes(x = mean, y = y, colour = option), size = 1.6) +
  annotate("text", x = c(-0.006, 0.006), y = length(ROWS_B) + .8, label = c("← further", "closer →"),
           hjust = c(1, 0), size = 2.1, colour = "grey30") +
  scale_colour_manual(values = PAL, guide = "none") +
  scale_x_continuous(trans = scales::pseudo_log_trans(sigma = 0.002, base = 10), breaks = c(-1, -0.1, -0.01, 0, 0.01, 0.1, 1),
                     labels = c("-100 %", "", "-1 %", "", "1 %", "", "100 %")) +
  scale_y_continuous(breaks = seq_along(ROWS_B), labels = rev(unname(ROWS_B)), expand = expansion(add = c(.5, 1))) +
  labs(title = "(b) Closer to the stated aims? (H3)",
       subtitle = "Share of today's level; line 10-90 %, dot mean.\nDrudgery, off-farm future: the same hours here",
       x = "Progress (signed log)", y = NULL) +
  theme(panel.grid.major.y = element_blank())
ROWS_B2 <- c("G · V0", "G · V1", "Wg · V1", "H · V0", "H · V1")
d_b2 <- do.call(rbind, lapply(ROWS_B2, function(r){ z <- strsplit(r, " · ")[[1]]
  data.frame(row = r, option = setdiff(OPTIONS, "sq"),
             value = sapply(setdiff(OPTIONS, "sq"), function(o) mean(Y[[sprintf("NB_%s_%s_%s", z[1], o, z[2])]])))}))
d_b2$y <- (length(ROWS_B2) + 1 - match(d_b2$row, ROWS_B2)) + DODGE[d_b2$option]
p_b2 <- ggplot(d_b2, aes(value, y, colour = option)) +
  geom_vline(xintercept = 0, colour = "grey45", linewidth = .4) +
  geom_point(size = 1.4) +
  scale_colour_manual(values = PAL, guide = "none") +
  scale_x_continuous(trans = scales::pseudo_log_trans(sigma = 50, base = 10), breaks = c(-1e4, 0, 1e4), labels = c("-10", "0", "10")) +
  scale_y_continuous(breaks = seq_along(ROWS_B2), labels = rev(ROWS_B2), expand = expansion(add = c(.5, 1))) +
  labs(x = "money,\n1000 FCFA", y = NULL) +
  theme(panel.grid.major.y = element_blank())

# (c) T3 and T2: women against women -- growers' women and paid hullers under out, both references
yy_c <- list(c("NB_Wg_out_V1", "women (Wg) · behaviour"), c("NB_Wg_out_PREF", "women (Wg) · preference"),
             c("NB_H_out_V1", "hullers (H) · behaviour"), c("NB_H_out_PREF", "hullers (H) · preference"))
d_c <- do.call(rbind, lapply(yy_c, function(z) fb_stats(Y[[z[1]]], z[2], ifelse(mean(Y[[z[1]]]) > 0, "pos", "neg"))))
p_c <- flying_bars(d_c, c(pos = POS, neg = NEG),
                   xlab = "Value per person vs status quo (1000 FCFA)",
                   title = "(c) Women against women, out (T3, T2)",
                   subtitle = "Box 10-90 %, whisker 1-99 %, diamond = mean") +
  scale_x_continuous(labels = k_fcfa, expand = expansion(mult = c(.04, .42)))

# (d) H2: the plan's two rule designs -- which design each measure puts ahead (value up_std | up_inc on the right);
#     next to it: who remains below the floor under each design
dsg <- res$T4$designs; fl <- res$T4$floor; adm <- res$T4$admissible
MEAS_D <- c("reach" = "reach", "compliance" = "compliance", "addressees' account" = "addressees",
            "utilitarian" = "utilitarian", "prioritarian" = "prioritarian", "atkinson_1" = "Atkinson ε 1",
            "maximin" = "maximin Δ", "maximin on levels" = "maximin level")
d_d <- dsg[match(names(MEAS_D), dsg$measure), c("measure", "value_up_std", "value_up_inc", "ranking")]
d_d$x <- c("std > inc" = -1, "equal" = 0, "inc > std" = 1)[d_d$ranking]
d_d$who <- c("std > inc" = "up_std", "equal" = "equal", "inc > std" = "up_inc")[d_d$ranking]
d_d$lab <- ifelse(d_d$measure %in% c("reach", "compliance"), sprintf("%.2f | %.2f", d_d$value_up_std, d_d$value_up_inc),
                  sprintf("%s | %s", k_fcfa(d_d$value_up_std), k_fcfa(d_d$value_up_inc)))
d_d$y <- rev(seq_len(nrow(d_d))) + 1
floor_row <- data.frame(y = 1, x = 0, lab = if (all(!adm$alpha_0)) "both out" else "differs")
p_d1 <- ggplot(d_d, aes(x, y)) +
  annotate("rect", xmin = -1.5, xmax = 1.5, ymin = .5, ymax = 1.5, fill = "grey95") +
  geom_vline(xintercept = c(-.5, .5), colour = "grey85", linewidth = .3) +
  geom_point(aes(colour = who), size = 2.4) +
  geom_text(aes(x = 1.7, label = lab), hjust = 0, size = 1.9, colour = "grey25") +
  annotate("text", x = c(-1, 0, 1, 1.7), y = max(d_d$y) + .9, label = c("std", "=", "inc", "std | inc"),
           hjust = c(.5, .5, .5, 0), size = 1.9, colour = "grey25", fontface = "bold") +
  geom_point(data = floor_row, shape = 4, size = 2.4, stroke = .9, colour = NEG) +
  geom_text(data = floor_row, aes(x = 1.7, label = lab), hjust = 0, size = 1.9, colour = NEG) +
  scale_colour_manual(values = c(up_std = PAL[["up_std"]], up_inc = PAL[["up_inc"]], equal = "grey55"), guide = "none") +
  scale_x_continuous(limits = c(-1.5, 4.4), breaks = NULL) +
  scale_y_continuous(breaks = c(d_d$y, 1), labels = c(unname(MEAS_D), "strict floor"), expand = expansion(add = c(.4, 1.3))) +
  labs(title = "(d) The plan's two rule designs (H2, T4)", subtitle = "Dot: the design each measure puts ahead (= tie).\nstd | inc: 1000 FCFA per person (V1);\nreach and compliance as shares",
       x = NULL, y = NULL) +
  theme(panel.grid.major = element_blank())
d_d2 <- fl[fl$option %in% c("up_std", "up_inc") & fl$group %in% c("G", "H"), ]
d_d2$grp <- factor(c(G = "household", H = "hullers")[d_d2$group], levels = c("hullers", "household"))
lab_d2 <- do.call(rbind, lapply(split(d_d2, d_d2$grp), function(z)
  data.frame(grp = z$grp[1], lab = sprintf("std %.0f | inc %.0f", 100 * z$p_below[z$option == "up_std"], 100 * z$p_below[z$option == "up_inc"]))))
p_d2 <- ggplot(d_d2, aes(p_below, grp)) +
  geom_vline(xintercept = res$settings$FLOOR_ALPHA, colour = NEG, linetype = "22", linewidth = .35) +
  geom_line(aes(group = grp), colour = "grey70", linewidth = .6) +
  geom_point(aes(colour = option), size = 2.2) +
  geom_text(data = lab_d2, aes(x = .5, label = lab), vjust = -1.3, size = 1.8, colour = "grey25") +
  annotate("text", x = res$settings$FLOOR_ALPHA, y = .45, label = "α", hjust = -0.5, size = 2.1, colour = NEG) +
  scale_colour_manual(values = PAL[c("up_std", "up_inc")], guide = "none") +
  scale_x_continuous(limits = c(0, 1), breaks = c(0, .5, 1), labels = c("0", "50", "100")) +
  scale_y_discrete(expand = expansion(add = c(.6, 1))) +
  labs(x = "below the floor,\n% of draws", y = NULL)

# (e) T5: value of heterogeneity over the household types, drawn like Espinoza et al. (2014, Fig. 2), one facet
#     per restriction
het <- res$T5$heterogeneity
PROF_E <- c(restricted = "only out targetable", unrestricted = "all targetable")
hv_e <- function(k) setNames(het$value[het$profiles == k], het$quantity[het$profiles == k])
d_e <- do.call(rbind, lapply(names(PROF_E), function(k){ v <- hv_e(k)
  data.frame(prof = PROF_E[[k]], x = c(1, 1, 2, 2), value = v[c("A", "C", "B", "D")], lab = c("A", "C", "B", "D"),
             info = c("today", "perfect", "today", "perfect")) }))
a_e <- do.call(rbind, lapply(names(PROF_E), function(k){ v <- hv_e(k)
  data.frame(prof = PROF_E[[k]], A = v[["A"]], B = v[["B"]], C = v[["C"]], D = v[["D"]], s = v[["VoH_static"]], dy = v[["VoH_dyn"]]) }))
d_e$prof <- factor(d_e$prof, levels = PROF_E); a_e$prof <- factor(a_e$prof, levels = PROF_E)
p_e <- ggplot(d_e, aes(x, value)) +
  geom_segment(data = a_e, aes(x = .78, xend = .78, y = A, yend = C), colour = INK, linewidth = .4) +
  geom_text(data = a_e, aes(x = .72, y = (A + C) / 2), label = "EVPI", hjust = 1, size = 1.9, colour = INK) +
  geom_segment(data = a_e, aes(x = 2.22, xend = 2.22, y = B, yend = D), colour = INK, linewidth = .4) +
  geom_text(data = a_e, aes(x = 2.27, y = (B + D) / 2), label = "EVPI\nper\ntype", hjust = 0, size = 1.9, colour = INK, lineheight = .85) +
  geom_segment(data = a_e, aes(x = 1, xend = 2, y = A, yend = B), colour = POS, linewidth = .5, linetype = "22") +
  geom_text(data = a_e, aes(x = 1.55, y = (A + B) / 2, label = sprintf("static\nVoH %.1f", s / 1000)),
            hjust = 0, vjust = 1, size = 1.9, colour = POS, lineheight = .85) +
  geom_segment(data = a_e, aes(x = 1, xend = 2, y = C, yend = D), colour = NEG, linewidth = .5, linetype = "22") +
  geom_text(data = a_e, aes(x = 1.5, y = pmax(C, D), label = sprintf("dynamic VoH %.1f", dy / 1000)),
            vjust = -0.9, size = 1.9, colour = NEG) +
  geom_point(aes(shape = info), size = 2, colour = INK, stroke = .7) +
  geom_text(aes(label = lab), hjust = -0.9, size = 2, colour = INK) +
  facet_wrap(~ prof, nrow = 1) +
  scale_shape_manual(values = c(today = 1, perfect = 16), guide = "none") +
  scale_x_continuous(limits = c(0.25, 2.8), breaks = 1:2, labels = c("one", "type")) +
  scale_y_continuous(labels = k_fcfa, expand = expansion(mult = c(.05, .18))) +
  labs(title = "(e) Heterogeneity over household types (T5)",
       subtitle = sprintf("Commune; open = today's information, filled = perfect.\nPlanner: %s", het$planner_profile[het$profiles == "restricted"][1]),
       x = "decision: one for all | per household type", y = "1000 FCFA per producer household") +
  theme(strip.text = element_text(size = 7, face = "plain"))

# (f) T6: the hullers under up_inc for the four compositions, and at the rule's threshold e* (machines delivered)
comp_T6 <- res$T6$compositions; es <- res$T6$e_star
d_f <- rbind(do.call(rbind, lapply(seq_len(nrow(comp_T6)), function(i)
  fb_stats(res$T6$draws[[i]]$NB_H_up_inc_V1, sprintf("%.2f · %.2f", comp_T6$reach[i], comp_T6$rule[i]),
           ifelse(comp_T6$reach[i] == 1 & comp_T6$rule[i] == 1, "full", "half")))),
  fb_stats(res$T6$e_star_draws, sprintf("1.00 · e* %.2f", es$e_star), "estar"))
p_f <- flying_bars(d_f, c(full = PAL[["up_std"]], half = "#7C96B3", estar = "#C8962E"),
                   xlab = "Paid hullers under up_inc, per person (1000 FCFA)",
                   title = "(f) Which component arrives (H4, T6)",
                   subtitle = "Rows: machines · rule delivered (ratios of the design).\nLight: mean fidelity 0.5; ochre: rule at e*") +
  scale_x_continuous(labels = k_fcfa, expand = expansion(mult = c(.04, .38)))

F2 <- p_a + p_b1 + p_b2 + p_c + p_d1 + p_d2 + p_e + p_f +
  plot_layout(design = "AAABBC\nDDDEEF\nGGGHHH", guides = "collect", heights = c(1, 1, 1.05)) +
  plot_annotation(title = "One panel per test, on the same draws",
                  subtitle = sprintf("Atacora case model v9, %s draws, seed %s. Values against the status quo, discounted over 10 years.",
                                     format(res$settings$draws, big.mark = ","), res$settings$seed),
                  theme = theme(plot.title = element_text(face = "bold", size = 11, colour = INK))) &
  theme(legend.position = "bottom")
save_fig(F2, file.path(FIG, "F2_shifts"), height = 270)



# ============================ SUPPLEMENT S1-S9 ================================

# S1 - the walnut trio for the conventional reading (T0): distributions | VIP | EVPI ("Approach 2");
#      the four options against the status quo on top, VIP and EVPI of the decisive pair below
md <- res$model
inputs <- read.csv("data/estimates/atacora_DA_inputs_v8.csv", stringsAsFactors = FALSE)
t0_vars <- paste0("NB_G_", setdiff(OPTIONS, "sq"), "_V0")
p_dist <- plot_distributions(simulation_results, vars = t0_vars, method = "boxplot_density",
                             old_names = t0_vars, new_names = unname(LAB[setdiff(OPTIONS, "sq")]),
                             colors = setNames(PAL[setdiff(OPTIONS, "sq")], LAB[setdiff(OPTIONS, "sq")]),
                             x_axis_name = "Producer household, money only (V0), vs status quo (FCFA)", base_size = 8) +
  facet_wrap(~ name, scales = "free", ncol = 4) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 6.5), legend.position = "none")
p_vip  <- plot_pls(md$pls_T0, input_table = inputs, threshold = 1, base_size = 8, pos_color = POS, neg_color = NEG)
p_evpi <- plot_evpi(md$evpi_T0, md$dec_T0, input_table = inputs, bar_color = INK, base_size = 8)
S1 <- p_dist / (p_vip | p_evpi) + plot_layout(heights = c(1, 1.1)) +
  plot_annotation(title = "S1 \u00b7 The conventional reading (T0): distributions, VIP and EVPI",
                  subtitle = paste("Each option against the status quo; VIP and EVPI of the decisive comparison", md$dec_T0),
                  theme = theme(plot.title = element_text(face = "bold", size = 10, colour = INK),
                                plot.subtitle = element_text(size = 7.5, colour = "grey35")))
save_fig(S1, file.path(SUP, "S1_T0_walnut_trio"), height = 150)

# S2 - cumulative discounted cash flow of the producer household, median and 25-75 % band (g_cashflow)
n_years <- length(grep("^Cashflow_G_out[0-9]+$", names(Y)))
cf_summary <- function(o){
  m <- as.matrix(Y[, paste0("Cashflow_G_", o, seq_len(n_years))])
  data.frame(option = o, year = seq_len(n_years), p25 = apply(m, 2, quantile, .25),
             med = apply(m, 2, median), p75 = apply(m, 2, quantile, .75))
}
cf <- do.call(rbind, lapply(OPTIONS, cf_summary)); cf$option <- factor(cf$option, levels = OPTIONS)
S2 <- ggplot(cf, aes(year, med, colour = option, fill = option)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = .4) +
  geom_ribbon(aes(ymin = p25, ymax = p75), alpha = .16, colour = NA) +
  geom_line(linewidth = .9) +
  scale_colour_manual(values = PAL, labels = LAB, name = NULL) +
  scale_fill_manual(values = PAL, labels = LAB, name = NULL) +
  scale_y_continuous(labels = k_fcfa) + scale_x_continuous(breaks = seq_len(n_years)) +
  labs(title = "S2 · Cumulative discounted cash difference to the status quo, producer household",
       subtitle = "Median with 25-75 % band. Money only: the plan acts after its lag; the campaign moves kg from sale to the plate and fades.",
       x = "Year", y = "Cumulative discounted cash (1000 FCFA)")
save_fig(S2, file.path(SUP, "S2_cashflow"), height = 95)

# S3 - T1, boundaries: flying bars per option under G | G + H | G + H + O, money only and behaviour
bnd <- list("G" = "NB_G_%s_%s", "G + H" = NULL, "G + H + O" = "NB_comm_%s_%s")
d3 <- do.call(rbind, lapply(c("V0", "V1"), function(s) do.call(rbind, lapply(names(bnd), function(k)
  do.call(rbind, lapply(OPTIONS[-1], function(o){
    v <- switch(k, "G" = Y[[sprintf("NB_G_%s_%s", o, s)]],
                "G + H" = Y[[sprintf("NB_comm_%s_%s", o, s)]] - Y[[sprintf("NB_O_%s_%s", o, s)]],
                "G + H + O" = Y[[sprintf("NB_comm_%s_%s", o, s)]])
    cbind(fb_stats(v, LAB[[o]], o), boundary = k, setting = ifelse(s == "V0", "money only (V0)", "behaviour (V1)"))
  }))))))
d3$y <- rev(seq_along(OPTIONS[-1]))[match(d3$row, LAB[OPTIONS[-1]])]
d3$boundary <- factor(d3$boundary, levels = names(bnd)); d3$setting <- factor(d3$setting, levels = c("money only (V0)", "behaviour (V1)"))
S3 <- ggplot(d3) +
  geom_vline(xintercept = 0, colour = "grey55", linewidth = .4) +
  geom_segment(aes(x = p01, xend = p99, y = y, yend = y), colour = "grey45", linewidth = .4) +
  geom_rect(aes(xmin = p10, xmax = p90, ymin = y - .3, ymax = y + .3, fill = fill), colour = INK, linewidth = .25, alpha = .92) +
  geom_segment(aes(x = p50, xend = p50, y = y - .3, yend = y + .3), colour = "white", linewidth = .7) +
  geom_point(aes(x = mean, y = y), shape = 23, size = 1.8, fill = "white", colour = INK, stroke = .6) +
  geom_text(aes(x = p99, y = y, label = sprintf(" %.0f %%", 100 * p_pos)), hjust = 0, size = 2.1, colour = "grey25") +
  facet_grid(setting ~ boundary, scales = "free_x") +
  scale_fill_manual(values = PAL, guide = "none") +
  scale_y_continuous(breaks = seq_along(OPTIONS[-1]), labels = rev(LAB[OPTIONS[-1]])) +
  scale_x_continuous(labels = k_fcfa, n.breaks = 4, expand = expansion(mult = c(.05, .3))) +
  labs(title = "S3 · Whose accounts count (T1): producer household, plus hullers, plus operator",
       subtitle = paste(FB_NOTE, "Label: share of draws above 0."),
       x = "Value vs status quo (1000 FCFA per producer household)", y = NULL) +
  theme(panel.grid.major.y = element_blank())
save_fig(S3, file.path(SUP, "S3_T1_boundaries"), height = 110)

# S4 - T4, one plan, two rules: the same commune value split between producer households and hullers
ps <- res$T4$plan_split
d4 <- rbind(data.frame(option = ps$option, part = "producer household", value = ps$G_mean),
            data.frame(option = ps$option, part = "paid hullers (per producer household)", value = ps$H_per_producer_hh))
d4$option <- factor(LAB[d4$option], levels = rev(LAB[c("up_std", "up_inc")]))
S4 <- ggplot(d4, aes(value, option, fill = part)) +
  geom_col(width = .55, colour = INK, linewidth = .25) +
  geom_vline(xintercept = 0, colour = "grey45", linewidth = .4) +
  geom_text(data = ps, inherit.aes = FALSE,
            aes(x = 0, y = factor(LAB[option], levels = rev(LAB[c("up_std", "up_inc")])),
                label = sprintf("P(hullers lose) = %.0f %%", 100 * p_hullers_lose)),
            vjust = -2.2, hjust = 0.5, size = 2.4, colour = "grey20") +
  scale_fill_manual(values = c("producer household" = PAL[["up_std"]], "paid hullers (per producer household)" = PAL[["out"]]), name = NULL) +
  scale_x_continuous(labels = k_fcfa) +
  labs(title = "S4 · One plan, two rules (T4): the same commune, a different split",
       subtitle = "Expected value vs status quo under behaviour (V1). Stacked parts sum to the same commune value under both rules.",
       x = "1000 FCFA per producer household", y = NULL)
save_fig(S4, file.path(SUP, "S4_T4_plan_rules"), height = 70)

# S5 - T5, the EVPI ladder: person -> household type -> commune, V0 and V1 side by side (g_ev_npv)
ld <- res$T5$ladder
ld <- ld[ld$setting %in% c("V0", "V1") & !grepl("^commune, rule", ld$level), ]
ld$level <- factor(ld$level, levels = rev(unique(ld$level)))
S5 <- ggplot(ld, aes(EVPI, level, fill = setting)) +
  geom_col(position = position_dodge(width = .7), width = .65) +
  geom_text(aes(label = option), position = position_dodge(width = .7), hjust = -0.15, size = 2.2, colour = "grey25") +
  scale_fill_manual(values = c(V0 = "#B7A99A", V1 = INK), labels = c(V0 = "money only (V0)", V1 = "behaviour (V1)"), name = NULL) +
  scale_x_continuous(labels = k_fcfa, expand = expansion(mult = c(0, .25))) +
  labs(title = "S5 · Value of information by level (T5)",
       subtitle = "EVPI of one decision, per level of aggregation; label: the option ahead at today's information.",
       x = "EVPI (1000 FCFA per person or per producer household)", y = NULL)
save_fig(S5, file.path(SUP, "S5_T5_evpi_ladder"), height = 90)

# S6 - T5, multi_EVPI() per level and per rule: small multiples, same variable order, bars coloured by status
EVPI_PANELS <- c(T5_level_Wg = "Wg", T5_level_H = "H", T5_level_G = "G", main_model = "commune",
                 T5_commune_utilitarian = "commune, utilitarian", T5_commune_maximin = "commune, maximin")
d6 <- do.call(rbind, lapply(names(EVPI_PANELS), function(k){
  e <- res$evpi$full[[k]]
  if (is.null(e)) return(NULL)
  data.frame(level = paste0(EVPI_PANELS[[k]], ": ", res$evpi$pairs[[k]]), variable = e[[1]]$variable, EVPI = pmax(e[[1]]$EVPI, 0))
}))
d6$status <- inputs$status[match(d6$variable, inputs$variable)]
keep6 <- unique(d6$variable[d6$EVPI > 0])
d6 <- d6[d6$variable %in% keep6, ]
ord6 <- names(sort(tapply(d6$EVPI / ave(d6$EVPI, d6$level, FUN = function(z) max(z, 1e-12)), d6$variable, max)))
d6$variable <- factor(d6$variable, levels = ord6)
d6$level <- factor(d6$level, levels = unique(d6$level))
S6 <- ggplot(d6, aes(EVPI, variable, fill = status)) +
  geom_col(width = .7) +
  facet_wrap(~ level, nrow = 2, scales = "free_x") +
  scale_fill_manual(values = STATUS_COL[c("L", "W", "T", "B", "P")], name = "Status") +
  scale_x_continuous(labels = scales::label_comma(), n.breaks = 3) +
  labs(title = "S6 · Which input is worth measuring, per level and per rule (T5, multi_EVPI())",
       subtitle = "Decisive pair under behaviour (V1): the option ahead against the runner-up. Partial EVPI per input; the research priority depends on the criterion.",
       x = "EVPI (FCFA)", y = NULL) +
  theme(strip.text = element_text(size = 7))
save_fig(S6, file.path(SUP, "S6_T5_multi_evpi"), height = 150)

# S7 - T6, fidelity: (a) f* of the preferred option per account and rule; (b) hullers under the compositions
ft <- res$T6$thresholds
ft7 <- ft[ft$recommended & ft$option != "sq", ]
ft7$who <- paste(ft7$account, ft7$rule, sep = " · ")
p7a <- ggplot(ft7, aes(f_star, factor(who, levels = rev(unique(who))), colour = option)) +
  geom_vline(xintercept = c(0, 1), colour = "grey70", linewidth = .3) +
  geom_point(size = 2.4) +
  geom_text(aes(label = sprintf("%.2f", f_star)), hjust = -0.4, size = 2.3, colour = "grey20") +
  scale_colour_manual(values = PAL, labels = LAB, name = NULL) +
  scale_x_continuous(limits = c(0, 1.12), breaks = seq(0, 1, .25)) +
  labs(title = "(a) Share of the effect that must arrive",
       subtitle = "f* of the preferred option; 0 = any share above 0 keeps it ahead\n(runner-up is the status quo). Not shown where the status quo is preferred.",
       x = "f*", y = NULL)
comp_T6 <- res$T6$compositions
d7b <- do.call(rbind, lapply(seq_len(nrow(comp_T6)), function(i)
  fb_stats(res$T6$draws[[i]]$NB_H_up_inc_V1, sprintf("machines %.2f · rule %.2f", comp_T6$reach[i], comp_T6$rule[i]),
           ifelse((comp_T6$reach[i] + comp_T6$rule[i]) / 2 == 0.5, "half", "full"))))
p7b <- flying_bars(d7b, c(half = "#7C96B3", full = PAL[["up_std"]]),
                   xlab = "Paid hullers under up_inc, per person (1000 FCFA)",
                   title = "(b) Hullers under up_inc, by composition",
                   subtitle = "Light boxes: mean fidelity 0.5; ratios of the design (H4)")
S7 <- (p7a | p7b) + plot_annotation(title = "S7 · Fidelity (T6)",
                                     theme = theme(plot.title = element_text(face = "bold", size = 10, colour = INK)))
save_fig(S7, file.path(SUP, "S7_T6_fidelity"), height = 100)

# S8 - shift map: one row per test, conventional against opened setting, and the threshold against its prior
if (file.exists("outputs/v9/shift_map.csv")) {
  sm <- read.csv("outputs/v9/shift_map.csv", stringsAsFactors = FALSE)
  sm$test <- factor(sm$test, levels = rev(unique(sm$test)))
  d8 <- rbind(data.frame(test = sm$test, column = "conventional", option = sm$option_conv, p = sm$p_conv, lab = sm$setting_conv),
              data.frame(test = sm$test, column = "opened", option = sm$option_open, p = sm$p_open, lab = sm$setting_open))
  d8$column <- factor(d8$column, levels = c("conventional", "opened"))
  p8 <- ggplot(d8, aes(column, test, fill = option)) +
    geom_tile(colour = "white", linewidth = 1) +
    geom_text(aes(label = sprintf("%s\n%s", ifelse(is.na(p), option, sprintf("%s (%.0f %%)", option, 100 * p)), lab)),
              size = 2.2, colour = "white", lineheight = .85) +
    scale_fill_manual(values = c(PAL, mixed = "grey60"), guide = "none") +
    labs(x = NULL, y = NULL, title = "Preferred option, share of draws ahead")
  thr8 <- sm[is.finite(sm$threshold), ]
  p8b <- ggplot(thr8, aes(y = test)) +
    geom_segment(aes(x = prior_lo, xend = prior_hi, yend = test), colour = "grey70", linewidth = 2.5) +
    geom_point(aes(x = threshold), shape = 21, size = 2.6, fill = NEG, colour = "white") +
    geom_text(aes(x = threshold, label = threshold_label), vjust = -1, size = 2.2, colour = "grey20") +
    facet_wrap(~ threshold_unit, scales = "free", ncol = 1) +
    labs(x = NULL, y = NULL, title = "Threshold (dot) vs 90 % prior range (bar)")
  S8 <- (p8 | p8b) + plot_layout(widths = c(1.2, 1)) +
    plot_annotation(title = "S8 · Shift map T0-T6 and H3", theme = theme(plot.title = element_text(face = "bold", size = 10, colour = INK)))
  save_fig(S8, file.path(SUP, "S8_shift_map"), height = 130)
}

# S9 - T4, the inequality curve (F2 (c) in v8; moved here in v9 because it flips nothing): every option under Atkinson
#      from eps 0 (utilitarian) to 5, then maximin, and the prioritarian rule (a loss counts twice) as its own point;
#      y on a signed log scale, so that the two plan rules (close to 0) and out (far below) are both readable
cv <- res$T4$curve; eps <- res$T4$eps_grid
d_9 <- do.call(rbind, lapply(OPTIONS, function(o) data.frame(option = o, x = eps, value = cv[o, paste0("eps_", eps)])))
pts_9 <- do.call(rbind, lapply(OPTIONS, function(o) data.frame(option = o, x = c(6.0, 7.4),
                                                              value = cv[o, c("maximin", "prioritarian")])))
best_9 <- sapply(eps, function(e) OPTIONS[which.max(cv[, paste0("eps_", e)])])
eps_star <- eps[which(best_9[-1] != best_9[-length(best_9)]) + 1]
slog <- scales::pseudo_log_trans(sigma = 50, base = 10)                            # signed log: linear within +-50 FCFA
S9 <- ggplot(d_9, aes(x, value, colour = option)) +
  annotate("rect", xmin = 5.45, xmax = 8.05, ymin = -Inf, ymax = Inf, fill = "grey96") +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = .4) +
  { if (length(eps_star)) geom_vline(xintercept = eps_star, colour = INK, linetype = "22", linewidth = .35) } +
  geom_line(linewidth = .8) +
  geom_point(data = pts_9, size = 2) +
  scale_colour_manual(values = PAL, breaks = OPTIONS, labels = LAB, name = NULL) +
  scale_x_continuous(breaks = c(0:5, 6.0, 7.4), labels = c("0\nutilit.", 1:5, "maximin", "prioritarian\nloss × 2")) +
  scale_y_continuous(trans = slog, breaks = c(-1e5, -1e4, -1e3, -1e2, 0), labels = c("-100", "-10", "-1", "-0.1", "0")) +
  labs(title = "S9 · One family of rules over all five options (T4)",
       subtitle = sprintf("Household and hullers per person, behaviour (V1); signed log scale%s",
                          if (length(eps_star)) "" else "; no rule changes the choice among the options"),
       x = "Atkinson inequality aversion ε", y = "Value under the rule (1000 FCFA per person)")
save_fig(S9, file.path(SUP, "S9_T4_inequality_curve"), height = 95)
