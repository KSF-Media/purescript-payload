module Payload.Examples.Movies.Test where

import Prelude

import Affjax.RequestHeader (RequestHeader(..))
import Data.Map (Map)
import Data.Map as Map
import Data.Tuple (Tuple(..))
import Payload.Client.Client (mkGuardedClient)
import Payload.Client.Client as Client
import Payload.Cookies as Cookies
import Payload.Examples.Movies.Main (moviesApi, moviesApiSpec)
import Payload.Headers as Headers
import Payload.Spec (type (:), Spec(Spec), DELETE, GET, Guards(..), POST, Route, Routes, Nil)
import Payload.Test.Config (TestConfig)
import Payload.Test.Helpers (assertFail, assertRes, withServer)
import Test.Unit (TestSuite, suite, test)

cookieOpts :: Map String String -> Client.RequestOptions
cookieOpts cookies = { headers: Headers.fromFoldable [cookieHeader] }
  where
    cookieHeader = case Cookies.cookieHeader cookies of
                     Tuple field value -> Tuple field value
  
tests :: TestConfig -> TestSuite
tests cfg = do
  let client = mkGuardedClient cfg.clientOpts moviesApiSpec
  let withApi = withServer moviesApiSpec moviesApi
  suite "Example: movies API" do
    test "Sub-route fails if parent route guard fails (missing API key)" $ do
      withApi do
        assertFail (client.v1.movies.latest {})
    test "Sub-route succeeds if parent route guard succeeds (has API key)" $ do
      withApi do
        let opts = cookieOpts (Map.singleton "apiKey" "key")
        assertRes (client.v1.movies.latest_ opts {})
                 { id: 723, title: "The Godfather" }
    test "Sub-route fails if passes parent guard but not child guard (missing session key)" $ do
      withApi do
        let payload = { params: { movieId: 1 }, body: { value: 9.0 } }
        let opts = cookieOpts $ Map.singleton "apiKey" "key"
        assertFail $ client.v1.movies.byId.rating.create_ opts payload
    test "Sub-route succeeds if passes parent and child guards (has API and session keys)" $ do
      withApi do
        let opts = cookieOpts $ Map.fromFoldable [Tuple "apiKey" "key", Tuple "sessionId" "sessionId"]
        assertRes (client.v1.movies.byId.rating.create_ opts
                     { params: { movieId: 1 }, body: { value: 9.0 } })
                   { statusCode: 1, statusMessage: "Created" }
