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


type alias Date =
    { hour : Int
    , minute : Int
    , second : Int
    }


type alias Model =
    Date


init : () -> ( Model, Cmd Msg )
init _ =
    ( Date 0 0 0, Cmd.none )



-- UPDATE


type Msg
    = Tick Time.Posix


update : Msg -> Model -> ( Model, Cmd Msg )
update msg _ =
    case msg of
        Tick newTime ->
            ( dateFromPosix newTime, Cmd.none )


dateFromPosix : Time.Posix -> Date
dateFromPosix time =
    Date (Time.toHour Time.utc time) (Time.toMinute Time.utc time) (Time.toSecond Time.utc time)



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
            (clockFn model)
        ]


clockFn : Date -> List (Svg Msg)
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


hourHand : Date -> List (Svg Msg)
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


hourMinute : Date -> Int
hourMinute theDateNow =
    modBy 12 theDateNow.hour * 5 + theDateNow.minute // 12


minutesHand : Date -> List (Svg Msg)
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


secondsHand : Date -> List (Svg Msg)
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
