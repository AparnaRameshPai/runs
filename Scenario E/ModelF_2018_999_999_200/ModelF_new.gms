* CHANGE LOG (Oct 2026), Model F: post-processing only, solve unchanged
* F1     SW_Check adds back eps_reg*SUM(T, d_plus.L(T)) (Model F)
* F2/R1  NodalPS also subtracts C_inv_vre(E)*b_vre.L(N,E) (both)
* F3     Fuel_Value_Max -> Fuel_Value = SUM of ABS(NucFuelMin.M) (Model F)
*        Flex_Value_Max -> Flex_Value = ABS(NucFlexStockInit.M('t1') + NucAnnualLimit.M) (Model F)
*        Reason: m_flex is a Positive variable, so its zero bound can carry the multiplier and NucFlexStockNonNeg
*        then shows EPS. M0 is the right-hand side of NucFlexStockInit and NucAnnualLimit only, so their
*        multipliers give the value of one more MW of budget.
*        Flex_Value_Init = ABS(NucFlexStockInit.M('t1')) kept as a read-only diagnostic (Model F)
*        Labels: Flex_Value, Daily_Value_Max, Weekly_Value_Max units now [EUR/MW] (Model F)
* F4/R2  Curtailment (Curt, Avail_TWh) uses G_vre+b_vre.L instead of a_vre.L (both)
* F5     REVERTED, not applied: Avg_Price_SE3 keeps the original SUM(T, ABS(EnergyBalance.M('se3',T))) / CARD(T) (both)
* F6     Commented GDX/Excel block: PS -> PS_Op (both)
* F7     Nuc/Hyd Max, Min, Range labels [MWh] -> [MW] (both)
* R4     Removed hardcoded-zero scalars Fuel_Value_Max, Flex_Value_Max, Fuel_End_TWh, Flex_Used_Pct (Model R)
* R5     Added C_max, cycle_depth, Up_Total, Equiv_Cycles, Budget_Used_Pct; removed Cycles_10pct and Cycles_20pct from the Display (Model R)

* Cost-minimizing LP for generation expansion: Multi-zone MCDA implementation

*$INCLUDE mcda_test_data_2024.gms
$INCLUDE Nordic_data_ModelF_new.gms


$Oneolcom  

Scalar starttime;
starttime = jnow;

Scalars
DN Set to '1' to turn off all adoption /1/
NAC Set to '1' to turn off all availability costs /0/
NIC Set to '1' to turn off all investment costs /0/
NX Set to '1' to turn off all net imports /0/
NUC Indicate derating of nuclear capacity /0/
;

Variables
OF_Welfare     Objective function value for social welfare maximization
*OF_Cost        Objective function value for cost minimisation
*OF_Emissions   Objective function value for emission minimisation
*q              Objective function value for minimax implementation
f(L,T)         Power flow on line l in period t
;

Positive Variables
q(N,T)        Electricity consumption at node n in period t 
a_gen(N,U)    Generation capacity made available of thermal unit u at node n
a_vre(N,E)    Generation capacity made available of VRE unit e at node n
a_hyd(N,W)    Generation capacity made available of hydro unit w at node n
b_vre(N,E)    Generation-capacity adopted of VRE unit e at node n
gg_gen(N,T,U) Generation by thermal unit u at node n in period t
gg_vre(N,T,E) Generation by VRE unit e at node n in period t
r_in(N,T,W)   Volume of water pumped by hydro unit w at node n in period t
r_out(N,T,W)  Volume of water turbined by hydro unit w at node n in period t
r_sto(N,T,W)  Volume of water stored by hydro unit w at node n in period t
z(N,T,W)      Volume of water spilled by hydro unit w at node n in period t
S_nuc(N,T)    Nuclear fuel remaining at node n in period t    !! newly added
d_plus(T)     Positive variation in nuclear fleet output in period t    !! newly added
m_flex(T)          Remaining nuclear flexibility stock in period t   !! newly added
g_fleet(T)    Total nuclear fleet output    !! newly added
;

* Added to prevent capacity availability where it does not exist
a_gen.fx(N,U)$(NOT ntou(N,U))=0;
a_vre.fx(N,E)$(NOT ntoe(N,E))=0;
a_hyd.fx(N,W)$(NOT ntow(N,W))=0;

* Added to turn off investment option
b_vre.fx(N,E)$(DN eq 1)=0;

* Added to turn off availability costs
C_ava_gen(U)$(NAC eq 1)=0;
C_ava_vre(E)$(NAC eq 1)=0;
C_ava_hyd(W)$(NAC eq 1)=0;

* Added to turn off investment costs
C_inv_vre(E)$(NIC eq 1)=0;

* Added to turn off net imports
X(T,N)$(NX eq 1)=0;

* Added to derate nuclear capacity
G_gen(N,'nuclear')=(1-NUC)*G_gen(N,'nuclear');


gg_gen.fx(N,T,U)$(G_gen(N,U) eq 0) = 0;
gg_vre.fx(N,T,E)$(G_vre(N,E) eq 0) = 0;
r_out.fx(N,T,W)$(Y_hyd(N,W) eq 0) = 0;
r_in.fx(N,T,'ror') = 0;
r_in.fx(N,T,'res') = 0;
r_in.fx(N,T,'phs')$(RR_max(N,'phs') eq 0) = 0;
r_sto.fx(N,T,'ror') = 0;

Display G_gen;

Scalar eps_reg 'Tiny regularization penalty on d_plus, EUR/MWh' /0.01/;

Equations

WelfareEq           Objective function for social welfare maximization
EnergyBalance       Energy balance by node and by period
FlowPosLimit        Power-flow limit in positive direction by line and by period
FlowNegLimit        Power-flow limit in negative direction by line and by period
GenCapacityLimit    Thermal generation limit for each technology by period
GenAvailLimit       Thermal capacity limit for each technology
VRECapacityLimit    VRE generation limit for each technology by period
VREAvailLimit       VRE capacity limit for each technology
VREInvLimit         VRE adoption limit for each technology
GenUpRampLimit      Thermal generation up ramping by technology and by period
GenDownRampLimit    Thermal generation down ramping by technology and by period
StorageBalance      Storage balance by hydro unit at each node and by period
StorageMaxLimit     Maximum storage volume by technology and by period
StorageMinLimit     Minimum storage volume by technology and by period
HydroPumpLimit      Maximum pumped-hydro charging by technology and by period
HydroCapacityLimit  Hydro generation limit for each technology by period
HydroAvailLimit     Hydro capacity limit for each technology


* Newly added
NucFuelBalance  
NucFuelMin
NucFuelMax
NucFleetOutput
NucPosVar
NucPosVarNonNeg
NucPosVarIniVal
NucFlexStockInit
NucFlexStockEvol
NucFlexStockNonNeg
NucDailyLimit
NucWeeklyLimit
NucAnnualLimit

;

WelfareEq..
   OF_Welfare =E=
   SUM((N,T), D_int(N,T) * q(N,T) - 0.5*D_slp(N,T) * q(N,T) * q(N,T))
   - SUM((N,T,U)$thermal_generators(N,U), (C_opr(U) + S * P(U)) * gg_gen(N,T,U))
   - SUM((N,E)$vre_generators(N,E), C_ava_vre(E) * a_vre(N,E) + C_inv_vre(E) * b_vre(N,E))
   - SUM((N,U)$thermal_generators(N,U), C_ava_gen(U) * a_gen(N,U))
   - SUM((N,W)$hyd_generators(N,W), C_ava_hyd(W) * a_hyd(N,W))
   - eps_reg * SUM(T, d_plus(T));
   
$onText

WelfareEq.. 
   OF_Welfare =E=
   SUM((N,T), D_int(N,T) * q(N,T) - 0.5*D_slp(N,T) * q(N,T) * q(N,T))
   - SUM((N,T,U)$thermal_generators(N,U), (C_opr(U) + S * P(U)) * gg_gen(N,T,U))
   - SUM((N,E)$vre_generators(N,E), C_ava_vre(E) * a_vre(N,E) + C_inv_vre(E) * b_vre(N,E))
   - SUM((N,U)$thermal_generators(N,U), C_ava_gen(U) * a_gen(N,U))
   - SUM((N,W)$hyd_generators(N,W), C_ava_hyd(W) * a_hyd(N,W));
   
$offText
   
* Constraint 1 : Power Balance 
EnergyBalance(N,T).. 
    SUM(U$thermal_generators(N,U), gg_gen(N,T,U))
  + SUM(E$vre_generators(N,E), gg_vre(N,T,E))
  + SUM(W$hyd_generators(N,W), Q_hyd(N,W)*r_out(N,T,W) - F_hyd(N,W)*r_in(N,T,W))
  + X(T,N)
  + TT(T)*V*SUM(L$NMinus(L,N), f(L,T))
  - TT(T)*V*SUM(L$NPlus(L,N), f(L,T))
  - q(N,T) =E= 0;
* Constraint 2a : Transmission-Capacity Limits
FlowPosLimit(L,T).. TT(T)*K_pos(L)-V*TT(T)*f(L,T)=G=0;
* Constraint 2b : Transmission-Capacity Limits
FlowNegLimit(L,T).. TT(T)*K_neg(L)+V*TT(T)*f(L,T)=G=0;

* Constraint 3 : Generation Capacity
GenCapacityLimit(N,T,U)$thermal_generators(N,U).. TT(T)*a_gen(N,U)-gg_gen(N,T,U)=G=0;
* Constraint 3 extra : Additional feature for capacity withholding
GenAvailLimit(N,U)$thermal_generators(N,U).. G_gen(N,U)-a_gen(N,U)=G=0;
* Constraint 4 : VRE generation
* VRE generation <= availability * available capacity
VRECapacityLimit(N,T,E)$vre_generators(N,E).. A(T,E,N)*TT(T)*a_vre(N,E)-gg_vre(N,T,E)=G=0;
* Constraint 4 : Available VRE capacity cannot exceed existing capacity
VREAvailLimit(N,E)$vre_generators(N,E).. G_vre(N,E)+b_vre(N,E)-a_vre(N,E)=G=0;
* Constraint 4 : New VRE capacity cannot exceed M * existing capacity ; doesnt allow unlimited investment
VREInvLimit(N,E)$vre_generators(N,E).. M(N,E)*G_vre(N,E)-b_vre(N,E)=G=0;

* Constraint 5a : Ramping up constraint
GenUpRampLimit(N,T,U)$( ORD(T) ge 2 AND thermal_generators(N,U) AND not sameas(U,'nuclear')).. -gg_gen(N,T,U)+gg_gen(N,T-1,U)+TT(T)*R_up(U)*a_gen(N,U)=G=0;
* Constraint 5b : Ramping down constraint   
GenDownRampLimit(N,T,U)$( ORD(T) ge 2 AND thermal_generators(N,U) AND not sameas(U,'nuclear')).. gg_gen(N,T,U)-gg_gen(N,T-1,U)+TT(T)*R_down(U)*a_gen(N,U)=G=0;
* Constraint 6 : Storage Balance without efficiency terms
StorageBalance(N,T,W)$nhconnect(N,W).. -r_sto(N,T,W)+r_sto(N,T-1,W)$(ORD(T) > 1)+RR_ini(N,W)$( ORD(T) eq 1 )+r_in(N,T,W)-r_out(N,T,W)-z(N,T,W)+II_hourly_ror(N,T)$( ORD(W) eq 1)+II_hourly_res(N,T)$( ORD(W) eq 2)=E=0;
* Constraint 7a :  Storage limits
StorageMaxLimit(N,T,W)$(RR_max(N,W) > 0).. RR_max(N,W)-r_sto(N,T,W)=G=0;
* Constraint 7b :  Storage limits ; only enforced at the final period
StorageMinLimit(N,T,W)$(ORD(T) eq CARD(T) AND RR_max(N,W) > 0).. -RR_min(N,W)+r_sto(N,T,W)=G=0;
* Constraint 8a : Charging Rate Limit
HydroPumpLimit(N,T,W)$(RR_max(N,W) > 0).. TT(T)*RR_in(N,W)*RR_max(N,W)-r_in(N,T,W)=G=0;
* Constraint 8b : Discharging Rate Limit ; depends on how much hydro capacity is made available ; check if it's acceptable for perfect competition 
HydroCapacityLimit(N,T,W)$hyd_generators(N,W).. TT(T)*a_hyd(N,W)-Q_hyd(N,W)*r_out(N,T,W)=G=0;
HydroAvailLimit(N,W)$hyd_generators(N,W).. Y_hyd(N,W)-a_hyd(N,W)=G=0;


* Newly added 

* Constraint 9 : Nuclear fuel balance
NucFuelBalance(N,T)$n_nuc(N)..  S_nuc(N,T) =E= (S_ini(N) - TT(T) * gg_gen(N,T,'nuclear')) $ T_ini(T) + (S_nuc(N,T-1) - TT(T) * gg_gen(N,T,'nuclear')) $ (NOT T_ini(T));

* Constraint 10a : Minimum nuclear fuel constraint
NucFuelMin(N,T)$n_nuc(N).. S_nuc(N,T) =G= S_min(N);
* Constraint 10a : Maximum nuclear fuel constraint
NucFuelMax(N,T)$n_nuc(N).. S_nuc(N,T) =L= S_max(N);
* Constraint 11 : Nuclear fleet output
NucFleetOutput(T).. g_fleet(T) =E= SUM(N$n_nuc(N), gg_gen(N,T,'nuclear'));
* Constraint 12a : Positive variation lower bound
NucPosVar(T)$(ORD(T) GT 1).. d_plus(T) - (g_fleet(T) - g_fleet(T-1)) =G= 0;
* Constraint 12b : Positive variation non-negativity
NucPosVarNonNeg(T).. d_plus(T) =G= 0;
* Constraint 12c 
NucPosVarIniVal(T)$T_ini(T).. d_plus(T) =E= 0;

* Constraint 13a : Initial flexibility stock at start of year
NucFlexStockInit(T)$T_ini(T).. m_flex(T) =E= N_reactors * C_max * cycle_depth * P_reactor;

* Constraint 13b : Flexibility stock evolution
NucFlexStockEvol(T)$(NOT T_ini(T)).. m_flex(T) =E= m_flex(T-1) - d_plus(T);
* Constraint 13b : Flexibility stock non-negativity
NucFlexStockNonNeg(T).. m_flex(T) =G= 0;
* Constraint 14a : Daily cycle limit
NucDailyLimit(dy).. sum(T$TD(T,dy), d_plus(T)) =L= N_reactors * C_daily * cycle_depth * P_reactor;
* Constraint 14b : Weekly cycle limit
NucWeeklyLimit(wy).. sum(T$TW(T,wy), d_plus(T)) =L= N_reactors * C_weekly * cycle_depth * P_reactor;
* Constraint 14c : Annual cycle limit (redundant with stock but included for completeness)
NucAnnualLimit.. sum(T, d_plus(T)) =L= N_reactors * C_max * cycle_depth * P_reactor;



MODEL GEP_QP /WelfareEq,EnergyBalance, FlowPosLimit, FlowNegLimit, GenCapacityLimit, GenAvailLimit, VRECapacityLimit, VREAvailLimit, VREInvLimit, GenUpRampLimit, GenDownRampLimit, StorageBalance, StorageMaxLimit, StorageMinLimit, HydroPumpLimit, HydroCapacityLimit, HydroAvailLimit,
             NucFuelBalance, NucFuelMin, NucFuelMax, NucFleetOutput, NucPosVar, NucPosVarNonNeg, NucPosVarIniVal, NucFlexStockInit, NucFlexStockEvol, NucFlexStockNonNeg,
             NucDailyLimit,
             NucWeeklyLimit,
             NucAnnualLimit/; !!newly added


option QCP = Gurobi;
*option LP = Gurobi;
option optcr = 0.0000;

SOLVE GEP_QP USING QCP MAXIMIZING OF_Welfare;

Parameters
    Consumption(N,T)        Electricity consumption (endogenous demand)
    Price(N,T)              Price from inverse demand at consumed quantity
    NetImport(N,T)          Net imports by node and period
    Em(N,T)                 Emissions by node and period
    NodalEm(N)              Emissions by node
    Flow(L,T)               Power flow on line L in period T
    CS(N,T)                 Consumer Surplus by node and period
    NodalCS(N)              Consumer Surplus by node
    PS_Op(N,T)              Producer Surplus from operations by node and period 
    NodalPS(N)              Producer Surplus by node
    MS(T)                   Merchandising Surplus by period
    GR(T)                   Government Carbon Revenue by period
    IC_NT(N,T)              Cost of exogenous net imports by node and period
    Charging(N,T,W)         Hydro charging by node, plant type, and period
    Stored(N,T,W)           Hydro storage by node, plant type, and period
    Stored_W(W)             Hydro storage by plant type
    ThermalGen(N,T,U)       Thermal generation by node, plant type, and period
    Gen_U(U)                Thermal generation by plant type
    VREGen(N,T,E)           VRE generation by node, plant type, and period
    Gen_E(E)                VRE generation by plant type
    HydGen(N,T,W)           Net hydro generation by node, plant type, and period
    Gen_W(W)                Net hydro generation by plant type
    
;

Scalars

    Tot_CS              Total Consumer Surplus
    Tot_PS              Total Producer Surplus
    Tot_MS              Total Merchandising Surplus
    Tot_GR              Total Government Carbon Revenue
    Tot_IC              Total cost of exogenous net imports
    Tot_Ch              Total hydro charging
    Tot_SW              Total Social Welfare
    TotEm               Total Emissions
    SW_Check            Verification: OF.L + GR - IC should equal Tot_SW
    
;

Consumption(N,T) = q.L(N,T);
Price(N,T) = D_int(N,T) - D_slp(N,T) * Consumption(N,T);
Flow(L,T) = TT(T) * V * f.L(L,T);
NetImport(N,T) = - SUM(L$NPlus(L,N), Flow(L,T)) + SUM(L$NMinus(L,N), Flow(L,T));
Charging(N,T,W) = r_in.L(N,T,W);
Tot_Ch = SUM((N,T,W), Charging(N,T,W));
Stored(N,T,W) = r_sto.L(N,T,W);
Stored_W(W) = SUM((N,T), Stored(N,T,W));
ThermalGen(N,T,U) = gg_gen.L(N,T,U);
Gen_U(U) = SUM((N,T), ThermalGen(N,T,U));
VREGen(N,T,E) = gg_vre.L(N,T,E);
Gen_E(E) = SUM((N,T), VREGen(N,T,E));
HydGen(N,T,W) = Q_hyd(N,W)*r_out.L(N,T,W) - F_hyd(N,W)*r_in.L(N,T,W);
Gen_W(W) = SUM((N,T), HydGen(N,T,W));

CS(N,T) = D_int(N,T)*Consumption(N,T)-0.5 * D_slp(N,T) * Consumption(N,T) * Consumption(N,T)-Price(N,T)*Consumption(N,T);
NodalCS(N) = SUM(T, CS(N,T));
Tot_CS = SUM(N, NodalCS(N));
 
PS_Op(N,T) = Price(N,T) * (
              SUM(U, gg_gen.L(N,T,U))
            + SUM(E, gg_vre.L(N,T,E))
            + SUM(W, Q_hyd(N,W)*r_out.L(N,T,W) - F_hyd(N,W)*r_in.L(N,T,W))
          )
          - SUM(U, (C_opr(U) + S * P(U)) * gg_gen.L(N,T,U))
          ;
        
*subtarct availability cost
NodalPS(N) = SUM(T, PS_Op(N,T))- ( SUM(E, C_ava_vre(E) * a_vre.L(N,E) + C_inv_vre(E) * b_vre.L(N,E))
            + SUM(U, C_ava_gen(U) * a_gen.L(N,U))
            + SUM(W, C_ava_hyd(W) * a_hyd.L(N,W))
            );
Tot_PS = SUM(N, NodalPS(N));

MS(T) = SUM(N, Price(N,T) * NetImport(N,T));
Tot_MS = SUM(T, MS(T));

Em(N,T) = SUM(U, P(U) * gg_gen.L(N,T,U));
NodalEm(N) = SUM(T, Em(N,T));
TotEm = SUM(N, NodalEm(N));

GR(T) = S * SUM(N, Em(N,T));
Tot_GR = SUM(T, GR(T));

IC_NT(N,T)= X(T,N)*Price(N,T);
Tot_IC=SUM((N,T),IC_NT(N,T));

Tot_SW = Tot_CS + Tot_PS + Tot_MS + Tot_GR;

SW_Check = OF_Welfare.L + eps_reg*SUM(T, d_plus.L(T)) + Tot_GR - Tot_IC;

Scalar Tot_Consumption          Total annual electricity consumption [MWh];
Tot_Consumption = SUM((N,T), Consumption(N,T));
Display Tot_Consumption;

Scalars
    Nuc_Max     'Max hourly nuclear output [MW]'
    Nuc_Min     'Min hourly nuclear output [MW]'
    Nuc_Range   'Max minus min hourly nuclear output [MW]'
    Hyd_Max     'Max hourly reservoir-hydro output [MW]'
    Hyd_Min     'Min hourly reservoir-hydro output [MW]'
    Hyd_Range   'Max minus min hourly reservoir-hydro output [MW]'
;

Nuc_Max   = SMAX((N,T)$n_nuc(N), gg_gen.L(N,T,'nuclear'));
Nuc_Min   = SMIN((N,T)$n_nuc(N), gg_gen.L(N,T,'nuclear'));
Nuc_Range = Nuc_Max - Nuc_Min;

Hyd_Max   = SMAX((N,T)$ntow(N,'res'), r_out.L(N,T,'res'));
Hyd_Min   = SMIN((N,T)$ntow(N,'res'), r_out.L(N,T,'res'));
Hyd_Range = Hyd_Max - Hyd_Min;

Display Nuc_Max, Nuc_Min, Nuc_Range, Hyd_Max, Hyd_Min, Hyd_Range;


$onText
* --- Gap Diagnostics ---
Scalars
    Tot_DSR_Cost       'Total DSR cost [EUR]'
    Tot_Ava_Cost       'Total availability cost [EUR]'
    Tot_Inv_Cost       'Total investment cost [EUR]'
    Gap                'Tot_SW - SW_Check [EUR]'
    Gap_Pct            'Gap as percentage of Tot_SW [%]'
;

*Tot_DSR_Cost = SUM((N,T), C_dsr(T,N) * dd.L(N,T));
Tot_Ava_Cost = SUM((N,E), C_ava_vre(E) * a_vre.L(N,E))
             + SUM((N,U), C_ava_gen(U) * a_gen.L(N,U))
             + SUM((N,W), C_ava_hyd(W) * a_hyd.L(N,W));
Tot_Inv_Cost = SUM((N,E), C_inv_vre(E) * b_vre.L(N,E));

Gap     = Tot_SW - SW_Check;
Gap_Pct = 100 * (Tot_SW - SW_Check) / Tot_SW;

Display Tot_Ava_Cost, Tot_Inv_Cost, Gap, Gap_Pct;

Scalar Gap_Alt;
Gap_Alt = Tot_CS + Tot_PS + Tot_MS - OF_Welfare.L;
Display Gap_Alt;
$offText

* --- Nuclear Constraint Diagnostics ---
$ontext
Scalars
    Fuel_Min_Binding    Hours where NucFuelMin is binding
    Fuel_Max_Binding    Hours where NucFuelMax is binding
    Flex_NonNeg_Binding Hours where FlexStockNonNeg is binding
    Daily_Binding       Days where DailyLimit is binding
    Weekly_Binding      Weeks where WeeklyLimit is binding
;

Fuel_Min_Binding = SUM((N,T)$(ABS(NucFuelMin.M(N,T)) > 1e-6), 1);
Fuel_Max_Binding    = SUM((N,T)$(NucFuelMax.M(N,T) > 1e-6), 1);
Flex_NonNeg_Binding = SUM(T$(NucFlexStockNonNeg.M(T) > 1e-6), 1);
Daily_Binding       = SUM(dy$(NucDailyLimit.M(dy) > 1e-6), 1);
Weekly_Binding      = SUM(wy$(NucWeeklyLimit.M(wy) > 1e-6), 1);

Display NucAnnualLimit.M, NucFuelMin.M, NucFuelMax.M, NucFlexStockNonNeg.M,
        NucDailyLimit.M, NucWeeklyLimit.M,
        Fuel_Min_Binding, Fuel_Max_Binding, Flex_NonNeg_Binding,
        Daily_Binding, Weekly_Binding;

* Check remaining fuel and flexibility at end of year
Scalars
    Fuel_End_Year       'Remaining fuel at t8760 [MWh_e]'
    Flex_End_Year       'Remaining flexibility at t8760 [MW-cycle]'
    Fuel_Depleted_Pct   'Percentage of fuel consumed'
    Flex_Used_Pct       'Percentage of flexibility used'
;

Fuel_End_Year  = SUM(N$n_nuc(N), S_nuc.L(N,'t8760'));
Flex_End_Year  = m_flex.L('t8760');
Fuel_Depleted_Pct = 100 * (S_ini('se3') - Fuel_End_Year) / (S_ini('se3') - S_min('se3'));
Flex_Used_Pct     = 100 * (M0 - Flex_End_Year) / M0;

Display Fuel_End_Year, Flex_End_Year, Fuel_Depleted_Pct, Flex_Used_Pct;

Display Consumption, Price, Flow, NetImport,
        CS, NodalCS, Tot_CS,
        PS_Op, NodalPS, Tot_PS,
        MS, Tot_MS, IC_NT, Tot_IC, Tot_Ch, Stored, Stored_W, ThermalGen, Gen_U, VREGen, Gen_E, HydGen, Gen_W,
        Em, NodalEm, TotEm,
        GR, Tot_GR,
        Tot_SW, SW_Check;
$offText

* =============================================================================
* NUCLEAR CONSTRAINT DIAGNOSTICS
* =============================================================================

Scalars
    Fuel_Min_Binding    'Hours where NucFuelMin is binding (shadow price > 0)'
    Fuel_Max_Binding    'Hours where NucFuelMax is binding'
    Flex_NonNeg_Binding 'Hours where FlexStockNonNeg is binding'
    Daily_Binding       'Days where DailyLimit is binding'
    Weekly_Binding      'Weeks where WeeklyLimit is binding'
    Fuel_Value          'Total shadow value of usable fuel — absolute value [EUR/MWh]'
    Fuel_Value_t8760    'Fuel shadow price at final hour t8760 [EUR/MWh]'
    Flex_Value          'Total shadow value of cycling budget M0 — absolute value [EUR/MW]'
    Flex_Value_Init     'Dual of NucFlexStockInit at t1 — absolute value'
    Avg_Price_SE3       'Annual average SE3 price [EUR/MWh]'
    Nuc_Gen_TWh         'Annual nuclear generation [TWh]'
;

* Note: =G= constraints return NEGATIVE duals in GAMS — use ABS throughout
Fuel_Min_Binding    = SUM((N,T)$(ABS(NucFuelMin.M(N,T)) > 1e-6), 1);
Fuel_Max_Binding    = SUM((N,T)$(ABS(NucFuelMax.M(N,T)) > 1e-6), 1);
Flex_NonNeg_Binding = SUM(T$(ABS(NucFlexStockNonNeg.M(T)) > 1e-6), 1);
Daily_Binding       = SUM(dy$(ABS(NucDailyLimit.M(dy)) > 1e-6), 1);
Weekly_Binding      = SUM(wy$(ABS(NucWeeklyLimit.M(wy)) > 1e-6), 1);

Fuel_Value       = SUM((N,T)$n_nuc(N), ABS(NucFuelMin.M(N,T)));
Fuel_Value_t8760 = ABS(NucFuelMin.M('se3','t8760'));
Flex_Value       = ABS(NucFlexStockInit.M('t1') + NucAnnualLimit.M);
Flex_Value_Init  = ABS(NucFlexStockInit.M('t1'));
Avg_Price_SE3    = SUM(T, ABS(EnergyBalance.M('se3',T))) / CARD(T);
Nuc_Gen_TWh      = SUM((N,T)$n_nuc(N), gg_gen.L(N,T,'nuclear')) / 1e6;

* =============================================================================
* FUEL AND FLEXIBILITY STOCK AT END OF YEAR
* =============================================================================

Scalars
    Fuel_End_Year       'Remaining fuel at t8760 [MWh]'
    Flex_End_Year       'Remaining flexibility at t8760 [MWh-equivalent]'
    Fuel_Depleted_Pct   'Percentage of usable fuel consumed (S_ini - S_min = 100%)'
    Flex_Used_Pct       'Percentage of cycling budget consumed'
;

Fuel_End_Year     = SUM(N$n_nuc(N), S_nuc.L(N,'t8760'));
Flex_End_Year     = m_flex.L('t8760');
Fuel_Depleted_Pct = 100 * (S_ini('se3') - Fuel_End_Year) / (S_ini('se3') - S_min('se3'));
Flex_Used_Pct     = 100 * (M0 - Flex_End_Year) / M0;

* =============================================================================
* QUICK RESULTS SUMMARY — search for this in the listing file
* =============================================================================

Display
    Nuc_Gen_TWh,
    Fuel_Value,
    Fuel_Value_t8760,
    Flex_Value,
    Flex_Value_Init,
    Fuel_Min_Binding,
    Fuel_Max_Binding,
    Flex_NonNeg_Binding,
    Daily_Binding,
    Weekly_Binding,
    Fuel_End_Year,
    Flex_End_Year,
    Fuel_Depleted_Pct,
    Flex_Used_Pct,
    Avg_Price_SE3,
    Tot_SW,
    SW_Check,
    Tot_CS,
    Tot_PS,
    Tot_MS,
    Tot_GR,
    Tot_IC
;

Scalars
    Daily_Value_Max    'Maximum daily cycling shadow price [EUR/MW]'
    Weekly_Value_Max   'Maximum weekly cycling shadow price [EUR/MW]'
;

Daily_Value_Max  = SMAX(dy, ABS(NucDailyLimit.M(dy)));
Weekly_Value_Max = SMAX(wy, ABS(NucWeeklyLimit.M(wy)));

Display Daily_Value_Max, Weekly_Value_Max;

* =============================================================================
* FULL RESULTS DISPLAY
* =============================================================================

Display Consumption, Price, Flow, NetImport,
        CS, NodalCS, Tot_CS,
        PS_Op, NodalPS, Tot_PS,
        MS, Tot_MS, IC_NT, Tot_IC, Tot_Ch,
        Stored, Stored_W,
        ThermalGen, Gen_U,
        VREGen, Gen_E,
        HydGen, Gen_W,
        Em, NodalEm, TotEm,
        GR, Tot_GR,
        Tot_SW, SW_Check;





* =============================================================================
* GDX EXPORT
* =============================================================================
$ontext
execute_unload 'results_welfare.gdx',
    Consumption, Price, Flow, NetImport,
    CS, NodalCS, Tot_CS,
    PS_Op, NodalPS, Tot_PS,
    MS, Tot_MS,
    Em, NodalEm, TotEm,
    GR, Tot_GR,
    Tot_SW, SW_Check;
    
* =============================================================================
* EXCEL EXPORT
* =============================================================================

execute 'gdxxrw.exe results_welfare.gdx par=Consumption  rng=Consumption!A1';
execute 'gdxxrw.exe results_welfare.gdx par=Price        rng=Price!A1';
execute 'gdxxrw.exe results_welfare.gdx par=NetImport    rng=NetImport!A1';
execute 'gdxxrw.exe results_welfare.gdx par=CS           rng=CS!A1';
execute 'gdxxrw.exe results_welfare.gdx par=PS_Op        rng=PS!A1';
execute 'gdxxrw.exe results_welfare.gdx par=MS           rng=MS!A1';
execute 'gdxxrw.exe results_welfare.gdx par=Em           rng=Emissions!A1';
execute 'gdxxrw.exe results_welfare.gdx par=GR           rng=GR!A1';
execute 'gdxxrw.exe results_welfare.gdx par=Tot_SW       rng=TotSW!A1';
$offtext

* =============================================================================
* VRE CURTAILMENT
* =============================================================================

Parameters
    Curt(N,T,E)       'Curtailed VRE output [MW]'
    Avail_TWh(E)      'Available VRE output [TWh]'
    Curt_TWh(E)       'Curtailed VRE output [TWh]'
    Curt_Pct(E)       'Curtailed share of available output [%]'
    Curt_Hours        'Hours with any curtailment'
;

* Available minus dispatched; values below 0.5 MW are treated as solver noise
Curt(N,T,E)$vre_generators(N,E) = MAX(0, A(T,E,N)*TT(T)*(G_vre(N,E)+b_vre.L(N,E)) - gg_vre.L(N,T,E));
Curt(N,T,E)$(Curt(N,T,E) < 0.5) = 0;

Avail_TWh(E)  = SUM((N,T)$vre_generators(N,E), A(T,E,N)*TT(T)*(G_vre(N,E)+b_vre.L(N,E))) / 1e6;
Curt_TWh(E)   = SUM((N,T), Curt(N,T,E)) / 1e6;
Curt_Pct(E)$Avail_TWh(E) = 100 * Curt_TWh(E) / Avail_TWh(E);
Curt_Hours    = SUM(T$(SUM((N,E), Curt(N,T,E)) > 0), 1);

Display Avail_TWh, Curt_TWh, Curt_Pct, Curt_Hours;


scalar elapsed; elapsed = (jnow - starttime)*24*3600;

display elapsed