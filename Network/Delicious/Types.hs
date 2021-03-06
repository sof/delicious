--------------------------------------------------------------------
-- |
-- Module      : Network.Delicious.Types
-- Copyright   : (c) Sigbjorn Finne, 2008-2014
-- License     : BSD3
--
-- Maintainer  : Sigbjorn Finne <sof@forkIO.com>
-- Stability   : provisional
-- Portability : portable
--
-- Types and data structures used by the Delicious API binding.
--
--------------------------------------------------------------------


module Network.Delicious.Types
       ( DateString
       , TimeString
       , URLString

       , User(..)
       , nullUser

       , DM
       , catchDM   -- :: DM a -> (IOError -> DM a) -> DM a
       , withUser  -- :: User -> DM a -> DM a
       , withCount -- :: Int -> DM a -> DM a
       , withUAgent -- :: String -> DM a -> DM a
       , getUser   -- :: DM User
       , getBase   -- :: DM URLString
       , getCount  -- :: DM (Maybe Int)
       , getUAgent -- :: DM String

       , liftIO   -- :: IO a -> DM a
       , runDelic -- :: User -> URLString -> DM a -> IO a
       , runDM    -- :: User -> DM a -> IO a

       , Tag
       , TagInfo(..)
       , Bundle(..)

       , Filter(..)
       , nullFilter

       , Post(..)
       , nullPost

       ) where

import Network.Curl.Types ( URLString )
import Data.Maybe ( catMaybes )

import Control.Exception (catch)

import Text.JSON.Types
import Text.JSON

type DateString = String
type TimeString = String -- 8601

data DMEnv
 = DMEnv
     { dmUser  :: User
     , dmBase  :: URLString
     , dmCount :: Maybe Int
     , dmAgent :: String
     }

data User
 = User
     { userName :: String
     , userPass :: String
     } deriving ( Show )

nullUser :: User
nullUser
 = User { userName = ""
        , userPass = ""
	}

newtype DM a = DM {unDM :: DMEnv -> IO a}

instance Monad DM where
  return x = DM $ \ _   -> return x
  m >>= k  = DM $ \ env -> do
     v <- unDM m env
     unDM (k v)  env

catchDM :: DM a -> (IOError -> DM a) -> DM a
catchDM (DM m) h = DM $ \ env -> Control.Exception.catch (m env) (\err -> unDM (h err) env)

withUser :: User -> DM a -> DM a
withUser u k = DM $ \ env -> (unDM k) env{dmUser=u}

withCount :: Int -> DM a -> DM a
withCount c k = DM $ \ env -> (unDM k) env{dmCount=Just c}

withUAgent :: String -> DM a -> DM a
withUAgent s k = DM $ \ env -> (unDM k) env{dmAgent=s}

getUser :: DM User
getUser = DM $ \ env -> return (dmUser env)

getCount :: DM (Maybe Int)
getCount = DM $ \ env -> return (dmCount env)

getBase :: DM URLString
getBase = DM $ \ env -> return (dmBase env)

getUAgent :: DM URLString
getUAgent = DM $ \ env -> return (dmAgent env)

liftIO :: IO a -> DM a
liftIO a = DM $ \ _ -> a

runDelic :: User -> URLString -> DM a -> IO a
runDelic u b dm = (unDM dm) DMEnv{dmUser=u,dmBase=b,dmCount=Nothing,dmAgent=defaultAgent}

-- the default User-Agent: setting.
defaultAgent :: String
defaultAgent = "hs-delicious"

del_base :: URLString
del_base = "https://api.del.icio.us/v1"

runDM :: User -> DM a -> IO a
runDM user a = runDelic user del_base a

--

type Tag = String

data TagInfo
 = TagInfo
     { tagName :: Tag
     , tagUses :: Integer
     } deriving ( Show )

data Bundle
 = Bundle
     { bundleName :: String
     , bundleTags :: [Tag]
     } deriving ( Show )

data Filter
 = Filter
     { filterTag   :: Maybe Tag -- it looks as if no more than one can be given
     , filterDate  :: Maybe DateString
     , filterURL   :: Maybe URLString
     , filterCount :: Maybe Integer
     } deriving ( Show )

nullFilter :: Filter
nullFilter =
  Filter{ filterTag   = Nothing
        , filterDate  = Nothing
        , filterURL   = Nothing
        , filterCount = Nothing
        }

data Post
 = Post
     { postHref   :: URLString
     , postUser   :: String
     , postDesc   :: String
     , postNotes  :: String
     , postTags   :: [Tag]
     , postStamp  :: DateString
     , postHash   :: String
     } deriving ( Show )

nullPost :: Post
nullPost = Post
     { postHref   = ""
     , postUser   = ""
     , postDesc   = ""
     , postNotes  = ""
     , postTags   = []
     , postStamp  = ""
     , postHash   = ""
     }


instance JSON Post where
    showJSON p = JSObject $ toJSObject $ catMaybes
        [ Just ("u",       showJSON (JSONString (postHref p)))
	, mb "d"          (showJSON.JSONString) (postDesc p)
	, mb "n"          (showJSON.JSONString) (postNotes p)
	, mb "dt"         (showJSON.JSONString) (postStamp p)
	, Just ("t",      JSArray (map (showJSON.JSONString) (postTags p)))
	]
     where
      mb _ _ "" = Nothing
      mb t f xs = Just (t, f xs)

    readJSON (JSArray []) = return nullPost
    readJSON (JSArray [x]) = readJSON x
    readJSON (JSObject (JSONObject pairs))
        = do tgs <- case lookup "t" pairs of
                     Just n -> readJSON n
                     Nothing -> return []
             ur  <- case lookup "u" pairs of
                        Nothing -> fail "Network.Delicious.JSON: Missing required JSON field: url"
                        Just  n -> readJSON n

             notes <- case lookup "n" pairs of
                        Nothing -> return ""
                        Just  n -> readJSON n
             desc <- case lookup "d" pairs of
                        Nothing -> return ""
                        Just  n -> readJSON n
             ts <- case lookup "dt" pairs of
                        Nothing -> return ""
                        Just  n -> readJSON n

             return $ nullPost{ postHref=ur
	                      , postDesc=desc
			      , postNotes=notes
			      , postTags=tgs
			      , postStamp=ts
			      }

    readJSON s = fail ("Network.Delicious.JSON: malformed post: "++ show s)


