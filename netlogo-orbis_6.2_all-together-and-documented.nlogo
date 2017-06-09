extensions [ gis nw vid]
;; the current version is substantially based on the netlogo gis extension;
;; the extension for network creation and analysis [i.e. nw] is not used at this point
;; the vid extension represents a simple way how to produce movies from the simulation

globals [
          orbnetwork-dataset ;;network from orbis
          provinces-dataset  ;; polygon dataset of roman provinces, including additional information concerning cities let by Wilson in anonymity

          wilson-dataset    ;; point dataset coded by VK on the basis of Wilson's article
          orbsites-dataset;; point dataset of sites from orbis, except of the sites marking crossroads

          road-ratio  ;; do I use it?
          sea-ratio    ;; do I use it?
          river-ratio   ;; do I use it?
          ]

breed [ids id ] ; all nodes in the network, including cities, which differ from other nodes by having population bigger than 0, i.e. ids with [pop > 0]

breed [ wilcities wilcity ]
breed [ orbcities orbcity ]

breed [orbwilsites orbwilsite] ; uploaded dataset of sites combining orbis and Wilson population sizes
breed [provinces province] ;

;; entities related to the diffusion process:

breed [churches church] ; to be sprouted in individual cities]
breed [disseminators disseminator] ;; a wandering prophet, missionary or travelling bishop
undirected-link-breed [routes route]
directed-link-breed [assimilators assimilator] ; a link helping with merging
;undirected-link-breed [connections connection]
; undirected-link-breed [helpings helping]

patches-own [cost my-province anon-num anon-num-avr]

;; the two input datasets of sites
wilcities-own [name wilpop]
orbcities-own [name rank closest-wil-pop closest-wil-name my-avr-pop my-anon-num my-province-others]

;;combined input dataset of sites
orbwilsites-own [name wilname pop pop-type former-breed] ;; originally newsites

;; all  points upon the network; some of them fulfilling the role of cities
ids-own [
  my-type
  my-type-ratio
  my-orb-id
  my-e
  pop
  name
  distance-to-one
  infected?
  my-close
  ]

routes-own [
  my-end-type
  my-end-orb-id
  my-end-e
  my-ratio-distance
  ]

; helpings-own [my-weighted-distance]



churches-own [
  my-orb-id
  pop
  name
  church-age]
disseminators-own [
  my-actual-id
  my-new-id
  my-last-id
  route-to-take
  travelled-route
  travelled-distance
  in-city?
  length-of-stay
  city-stay-length
]



to setup-environment
  clear-all
  gis:load-coordinate-system (word "data/WGS_84_Geographic.prj")
  ; Load all of our datasets
  set wilson-dataset gis:load-dataset "data/wilson-settlements.shp"
  set orbsites-dataset gis:load-dataset "data/orbis-sites.shp"
  set orbnetwork-dataset gis:load-dataset "data/orbis.shp"
  set provinces-dataset gis:load-dataset "data/provinces.shp"
  ;; set connections-dataset gis:load-dataset "data/supportive-roads.shp"  ;; can we create them as well
  gis:set-world-envelope (gis:envelope-union-of
                                                (gis:envelope-of wilson-dataset)
                                                (gis:envelope-of orbsites-dataset)
                                                ;(gis:envelope-of orbnetwork-dataset)
                                                (gis:envelope-of provinces-dataset)
                                                )

   display-wilcities
   display-orbcities
   display-provinces
   merge-cities
   find-anonymous  ;; creates new wilcities on the place of some orbsites
   generate-orbwilsites ;; a new generation of cities
;
   display-orbis-lines
   constrain-by-provinces
;
;   ;produce-connections-into-new-dataset
   reset-ticks
end

to display-wilcities
  foreach gis:feature-list-of wilson-dataset [ [vector-feature] ->
    ;; gis:set-drawing-color scale-color red (gis:property-value vector-feature "INHAB") 1000000 1000
    ;; gis:fill vector-feature 2.0
    let location gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
      ; location will be an empty list if the point lies outside the
      ; bounds of the current NetLogo world, as defined by our current
      ; coordinate transformation
       if not empty? location
      [ create-wilcities 1
        [ set xcor item 0 location
          set ycor item 1 location
          set shape "circle"
          ;; set size 5
          set wilpop gis:property-value vector-feature "POP2" ;; calls Wilson's population numbers in form of integers
          if gis:property-value vector-feature "POP2" = 0 [ ;; calls Willson's average numbers in form of intergers
            set wilpop gis:property-value vector-feature "POP3"
            ]
          set size sqrt (wilpop / 2000) ;; visualizes the city size as squared root of the population size divided by 2000
          set color yellow
          set name gis:property-value vector-feature "name"
        ]
      ]
    ]

end


to display-orbcities
  foreach gis:feature-list-of orbsites-dataset [ [vector-feature] ->
    ;; gis:set-drawing-color scale-color red (gis:property-value vector-feature "INHAB") 1000000 1000
    ;; gis:fill vector-feature 2.0
    let location gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
      ; location will be an empty list if the point lies outside the
      ; bounds of the current NetLogo world, as defined by our current
      ; coordinate transformation
       if not empty? location
      [ create-orbcities 1
        [ set xcor item 0 location
          set ycor item 1 location
          set shape "circle"
          set rank gis:property-value vector-feature "Rank"
          set size (rank / 50)
          set color red
          set name gis:property-value vector-feature "Name"
        ]
      ]
    ]

end

to display-provinces
  gis:set-drawing-color white
  gis:draw provinces-dataset 1

  gis:apply-coverage provinces-dataset "NUM_OF_CIT" anon-num
  gis:apply-coverage provinces-dataset "AVR_CITY" anon-num-avr
  gis:apply-coverage provinces-dataset "NAME" my-province

end



to merge-cities
  ask wilcities [
     if any? orbcities in-radius radius-size [ ;;specified distance for merging
       create-assimilator-to max-one-of orbcities in-radius radius-size [rank] ;; creates a link (called here "assimilator") between with the biggest one (i.e. with highest rank) from close orbsites
       ]
  ] ;;; each city from Wilson's dataset creates link with its nearest neighbor from the orbis dataset


  ask assimilators [ ; now we use this link to transfer values of certain variables upon the orbsites
      ask end2 [ ;;those from orbcities in the radius with highest rank
        set closest-wil-pop [wilpop] of max-one-of in-link-neighbors [wilpop] ; min-one-of wilcities [distance myself] ;;adopt the population from the nearest one from them
        set closest-wil-name [name] of max-one-of in-link-neighbors [wilpop] ;; the linked orbcity receives information about label of its closest wilcity
        set size sqrt (closest-wil-pop / 2000)
        set color green
        ask max-one-of in-link-neighbors [wilpop] [hide-turtle]
        ]
       ]
end

to find-anonymous
 ask orbcities with [count my-in-links = 0 and is-number? anon-num-avr and anon-num > 0 ] [
     set my-anon-num anon-num ; the city gains knowledge about number of anonymous cities in given province
     set my-province-others count other orbcities with [count my-in-links = 0 and my-province = [my-province] of myself]
     ifelse (count other orbcities with [count my-in-links = 0 and my-province = [my-province] of myself and my-avr-pop != 0] < my-anon-num) and (count other orbcities with [count my-in-links = 0 and my-province = [my-province] of myself and my-avr-pop != 0] < count orbcities with [my-province = [my-province] of myself and rank <= [rank] of myself]) [
       ; A city has to decide whether to accept the anonymous pop-size.
       ; It counts other cities in the province to check how many from the available candidates already adopted the new pop-size.
       ; It compares the number of cities already with number of other candidates with higher or the same rank.
       set my-avr-pop anon-num-avr
       set size sqrt ( my-avr-pop / 2000 )
       set color blue]
      [set color red]
    ]
end

to generate-orbwilsites ;; generates a new set of cities, combining features from wilson and orbis
  ask orbcities with [color = blue or color = green][ ; consider only cities with either given or attributed population
    hatch-orbwilsites 1 [
         set name [name] of myself
         set wilname [closest-wil-name] of myself
         set former-breed [breed] of myself
         ifelse [closest-wil-pop] of myself > 0
           [set pop [closest-wil-pop] of myself]
           [set pop [my-avr-pop] of myself]
         ]
       ]
  ask wilcities with [count my-out-links = 0] [   ;;;;;;!!!!!! this does not solve those who found their neighbors but did not give them their values
    hatch-orbwilsites 1 [
        set name [name] of myself
        set former-breed [breed] of myself
        set pop [wilpop] of myself
        ]
       ]

  ask orbwilsites [
    set shape "circle"
    set size sqrt (pop / 1000)
    set color white

    hatch-ids 1 [ ;;; to work with the network extension, we need all turtles considered to be part of the same breed. Therefore, we create new ids, equepped by properties of their parent orbwisites
      set shape "circle"
      set size sqrt (pop / 2000)]
     ; set hidden? true
  ]
end



to display-orbis-lines
  ;gis:set-drawing-color red
  ;gis:draw orbnetwork-dataset 1
  foreach gis:feature-list-of orbnetwork-dataset [ [vector-feature] ->
    foreach gis:vertex-lists-of vector-feature [ [vertex] ->
      let previous-turtle nobody
      let first-turtle nobody
      foreach but-last vertex [ [point] ->
        let location gis:location-of point
        if not empty? location
        [ create-ids 1
          [ set xcor item 0 location
            set ycor item 1 location
            set my-type gis:property-value vector-feature "t" ; the types are: coastal, ferry, hires, overseas, road, slowover, upstream
            set my-orb-id gis:property-value vector-feature "gid"
            set my-e gis:property-value vector-feature "e"
            set pop 0
            ifelse previous-turtle = nobody
            [ set first-turtle self ]
            [ create-route-with previous-turtle [
                set color 56
                if [my-type] of end1 = [my-type] of end2
                    [set my-end-type [my-type] of end1]
                if [my-orb-id] of end1 = [my-orb-id] of end2
                    [set my-end-orb-id [my-orb-id] of end1]
                if [my-e] of end1 = [my-e] of end2
                    [set my-end-e [my-e] of end1]
                ]
            ]
            set hidden? true
            set previous-turtle self ] ] ] ] ]
  ask routes with [my-end-type = "road" or my-end-type = "hires" or my-end-type = "ferry"] [set my-ratio-distance link-length * 52] ; * road-ratio)]
  ask routes with [my-end-type = "overseas" or my-end-type = "slowover" or my-end-type = "coastal"] [set my-ratio-distance link-length * 1] ;* sea-ratio]
  ask routes with [my-end-type = "upstream"] [set my-ratio-distance link-length * 7.5] ; * river-ratio]
  ask ids with [my-type = "road" or my-type = "hires" or my-type = "ferry"] [set my-type-ratio 52] ; * road-ratio)]
  ask ids with [my-type = "overseas" or my-type = "slowover" or my-type = "coastal"] [set my-type-ratio 1] ;* sea-ratio]
  ask ids with [my-type = "upstream"] [set my-type-ratio 7.5] ; * river-ratio]
end

;to generate-orbwilsites
;  foreach gis:feature-list-of orbwilsites-dataset [ [vector-feature] ->
;    ;; gis:set-drawing-color scale-color red (gis:property-value vector-feature "INHAB") 1000000 1000
;    ;; gis:fill vector-feature 2.0
;    let location gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
;      ; location will be an empty list if the point lies outside the
;      ; bounds of the current NetLogo world, as defined by our current
;      ; coordinate transformation
;       if not empty? location
;      [ create-orbwilsites 1
;        [ set xcor item 0 location
;          set ycor item 1 location
;          set shape "circle"
;          ;; set size 5
;          set pop gis:property-value vector-feature "POP" ;; calls Wilson's population numbers in form of integers
;          set size sqrt (pop / 2000) ;; visualizes the city size as squared root of the population size divided by 2000
;          set color 45
;          set name gis:property-value vector-feature "name"
;        ]
;      ]
;    ]
;  ask orbwilsites [
;    hatch-ids 1 [ ;;; to work with the network extension, we need all turtles considered to be part of the same breed. Therefore, we create new ids, equepped by properties of their parent orbwisites
;      set shape "circle"
;      set size sqrt (pop / 2000)]
;    set hidden? true]
;end

to constrain-by-provinces ; destroys ids and routes outside roman provinces
  gis:set-drawing-color white
  gis:draw provinces-dataset 1
  ask patches gis:intersecting provinces-dataset [set pcolor 31]
  ;gis:apply-coverage provinces-dataset "NAME" my-province
  ;ask patches [
  ;  if empty? my-province [set pcolor blue]
  ;  ]
  ;if not gis:contained-by? orbwilsites-dataset provinces-dataset [die]
  ask ids with [(pcolor != 31) and ((my-type = "road") or ( my-type = "hires") or (my-type = "upstream") or (my-type = "ferry"))] [  ;to eliminate everthing on land outside the provinces
    ask my-links [die]
    die]
  ask ids with [(pcolor != 31) and pop > 0] [die] ; to eliminate ids outside the provinces generated from orbwilsites
end


to complete-network ;; produces connections to complete the network
  ask ids with [pop < 1 and count my-links = 0] [die]
  ask ids with [pop < 1 and count my-links < 2] [
    create-routes-with min-n-of 2 other ids [distance myself]
    ]
  ask ids with [pop > 0] [
    create-routes-with min-n-of 1 other ids with [xcor != [xcor] of myself and ycor != [ycor] of myself] [distance myself]
  ]
  ask routes with [color != 56] ;set my-ratio-distance for just created connections
    [ set my-end-type "road"
      set my-ratio-distance (link-length * 52)]
end


to setup-simulation
  ask churches [die]
  ask disseminators [die]
  ask one-of ids with [name = "Ierusalem"] ; starting by a community in Jerusalem
    [hatch-churches 1
      [set shape "square"
      set color red
      set size 3
      set church-age 0]
      ]
    reset-ticks
    if vid:recorder-status = "recording" [ vid:record-view ]
end

to go
  ask churches [
     set church-age church-age + 1
     if size < ([size] of one-of ids-here with [pop > 0] ) [
        set size size + (church-age / 10000)]
     let hatching-chance 0
     set hatching-chance random 9
     if hatching-chance = 1 [
         hatch-disseminators 1 [
           set shape "person"
           set color red
           set size 2
           set my-actual-id one-of ids-here
           set in-city? false] ;;new born disseminators are free to move immediately
         ]
     ]
    ask disseminators [
      while [in-city? = false and travelled-distance < max-distance] [
        set route-to-take one-of [my-routes] of my-actual-id ; with [link-neighbors != my-last-id]  ;with [other-end != my-last-id]  ; with [color != red]
        set my-new-id one-of other [link-neighbors] of my-actual-id
        move-to my-new-id
        let step-length 0
        set step-length (distance my-actual-id * [my-type-ratio] of my-new-id)
        set my-actual-id my-new-id
        set travelled-distance travelled-distance + step-length
        if ([pop] of my-actual-id) > 0 [
           set in-city? true
           set length-of-stay 0
        ]]]

  ask disseminators with [in-city? = true] [
    set city-stay-length int ([pop] of my-actual-id / 1000) ; how long it is appropriate to stay here
    set length-of-stay (length-of-stay + 1) ;how long has been the disseminator here so far
    let hatching-chance 0
    set hatching-chance random 4 ; while in a city, I can hatch a church with probability 1:5
    if hatching-chance = 1 [
      ifelse any? churches-here
        [
          ask churches-here [
             if size < ([size] of one-of ids-here with [pop > 0] )
               [set size (size + 0.5)]
          ]]
        [
        hatch-churches 1
        [set shape "square"
        set color red
        set size 3
        set church-age 0]
        ]
        ]

    if length-of-stay >= city-stay-length [
      set in-city? false
      set travelled-distance 0
    ] ; the stay length is proportional to city size
    ]
  if vid:recorder-status = "recording" [ vid:record-view ]
  tick
end


to start-recorder
  reset-recorder
  carefully [ vid:start-recorder ] [ user-message error-message ]
end

to reset-recorder
  let message (word
    "If you reset the recorder, the current recording will be lost."
    "Are you sure you want to reset the recorder?")
  if vid:recorder-status = "inactive" or user-yes-or-no? message [
    vid:reset-recorder
  ]
end

to save-recording
  if vid:recorder-status = "inactive" [
    user-message "The recorder is inactive. There is nothing to save."
    stop
  ]
  ; prompt user for movie location
  user-message (word
    "Choose a name for your movie file (the "
    ".mp4 extension will be automatically added).")
  let path user-new-file
  if not is-string? path [ stop ]  ; stop if user canceled
  ; export the movie
  carefully [
    vid:save-recording path
    user-message (word "Exported movie to " path ".")
  ] [
    user-message error-message
  ]
end

@#$#@#$#@
GRAPHICS-WINDOW
5
10
590
596
-1
-1
1.0
1
10
1
1
1
0
1
1
1
-288
288
-288
288
0
0
1
ticks
30.0

BUTTON
606
16
757
50
NIL
setup-environment
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
185
18
311
63
links
count links
17
1
11

MONITOR
320
17
378
62
ids
count ids
17
1
11

TEXTBOX
625
462
775
546
ask one-of ids with [name = \"Roma\"] [show nw:weighted-distance-to one-of ids with [name = \"Ierusalem\"] my-ratio-distance]
11
0.0
1

BUTTON
609
101
747
134
NIL
setup-simulation
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
612
143
675
176
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
610
58
754
91
NIL
complete-network
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
604
252
776
285
max-distance
max-distance
0
50000
25200.0
100
1
NIL
HORIZONTAL

MONITOR
634
353
774
398
NIL
count disseminators
17
1
11

MONITOR
638
414
748
459
NIL
count churches
17
1
11

BUTTON
949
119
1070
152
NIL
start-recorder
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
951
172
1078
205
NIL
save-recording\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
949
213
1083
258
NIL
vid:recorder-status
17
1
11

SLIDER
806
76
978
109
radius-size
radius-size
0
10
2.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
