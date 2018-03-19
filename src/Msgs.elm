module Msgs exposing (Msg(..))

import RemoteData exposing (WebData)
import Authentication
import Models.Types exposing (..)
import Models.Pokedex exposing (Pokedex)
import Models.Ratings exposing (UserVote, TeamRatings, UserRatings)
import Control exposing (Control)


type Msg
    = OnLoadRatings (WebData TeamRatings)
    | OnSaveRatings (WebData UserRatings)
    | OnLoadPokedex (WebData Pokedex)
    | AuthenticationMsg Authentication.Msg
    | ChangeGenerationAndLetter Int Char
    | ChangeGeneration Int
    | ChangeLetter Char
    | ChangeVariant Int BrowseDirection
    | SearchPokemon String
    | Debounce (Control Msg)
    | VoteForPokemon UserVote
