module View exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)



navBar : Html msg
navBar =
    nav [ class "navigation" ]
        [ div [ class "title" ]
            [ text "health-proxy" ]
        ]


notFoundView : Html msg
notFoundView =
    div [ class "notfound" ]
        [ text "Page Not Found."]
