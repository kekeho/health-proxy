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
import Html.Events exposing (onClick)
import Model exposing (Filter)
import Html.Events exposing (onInput)
import Model exposing (FilterEditor)



navBar : Html msg
navBar =
    nav [ class "navigation" ]
        [ div [ class "title" ]
            [ text "health-proxy" ]
        , div [ class "links" ]
            [ a [ class "github", href "https://github.com/kekeho/health-proxy" ]
                [ text "GitHub" ]
            ]
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


listView : Time.Zone -> Model.Filter -> Model.FilterEditor -> Maybe Int -> List Model.Session -> Html Msg
listView tz filter filterEditor selectedSession sessions =
    div [ class "list-view" ]
        [ div [ class "traffic" ]
            [ h1 [] [ text "Filter" ] 
            , filterView filter filterEditor
            , h1 [] [ text "Traffic" ]
            , table [] 
                [ thead []
                    [ tr []
                        [ th [] [ text "Method" ]
                        , th [] [ text "Path" ]
                        , th [] [ text "Status" ]
                        , th [] [ text "From" ]
                        , th [] [ text "Time" ]
                        ]
                    ]
                , tbody []
                    (List.indexedMap (\i s -> sessionRow tz selectedSession s i) <| filterFunc filter sessions)
                ]
            ]
        ]


filterFunc : Filter -> List Model.Session -> List Model.Session
filterFunc filter sessionList =
    let
        statusFilter: List Int -> List Model.Session -> List Model.Session
        statusFilter st ss =
            if List.length st == 0 then
                ss
            else
                List.filter (\s -> List.member s.response.statusCode st) ss

        methodFilter: List Model.HttpMethod -> List Model.Session -> List Model.Session
        methodFilter mt ss =
            if List.length mt == 0 then
                ss
            else
                List.filter (\s -> List.member s.request.httpMethod mt) ss
        fromFilter: List String -> List Model.Session -> List Model.Session
        fromFilter fr ss =
            if List.length fr == 0 then
                ss
            else
                List.filter (\s -> List.member s.fromHostName fr) ss
        toFilter: List String -> List Model.Session -> List Model.Session
        toFilter to ss =
            if List.length to == 0 then
                ss
            else
                List.filter (\s -> List.member s.toHostName to) ss
    in
    sessionList
        |> statusFilter filter.status
        |> methodFilter filter.method
        |> fromFilter filter.from
        |> toFilter filter.to


filterView : Filter -> FilterEditor -> Html Msg
filterView filter filterEditor =
    div [ class "filter-view" ]
        [ details [ class "status" ]
            [ summary [] [ text ("Status (" ++ String.fromInt (List.length filter.status) ++ ")") ]
            , addView Model.Status filterEditor.status
            , ul []
                (List.indexedMap (filterList Model.Status) <| List.map String.fromInt filter.status)
            ]
        , details [ class "method" ]
            [ summary [] [ text ("Method (" ++ String.fromInt (List.length filter.method) ++ ")") ]
            , addView Model.Method filterEditor.method
            , ul []
                (List.indexedMap (filterList Model.Method) <| List.map Model.httpMethodToStr filter.method )
            ]
        , details [ class "from" ]
            [ summary [] [ text ("From (" ++ String.fromInt (List.length filter.from) ++ ")") ]
            , addView Model.From filterEditor.from
            , ul []
                (List.indexedMap (filterList Model.From) filter.from)
            ]
        , details [ class "to" ]
            [ summary [] [ text ("To (" ++ String.fromInt (List.length filter.to) ++ ")") ]
            , addView Model.To filterEditor.to
            , ul []
                (List.indexedMap (filterList Model.To) filter.to)
            ]
        ]


filterList : Model.FilterType -> Int -> String -> Html Msg
filterList filterType id string =
    li []
        [ text string
        , span [ onClick (DeleteFilter filterType id) ] [text " [☓]"]
        ]

addView : Model.FilterType -> String -> Html Msg
addView filterType val =
    div [ class "add" ]
        [ input [type_ "text", onInput (EditFilterEditor filterType), value val ] []
        , button [ onClick (AddFilter filterType) ] [ text "Add" ]
        ]


sessionRow : Time.Zone -> Maybe Int -> Model.Session -> Int -> Html Msg
sessionRow tz selectedSession session index =
    let
        selected =
            case selectedSession of
                Nothing ->
                    ""
                Just sessionId ->
                    if sessionId == index then "selected" else ""
    in
    tr [ onClick <| ChangeSelectedSession index, class selected ]
        [ td [] [ text <| Model.httpMethodToStr session.request.httpMethod ]  -- method
        , td [] [ text <| Model.fullPath session.request ]  -- path
        , td [] [ text <| String.fromInt session.response.statusCode ]  -- status
        , td [] [ text session.fromHostName ] -- from
        , td [] [ text <| toString tz session.timestamp ]
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
                        , listView model.timezone model.filter model.filterEditor model.selectedSession model.sessions
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
    (String.padLeft 2 '0' <| String.fromInt (Time.toHour zone time))
    ++ ":" ++
    (String.padLeft 2 '0' <| String.fromInt (Time.toMinute zone time))
    ++ ":" ++
    (String.padLeft 2 '0' <| String.fromInt (Time.toSecond zone time))
