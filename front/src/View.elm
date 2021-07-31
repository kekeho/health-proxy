module View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Browser
import Url.Parser

import Model
import Message exposing (..)



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


view : Model.Model -> Browser.Document Msg
view model =
    { title = "health-proxy"
    , body =
        [ header []
            [ navBar ]
        , div [ class "app"]
            [ case Url.Parser.parse Model.routeParser model.url of
                Just Model.IndexPage ->
                    div []
                        [ text "Index"]
                Nothing ->
                    notFoundView
            ]
        ]
    }
