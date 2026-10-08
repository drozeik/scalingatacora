The twelve displayed equations of the valuation functions, verbatim from the appendix source.
tests/testthat/test-documentation.R checks that FUNCTIONS.md and FUNCTIONS.de.md show them unchanged.

<!-- eq-money -->
```math
NB_G = y_G + \omega_W\, w_h\, t_G + \kappa\, p_f\, c_G ,
```

<!-- eq-value -->
```math
V(d) = \mathbb{E}_\theta\, W\big(NB(d,\theta);\,p\big),
\qquad
d^{*} = \arg\max_{d \in D}\, V(d).
```

<!-- eq-rules -->
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

<!-- eq-marginalisation -->
```math
M = \frac{1}{S} \sum_{s=1}^{S}
\mathbf{1}\Big[\, W\big(NB(d^{*},\theta_s)\big) > 0 \;\wedge\; \min_{g}\, NB_g(d^{*},\theta_s) < 0 \,\Big].
```

<!-- eq-units -->
```math
NB_k(d,\theta) = \sum_{g} c_{kg}\, NB_g(d,\theta).
```

<!-- eq-voi -->
```math
\begin{aligned}
A &= \max_{d}\; \mathbb{E}_\theta\, W\big(NB(d,\theta)\big),\\
B &= \max_{(d_1,\dots,d_G)}\; \mathbb{E}_\theta\, W\big(NB_1(d_1,\theta),\dots,NB_G(d_G,\theta)\big),\\
C &= \mathbb{E}_\theta\, \max_{d}\; W\big(NB(d,\theta)\big),\\
D &= \mathbb{E}_\theta\, W\Big(\max_{d} NB_1(d,\theta),\dots,\max_{d} NB_G(d,\theta)\Big).
\end{aligned}
```

<!-- eq-voi-profiles -->
```math
B = \max_{r \in R}\; \mathbb{E}_\theta\, W\big(NB(r,\theta)\big),
\qquad
D = \mathbb{E}_\theta\, \max_{r \in R}\; W\big(NB(r,\theta)\big).
```

<!-- eq-reference -->
```math
NB_g(d,\theta;\,r) = Y_g(d,\theta;\,r) - Y_g(d_0,\theta;\,r),
```

<!-- eq-fidelity -->
```math
V_d(f) = \mathbb{E}_\theta\, W\big(f \cdot NB(d,\theta)\big),
\qquad
f^{*}_d = \min\Big\{ f \in [0,1] : V_d(f) \ge \max_{e \ne d} V_e(1) \Big\}.
```

<!-- eq-evppi -->
```math
\mathrm{EVPI}_j = \mathbb{E}_{\theta_j}\Big[\max\big(\mathbb{E}(\Delta \mid \theta_j),\,0\big)\Big] - \max\big(\mathbb{E}\,\Delta,\,0\big).
```

<!-- eq-boundary -->
```math
NB_{\text{comm}} = NB_G + K\, NB_H + NB_O ,
```
