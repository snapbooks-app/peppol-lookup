#!/usr/bin/env runhaskell

{-|
PEPPOL uses two key services to enable document exchange:

1. SML (Service Metadata Locator):
   - Acts as a DNS-based directory service
   - Maps a participant's ID to their SMP provider
   - Uses DNS lookup to find where a participant's metadata is hosted
   - Similar to how email's MX records help find mail servers

2. SMP (Service Metadata Publisher):
   - Hosts metadata about a participant's capabilities
   - Tells you what document types they can receive
   - Provides technical details needed for sending documents
   - Acts like a participant's business card in the network

This example demonstrates how to:
1. Use SML to find where a participant's metadata is hosted
2. Query their SMP to discover what documents they can receive
3. Check for PEPPOL BIS Billing 3.0 support
-}

import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.Digest.Pure.MD5 (md5)
import Network.HTTP.Simple
import Network.Socket (getAddrInfo, defaultHints, AddrInfo)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Printf (printf)
import Text.Regex.Posix ((=~))
import Network.HTTP.Client (parseUrlThrow)
import Network.URI (escapeURIString, isUnescapedInURIComponent, unEscapeString)

-- Test environment SML domain
smlDomain :: String
smlDomain = "edelivery.tech.ec.europa.eu"

-- PEPPOL BIS Billing 3.0 document identifiers
bisBillingInvoice :: String
bisBillingInvoice = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"

bisBillingCreditNote :: String
bisBillingCreditNote = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

{-|
Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname

The SML is like a phone book for the PEPPOL network. Given a participant's ID:
1. Create an MD5 hash of their ID (e.g., "0192:921605900")
2. Use the hash to construct a DNS hostname
3. If the hostname exists, the participant is registered in PEPPOL
4. The hostname tells us where to find their metadata (SMP)

Returns Just hostname if found, Nothing if not found
-}
smlLookup :: String -> String -> IO (Maybe String)
smlLookup icd identifier = do
  -- Create MD5 hash of participant ID
  let participantId = icd ++ ":" ++ identifier
      md5Hash = show $ md5 $ LBS.pack participantId
      hostname = "b-" ++ md5Hash ++ ".iso6523-actorid-upis." ++ smlDomain

  -- Check if hostname exists
  result <- tryGetAddrInfo hostname
  case result of
    Just _  -> return $ Just hostname
    Nothing -> return Nothing

-- Helper function to try DNS lookup
tryGetAddrInfo :: String -> IO (Maybe [AddrInfo])
tryGetAddrInfo hostname = do
  result <- try (getAddrInfo (Just defaultHints) (Just hostname) Nothing) :: IO (Either IOError [AddrInfo])
  case result of
    Left _  -> return Nothing
    Right addrs -> return $ Just addrs

-- Import Control.Exception for try
import Control.Exception (try, IOException, SomeException)

{-|
Step 2: Query SMP (Service Metadata Publisher) to get supported document types

The SMP is like a business card in the PEPPOL network. It tells us:
1. What types of documents the participant can receive
2. Technical details needed for sending documents
3. Specific document format versions they support

This is similar to how DNS MX records tell you where to send email,
but SMP also includes what "types" of messages you can send.
-}
smpLookup :: String -> String -> String -> IO [String]
smpLookup smpHostname icd identifier = do
  -- Construct SMP URL
  -- Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
  let participantId = icd ++ ":" ++ identifier
      encodedId = escapeURIString isUnescapedInURIComponent participantId
      urlString = "http://" ++ smpHostname ++ "/iso6523-actorid-upis::" ++ encodedId

  -- Perform HTTP GET request
  request <- parseRequest urlString
  response <- httpLBS request
  let responseBody = LBS.unpack $ getResponseBody response

  -- Extract document types from ServiceMetadataReference href attributes
  let pattern = "ServiceMetadataReference[^>]*href=\"([^\"]*)\"[^>]*>" :: String
      matches = responseBody =~ pattern :: [[String]]
      hrefs = map (!! 1) matches
      decodedHrefs = map unEscapeString hrefs
      documentTypes = [getDocType href | href <- decodedHrefs, "busdox-docid-qns::" `isInfixOf` href]

  return documentTypes
  where
    isInfixOf needle haystack = needle `elem` (tails haystack)
    tails [] = [[]]
    tails s@(_:xs) = s : tails xs

    getDocType href =
      let parts = splitOn "busdox-docid-qns::" href
      in if length parts > 1
         then takeWhile (/= '#') (parts !! 1)
         else ""

-- Helper function to split string
splitOn :: String -> String -> [String]
splitOn delimiter str =
  case break (== head delimiter) str of
    (before, []) -> [before]
    (before, match) ->
      if take (length delimiter) match == delimiter
      then before : splitOn delimiter (drop (length delimiter) match)
      else before : splitOn delimiter (tail match)

-- Check if substring is in string
isInfixOf :: String -> String -> Bool
isInfixOf [] _ = True
isInfixOf _ [] = False
isInfixOf needle haystack@(_:hs) =
  needle `isPrefixOf` haystack || needle `isInfixOf` hs

isPrefixOf :: String -> String -> Bool
isPrefixOf [] _ = True
isPrefixOf _ [] = False
isPrefixOf (x:xs) (y:ys) = x == y && isPrefixOf xs ys

-- Main execution
main :: IO ()
main = do
  result <- try mainLogic :: IO (Either SomeException ())
  case result of
    Left ex -> do
      hPutStrLn stderr $ "Error: " ++ show ex
      exitFailure
    Right _ -> return ()

mainLogic :: IO ()
mainLogic = do
  -- Snapbooks AS (Norwegian organization number)
  let icd = "0192"
      identifier = "921605900"

  -- Step 1: Use SML to find where participant's metadata is hosted
  maybeSmpHostname <- smlLookup icd identifier
  case maybeSmpHostname of
    Nothing -> do
      putStrLn $ "Not a PEPPOL participant: " ++ icd ++ ":" ++ identifier
      exitFailure
    Just smpHostname -> do
      putStrLn $ "SMP hostname: " ++ smpHostname

      -- Step 2: Query their SMP to discover supported documents
      documentTypes <- smpLookup smpHostname icd identifier
      putStrLn "\nSupported document identifiers:"
      mapM_ (\docType -> putStrLn $ "- " ++ docType) documentTypes

      -- Check for PEPPOL BIS Billing 3.0 documents
      putStrLn "\nPEPPOL BIS Billing 3.0 Support:"
      when (bisBillingInvoice `elem` documentTypes) $
        putStrLn "- Supports Invoice"
      when (bisBillingCreditNote `elem` documentTypes) $
        putStrLn "- Supports Credit Note"

-- Import Control.Monad for when
import Control.Monad (when)
