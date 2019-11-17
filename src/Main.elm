module Main exposing (Model)

import Browser
import Html exposing (Html, div)
import Html.Attributes exposing (style)
import Svg exposing (Svg, circle, g, line, polygon, svg)
import Svg.Attributes exposing (cx, cy, fill, fillOpacity, points, r, stroke, transform, viewBox, width, x1, x2, y1, y2)
import Time


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    Time.Posix


init : () -> ( Model, Cmd Msg )
init _ =
    ( Time.millisToPosix 0, Cmd.none )



-- UPDATE


type Msg
    = Tick Time.Posix


update : Msg -> Model -> ( Model, Cmd Msg )
update msg _ =
    case msg of
        Tick newTime ->
            ( newTime, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every second Tick


second =
    1000



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ style "padding" "10px"
        , style "border" "solid 1px"
        , style "max-width" "100px"
        ]
        [ svg [ viewBox "0 0 100 100", width "100px" ]
            (clockFn model Time.utc)
        ]


clockFn : Time.Posix -> Time.Zone -> List (Svg Msg)
clockFn theDateNow zone =
    [ g [ fill "black", stroke "black", transform "translate(50,50)" ]
        (clockFace
            ++ hourHand theDateNow zone
            ++ minutesHand theDateNow zone
            ++ secondsHand theDateNow zone
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
            toString (minuteToAngle minute)
    in
    line [ x1 tickStart, y1 "0", x2 "49", y2 "0", transform ("rotate(" ++ angle ++ ")") ] []


minuteToAngle : Int -> Float
minuteToAngle minute =
    (toFloat minute - 15.0) * 360 / 60.0


hourHand : Time.Posix -> Time.Zone -> List (Svg Msg)
hourHand theDateNow zone =
    let
        angle =
            minuteToAngle (hourMinute theDateNow zone)
    in
    [ g [ transform ("rotate(" ++ toString angle ++ ")") ]
        [ polygon [ points "0,0 4,4 20,0 4, -4", transform "translate(10,0)" ] []
        , xLine "0" "10"
        ]
    ]


toString : Float -> String
toString f =
    String.fromFloat f



-- Which minute should the hour hand point to?


hourMinute : Time.Posix -> Time.Zone -> Int
hourMinute theDateNow zone =
    modBy 12 (Time.toHour zone theDateNow) * 5 + Time.toMinute zone theDateNow // 12


minutesHand : Time.Posix -> Time.Zone -> List (Svg Msg)
minutesHand theDateNow zone =
    let
        angle =
            minuteToAngle (Time.toMinute zone theDateNow)
    in
    [ g [ transform ("rotate(" ++ toString angle ++ ")") ]
        [ polygon [ points "0,0 2,2 30,0 2, -2", transform "translate(5,0)" ] []
        , xLine "0" "5"
        ]
    ]


secondsHand : Time.Posix -> Time.Zone -> List (Svg Msg)
secondsHand theDateNow zone =
    let
        angle =
            minuteToAngle (Time.toSecond zone theDateNow)
    in
    [ g [ transform ("rotate(" ++ toString angle ++ ")") ]
        [ xLine "-5" "40"
        , circle [ cx "0", cy "0", r "5", fillOpacity "0", transform "translate(30,0)" ] []
        ]
    ]


xLine : String -> String -> Svg Msg
xLine start end =
    line [ x1 start, y1 "0", x2 end, y2 "0" ] []
