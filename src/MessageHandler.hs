{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns #-}

module MessageHandler
    ( messageHandler
    , parseCommand
    , UserCommand
    ) where

import Data.Text(Text)
import qualified Data.Text as T
import Data.Text.Read(decimal)
import Data.Either(isRight)
import Data.Maybe(fromMaybe, listToMaybe)
import Data.String(fromString)
import Control.Applicative((<|>))
import Control.Monad
import Utilits

import DataBase.Requests(Config)


import Service
data UserCommand = Start |
                   Help |
                   WrongUrl |
                   ShortUrl Service Text |
                   ShortUrlDef Text |
                   GenPrime Int |
                   SetDefault Service |
                   Unknown Text
                deriving(Show)

messageHandler :: Int -> Config -> Text -> IO Text
messageHandler uid dbc = (processCommand uid dbc) . parseCommand

genPrime = (!!) (1:filter isPrime [2..])
  where
    factors n = [x | x <- [1..n], n `mod` x == 0]
    isPrime n = factors n == [1, n]

parseCommand :: Text -> UserCommand
parseCommand t = let (cmd:args) = T.words t
                 in orUnknown $ join (lookup cmd cmds <*> Just args)
  where
    orUnknown
      | isUrl t = fromMaybe $ ShortUrlDef t
      | otherwise = fromMaybe $ Unknown t
    cmds :: [(Text, [Text] -> Maybe UserCommand)]
    cmds = [ ("/p",      parseGenPrimeCmd)
           , ("/bitly",  parseShortCmd Bitly)
           , ("/google", parseShortCmd Google)
           , ("/qps",    parseShortCmd Qps)
           , ("/help",   const (Just Help))
           , ("/default",  parseSetDefault)
           , ("/start",  const (Just Start))
           ]
    parseGenPrimeCmd a = GenPrime <$> (decimal <$> listToMaybe a >>= fmap fst . eitherToMaybe)
    parseShortCmd s a = (ShortUrl s <$> do
                              t <- listToMaybe a
                              guard (isUrl t)
                              return t) <|> (Just WrongUrl)
    parseSetDefault [T.toLower->"bitly"] = Just $ SetDefault Bitly
    parseSetDefault [T.toLower->"google"] = Just $ SetDefault Google
    parseSetDefault [T.toLower->"qps"] = Just $ SetDefault Qps
    parseSetDefault _ = Nothing

eitherToMaybe :: Either e a -> Maybe a
eitherToMaybe (Left _) = Nothing
eitherToMaybe (Right a) = Just a

isUrl :: Text -> Bool
isUrl t = T.all (/= ' ') t && T.any (=='.') t

processCommand :: Int -> Config -> UserCommand -> IO Text
processCommand uid dbc (SetDefault s) = setDefaultService uid s dbc >> return "done!"
processCommand uid dbc (ShortUrl s u) = getShortUrl uid s u dbc
processCommand uid dbc (ShortUrlDef t) = getByDefault uid t dbc
processCommand uid dbc (Unknown t) = return $ T.concat ["Wrong cmd: `", t, "`"]
processCommand uid dbc Help = return $ T.pack $ "Hello, I'm url-shortener bot.\n"
    ++ "I can work with such services: google, bilty, qps.\n"
    ++ "To get short url you should enter command of service and your link."
processCommand uid dbc Start = return "Hello!"
processCommand uid dbc WrongUrl = return "Wrong Url!"
processCommand uid dbc (GenPrime n) = return $ fromString $
                                concat ["The ", show n, "th prime number is ", show $ genPrime n]
