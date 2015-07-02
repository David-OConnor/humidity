# Formulas taken from academic paper here:
#http://www.vaisala.com/Vaisala%20Documents/
#Application%20notes/Humidity_Conversion_Formulas_B210973EN-F.pdf

module Humidity

export enthalpy, vap_pres_sat, report

import DataFrames


constants = DataFrames.DataFrame(
    row_temp_mins = [-20, 50, 100, 150, 200, 0, -70],
    row_temp_maxes = [50, 100, 150, 200, 350, 200, 0],
    A = [6.116441, 6.004918, 5.856548, 6.002859, 9.980622, 6.089613, 6.113732],
    m = [7.591386, 7.337936, 7.27731, 7.290361, 7.388931, 7.33502, 9.778707],
    Tn = [240.7263, 229.3975, 225.1033, 227.1704, 263.1239, 230.3921, 273.1466],
    max_error = [0.083, 0.017, 0.003, 0.007, 0.395,  0.368, 0.052] 
)


function vap_pres_sat(temp::Real)
    #"""Return vapor saturation pressure, for air. temp is in C."""

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
    e^((Tc / T) * (C1*v + C2*v^1.5 + C3*v^3 + C4*v^3.5 + C5*v^4 +
                   C6*v^7.5)) * Pc
end


function rel_hum(dewpoint, ambient_temp)
    #"""Calculate relative humidity for a given temperature, and mixing ratio."""
    vap_pres_sat(dewpoint) / vap_pres_sat(ambient_temp)
end


function rel_hum2(Td, ambient_temp)
    #"""Calculate relative humidity, with"""
    # todo merge with rel_hum function above. Also, make this function.
    # todo add it to humidity.py too.
    # Td is the dewpoint, Tambient is dry bulb air temperature, both in C.

    return 0
end


function enthalpy(temp::Number, X::Number)
    #"""Calculate enthalpy, in kJ/kg."""
    # X is mixing ratio, ie specific humidity.
    temp * (1.01 + 0.00189X) + 2.5X
end


function mixing_ratio(Ptot; temp = 69, RH = 69, Pw = 69)
    #"""Calculate mixing ratio, in g/kg; the mass of water vapor / 
    #mass of dry gas. Specific humidity is a related concept: the mass of water
    #vapor / total air mass. Must specify either temp, or RH and Pw."""

    # Ptot is the total air pressure. Pw is the vapor pressure. Both are in hPa.
    # B is in g / kg, and depends on the gas; this value is valid for air.

    # Input arguments are Ptot and Pw.
    if Pw != 69 && RH == 69 && temp == 69
        B = 621.9907
        B * Pw / (Ptot - Pw)

    # Input arguments are Ptot, temp and RH.
    elseif temp != 69 && RH != 69 && Pw == 69
        Pws = vap_pres_sat(temp)
        Pw = Pws * RH
        mixing_ratio(Ptot, Pw=Pw)

    else
        throw(ArgumentError("Must specificy either temp, or RH and Pw."))
    end
end


function abs_humidity(temp; RH = 69, Pw = 69)
    #"""Calculate absolute humidity, in g/m^3. Must specify one of temp or Pw."""
    # Pw is the vapor pressure, in hPa. temp is in C.

    # Input arguments are temp and Pw.
    if Pw != 69 && RH == 69
        C = 2.16679  # Constant, in gK / J
        temp_kelvin = temp + 273.15
        Pw *= 100  # Convert from hPa to Pa, for desired output units.

        C * Pw / temp_kelvin

    # Input arguments are temp and RH.
    elseif RH != 69 && Pw == 69
        Pws = vap_pres_sat(temp)
        Pw = Pws * RH
        abs_humidity(temp, Pw=Pw)

    else
        throw(ArgumentError("Must specificy exactly one of rel_hum and Pw."))
    end
end


function dewpoint(RH; temp=69, Pws=69, P_ratio=1)
    #"""Calculate the dewpoint, in C. Must specify either Pws, or temp. temp
    #can be specified along with Pws to help find correct constants."""

    # P_ratio is used when for calculating the dewpoint at a different
    # pressure. It's the ratio of the new pressure the the old. # todo Backwards?

    # Pws is specified. temp is optional, and used only to determined which
    # constants to use. If unspecified, use for temp range of -20 to 50C.
    if Pws != 69
        Pw = Pws * RH * P_ratio

        # todo temp way of table handling
        A = constants[1, :A]
        m = constants[1, :m]
        Tn = constants[1, :Tn]
        
        Tn / (m / log10(Pw/A) - 1)

    # Pw is unspecified. Calculate it using temp.
    elseif temp != 69 && Pws == 69
        Pws = vap_pres_sat(temp)
        dewpoint(RH, temp=temp, Pws=Pws)

    else
        Throw(ArgumentError("Must specfify at least one of temp and PWs."))
    end
end


function wetbulb(temp_dry, RH)
    #"""Estimate wet bulb temperature, given dry bulb temperature and relative
    #humidity."""
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

    temp_dry * atan(c1 * (RH + c2)^0.5) + atan(temp_dry + RH) - atan(RH - c3) +
    c4 * RH^1.5 * atan(c5 * RH) - c6
end
           
           
function dewpoint_depression(temp, RH)
    #"""Calculate dewpoint depression; the difference between (dry-bulb)
    #temperature and dewpoint, in C."""
    temp - dewpoint(RH, temp=temp)
end


function wetbulb_depression(temp, RH)
    #"""Calculate wetbulb depression; the difference between (dry-bulb)
    #temperature and dewpoint, in C."""
    temp - wetbulb(temp, RH)
end


function report(temp, RH, air_pressure, precision=2)
    #"""Display several humidity metrics for a given temperature, relative humidity,
    #and air pressure. temp is in C, RH is a portion, and air_pressure is in hPa."""

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

    display = 
"
Dewpoint: $(round(dewpoint_, precision)) °C
Mixing ratio: $(round(mixing_ratio_, precision)) g/Kg
Absolute humidity: $(round(abs_humidity_, precision)) g/m^3
Wetbulb temperature: $(round(wetbulb_temp, precision)) °C
Dewpoint depression: $(round(dewpoint_depression_, precision)) °C
Wetbulb depression: $(round(wetbulb_depression_, precision)) °C
Vapor pressure saturation: $(round(vap_pres_sat_, precision)) hPa
Vapor pressure: $(round(vap_pres, precision)) hPa"

    println(display)
end


end

