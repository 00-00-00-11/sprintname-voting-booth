module Main exposing (..)

import Html exposing (..)
import Models exposing (..)
import View exposing (view)
import Update exposing (update)
import Msgs exposing (Msg)
import CommandsRatings exposing (loadRatings)
import CommandsPokemon exposing (loadPokemon)


init : ( ApplicationState, Cmd Msg )
init =
    ( initialState, loadPokemon 1 )


subscriptions : ApplicationState -> Sub Msg
subscriptions state =
    Sub.none


main : Program Never ApplicationState Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
