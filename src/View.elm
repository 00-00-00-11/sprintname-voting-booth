module View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)


{-
   import Material
   import Material.Scheme
   import Material.Table as Table
   import Material.Button as Button
   import Material.Options as Options exposing (css)
   import Material.Typography as Typo
   import Material.Elevation as Elevation
-}

import ViewHelper exposing (..)
import Model exposing (..)
import Msgs exposing (Msg)


pokemonImg : String -> Html Msg
pokemonImg imageUrl =
    img
        [ src imageUrl
        , class "pokemon-image"
        ]
        []


pokemonVotes : List UserVote -> Html Msg
pokemonVotes userVotes =
    span [] (List.map voteNode userVotes)


pokemonRow : Pokemon -> Html Msg
pokemonRow pokemon =
    tr []
        [ td [] [ text <| toString pokemon.number ]
        , td [] [ linkTo pokemon.url <| text pokemon.name ]
        , td [] [ linkTo pokemon.url <| pokemonImg pokemon.image ]
        , td [] [ pokemonVotes pokemon.votes ]
        , td [] [ rateWidget ]
        ]


pokemonRows : List Pokemon -> List (Html Msg)
pokemonRows pokelist =
    List.map pokemonRow pokelist


viewPokemonTable : Int -> Char -> Pokedex -> Html Msg
viewPokemonTable currentgen currentletter pokedex =
    div []
        [ heading currentgen
        , table [ class "poketable" ] (pokemonRows pokedex.pokemon) -- TODO filter by currentletter
        ]
