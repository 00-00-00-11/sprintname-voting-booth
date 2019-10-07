module Main exposing (main)

import Control
import Result
import Time exposing (millisecond)
import Navigation exposing (programWithFlags, Location, newUrl)
import RemoteData exposing (RemoteData(..))
import Json.Encode as Encode exposing (Value)
import Constants exposing (initialGeneration, initialLetter)
import Msgs exposing (Msg(..))
import Routing exposing (parseLocation, createBrowsePath)
import Models exposing (ApplicationState)
import Models.Types exposing (StatusLevel(None), Route(..), BrowseMode(..))
import Models.Authentication as Authentication exposing (AuthenticationState(..))
import View exposing (view)
import Update exposing (update)
import Commands exposing (getTodayTime)
import Commands.Authentication exposing (decodeUser)
import Commands.Database exposing (firebaseInit, firebaseLoginWithJwtToken)
import Commands.Settings exposing (decodeSettings)
import Commands.Pokemon exposing (decodePokedex)
import Commands.Pages exposing (decodePages, decodePage)
import Commands.Ratings exposing (decodeTeamRatings, decodeUserRatings)
import Ports
    exposing
        ( onAuthenticationReceived
        , onAuthenticationFailed
        , onFirebaseLoginFailed
        , onLoadSettings
        , onLoadPokedex
        , onLoadPages
        , onLoadPage
        , onLoadTeamRatings
        , onLoadUserRatings
        )


init : Value -> Location -> ( ApplicationState, Cmd Msg )
init credentials location =
    let
        authModel =
            decodeUser credentials
                |> Result.toMaybe
                |> Authentication.init

        authCmd =
            case authModel.state of
                LoggedIn userData ->
                    Cmd.batch
                        [ firebaseInit
                        , firebaseLoginWithJwtToken userData.idToken
                        ]

                LoggedOut ->
                    firebaseInit

        emptyPreloaded =
            { generations = []
            , letters = []
            }

        defaultSubpage =
            { generation = initialGeneration
            , letter = initialLetter
            }

        currentRoute =
            parseLocation location

        ( initialSubpage, initialQuery, urlCmd ) =
            case currentRoute of
                Search query ->
                    ( defaultSubpage, query, Cmd.none )

                Browse _ subpage ->
                    ( subpage, "", newUrl <| createBrowsePath subpage.generation subpage.letter )

        initialState : ApplicationState
        initialState =
            { authModel = authModel
            , currentUser = Nothing
            , statusMessage = ""
            , statusLevel = None
            , statusExpiryTime = Nothing
            , debounceState = Control.initialState
            , currentRoute = currentRoute
            , generation = initialSubpage.generation
            , letter = initialSubpage.letter
            , preloaded = emptyPreloaded
            , query = initialQuery
            , settings = RemoteData.NotAsked
            , pokedex = RemoteData.NotAsked
            , pages = RemoteData.NotAsked
            , ratings = RemoteData.NotAsked
            }
    in
        ( initialState
          -- FIXME calling getTodayTime first will (possibly) update subpage.{letter,generation}.
          -- The urlCmd is not equipped to handle that. Furthermore, we don't want to overwrite page
          -- parameters that came to us in the URL. Think.
        , Cmd.batch [ getTodayTime, authCmd, urlCmd ]
        )


subscriptions : ApplicationState -> Sub Msg
subscriptions _ =
    Sub.batch
        [ onAuthenticationReceived (decodeUser >> Msgs.AuthenticationReceived)
        , onAuthenticationFailed Msgs.AuthenticationFailed
        , onFirebaseLoginFailed (.message >> Msgs.FirebaseLoginFailed)
        , onLoadSettings (decodeSettings >> Msgs.SettingsLoaded)
        , onLoadPokedex (decodePokedex >> Msgs.PokedexLoaded)
        , onLoadPages (decodePages >> Msgs.PagesLoaded)
        , onLoadPage (decodePage >> Msgs.PageLoaded)
        , onLoadTeamRatings (decodeTeamRatings >> Msgs.TeamRatingsLoaded)
        , onLoadUserRatings (decodeUserRatings >> Msgs.UserRatingsLoaded)
        , Time.every (500 * millisecond) Tick
        ]


main : Program Value ApplicationState Msg
main =
    Navigation.programWithFlags
        (parseLocation >> UrlChanged)
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
