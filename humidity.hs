import Text.Printf

--simplified version with only the -20 to 50 temp range.
--Practicing guards, and not sure what the elegant way is.
constants :: String -> Float
constants col_name
    | col_name == "A" = 6.116441
    | col_name == "m" = 7.591386
    | col_name == "Tn" = 240.7263


vap_pres_sat :: Float -> Float 
vap_pres_sat temp =
    let t = temp + 273.15  -- Temperature in K
        tc = 647.096  -- Critical temperature, in K
        pc = 220640  -- Critical pressure in hPa
        c1 = -7.85951783
        c2 = 1.84408259
        c3 = -11.7866497
        c4 = 22.6807411
        c5 = -15.9618719
        c = 1.80122502
        c6 = 1.80122502
        e = 2.718281828459045
        v = 1 - (t / tc)
    in  e ** ((tc / t) * (c1*v + c2*v**1.5 + c3*v**3 + c4*v**3.5 + c5*v**4 + 
        c6*v**7.5)) * pc


rel_hum :: Float -> Float -> Float
rel_hum dewpoint ambient_temp = vap_pres_sat(dewpoint) / vap_pres_sat(ambient_temp)


enthalpy :: Float -> Float -> Float
-- x is the mixing ratio.
enthalpy temp x = temp * (1.01 + 0.00189 * x) + 2.5 * x


mixing_ratio :: Float -> Float -> Float
mixing_ratio p_total pw = b * pw / (p_total - pw)
    where b = 621.9907

          
abs_humidity :: Float -> Float -> Float
abs_humidity temp pw = constant * pw_pa / temp_k
    where constant = 2.16679 -- in gK / J
          temp_k = temp + 273.15
          pw_pa = pw * 100 -- Convert from hPa to Pa, for desired output units.
          
          
dewpoint :: Float -> Float -> Float-> Float
dewpoint rel_humidity pws p_ratio = 
    let pw = pws * rel_humidity * p_ratio
        a = constants "A"
        m = constants "m"
        tn = constants "Tn"
    in tn / (m / (logBase 10 (pw/a)) - 1)
    

wetbulb :: Float -> Float -> Float
wetbulb temp_dry rh2 = temp_dry * atan(c1 * (rh + c2)**0.5) + atan(temp_dry + rh) - atan(rh - c3) +  c4 * rh**1.5 * atan(c5 * rh) - c6
    where rh = rh2 * 100
          -- c1-6 are constants.
          c1 = 0.151977
          c2 = 8.3131659
          c3 = 1.676331
          c4 = 0.00391838
          c5 = 0.023101
          c6 = 4.686035


dewpoint_depression :: Float -> Float -> Float
dewpoint_depression temp rel_humidity = temp - (dewpoint rel_humidity pws p_ratio)
    where pws = vap_pres_sat temp
          p_ratio = 1
          
          
wetbulb_depression :: Float -> Float -> Float
wetbulb_depression temp rel_humidity = temp - (wetbulb temp rel_humidity)


roundToStr :: (PrintfArg a, Floating a) => Int -> a -> String
roundToStr n f = printf ("%0." ++ show n ++ "f") f


report :: Float -> Float -> Float -> Int -> IO ()
report temp rel_humidity air_pressure precision =           
    let p_ratio = 1
        pws = vap_pres_sat temp
        pw = pws * rel_humidity
        dewpoint_ = dewpoint rel_humidity pws p_ratio
        mixing_ratio_ = mixing_ratio air_pressure pw
        abs_humidity_ = abs_humidity temp pw
        wetbulb_temp = wetbulb temp rel_humidity
        dewpoint_depression_ = temp - dewpoint_
        wetbulb_depression_ = temp - wetbulb_temp
                 
    in putStrLn ("\nDewpoint: " ++ roundToStr precision dewpoint_ ++ " °C" ++
    "\nMixing ratio: " ++ roundToStr precision mixing_ratio_ ++ " g/Kg" ++
    "\nAbsolute humidity: " ++ roundToStr precision abs_humidity_ ++ " g/m^3" ++
    "\nWetbulb temperature: " ++ roundToStr precision wetbulb_temp ++ " °C" ++
    "\nDewpoint depression: " ++ roundToStr precision dewpoint_depression_ ++ " °C" ++
    "\nWetbulb depression: " ++ roundToStr precision wetbulb_depression_ ++ " °C" ++
    "\nVapor pressure saturation: " ++ roundToStr precision pws ++ " hPa" ++
    "\nVapor pressure: " ++ roundToStr precision pw ++ " hPa"
    )
          
          
          
