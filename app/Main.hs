{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Main where

import Web.Scotty
import GHC.Generics
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as BS
import qualified Data.Vector as V
import Data.Aeson (ToJSON, (.=), object)
import Data.Csv (FromNamedRecord(..), FromField(..), decodeByName, (.:))
import Control.Monad.IO.Class (liftIO)
import Data.List (sortOn)
import Network.Wai.Middleware.Cors

--------------------------------------------------
-- BOOL PARSER (required for GHC 9.10)
--------------------------------------------------

instance FromField Bool where
  parseField s =
    case BS.map toLower s of
      "true"  -> pure True
      "false" -> pure False
      _       -> fail "Invalid Bool"
    where
      toLower c
        | c >= 'A' && c <= 'Z' = toEnum (fromEnum c + 32)
        | otherwise = c

--------------------------------------------------
-- STORM DATA TYPE
--------------------------------------------------

data Storm = Storm
  { stormId            :: Int
  , name               :: String
  , start_date         :: String
  , end_date           :: String
  , basin              :: String
  , lat                :: Double
  , lon                :: Double
  , max_wind_kmh       :: Double
  , min_pressure_mb    :: Double
  , total_rainfall_mm  :: Double
  , tide_level_m       :: Double
  , surge_occurred     :: Bool
  , surge_height_m     :: Double
  , affected_states    :: String
  } deriving (Show, Generic)

instance FromNamedRecord Storm where
  parseNamedRecord m =
    Storm
      <$> m .: "id"
      <*> m .: "name"
      <*> m .: "start_date"
      <*> m .: "end_date"
      <*> m .: "basin"
      <*> m .: "lat"
      <*> m .: "lon"
      <*> m .: "max_wind_kmh"
      <*> m .: "min_pressure_mb"
      <*> m .: "total_rainfall_mm"
      <*> m .: "tide_level_m"
      <*> m .: "surge_occurred"
      <*> m .: "surge_height_m"
      <*> m .: "affected_states"

instance ToJSON Storm

--------------------------------------------------
-- SIMILARITY
--------------------------------------------------

similarity :: Storm -> Storm -> Double
similarity s1 s2 =
    (0.4 * (max_wind_kmh s1 - max_wind_kmh s2) ^ 2)
  + (0.4 * (min_pressure_mb s1 - min_pressure_mb s2) ^ 2)
  + (0.2 * (tide_level_m s1 - tide_level_m s2) ^ 2)

--------------------------------------------------
-- RISK CALCULATION
--------------------------------------------------

calculateRisk :: [Storm] -> (Double, String)
calculateRisk storms =
  let total  = length storms
      surged = length (filter surge_occurred storms)
      prob   = if total == 0
               then 0
               else (fromIntegral surged / fromIntegral total) * 100

      label | prob > 70 = "High Risk"
            | prob > 40 = "Moderate Risk"
            | otherwise = "Low Risk"
  in (prob, label)

--------------------------------------------------
-- LOAD CSV
--------------------------------------------------

loadHistorical :: IO [Storm]
loadHistorical = do
  csvData <- BL.readFile "historical_storms.csv"
  case decodeByName csvData of
    Left err -> do
      putStrLn err
      return []
    Right (_, v) -> return (V.toList v)

--------------------------------------------------
-- MAIN
--------------------------------------------------

main :: IO ()
main = do

  historical <- loadHistorical
  putStrLn ("Loaded storms: " ++ show (length historical))

  scotty 3000 $ do

    middleware $ cors (const $ Just simpleCorsResourcePolicy)

    get "/" $
      text "Storm Surge Risk Analysis API Running"

    get "/analyze" $ do
      w <- param "wind"  :: ActionM Double
      p <- param "press" :: ActionM Double
      t <- param "tide"  :: ActionM Double

      let inputStorm = Storm 0 "Current" "" "" "" 0 0 w p 0 t False 0 ""

      -- 1. Sort historical data by similarity and take only the single best match
      let sortedMatches = sortOn (similarity inputStorm) historical
      let bestMatch = head sortedMatches

      -- 2. Calculate match percentage (100% is perfect, decreasing as distance increases)
      let matchScore = max 0 (100 - (sqrt (similarity inputStorm bestMatch)))

      -- 3. Probability is now derived from the best match's surge status 
      -- weighted by how similar it is to your input
      let surgeProb = if surge_occurred bestMatch then matchScore else (100 - matchScore)

      json $ object
        [ "best_match"       .= bestMatch
        , "match_percentage" .= matchScore
        , "surge_probability".= surgeProb
        , "input_values"     .= object ["w" .= w, "p" .= p, "t" .= t]
        ]