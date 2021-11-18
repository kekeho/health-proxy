module View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Browser
import Url.Parser
import Time
import Json.Encode as Encode

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


sessionView : Session -> Html msg
sessionView session =
    tr [ ]
        [ td [] [ text session.fromHostName ]
        , td [] [ text <| String.fromInt session.response.statusCode ]
        , td [] [ text session.request.path ]
        ]


detailView : Time.Zone -> Maybe Session -> Html msg
detailView zone maybeSession =
    case maybeSession of
        Nothing ->
            div [ class "detail-view" ]
                []
        Just session ->
            div [ class "detail-view" ]
                [ summaryView zone session
                , requestView session.request
                , responseView session.response
                ]

summaryView : Time.Zone -> Model.Session -> Html msg
summaryView zone session =
    div [ class "summary" ]
        [ h1 []
            [ span [ class "method" ] [ text <| Model.httpMethodToStr session.request.httpMethod ]
            , span [ class "path" ] [ text <| Model.fullPath session.request ]
            ]
        , p [ class "status" ]
            [ span
                [ class "code" 
                , style "background-color" (Model.statusColor session.response.statusCode)
                ]
                [ text <| String.fromInt session.response.statusCode ]
            , span [ class "message" ] [ text session.response.statusMessage ]
            ]
        , div [ class "route" ]
            [ p [] [ text <| "From: " ++ session.fromHostName ]
            , p [] [ text <| "To: " ++ session.toHostName ]
            ]
        , div [ class "time" ]
            [ p [] [ text <| toString zone session.timestamp ]
            ]
        ]


requestView : Model.ProxyHttpRequest -> Html msg
requestView request =
    div [ class "request" ]
        [ h2 [] [ text "Request" ]
        , details [ class "headers", property "open" (Encode.string "true") ]
            [ summary [] [ text "Headers" ]
            , ul []
                (List.map headerItem request.headers)
            ]
        , details [ class "body", property "open" (Encode.string "true") ]
            [ summary [] [ text "Body" ]
            , textarea [ readonly True ]
                [ text request.body ]
            ]
        ]


responseView : Model.HttpResponse -> Html msg
responseView response =
    div [ class "response" ]
        [ h2 [] [ text "Response" ]
        , details [ class "headers", property "open" (Encode.string "true") ]
            [ summary [] [ text "Headers" ]
            , ul []
                (List.map headerItem response.headers)
            ]
        , details [ class "body", property "open" (Encode.string "true") ]
            [ summary [] [ text "Body" ]
            , textarea [ readonly True ]
                [ text response.body ]
            ]
        ]


headerItem : (String, String) -> Html msg
headerItem (k, v) =
    li []
        [ span [] [ text k ]
        , text " : "
        , span [] [ text v ]
        ]


view : Model.Model -> Browser.Document Msg
view model =
    { title = "health-proxy"
    , body =
        [ header []
            [ navBar ]
        , div [ class "app"]
            ( case Url.Parser.parse Model.routeParser model.url of
                Just Model.IndexPage ->
                        [ detailView 
                            model.timezone
                            (Maybe.andThen (\i -> getWithIndex i model.sessions ) model.selectedSession)
                        ]
                Nothing ->
                    [ notFoundView ]
            )
        ]
    }


-- Utils

getWithIndex : Int -> List a -> Maybe a
getWithIndex index lis =
    List.take (index+1) lis
        |> List.reverse
        |> List.head


toString : Time.Zone -> Time.Posix -> String
toString zone time =
    String.fromInt (Time.toHour zone time)
    ++ ":" ++
    String.fromInt (Time.toMinute zone time)
    ++ ":" ++
    String.fromInt (Time.toSecond zone time)
