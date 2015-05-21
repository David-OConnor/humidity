from math import e, log, log10

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
    """Return vapor saturation pressure, for air. temp is in C."""

    T = temp + 273.15  # Temperature in K
    Tc = 647.096  # Critical temperature, in K
    Pc = 220640  # Critical pressure in hPa
    C1 = -7.85951783
    C2 = 1.84408259
    C3 = -11.7866497
    C4 = 22.6807411
    C5 = -15.9618719
    C6 = 1.80122502

    v = 1 - (T / Tc)

    # Water vapour saturation pressure. Note: This is only valid between 0 and
    # 373C; ie not ice. There's a different formula for that.
    return e ** ((Tc / T) * (C1*v + C2*v**1.5 + C3*v**3 + C4*v**3.5 + C5*v**4 +
                             C6*v**7.5)) * Pc


def dewpoint(Pws, rel_hum, temp=30):
    """Calculate the dewpoint."""

    Pw = Pws * rel_hum
    # todo add bit about different pressure ratio.

    # todo temp way of table handling
    A = constants.loc['-20_50', 'A']
    m = constants.loc['-20_50', 'm']
    Tn = constants.loc['-20_50', 'Tn']

    return Tn / (m / log10(Pw/A) - 1)


def rel_hum(Td, Tambient):
    """Calculate relative humidity."""
    # Td is the dewpoint, Tambient is air temperature, both in C.

    return vap_pres_sat(Td) / vap_pres_sat(Tambient)


def mixing_ratio(Pw, Ptot):
    """Calculate mixing ratio; the mass of water vapor / mass od dry gas.
     ie specific humidity."""
    # Ptot is the total air pressure. Pw is the vapor pressure.
    # B is in g / kg, and depends on the gas; this value is valid for air.
    B = 621.9907

    return B * Pw / (Ptot - Pw)


def enthalpy(temp, X):
    """Calculate enthalpy, in kJ/kg."""
    # X is mixing ratio, ie specific humidity.
    return temp * (1.01 + .00189 * X) + 2.5 * X


def abs_humidity(temp, Pw):
    """Calculate absolute humidity, in g/m**3"""
    # Pw is the vapor pressure, in hPa. temp is in C.

    C = 2.16679  # Constant, in gK / J
    T = temp + 273.15
    Pw *= 100  # Convert from hPa to Pa, for desired output units.

    return C * Pw / T


def dewpoint2(temp, rel_hum):
    Pws = vap_pres_sat(temp)

    return dewpoint(Pws, rel_hum, temp)


def abs_humidity2(temp, rel_hum):
    Pws = vap_pres_sat(temp)
    Pw = Pws * rel_hum

    return abs_humidity(temp, Pw)