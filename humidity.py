from math import atan, e, log10

import pandas as pd


# Formulas taken from academic paper here:
#http://www.vaisala.com/Vaisala%20Documents/
#Application%20notes/Humidity_Conversion_Formulas_B210973EN-F.pdf


constants = pd.DataFrame(
    {
        '-20_50': [6.116441, 7.591386, 240.7263, 0.083],
        '50_100': [6.004918, 7.337936, 229.3975, 0.017],
        '100_150': [5.856548, 7.27731, 225.1033, 0.003],
        '150_200': [6.002859, 7.290361, 227.1704, 0.007],
        '200_350': [9.980622, 7.388931, 263.1239, 0.395],
        '0_200': [6.089613, 7.33502, 230.3921, 0.368],
        '-70_0': [6.114742, 9.778707, 273.1466, 0.052]
    }, index=['A', 'm', 'Tn', 'max_error']
).T


def vap_pres_sat(temp):
    """Return vapor saturation pressure in hPa, for air. temp is in C."""

    T = temp + 273.15  # Temperature in K
    Tc = 647.096  # Critical temperature, in K
    Pc = 220640  # Critical pressure in hPa
    c1 = -7.85951783
    c2 = 1.84408259
    c3 = -11.7866497
    c4 = 22.6807411
    c5 = -15.9618719
    c6 = 1.80122502

    v = 1 - (T / Tc)

    # Water vapour saturation pressure. Note: This is only valid between 0 and
    # 373c; ie not ice. There's a different formula for that.
    return e ** ((Tc / T) * (c1*v + c2*v**1.5 + c3*v**3 + c4*v**3.5 + c5*v**4 +
                             c6*v**7.5)) * Pc


def rel_hum(Td, Tambient):
    """Calculate relative humidity."""
    # Td is the dewpoint, Tambient is air temperature, both in C.

    return vap_pres_sat(Td) / vap_pres_sat(Tambient)


def enthalpy(temp, X):
    """Calculate enthalpy, in kJ/kg."""
    # X is mixing ratio.
    return temp * (1.01 + .00189 * X) + 2.5 * X


def mixing_ratio(Ptot, temp=None, RH=None, Pw=None):
    """Calculate mixing ratio, in g/kg; the mass of water vapor / 
    mass of dry gas. Specific humidity is a related concept: the mass of water
    vapor / total air mass. Must specify either temp, or RH and Pw."""

    # Ptot is the total air pressure. Pw is the vapor pressure. Both are in hPa.
    # B is in g / kg, and depends on the gas; this value is valid for air.

    # Input arguments are Ptot and Pw.
    if Pw is not None and RH is None and temp is None:
        B = 621.9907
        return B * Pw / (Ptot - Pw)

    # Input arguments are Ptot, temp and RH.
    elif temp is not None and RH is not None and Pw is None:
        Pws = vap_pres_sat(temp)
        Pw = Pws * RH
        return mixing_ratio(Ptot, Pw=Pw)

    else:
        raise AttributeError("Must specificy either temp, or RH and Pw.")


def abs_humidity(temp, RH=None, Pw=None):
    """Calculate absolute humidity, in g/m**3. Must specify one of temp or Pw."""
    # Pw is the vapor pressure, in hPa. temp is in C.

    # Input arguments are temp and Pw.
    if Pw is not None and RH is None:
        C = 2.16679  # Constant, in gK / J
        T = temp + 273.15
        Pw *= 100  # Convert from hPa to Pa, for desired output units.

        return C * Pw / T

    # Input arguments are temp and RH.
    elif RH is not None and Pw is None:
        Pws = vap_pres_sat(temp)
        Pw = Pws * RH
        return abs_humidity(temp, Pw=Pw)

    else:
        raise AttributeError("Must specificy exactly one of rel_hum and Pw.")


def dewpoint(RH, temp=None, Pws=None, P_ratio=1):
    """Calculate the dewpoint, in C. Must specify either Pws, or temp. temp
    can be specified along with Pws to help find correct constants."""

    # P_ratio is used when for calculating the dewpoint at a different
    # pressure. It's the ratio of the new pressure the the old. # todo Backwards?

    # Pws is specified. temp is optional, and used only to determined which
    # constants to use. If unspecified, use for temp range of -20 to 50C.
    if Pws is not None:
        Pw = Pws * RH * P_ratio

        # todo temp way of table handling
        A = constants.loc['-20_50', 'A']
        m = constants.loc['-20_50', 'm']
        Tn = constants.loc['-20_50', 'Tn']

        return Tn / (m / log10(Pw/A) - 1)

    # Pw is unspecified. Calculate it using temp.
    elif temp is not None and Pws is None:
        Pws = vap_pres_sat(temp)
        return dewpoint(RH, temp=temp, Pws=Pws)

    else:
        raise AttributeError("Must specfify at least one of temp and PWs.")


def dewpoint_depression(temp, RH):
    """Calculate dewpoint depression; the difference between (dry-bulb)
    temperature and dewpoint, in C."""
    return temp - dewpoint(RH, temp)


def wetbulb(T_dry, RH):
    """Estimate wet bulb temperature, given dry bulb temperature and relative
    humidity."""
    # From http://journals.ametsoc.org/doi/pdf/10.1175/JAMC-D-11-0143.1
    # Note that this isn't an exact formula, but is based on a best-fit plot
    # of recorded data. Assumes sea level pressure of 1013.25 hPa.

    RH *= 100  # The paper this formula reference using RH as a percent
    # instead of a portion. This formula takes a portion as input.

    # c1-6 are constants.
    c1 = 0.151977
    c2 = 8.3131659
    c3 = 1.676331
    c4 = 0.00391838
    c5 = 0.023101
    c6 = 4.686035

    return T_dry * atan(c1 * (RH + c2)**.5) + atan(T_dry + RH) - atan(RH - c3) +\
           c4 * RH**1.5 * atan(c5 * RH) - c6


def report(temp, RH, air_pressure, precision=2):
    """Display several humidity metrics for a given temperature, relative humidity,
    and air pressure. temp is in C, RH is a portion, and air_pressure is in hPa."""

    # precision is the number of decimal places to round the results to.
    # Note: Air pressure currently only affects the mixing ratio result.

    dewpoint_ = dewpoint(RH, temp=temp)
    
    mixing_ratio_ = mixing_ratio(air_pressure, temp=temp, RH=RH)
    abs_humidity_ = abs_humidity(temp, RH=RH)
    wetbulb_temp = wetbulb(temp, RH)
    vap_pres_sat_ = vap_pres_sat(temp)
    vap_pres = vap_pres_sat_ * RH

    dewpoint_depression_ = temp - dewpoint_
    wetbulb_depression_ = temp - wetbulb_temp

    vars = (dewpoint_, mixing_ratio_, abs_humidity_, wetbulb_temp,
           dewpoint_depression_, wetbulb_depression_, vap_pres_sat_, vap_pres)

    vars_rounded = (round(var, precision) for var in vars)

    display = \
"""\nDewpoint: {} °C
Mixing ratio: {} g/Kg
Absolute humidity: {} g/m^3
Wetbulb temperature: {} °C
Dewpoint depression: {} °C
Wetbulb depression: {} °C
Vapor pressure saturation: {} hPa
Vapor pressure: {} hPa""".format(*vars_rounded)

    print(display)

