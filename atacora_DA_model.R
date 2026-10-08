#  ------------------------------------------------------------------------
#  DECISION ANALYSIS - Scaling fonio processing in the Atacora (North Benin), v9
#  Case model of the review article "Scaling as a valuation decision" (Circular Agricultural Systems)
#  Author   : Daniel Rozeik, University of Bonn
#  Decision : which workshop option to scale -- processing equipment (out), advocacy for a national
#             fonio plan (up), public awareness (deep) -- or none (status quo)
#  Level    : one commune (Boukoumbe or Natitingou). Values per producer household of the commune,
#             aggregated from persons over households to the commune, never across communes
#  Inputs   : data/estimates/atacora_DA_inputs_v8.csv, one row per input with its source and status
#             (L literature, W workshop/Dataverse, T transferred, P prior set by me)
#  Structure: make_variables() -> decision_model() -> SIMULATION -> VALUE OF INFORMATION -> SENSITIVITY.
#  The axis tests T0-T6 are in atacora_DA_axes_full.R; atacora_DA_axes.R is the short screen of the five axes.
#  ------------------------------------------------------------------------

# Model structure and abbreviations: see figures/atacora_model_v9_core.png


library(decisionSupport)

# In this model 'p' is the grain price. In the valuation functions of R/, 'p' means group shares.

make_variables <- function(est, n = 1){
  x <- random(rho = est, n = n)                                                     # draw one row from the estimate
  for (i in colnames(x)) assign(i, as.numeric(x[1, i]), envir = .GlobalEnv)         # push each variable to the global environment
}

make_variables(estimate_read_csv("data/estimates/atacora_DA_inputs_v8.csv"))        # Read the estimate table (ranges + distributions) and expose one draw globally.
#  MODEL FUNCTION
decision_model <- function(){


  # 1. TIME HORIZON

  n_years  <- round(horizon_years)                                                  # appraisal length in years (const = 10 in the CSV)
  time     <- 1:n_years                                                             # year index used by the plan lag (U1) and the campaign decay
  disc_pct <- discount_rate * 100                                                   # decisionSupport's discount() wants a percentage



  # 2. SHARED CHANCE EVENTS  (drawn ONCE, reused by every option => fair comparison)
  #    Machine downtime (O2): in a breakdown year part of the machine throughput is lost and hulled
  #    by hand again. The same years hit out and up, the two options with machines. Technical fidelity.

  down_t  <- chance_event(p_machine_downtime, value_if = machine_downtime_loss_share,
                          value_if_not = 0, n = n_years)                            # O2 share of machine throughput lost, per year [P, P]
  avail_t <- 1 - down_t                                                             # O2 technical availability, shared by out and up



  # 3. FONIO SUPPLY  (shared physical input, constant over the horizon)
  #    One producer household of the commune. The area stays constant: the preference-informed
  #    reference works through the value of freed time (section 7), not through an area path (increased / decreased area).

  Q <- fonio_area_hh_ha * fonio_yield_kg_ha                                         # Q1 kg paddy per producer household and year [P ha x L kg/ha]



  # 4. SHARED PRICES AND UNIT COSTS  (drawn once, used by all options)

  p      <- retail_price_hulled_fcfa_kg * producer_price_share                      # M1 FCFA per kg hulled grain realised by the household [W x P]
  f_h    <- hand_service_price_fcfa_kg                                              # M2 FCFA per kg paddy paid for hand hulling [P]
  f_m    <- f_h * machine_cost_ratio_to_manual                                      # M3 machine fee, FCFA per kg paddy [P x L]
  margin <- operator_margin_share * f_m                                             # M4 FCFA per kg paddy left to the operator; the rest is running cost [P]
  wage_h <- f_h * hand_hull_rate_kg_h                                               # FCFA per hour of hand hulling, the paid rate [P x L kg/h]



  # 5. PROCESSING CHAIN  (mass balance, per household type)
  #    Returns kg, hours and the cash of the three accounts of one household type, per year.
  #    m     machine share of the paddy (vector over years)    
  #    own   share of the grain eaten at home
  #    op    who receives the operator margin, c(G, H, O) sums to 1
  #    paid  0 = type self (the household's women hull everything), 1 = type hire (paid hullers do)
  #    Check: Qm + Qh = Q and grain = eaten + sold in every year (tests/testthat/test-model.R).

  process_fonio <- function(m, own, op, paid){
    Qm    <- m * Q                                                                  # P1 kg paddy hulled by machine
    Qh    <- Q - Qm                                                                 # P1 kg paddy hulled by hand
    Qp    <- paid * Qh                                                              # P2 kg paddy hulled by hand for pay
    Qu    <- Qh - Qp                                                                # P2 kg paddy hulled by hand, unpaid, by the household's women
    grain <- Qh * recovery_hand_share + Qm * recovery_machine_share                 # P3 kg hulled grain [L, L]
    eaten <- own * grain                                                            # S1 kg eaten at home
    sold  <- grain - eaten                                                          # S1 kg sold
    fee   <- Qp * f_h + Qm * f_m                                                    # M2 M3 FCFA/yr hulling fees paid by the household
    wages <- Qp * f_h                                                               # M2 FCFA/yr received by the paid hullers
    marg  <- margin * Qm                                                            # M4 FCFA/yr operator margin on this household's machine paddy
    list(Qm = Qm, Qh = Qh, Qp = Qp, Qu = Qu, grain = grain, eaten = eaten, sold = sold,   # kg per year
         fee = fee, wages = wages, marg = marg, op = op,                            # FCFA per year; op = who receives the margin
         G_cash = sold * p - fee + op[["G"]] * marg,                                # M1-M4 FCFA/yr, producer household
         H_cash = wages + op[["H"]] * marg,                                         # M2 M4 FCFA/yr, hullers (group total per producer household)
         O_cash = op[["O"]] * marg,                                                 # M4 FCFA/yr, private operator
         G_hrs  = Qu / hand_hull_rate_kg_h,                                         # L1 h/yr of unpaid hulling by the household's women [L]
         H_hrs  = Qp / hand_hull_rate_kg_h)                                         # L2 h/yr of paid hulling [L]
  }



  # (0) STATUS QUO  -  all fonio is hulled by hand, by the household's women (type self) or for pay (type hire)

  #  A. COSTS            : hand hulling, unpaid or at f_h per kg paddy (M2)
  #  B. BENEFITS         : sales at p (M1) and the kg eaten at home (S1)
  #  C. RISKS / FIDELITY : none; no machine and no programme

  m_sq    <- rep(0, n_years)                                                        # no machine
  own_sq  <- rep(own_consumption_share_behavioural, n_years)                        # S1 today's share of the grain eaten at home [P]
  ## own_sq <- rep(own_consumption_share_behavioural_alt, n_years)                  # >>> HISTORICAL REFERENCE (Ballogou et al. 2014, survey 2011) [L]; <<<
  op_none <- c(G = 0, H = 0, O = 0)                                                 # no operator margin
  sq_self <- process_fonio(m_sq, own_sq, op_none, paid = 0)                         # type self, for reference see section 5. PROCESSING CHAIN
  sq_hire <- process_fonio(m_sq, own_sq, op_none, paid = 1)                         # type hire



  # (1) OUT - PROCESSING EQUIPMENT  -  installed hulling machines, bounded by their capacity; private operator

  #  A. COSTS            : machine fee f_m on the machine-hulled paddy (M3); buying the machines lies outside the community boundary
  #  B. BENEFITS         : hand-hulling hours saved (L1, L2) and the recovery difference machine - hand (P3)
  #  C. RISKS / FIDELITY : downtime years (O2), representing the technical fidelity of the machines
  #  The units scale with the households served, so m is the same for both types, also when out reaches one type only (T5).

  cap_share_out <- out_units * volume_processed_t_yr * 1000 / (n_producer_hh * Q)    # O1 capacity as share of the area's paddy [P units x L t/yr / (B hh x Q1 kg)]
  m_out         <- min(1, cap_share_out) * avail_t                                   # O1 O2 machine share per year: capacity-bound, minus downtime
  op_out        <- c(G = 0, H = 0, O = 1)                                            # the margin stays with the private operator
  out_self      <- process_fonio(m_out, own_sq, op_out, paid = 0)                    # type self
  out_hire      <- process_fonio(m_out, own_sq, op_out, paid = 1)                    # type hire



  # (2) UP - NATIONAL FONIO PLAN  (standard / inclusive rule)  -  the plan co-finances machines after a lag

  #  A. COSTS            : machine fee f_m (M3); the plan's own cost lies outside the community boundary
  #  B. BENEFITS         : hours saved, recovery (P3), the operator margin to the group the rule names (U3)
  #  C. RISKS / FIDELITY : lag (U1), implementation share (U2), downtime (O2), enforcement of the inclusive rule (U3)
  #  That the plan co-finances machines is an assumption by decision.
  #  The two rules differ only in who receives the operator margin (H2, T4).

  plan_share_c <- min(1, max(0, plan_machine_share))                                 # U2 share of producer households the plan equips; norm 0/0.30 censored to [0, 1] [P]
  active_t     <- as.numeric(time > round(plan_lag_years))                           # U1 the plan acts after its lag [P years]
  m_up         <- plan_share_c * plan_implementation_share * active_t * avail_t      # U2 O2 machine share per year: share-bound [P x T]
  op_up_std    <- c(G = 1, H = 0, O = 0)                                             # U3 standard rule: producer groups operate the machines
  op_up_inc    <- c(G = 1 - inclusive_rule_enforcement,                              # U3 inclusive rule: hullers' groups (paid hullers) operate,
                    H = inclusive_rule_enforcement, O = 0)                           #    as far as the rule is enforced (const 1) [P]
  up_std_self  <- process_fonio(m_up, own_sq, op_up_std, paid = 0)                   # type self, standard rule
  up_std_hire  <- process_fonio(m_up, own_sq, op_up_std, paid = 1)                   # type hire, standard rule
  up_inc_self  <- process_fonio(m_up, own_sq, op_up_inc, paid = 0)                   # type self, inclusive rule
  up_inc_hire  <- process_fonio(m_up, own_sq, op_up_inc, paid = 1)                   # type hire, inclusive rule



  # (3) DEEP - PUBLIC AWARENESS  -  a campaign raises the share of the grain eaten at home

  #  A. COSTS            : none inside the community; the campaign's cost lies outside the boundary
  #  B. BENEFITS         : kg moved from sale to the household's plate (S1), valued in section 7 (kappa)
  #  C. RISKS / FIDELITY : reach (D1), size of the change (D2), decay after the campaign (D1)

  C_years   <- round(awareness_campaign_years)                                       # D1 years the campaign runs [P]
  aware_t   <- awareness_reach_share *                                               # D1 share of households reached and still acting on it [T]
               ifelse(time <= C_years, 1, (1 - awareness_decay_rate)^(time - C_years))  #    full during the campaign, then decaying [T]
  own_deep  <- pmin(1, own_sq * (1 + awareness_consumption_change_share * aware_t))  # D2 share of the grain eaten at home [T]
  deep_self <- process_fonio(m_sq, own_deep, op_none, paid = 0)                      # type self
  deep_hire <- process_fonio(m_sq, own_deep, op_none, paid = 1)                      # type hire



  # 6. ACCOUNTS PER GROUP  (option minus status quo, per year and per household type)
  #    G   producer household              Wg  its women: their hulling time only (how the household's
  #    H   paid hullers (group total per producer household here, per person in section 8)   money is split is unknown)
  #    O   the private operator of out: for the system boundary (T1), never in rules over persons
  #    "Saved" and "freed" hours are status quo minus option; cash and kg are option minus status quo.
  #    Households -> commune: the two types mixed with their shares. Programme costs (machines, plan,
  #    campaign) lie outside the community boundary and are not modelled.
  #    Check: every difference of sq to itself is exactly 0; transfers cancel in the commune (tests).

  accounts <- function(x, b){                                                       # one option x against the status quo b, one household type
    list(G_sold = (x$grain - b$grain) - (x$eaten - b$eaten),                        # S1 kg/yr more sold (grain gained minus kg moved to the plate)
         G_kg   = x$eaten - b$eaten,                                                # S1 kg/yr more eaten at home
         G_fee  = x$fee   - b$fee,                                                  # M2 M3 FCFA/yr more hulling fees paid by the household
         H_wage = x$wages - b$wages,                                                # M2 FCFA/yr more wages to the paid hullers
         marg   = x$marg  - b$marg,                                                 # M4 FCFA/yr more operator margin (the status quo has none)
         G_hrs  = b$G_hrs - x$G_hrs,                                                # L1 h/yr saved by the household's women
         H_hrs  = b$H_hrs - x$H_hrs,                                                # L2 h/yr freed from paid hulling
         m      = x$Qm / Q,                                                         # P1 machine share of the paddy, per year
         op     = x$op)                                                             # who receives the margin under this option
  }

  d_self <- list(sq     = accounts(sq_self,     sq_self),                           # type self: the status quo against itself (0 by construction)
                 out    = accounts(out_self,    sq_self),                           # out
                 up_std = accounts(up_std_self, sq_self),                           # up, standard rule
                 up_inc = accounts(up_inc_self, sq_self),                           # up, inclusive rule
                 deep   = accounts(deep_self,   sq_self))                           # deep
  d_hire <- list(sq     = accounts(sq_hire,     sq_hire),                           # type hire, the same five
                 out    = accounts(out_hire,    sq_hire),
                 up_std = accounts(up_std_hire, sq_hire),
                 up_inc = accounts(up_inc_hire, sq_hire),
                 deep   = accounts(deep_hire,   sq_hire))
  
  mix <- function(a, b){                                                            # households -> commune: the types mixed with their shares [P]
    out <- Map(function(u, v) (1 - hiring_hh_share) * u + hiring_hh_share * v, a, b)
    out$op <- a$op                                                                  # the rule is the same for both types
    out
  }
  d_comm <- Map(mix, d_self, d_hire)                                                # the commune, per producer household, every option



  # 7. VALUATION CONVENTIONS  (in the model, like the index in the template; three named settings, no free weights)
  #    omega_W  a saved hulling hour of a woman in a producer household, in multiples of wage_h (1 = replacement cost)
  #    omega_H  a freed hour of a paid huller, in multiples of wage_h
  #    kappa    a kg eaten at home, in multiples of the sale price p (1 = market price)
  #    V0    conventional: money only
  #    V1    reference "behaviour" (main run): a freed hour is worth what today's behaviour shows -- unpaid work at
  #          replacement cost; for hullers today's fallback, at most their wage, because they chose hulling
  #    PREF  reference "preference": young women mostly name a future outside farming (Mausch 2025: 74 %, youth
  #          sample; reported only, never a weight); every hour freed from fonio work counts at the value of an
  #          hour of off-farm work (B). Observed behaviour is not a preference; T2 makes the difference visible.

  kappa     <- 1                                                                    # V1/PREF: a kg eaten at home is valued at the price it would have fetched (market-price convention)
  ## kappa  <- 1.5                                                                  # >>> ALTERNATIVE O2: declared nutrition premium; swap the two lines to switch on <<<
  theta     <- min(1, max(0, time_value_ratio_hullers))                             # V1 value of a freed huller hour / wage_h; norm 0/0.8 censored to [0, 1] [P]
  w_off_rel <- opportunity_wage_fcfa_h / wage_h                                     # PREF value of an off-farm hour / wage_h [B / (B x L)]

  settings <- list(V0   = c(omega_W = 0,         omega_H = 0,         kappa = 0),       # conventional: money only
                   V1   = c(omega_W = 1,         omega_H = theta,     kappa = kappa),   # reference "behaviour" (main run)
                   PREF = c(omega_W = w_off_rel, omega_H = w_off_rel, kappa = kappa))   # reference "preference"

  # Equation A11 (eq-money, FUNCTIONS.md) uses already discounted y, t and c. decisionSupport's
  # discount(v, rate, TRUE) computes sum(v[t] / (1 + rate/100)^(t-1)):
  # the first model year is undiscounted. Do not silently change the exponent to t.
  npv  <- function(v) discount(v, disc_pct, calculate_NPV = TRUE)                   # discounted sum over the horizon (year 1 undiscounted)
  comp <- function(a) c(                                                            # discounted components of one option, FCFA
    G_cash = p * npv(a$G_sold) - npv(a$G_fee) + a$op[["G"]] * npv(a$marg),          # dG_cash      sales - fees + margin, producer household
    G_time = wage_h * npv(a$G_hrs),                                                 # dG_time_val  wage_h x discounted hours saved
    G_kg   = p * npv(a$G_kg),                                                       # dG_kg_val    p x discounted kg eaten
    H_cash = npv(a$H_wage) + a$op[["H"]] * npv(a$marg),                             # dH_cash      wages + margin, hullers per producer household
    H_time = wage_h * npv(a$H_hrs),                                                 # dH_time_val  wage_h x discounted hours freed
    O_cash = a$op[["O"]] * npv(a$marg),                                             # dO_cash      margin, operator
    money  = p * npv(a$G_sold) - npv(a$G_fee) + npv(a$H_wage) + npv(a$marg))       # the commune's money, whoever receives the margin (= G + H + O cash)
  C_comm <- lapply(d_comm, comp)                                                    # components per option, the commune's mix
  C_self <- lapply(d_self, comp)                                                    # the same, type self
  C_hire <- lapply(d_hire, comp)                                                    # the same, type hire



  # 8. DECISIONS  (option vs status quo, per account and setting; > 0 => the option is better for that account)
  #    NB_G     = dG_cash + omega_W * dG_time_val + kappa * dG_kg_val       producer household
  #    NB_Wg    = omega_W * dG_time_val                                     women in producer households, per woman
  #    NB_H     = (dH_cash + omega_H * dH_time_val) / K                     per huller, K = hullers per producer household
  #    NB_O     = dO_cash                                                   the private operator
  #    NB_comm  = NB_G + K * NB_H + NB_O                                    the commune, per producer household
  #    NB_Gself, NB_Ghire, NBc_self, NBc_hire: the household account and the commune value of one household
  #    type, with the H and O flows that type causes (T5). Check: NB_comm of up_std equals that of up_inc in
  #    every draw; kappa = 1 gives NB_G(deep) = 0 in every draw (tests).

  K <- hullers_per_producer_hh                                                      # paid hullers per producer household (const 0.25) [P]

  # Equation A11 (eq-money): y_G + omega_W*w_h*t_G + kappa*p_f*c_G.
  # comp() above has ALREADY multiplied discounted hours by wage_h and kg by p.
  # Hence G_time is w_h*t_G and G_kg is p_f*c_G; multiplying those prices again
  # here would double-value them. [[ ]] extracts one named scalar from a vector.
  # The three terms below are all FCFA. Raw kg and hours are reported separately.
  # Equation A12 (eq-boundary): G + K*H + O. H is divided by K to report per huller;
  # the boundary sum multiplies it by K again to report per producer household.
  value <- function(cc, w) c(                                                      # the accounts of one option under one setting w
    G    = cc[["G_cash"]] + w[["omega_W"]] * cc[["G_time"]] + w[["kappa"]] * cc[["G_kg"]],  # NB_G FCFA per producer household
    Wg   = w[["omega_W"]] * cc[["G_time"]],                                         # NB_Wg FCFA per woman in a producer household
    H    = (cc[["H_cash"]] + w[["omega_H"]] * cc[["H_time"]]) / K,                  # NB_H FCFA per huller
    O    = cc[["O_cash"]],                                                          # NB_O FCFA, operator
    comm = cc[["money"]] + w[["omega_W"]] * cc[["G_time"]] +                        # NB_comm = NB_G + K * NB_H + NB_O, FCFA per producer household,
           w[["omega_H"]] * cc[["H_time"]] + w[["kappa"]] * cc[["G_kg"]])           #   summed so that it does not depend on who receives the margin

  nb <- list()
  for (o in names(C_comm)) for (s in names(settings)) {                             # every option x setting, on the same draw
    v_comm <- value(C_comm[[o]], settings[[s]])                                     # the commune's mix of household types
    v_self <- value(C_self[[o]], settings[[s]])                                     # type self
    v_hire <- value(C_hire[[o]], settings[[s]])                                     # type hire
    nb[paste("NB", names(v_comm), o, s, sep = "_")] <- as.list(v_comm)              # NB_{G, Wg, H, O, comm}_{option}_{setting}
    nb[paste("NB", c("Gself", "Ghire"), o, s, sep = "_")] <- list(v_self[["G"]], v_hire[["G"]])        # household account per type
    nb[paste("NBc", c("self", "hire"), o, s, sep = "_")]  <- list(v_self[["comm"]], v_hire[["comm"]])  # commune value per type (T5)
  }

  cmp <- list()
  for (o in names(C_comm)) {                                                        # components, linear in the weights => exact thresholds after the run
    k <- setdiff(names(C_comm[[o]]), "money")                                       # the six components of the accounts
    cmp[paste("C", k, o, sep = "_")] <- as.list(C_comm[[o]][k])                                 # C_{G, H, O}_{component}_{option}
    cmp[paste("C", sub("_", "self_", k), o, sep = "_")] <- as.list(C_self[[o]][k])              # C_{Gself, Hself, Oself}_...
    cmp[paste("C", sub("_", "hire_", k), o, sep = "_")] <- as.list(C_hire[[o]][k])              # C_{Ghire, Hhire, Ohire}_...
    cmp[paste(c("C_money", "C_moneyself", "C_moneyhire"), o, sep = "_")] <-                     # the money of the commune and of each type,
      list(C_comm[[o]][["money"]], C_self[[o]][["money"]], C_hire[[o]][["money"]])              #   whoever receives the margin (G + H + O cash)
  }

  units <- list()
  for (o in names(d_comm)) {                                                        # natural units, undiscounted sums over the horizon
    a <- d_comm[[o]]                                                                # the commune's mix, per producer household
    units[[paste0("Hrs_G_saved_", o)]] <- sum(a$G_hrs)                              # L1 h saved by the household's women
    units[[paste0("Hrs_H_freed_", o)]] <- sum(a$H_hrs) / K                          # L2 h freed from paid hulling, per huller
    units[[paste0("Kg_eaten_", o)]]    <- sum(a$G_kg)                               # S1 kg more eaten at home
    units[[paste0("Kg_sold_", o)]]     <- sum(a$G_sold)                             # S1 kg more sold
    units[[paste0("M_share_", o)]]     <- mean(a$m)                                 # P1 mean machine share of the paddy per year
    G_cash_t <- p * a$G_sold - a$G_fee + a$op[["G"]] * a$marg                       # M FCFA/yr cash difference to sq, producer household
    units[[paste0("Cashflow_G_", o)]]  <- cumsum(discount(G_cash_t, disc_pct, calculate_NPV = FALSE))  # cumulative discounted cash difference to sq
  }



  # 9. RETURN  (everything the simulation should keep)

  return(c(
    nb,                                                                             # --- net benefits, FCFA: NB_{G, Wg, H, O, comm, Gself, Ghire}_{option}_{V0, V1, PREF}, NBc_{self, hire}_{option}_{setting} ---
    cmp,                                                                            # --- components, FCFA discounted: C_{G, Gself, Ghire}_{cash, time, kg}_{option}, C_{H, ...}_{cash, time}_{option}, C_{O, ...}_cash_{option}, C_money{, self, hire}_{option} ---
    units,                                                                          # --- natural units: Hrs_*, Kg_*, M_share_*; cumulative discounted cash flow Cashflow_G_{option}{year} ---
    list(wage_h        = wage_h,                                                    # --- per draw: FCFA per hour of hand hulling
         p             = p,                                                         #     FCFA per kg hulled grain, realised
         w_off_rel     = w_off_rel,                                                 #     off-farm hour / wage_h (PREF)
         theta         = theta,                                                     #     huller hour / wage_h (V1), censored
         Q_paddy       = Q),                                                        #     kg paddy per producer household and year ---
    list(Lvl_kg_eaten_sq = sum((1 - hiring_hh_share) * sq_self$eaten +              # --- levels of the status quo, the reference of the progress index (T1b)
                               hiring_hh_share * sq_hire$eaten),                    #     and of the level rules (T4): S1 kg eaten at home over the horizon, per producer household
         Lvl_hrs_Wg_sq   = sum((1 - hiring_hh_share) * sq_self$G_hrs +              #     L1 h of unpaid hulling over the horizon,
                               hiring_hh_share * sq_hire$G_hrs),                    #        per woman in a producer household
         Lvl_hrs_H_sq    = sum((1 - hiring_hh_share) * sq_self$H_hrs +              #     L2 h of paid hulling over the horizon,
                               hiring_hh_share * sq_hire$H_hrs) / K,                #        per huller
         NPV_G_cash_sq   = npv((1 - hiring_hh_share) * sq_self$G_cash +             #     M1-M4 money of the producer household, FCFA discounted
                               hiring_hh_share * sq_hire$G_cash),                   #        (also the Atkinson offset of T4)
         Lvl_H_cash_sq   = npv((1 - hiring_hh_share) * sq_self$H_cash +             #     M2 hulling wages, FCFA discounted,
                               hiring_hh_share * sq_hire$H_cash) / K)               #        per huller ---
  ))
}


#  SIMULATION
SEED    <- 20260927                                                                 # fixed seed of v9 runs
N_DRAWS <- 10000                                                                    # Monte Carlo draws
set.seed(SEED)
simulation_results <- mcSimulation(
  estimate          = estimate_read_csv("data/estimates/atacora_DA_inputs_v8.csv"),
  model_function    = decision_model,
  numberOfModelRuns = N_DRAWS,
  functionSyntax    = "plainNames"
)
#  VALUE OF INFORMATION  (EVPI) on the decisive comparisons
#  The decisive comparison of a reading is the option ahead against the runner-up (by mean): once for the
#  conventional reading (producer household, money only, V0 = T0) and once for the main run (commune, V1).


OPTIONS <- c("sq", "out", "up_std", "up_inc", "deep")            # the options, as in decision_model()
y       <- simulation_results$y                                   # model outputs: one row per draw, one column per output

# Net benefit of every option for one account under one setting: a table, draws x options
nb_table <- function(account, setting){
  nb <- y[paste("NB", account, OPTIONS, setting, sep = "_")]      # e.g. NB_G_sq_V0, NB_G_out_V0, ...
  setNames(nb, OPTIONS)                                           # short column names: sq, out, ...
}

# The option ahead and its runner-up, by mean net benefit
ahead <- function(account, setting){
  nb        <- nb_table(account, setting)
  ranking   <- names(sort(colMeans(nb), decreasing = TRUE))             # options from best to worst
  best      <- ranking[1]
  same      <- sapply(ranking, function(o) all(nb[[o]] == nb[[best]]))  # equal to the best in every draw: a tie, not a rival
  runner_up <- ranking[!same][1]                                        # the first option that really differs
  c(best = best, runner_up = runner_up)
}

# Net benefit of the option ahead minus that of the runner-up, per draw
decisive <- function(account, setting){
  nb   <- nb_table(account, setting)
  pair <- ahead(account, setting)
  nb[[pair[["best"]]]] - nb[[pair[["runner_up"]]]]
}

# The name of that comparison, e.g. G_V0_up_std_vs_sq
dec_name <- function(account, setting){
  pair <- ahead(account, setting)
  paste0(account, "_", setting, "_", pair[["best"]], "_vs_", pair[["runner_up"]])
}

dec_T0   <- dec_name("G", "V0")                                   # conventional reading: producer household, money only
dec_main <- dec_name("comm", "V1")                                # main run: commune, behavioural reference


mc_table <- data.frame(simulation_results$x, decisive("G", "V0"))
names(mc_table)[ncol(mc_table)] <- dec_T0
evpi_T0 <- multi_EVPI(mc = mc_table, first_out_var = dec_T0)
plot_evpi(evpi_T0, dec_T0)

mc_table <- data.frame(simulation_results$x, decisive("comm", "V1"))
names(mc_table)[ncol(mc_table)] <- dec_main
evpi_main <- multi_EVPI(mc = mc_table, first_out_var = dec_main)
plot_evpi(evpi_main, dec_main)


# SENSITIVITY ANALYSIS (PLS -> VIP Scores)
input_table <- read.csv("data/estimates/atacora_DA_inputs_v8.csv")

sim_T0 <- simulation_results; sim_T0$y <- setNames(data.frame(decisive("G", "V0")), dec_T0)          # the decisive comparison as the result
pls_T0 <- plsr.mcSimulation(object     = sim_T0,
                            resultName = dec_T0,
                            ncomp      = 1)
plot_pls(pls_T0, input_table = input_table, threshold = 1)

sim_main <- simulation_results; sim_main$y <- setNames(data.frame(decisive("comm", "V1")), dec_main)
pls_main <- plsr.mcSimulation(object     = sim_main,
                              resultName = dec_main,
                              ncomp      = 1)
plot_pls(pls_main, input_table = input_table, threshold = 1)
