module Main exposing (Model)

import Browser
import Html exposing (Html, div)
import Html.Attributes exposing (style)
import Svg exposing (Svg, circle, g, line, polygon, svg)
import Svg.Attributes exposing (cx, cy, fill, fillOpacity, points, r, stroke, transform, viewBox, width, x1, x2, y1, y2)
import Task
import Time
import TimeZone


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias TimeOfDay =
    { hour : Int
    , minute : Int
    , second : Int
    }


type alias Model =
    { time : TimeOfDay
    , timeZone : Time.Zone
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { time = TimeOfDay 0 0 0
      , timeZone = Time.utc
      }
    , TimeZone.getZone |> Task.attempt ReceiveTimeZone
    )



-- UPDATE


type Msg
    = Tick Time.Posix
    | ReceiveTimeZone (Result TimeZone.Error ( String, Time.Zone ))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick newTime ->
            ( { model | time = dateFromPosix model.timeZone newTime }, Cmd.none )

        ReceiveTimeZone (Ok ( _, zone )) ->
            ( { model | timeZone = zone }, Cmd.none )

        ReceiveTimeZone (Err _) ->
            ( model, Cmd.none )


dateFromPosix : Time.Zone -> Time.Posix -> TimeOfDay
dateFromPosix zone time =
    TimeOfDay (Time.toHour zone time) (Time.toMinute zone time) (Time.toSecond zone time)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every second Tick


second =
    1000



-- VIEW


clockWidth =
    "300px"


view : Model -> Html Msg
view model =
    div
        [ style "height" "100%"
        , style "display" "flex"
        , style "align-items" "center"
        , style "justify-content" "center"
        ]
        [ div
            [ style "padding" "10px"
            , style "max-width" clockWidth
            ]
            [ svg [ viewBox "0 0 100 100", width clockWidth ]
                (clockFn model.time)
            ]
        ]


clockFn : TimeOfDay -> List (Svg Msg)
clockFn theDateNow =
    [ g [ fill "black", stroke "black", transform "translate(50,50)" ]
        (clockFace
            ++ hourHand theDateNow
            ++ minutesHand theDateNow
            ++ secondsHand theDateNow
        )
    ]


clockFace : List (Svg Msg)
clockFace =
    [ circle [ cx "0", cy "0", r "49", fill "white" ] []
    ]
        ++ tickMarks


tickMarks : List (Svg Msg)
tickMarks =
    List.map tick (List.range 1 60)


tick : Int -> Svg Msg
tick minute =
    let
        tickStart =
            if modBy 5 minute == 0 then
                "35"

            else
                "42"

        angle =
            String.fromFloat (minuteToAngle minute)
    in
    line [ x1 tickStart, y1 "0", x2 "49", y2 "0", transform ("rotate(" ++ angle ++ ")") ] []


minuteToAngle : Int -> Float
minuteToAngle minute =
    (toFloat minute - 15.0) * 360 / 60.0


hourHand : TimeOfDay -> List (Svg Msg)
hourHand theDateNow =
    let
        angle =
            minuteToAngle (hourMinute theDateNow)
    in
    [ g [ transform ("rotate(" ++ String.fromFloat angle ++ ")") ]
        [ polygon [ points "0,0 4,4 20,0 4, -4", transform "translate(10,0)" ] []
        , xLine "0" "10"
        ]
    ]



-- Which minute should the hour hand point to?


hourMinute : TimeOfDay -> Int
hourMinute theDateNow =
    modBy 12 theDateNow.hour * 5 + theDateNow.minute // 12


minutesHand : TimeOfDay -> List (Svg Msg)
minutesHand theDateNow =
    let
        angle =
            minuteToAngle theDateNow.minute
    in
    [ g [ transform ("rotate(" ++ String.fromFloat angle ++ ")") ]
        [ polygon [ points "0,0 2,2 30,0 2, -2", transform "translate(5,0)" ] []
        , xLine "0" "5"
        ]
    ]


secondsHand : TimeOfDay -> List (Svg Msg)
secondsHand theDateNow =
    let
        angle =
            minuteToAngle theDateNow.second
    in
    [ g [ transform ("rotate(" ++ String.fromFloat angle ++ ")") ]
        [ xLine "-5" "40"
        , circle [ cx "0", cy "0", r "5", fillOpacity "0", transform "translate(30,0)" ] []
        ]
    ]


xLine : String -> String -> Svg Msg
xLine start end =
    line [ x1 start, y1 "0", x2 end, y2 "0" ] []
