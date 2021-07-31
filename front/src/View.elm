module View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Browser
import Url.Parser

import Model
import Message exposing (..)
import Model exposing (Session)



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


errorsView : Html msg
errorsView =
    div [ class "errors" ]
        [ h1 [] [ text "Errors"]
        ]


hostsView : List Session -> Html msg
hostsView sessions =
    div [ class "hosts" ]
        [ h1 [] [ text "Hosts" ]
        , div [ class "container" ]
            (Model.splitByHost sessions
                |> List.map hostView)
        ]


hostView : (String, List Session) -> Html msg
hostView (toHostName, sessions) =
    div [ class "host" ]
        [ h2 [] [ text toHostName ]
        , table []
            [ tbody []
                (List.map sessionView <| List.take 5 sessions)
            ]
            
        ]


sessionView : Session -> Html msg
sessionView session =
    tr [ ]
        [ td [] [ text session.fromHostName ]
        , td [] [ text <| String.fromInt session.response.statusCode ]
        , td [] [ text session.request.path ]
        ]

view : Model.Model -> Browser.Document Msg
view model =
    { title = "health-proxy"
    , body =
        [ header []
            [ navBar ]
        , div [ class "app"]
            [ case Url.Parser.parse Model.routeParser model.url of
                Just Model.IndexPage ->
                    div [ class "panel" ]
                        [ errorsView
                        , hostsView model.sessions
                        ]
                Nothing ->
                    notFoundView
            ]
        ]
    }
