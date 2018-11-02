module Models exposing (..)

import Time exposing (Time)
import Models.Types exposing (..)
import Models.Authentication exposing (AuthenticationModel)
import Models.Pokemon exposing (RemotePokedex)
import Models.Ratings exposing (RemoteTeamRatings)
import Msgs exposing (Msg)
import Control exposing (State)


type alias LighthouseData =
    { name : String
    , caption : String
    }


type alias User =
    Maybe String


type alias PreloadedSets =
    { generations : List Int
    , letters : List Char
    }


type alias ApplicationState =
    { authModel : AuthenticationModel
    , currentUser : User
    , statusMessage : String
    , statusLevel : StatusLevel
    , statusTime : Time
    , debounceState : Control.State Msg
    , currentRoute : Route
    , generation : Int
    , letter : Char
    , preloaded : PreloadedSets
    , query : String
    , pokedex : RemotePokedex
    , ratings : RemoteTeamRatings
    }
