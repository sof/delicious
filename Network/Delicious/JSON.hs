--------------------------------------------------------------------
-- |
-- Module      : Network.Delicious.JSON
-- Copyright   : (c) Galois, Inc. 2008
-- License     : BSD3
--
-- Maintainer  : Sigbjorn Finne <sigbjorn.finne@gmail.com>
-- Stability   : provisional
-- Portability : portable
--
-- Access del.icio.us JSON services.
--
-- See <http://del.icio.us/help/json/> for more details on the API.
--
-- "You can use JSON feeds at del.icio.us to fetch, remix, and mashup a
-- variety of data for use in your own custom applications and
-- browser-based presentation styles."
--
module Network.Delicious.JSON
       ( getHotlist          -- :: DM [Post]
       , getRecentBookmarks  -- :: IO [Post]
       , getTagBookmarks     -- :: Tag -> IO [Post]
       , getTagsBookmarks    -- :: [Tag] -> IO [Post]
       , getPopularBookmarks -- :: IO [Post]
       , getTagPopularBookmarks -- :: Tag -> IO [Post]
       , getSiteAlerts       -- :: IO [Post]
       , getUserBookmarks    -- :: String -> IO [Post]
       , getUserTagBookmarks -- :: String -> Tag -> IO [Post]
       , getUserTaggedBookmarks -- :: String -> [Tag] -> IO [Post]
       , getUserInfo            -- :: String -> IO [Post]
       , getUserPublicTags      -- :: String -> IO [Post]
       , getUserSubscriptions   -- :: String -> IO [Post]
       , getUserInboxBookmarks  -- :: String -> String -> IO [Post]
       , getNetworkMemberBookmarks -- :: String -> IO [Post]
       , getNetworkMemberTaggedBookmarks -- :: String -> [Tag] -> IO [Post]
       , getNetworkMembers      -- :: String -> IO [Post]
       , getNetworkFans         -- :: String -> IO [Post]
       , getURLBookmarks        -- :: URLString -> IO [Post]
       , getURLSummary          -- :: URLString -> IO URLDetails
       , getURLDetails          -- :: URLString -> IO URLDetails

       , HtmlFeed(..)
       , baseHtmlFeed           -- :: HtmlFeed
       , feed_html_url
       , getHtmlForTag          -- :: HtmlFeed -> Maybe Tag -> IO {-Html-}String

       , URLDetails(..)
       ) where

import Text.JSON
import Text.JSON.Types

import Network.Delicious.Types

import Control.Monad
import Data.List
import Data.Ord
import Data.Maybe

import Debug.Trace

import Network.Delicious.Fetch ( readContentsURL )
import Data.ByteString ( pack )
import Data.Digest.OpenSSL.MD5

------------------------------------------------------------------------

-- | Retrieve tags associated with a url from delicious.
-- An example, extract the tags associated with 'xmonad':
--
-- > > getURLSummary "http://xmonad.org/"
-- >
-- >       (URLDetails {total = 283
-- >                   ,tags = [("haskell",176)
-- >                           ,("windowmanager",133)
-- >                           ,("x11",126)
-- >                           ,("linux",116)
-- >                           ,("wm",74)
-- >                           ,("software",55)
-- >                           ,("gui",39)
-- >                           ,("desktop",26)
-- >                           ,("programming",25)
-- >                           ,("opensource",23)
-- >                           ,("xmonad",20)]
-- >                   }
--
getURLDetails :: String -> DM URLDetails
getURLDetails uarl = getURLSummary uarl

baseUrl :: String
baseUrl = "http://feeds.delicious.com/v2/json"

buildUrl :: (String -> URLString -> IO a) -> URLString -> DM a
buildUrl f u = do
  mbc <- getCount
  ua  <- getUAgent
  liftIO (f ua (case mbc of { Nothing -> u ; Just c ->  u++"?count="++show c}))

handleResult :: JSON a => String -> URLString -> DM a
handleResult loc u = do
    s <- buildUrl readContentsURL u
    case decodeStrict s of
      Ok e    -> return e
      Error e -> liftIO $ ioError $ userError (loc ++ ':':' ':e)

------------------------------------------------------------------------

getHotlist :: DM [Post]
getHotlist = handleResult "getHotlist" baseUrl

getRecentBookmarks :: DM [Post]
getRecentBookmarks = handleResult "getRecentBookmarks" rec_url
  where rec_url = baseUrl ++ "/recent"

getTagBookmarks :: Tag -> DM [Post]
getTagBookmarks tg = handleResult "getTagBookmarks" eff_url
  where eff_url = baseUrl ++ "/tag/" ++ tg

getTagsBookmarks    :: [Tag] -> DM [Post]
getTagsBookmarks tgs = handleResult "getTagsBookmarks" eff_url
  where eff_url = baseUrl ++ "/tag/" ++ concat (intersperse "+" tgs)

getPopularBookmarks :: DM [Post]
getPopularBookmarks = handleResult "getPopularBookmarks" eff_url
  where eff_url = baseUrl ++ "/popular"

getTagPopularBookmarks :: Tag -> DM [Post]
getTagPopularBookmarks tg = handleResult "getTagPopularBookmarks" eff_url
  where eff_url = baseUrl ++ "/popular/" ++ tg

getSiteAlerts       :: DM [Post]
getSiteAlerts = handleResult "getSiteAlerts" eff_url
  where eff_url = baseUrl ++ "/alerts"

getUserBookmarks    :: String -> DM [Post]
getUserBookmarks usr = trace (eff_url) $ handleResult "getUserBookmarks" eff_url
  where eff_url = baseUrl ++ '/':usr

getUserTagBookmarks :: String -> Tag -> DM [Post]
getUserTagBookmarks usr tg = handleResult "getUserTagBookmarks" eff_url
  where eff_url = baseUrl ++ '/':usr++'/':tg

getUserTaggedBookmarks :: String -> [Tag] -> DM [Post]
getUserTaggedBookmarks usr tgs = handleResult "getUserTaggedBookmarks" eff_url
  where eff_url = baseUrl ++ '/':usr++'/':concat (intersperse "+" tgs)

getUserInfo :: String -> DM [Post]
getUserInfo usr = handleResult "getUserInfo" eff_url
  where eff_url = baseUrl ++ "/userinfo/" ++ usr

getUserPublicTags      :: String -> DM [Post]
getUserPublicTags usr = handleResult "getUserPublicTags" eff_url
  where eff_url = baseUrl ++ "/tags/" ++ usr


getUserSubscriptions   :: String -> DM [Post]
getUserSubscriptions usr = handleResult "getUserSubscriptions" eff_url
  where eff_url = baseUrl ++ "/subscriptions/" ++ usr

getUserInboxBookmarks  :: String -> String -> DM [Post]
getUserInboxBookmarks usr k = handleResult "getUserInboxBookmarks" eff_url
  where eff_url = baseUrl ++ "/inbox/" ++ usr ++ "?private="++k

getNetworkMemberBookmarks :: String -> DM [Post]
getNetworkMemberBookmarks usr = handleResult "getNetworkMemberBookmarks" eff_url
  where eff_url = baseUrl ++ "/network/" ++ usr

getNetworkMemberTaggedBookmarks :: String -> [Tag] -> DM [Post]
getNetworkMemberTaggedBookmarks usr tgs =
  handleResult "getNetworkMemberTaggedBookmarks" eff_url
   where eff_url = baseUrl ++ "/network/" ++ usr ++ '/':concat (intersperse "+" tgs)


getNetworkMembers :: String -> DM [Post]
getNetworkMembers usr = handleResult "getNetworkMembers" eff_url
  where eff_url = baseUrl ++ "/networkmembers/" ++ usr

getNetworkFans         :: String -> DM [Post]
getNetworkFans usr = handleResult "getNetworkFans" eff_url
  where eff_url = baseUrl ++ "/networkfans/" ++ usr

getURLBookmarks  :: URLString -> DM [Post]
getURLBookmarks turl = handleResult "getURLBookmarks" eff_url
  where eff_url = baseUrl ++ "/url/" ++ hashUrl turl

getURLSummary :: URLString -> DM URLDetails
getURLSummary turl = handleResult "getURLSummary" eff_url
  where eff_url = baseUrl ++ "/urlinfo/" ++ hashUrl turl

hashUrl :: URLString -> String
hashUrl s = md5sum (pack (map (fromIntegral.fromEnum) s))

------------------------------------------------------------------------

-- | A structure represening the the delicious tags associated with a url.
data URLDetails =
        URLDetails { total :: !Integer
                   , tags  :: [(String,Integer)]
		   , hash  :: String {-MD5-}
		   , url   :: String {-URL-}
		   }
        deriving (Eq,Show,Read)

nullURLDetails :: URLDetails
nullURLDetails =
  URLDetails { total = 0
             , tags  = []
	     , hash  = ""
	     , url   = ""
	     }

-- | Compose and decompose URLDetails as JSON in the form delicious uses.
instance JSON URLDetails where
    showJSON ud = JSObject $ toJSObject
        [ ("hash",        showJSON (JSONString (hash ud)))
        , ("total_posts", showJSON (total ud))
        , ("top_tags",    JSObject $ toJSObject
                            [(x,showJSON y) | (x,y) <- tags ud ])
        , ("url",         showJSON (JSONString (url ud)))
        ]

    readJSON (JSArray []) = return nullURLDetails
    readJSON (JSArray [x]) = readJSON x
    readJSON (JSObject (JSONObject pairs))
        = do the_tags <- case lookup "top_tags" pairs of
                        Nothing -> fail "Network.Delicious.JSON: Missing JSON field: top_tags"
                        Just (JSObject (JSONObject obj)) ->
                          liftM (reverse . sortBy (comparing snd)) $
                            mapM (\(x,y) -> readJSON y >>= \y' -> return (x,y')) obj
                        Just x ->
			  fail ("Network.Delicious.JSON: Unexpected JSON value for 'top_tags': " ++ show x)

             the_total <- case lookup "total_posts" pairs of
                        Nothing -> fail "Network.Delicious.JSON: Missing JSON field: total_posts"
                        Just  n -> readJSON n

             the_url <- case lookup "url" pairs of
                         Nothing -> fail "Network.Delicious.JSON: Missing JSON field: url"
                         Just  n -> readJSON n

             hsh     <- readJSON (fromMaybe JSNull (lookup "hash" pairs))
             return $
                URLDetails { total = the_total
                           , url   = the_url
                           , tags  = the_tags
			   , hash  = hsh
			   }

    readJSON s = fail ("Network.Delicious.JSON: url details malformed: "++ show s)

data HtmlFeed
 = HtmlFeed
     { hf_delUrl         :: Maybe {-URL-}String
     , hf_extended       :: Bool
     , hf_divClass       :: Maybe String
     , hf_aClass         :: Maybe String
     , hf_showTags       :: Bool
     , hf_tagClass       :: Maybe String
     , hf_tagSep         :: Maybe String
     , hf_tagSepClass    :: Maybe String
     , hf_bulletEnt      :: Maybe String
     , hf_withFeedButton :: Maybe Bool
     , hf_extendedInDiv  :: Maybe Bool
     , hf_extendedClass  :: Maybe String
     }

baseHtmlFeed :: HtmlFeed
baseHtmlFeed = HtmlFeed
     { hf_delUrl         = Nothing
     , hf_extended       = False
     , hf_divClass       = Nothing
     , hf_aClass         = Nothing
     , hf_showTags       = True
     , hf_tagClass       = Nothing
     , hf_tagSep         = Nothing
     , hf_tagSepClass    = Nothing
     , hf_bulletEnt      = Nothing
     , hf_withFeedButton = Nothing
     , hf_extendedInDiv  = Nothing
     , hf_extendedClass  = Nothing
     }

feed_html_url :: {-URL-}String
feed_html_url = "http://feeds.delicious.com/html"

getHtmlForTag :: HtmlFeed
              -> Maybe Tag
	      -> DM {-Html-}String
getHtmlForTag hf mbTg = do
  u <- getUser
  c <- getCount
  let partial_url = build_query u c
  let base_url = fromMaybe feed_html_url (hf_delUrl hf)
  let eff_url = base_url ++ partial_url
  ua <- getUAgent
  liftIO $ readContentsURL ua eff_url
 where
  build_query u c = consSlash (userName u) ++ (fromMaybe "" (fmap consSlash mbTg)) ++ '?':opts
    where
      opts = concat $ intersperse "&" $ catMaybes
         [ "count"     -==> fmap show c
	 , "extended"  -=> toB (hf_extended hf) "title" "body"
	 , "divclass"  -==> hf_divClass hf
	 , "aclass"    -==> hf_aClass hf
	 , "tags"      -=> toB (hf_showTags hf) "no" "yes"
	 , "tagclass"  -==> hf_tagClass hf
	 , "tagsep"    -==> hf_tagSep hf
	 , "tagsepclass" -==> hf_tagSepClass hf
	 , "bullet"    -==> hf_bulletEnt hf
	 , "rssbutton" -==> fmap (\ x -> toB x "no" "yes") (hf_withFeedButton hf)
	 , "extendeddiv" -==> fmap (\ x -> toB x "no" "yes") (hf_extendedInDiv hf)
	 , "extendedclass" -==> hf_extendedClass hf
	 ]

  consSlash "" = ""
  consSlash xs = '/':xs

  (-==>) _ Nothing = Nothing
  (-==>) a (Just b) = Just (a ++ '=':b)
  (-=>) a b = Just (a ++ '=':b)

  toB False a _ = a
  toB _     _ b = b
