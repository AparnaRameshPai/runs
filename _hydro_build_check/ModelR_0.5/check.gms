Sets n, w, t;
$gdxin base.gdx
$load n w t
Parameters Yb(n,w), Xb(n,w), Mb(n,w), Nb(n,w), Ab(n,t,w), Rb(n,t), Sb(n,t);
$load Yb=Y_hyd Xb=RR_max Mb=RR_min Nb=RR_ini Ab=I Rb=II_hourly_ror Sb=II_hourly_res
$gdxin
Parameters Yh(n,w), Xh(n,w), Mh(n,w), Nh(n,w), Ah(n,t,w), Rh(n,t), Sh(n,t);
$gdxin hyd.gdx
$load Yh=Y_hyd Xh=RR_max Mh=RR_min Nh=RR_ini Ah=I Rh=II_hourly_ror Sh=II_hourly_res
$gdxin
Scalar h /0.5/, maxdiff;
maxdiff = SUM((n,w), ABS(Yh(n,w) - Yb(n,w)*h) + ABS(Xh(n,w) - Xb(n,w)*h) + ABS(Mh(n,w) - Mb(n,w)*h) + ABS(Nh(n,w) - Nb(n,w)*h))
        + SUM((n,t,w), ABS(Ah(n,t,w) - Ab(n,t,w)*h))
        + SUM((n,t), ABS(Rh(n,t) - Rb(n,t)*h) + ABS(Sh(n,t) - Sb(n,t)*h));
execute_unload 'check.gdx', maxdiff;
abort$(maxdiff > 0) 'hydro scaling is not exactly baseline x scale', maxdiff;
