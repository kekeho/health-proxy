module View exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)

notFoundView : Html msg
notFoundView =
    div [ class "notfound" ]
        [ text "Page Not Found."]
