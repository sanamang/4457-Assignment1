extensions [ nw ]

turtles-own [ node-id xcord ycord degree community state class fear anxiety skepticism cost-of-verifying
              countdown reached? ever-shared? tick-reached decided? shared-now? c-at-decision ]
  ;; Five states: "S" (susceptible), "B" (believer: sharing the alarm, visible to friends),
  ;;   "V" (verifying the alarm before deciding), "H" (held: post hidden while the platform checks it),
  ;;   "F" (fact-checker: knows the alarm is false and does not share it)
  ;; Five classes: "Sc" (Scholar), "I" (influencer), "N" (Normal), "BBot" (Believer bots), "FBot" (Fact checker bots)
  ;; Emotion/personality: fear = emotional state (e); anxiety, skepticism = personality traits (a, s)
  ;; cost-of-verifying = c = max(0, c0 + anxiety * fear - skepticism)
  ;; countdown = ticks left in the V or H state
  ;; Tracking: reached? (has received the alarm at least once), ever-shared? (was a visible believer at least once),
  ;;   tick-reached (first tick reached, -1 if never), decided? / shared-now? / c-at-decision (the agent's first
  ;;   share-now-or-verify decision and its cost of verifying at that moment)

links-own [ weigth ]  ;; the weight of the links between agents
globals [ number-of-agents total-ticks time-effect n-effect i-s-sc i-b-sc i-f-sc i-s-in i-b-in i-f-in i-s-n i-b-n i-f-n i-b-b i-f-b
          peak-believers tick-50-reached tick-90-reached ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;   SETUP   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  if skepticism-min > skepticism-max [ error "skepticism-min must not be greater than skepticism-max" ]
  clear-all
  set number-of-agents 4039
  set total-ticks 168
  set tick-50-reached -1
  set tick-90-reached -1
  nw:set-context turtles links
  nw:load-gml "facebook.gml" turtles links
  reset-ticks             ;; start the tick counter at 0 before seeding, so seeds are recorded as reached at tick 0
  setup-turtles
  update-tracking
  update-plot
  update-output
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;   GO   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  tick
  if ticks > total-ticks [stop]   ;; stop condition (24*7 units of time - hours)

  ifelse has-time-effect? [set time-effect max list ((total-ticks - ticks) / total-ticks) 0.5][set time-effect 1]

  ifelse night-time-effect? [
    ifelse 3 <= remainder (ticks / 6) 4 [set n-effect 0][set n-effect 1]
  ][set n-effect 1]

  finish-pending          ;; held posts and verifying agents whose delay has run out reach their outcome

  spread-fear             ;; fear rises with visible believers among friends, decays otherwise
  update-cost             ;; recompute cost-of-verifying = c0 + anxiety * fear - skepticism

  spreading               ;
  forgetting              ;-- Three main procedures for agent's behavior
  veryfing                ;

  update-tracking
  update-colors           ;; just to improve the visualisation
  update-plot             ;; update plots of the Interface
  update-plot-normal
  update-plot-scholar
  update-plot-influencer
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  SETUP PROCEDURES  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-turtles
  set-default-shape turtles "person"
  ask turtles [
    setxy xcord ycord
    set size 3
    set color violet
    set anxiety random-float 1
    set skepticism skepticism-min + random-float (skepticism-max - skepticism-min)
    set fear 0
    set cost-of-verifying max list 0 (c0 - skepticism)
    set countdown 0
    set reached? false
    set ever-shared? false
    set tick-reached -1
    set decided? false
    set shared-now? false
    set c-at-decision 0
  ]

  if scholars-community != "None" [
    ask turtles with [community = scholars-community][
      set color cyan
      set class "Sc"
  ]]

  ask turtles with [degree > 200 and class != "Sc"][
    set color brown
    set size 4
    set class "I"
  ]

  ask turtles with [degree > 100 and degree < 200 and class != "Sc"][
    if count turtles with [class = "BBot"] < %-of-B-bot / 100 * number-of-agents [
      ifelse random 100 >= %-of-B-bot [set class "BBot"][ifelse count turtles with [class = "FBot"] < %-of-F-bot / 100 * number-of-agents [
        ifelse random 100 >= %-of-F-bot [set class "FBot"][set class "N"]][set class "N"]]
    ]
    if count turtles with [class = "FBot"] < %-of-F-bot / 100 * number-of-agents [
      ifelse random 100 >= %-of-F-bot [set class "FBot"][set class "N"]
    ]
  ]

  ask turtles with [class != "Sc" and class != "I" and class != "BBot" and class != "FBot"][set class "N"]
  initialization
end


to update-output
  clear-output
  output-print (word "* False-alarm diffusion with a fact-checking platform - " %-of-initial-believers "% initial believers \n alarm type: " alarm-type " \n darker colors are influencers - lighter colors are scholars \n orange = verifying, gray = held for a platform check *")
end


to initialization
  ask turtles [ set state "S" ]

  ;; seeds: exactly round(%-of-initial-believers % of the network) agents start sharing at tick 0;
  ;; each seed's post is a new post, so it gets the platform check like any other
  let n-seeds round (%-of-initial-believers / 100 * number-of-agents)
  let candidates turtles with [class != "BBot" and class != "FBot"]
  ask n-of (min list n-seeds count candidates) candidates [
    mark-reached
    start-sharing
  ]

  ask turtles with [class = "BBot"][set state "B"]
  ask turtles with [class = "FBot"][set state "F"]

  set i-b-b count turtles with [state = "B" and class = "BBot"]
  set i-f-b count turtles with [state = "F" and class = "FBot"]

  set i-s-sc count turtles with [state = "S" and class = "Sc"]
  set i-f-sc count turtles with [state = "F" and class = "Sc"]
  set i-b-sc count turtles with [state = "B" and class = "Sc"]

  set i-s-in count turtles with [state = "S" and class = "I"]
  set i-f-in count turtles with [state = "F" and class = "I"]
  set i-b-in count turtles with [state = "B" and class = "I"]

  set i-s-n count turtles with [state = "S" and class = "N"]
  set i-f-n count turtles with [state = "F" and class = "N"]
  set i-b-n count turtles with [state = "B" and class = "N"]

  update-colors
end

to update-colors
  ask turtles [
    if state = "B" [ ifelse class = "Sc" [set color blue + 3][ifelse class = "I" [set color blue - 3][ifelse class = "BBot" [set color yellow][set color blue]]]]
    if state = "F" [ ifelse class = "Sc" [set color red + 3][ifelse class = "I" [set color red - 3][ifelse class = "FBot" [set color green][set color red]]]]
    if state = "S" [ ifelse class = "Sc" [set color violet + 3][ifelse class = "I" [set color violet - 3][set color violet]]]
    if state = "V" [ set color orange ]
    if state = "H" [ set color gray ]
  ]
end

to update-plot
  set-current-plot "State-of-people"
  set-current-plot-pen "BELIEVERS"
  plot count turtles with [state = "B"]
  set-current-plot-pen "FACT-CHECKERS"
  plot count turtles with [state = "F"]
  set-current-plot-pen "SUSCEPTIBLES"
  plot count turtles with [state = "S"]
  set-current-plot-pen "VERIFYING"
  plot count turtles with [state = "V"]
  set-current-plot-pen "HELD"
  plot count turtles with [state = "H"]
end

to update-plot-normal
  set-current-plot "State-of-normals"
  set-current-plot-pen "BELIEVERS"
  plot count turtles with [class = "N" and state = "B"]
  set-current-plot-pen "FACT-CHECKERS"
  plot count turtles with [class = "N" and state = "F"]
  set-current-plot-pen "SUSCEPTIBLES"
  plot count turtles with [class = "N" and state = "S"]
end

to update-plot-scholar
  set-current-plot "State-of-scholars"
  set-current-plot-pen "BELIEVERS"
  plot count turtles with [class = "Sc" and state = "B"]
  set-current-plot-pen "FACT-CHECKERS"
  plot count turtles with [class = "Sc" and state = "F"]
  set-current-plot-pen "SUSCEPTIBLES"
  plot count turtles with [class = "Sc" and state = "S"]
end

to update-plot-influencer
  set-current-plot "State-of-influencers"
  set-current-plot-pen "BELIEVERS"
  plot count turtles with [class = "I" and state = "B"]
  set-current-plot-pen "FACT-CHECKERS"
  plot count turtles with [class = "I" and state = "F"]
  set-current-plot-pen "SUSCEPTIBLES"
  plot count turtles with [class = "I" and state = "S"]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  GO PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to finish-pending  ;; H -> F/B (platform check result) ; V -> F/B (own verification result)
  ask turtles with [state = "H" or state = "V"][
    set countdown countdown - 1
    if countdown <= 0 [
      ifelse state = "H" [
        ;; the platform's check is finished: a false alarm is flagged, a true warning is confirmed and shown
        ifelse alarm-false? [ set state "F" ][ become-visible-believer ]
      ][
        ;; the agent's own verification is finished: reject a false alarm, share a confirmed true warning
        ;; (sharing is a new post, so the platform may check it)
        ifelse alarm-false? [ set state "F" ][ start-sharing ]
      ]
    ]
  ]
end

to spread-fear  ;; fear (e) rises with the share of friends who are visible believers (B), decays otherwise
  ask turtles [
    let n-neighbors count link-neighbors
    let nB count link-neighbors with [state = "B"]
    ifelse nB > 0
      [ set fear min list 1 (fear + fear-contagion-rate * (nB / n-neighbors)) ]
      [ set fear max list 0 (fear - fear-decay-rate) ]
  ]
end

to update-cost  ;; c = c0 + a * e - s, per the formal model's Emotion and Personality section
  ask turtles [ set cost-of-verifying max list 0 (c0 + anxiety * fear - skepticism) ]
end

to spreading  ;; S -> B or H (share now) ; S -> V (verify first)
  ; only visible believers pass the alarm on. The agents exposed this tick are fixed before anyone
  ; decides, so an agent who starts sharing this tick cannot expose others until the next tick.
  ; Receiving the alarm is itself frightening: fear jumps by fear-contagion-rate before the agent decides.
  ; Once an agent receives the alarm, it follows the game's decision rule: share now when
  ; c + f * g > q * f * r, otherwise verify first.
  let exposed turtles with [state = "S" and any? link-neighbors with [state = "B"]]
  ask exposed [
    if random-float 1 < n-effect * time-effect * beta-spreadingRate [
      mark-reached
      set fear min list 1 (fear + fear-contagion-rate)
      set cost-of-verifying max list 0 (c0 + anxiety * fear - skepticism)
      let share-now? (cost-of-verifying + f * g > q * f * r)
      if not decided? [
        set decided? true
        set shared-now? share-now?
        set c-at-decision cost-of-verifying
      ]
      ifelse share-now?
        [ start-sharing ]
        [ set state "V" set countdown verify-delay ]
    ]
  ]
end

to forgetting  ;; B -> S; F -> S  -- Each agent, regardless of belief state, forgets the alarm with a fixed probability pforget
  ask turtles with [state = "B" or state = "F"][
    ifelse class = "Sc" [if random-float 1 < n-effect * time-effect * pForget-scholar [set state "S"]][
      ifelse class = "I" [if random-float 1 < n-effect * time-effect * pForget-influencer [set state "S"]]
        [if class = "N" and random-float 1 < n-effect * time-effect * pForget [set state "S"]]
      ]
  ]
end

to veryfing  ;; B -> F ; a believer can realize the alarm is false with a fixed probability pverify (false alarms only)
  if alarm-false? [
    ask turtles with [state = "B"][
      ifelse class = "Sc" [if random-float 1 < n-effect * time-effect * pVerify-scholar [set state "F"]][
        ifelse class = "I" [if random-float 1 < n-effect * time-effect * pVerify-influencer [set state "F"]]
          [if class = "N" and random-float 1 < n-effect * time-effect * pVerify [set state "F"]]
        ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;; PLATFORM AND SHARING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to start-sharing  ;; turtle procedure: the agent posts the alarm; the platform checks this post once, with probability q
  ifelse random-float 1 < q
    [ set state "H" set countdown check-delay ]
    [ become-visible-believer ]
end

to become-visible-believer  ;; turtle procedure
  set state "B"
  set ever-shared? true
end

to mark-reached  ;; turtle procedure: records the first time the agent receives the alarm
  if not reached? [
    set reached? true
    set tick-reached ticks
  ]
end

;;;;;;;;;;;;;;;;;;;;;;; TRACKING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-tracking
  let n-believers count turtles with [state = "B"]
  if n-believers > peak-believers [ set peak-believers n-believers ]
  let n-reached count turtles with [reached?]
  if tick-50-reached = -1 and n-reached >= 0.5 * number-of-agents [ set tick-50-reached ticks ]
  if tick-90-reached = -1 and n-reached >= 0.9 * number-of-agents [ set tick-90-reached ticks ]
end

;;;;;;;;;;;;;;;;;;;;;;; REPORTERS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report alarm-false?
  report alarm-type = "false"
end

to-report false-alarm-reach  ;; share of agents who were a visible believer at least once
  report count turtles with [ever-shared?] / count turtles
end

to-report share-never-reached  ;; share of agents who never received the alarm
  report count turtles with [not reached?] / count turtles
end

to-report simulated-p  ;; share of deciding agents whose first decision was to share now (-1 if nobody has decided yet)
  let deciders turtles with [decided?]
  if not any? deciders [ report -1 ]
  report count deciders with [shared-now?] / count deciders
end

to-report mean-c-at-decision  ;; mean cost of verifying at each agent's first decision (-1 if nobody has decided yet)
  let deciders turtles with [decided?]
  if not any? deciders [ report -1 ]
  report mean [c-at-decision] of deciders
end

;;;;;;;;;;;;;;;;;;;;;;; UTILS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
0
312
436
749
-1
-1
2.13
1
0
1
1
1
0
0
0
1
-100
100
-100
100
0
0
1
ticks
30.0

BUTTON
88
231
161
293
SETUP
setup\n
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
193
110
327
143
pForget
pForget
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
193
144
327
177
pVerify
pVerify
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
8
124
158
157
beta-spreadingRate
beta-spreadingRate
0
1
0.5
0.01
1
NIL
HORIZONTAL

PLOT
447
405
875
653
State-of-people
NIL
NIL
0.0
170.0
0.0
2000.0
true
true
"set-plot-y-range 0 number-of-agents" ""
PENS
"BELIEVERS" 1.0 0 -13345367 true "" ""
"SUSCEPTIBLES" 1.0 0 -7500403 true "" ""
"FACT-CHECKERS" 1.0 0 -2674135 true "" ""
"VERIFYING" 1.0 0 -955883 true "" ""
"HELD" 1.0 0 -4539718 true "" ""

MONITOR
783
499
858
544
Believers
count turtles with [state = \"B\"]
0
1
11

MONITOR
783
546
858
591
Susceptibles
count turtles with [state = \"S\"]
0
1
11

MONITOR
783
593
858
638
Fact-checker
count turtles with [state = \"F\"]
0
1
11

MONITOR
550
697
620
742
# Vertices
count turtles
17
1
11

BUTTON
185
231
258
293
GO
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
621
697
692
742
# Edges
count links
1
1
11

TEXTBOX
8
10
91
30
Initial setting
14
0.0
1

TEXTBOX
7
106
107
124
Alarm diffusion
14
0.0
1

TEXTBOX
454
709
552
727
Graph metrics:
13
0.0
1

MONITOR
693
697
773
742
Avg. Degree
sum([count link-neighbors] of turtles) / count turtles
3
1
11

TEXTBOX
786
482
840
502
#Agents:
13
0.0
1

TEXTBOX
6
202
156
221
Main commands
14
0.0
1

TEXTBOX
195
90
345
108
Probabilities
14
0.0
1

SLIDER
350
110
522
143
pForget-scholar
pForget-scholar
0
1
0.07
0.01
1
NIL
HORIZONTAL

SLIDER
538
109
710
142
pForget-influencer
pForget-influencer
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
349
149
521
182
pVerify-scholar
pVerify-scholar
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
537
150
709
183
pVerify-influencer
pVerify-influencer
0
1
0.2
0.01
1
NIL
HORIZONTAL

MONITOR
389
202
459
247
% Normal
count turtles with [class = \"N\"] / number-of-agents * 100
2
1
11

TEXTBOX
280
198
430
216
Agent classes
14
0.0
1

MONITOR
181
31
335
76
% Scholars-community
count turtles with [community = scholars-community] / 4039 * 100
2
1
11

MONITOR
543
201
637
246
% Influencers
count turtles with [class = \"I\"] / number-of-agents * 100
2
1
11

SLIDER
352
27
524
60
%-of-B-bot
%-of-B-bot
0
5
0.0
0.5
1
NIL
HORIZONTAL

MONITOR
638
202
740
247
% Believer Bots
count turtles with [class = \"BBot\"] / number-of-agents * 100
2
1
11

SLIDER
352
67
524
100
%-of-F-bot
%-of-F-bot
0
5
0.0
0.5
1
NIL
HORIZONTAL

MONITOR
575
255
707
300
% Fact checker Bots
count turtles with [class = \"FBot\"] / number-of-agents * 100
2
1
11

CHOOSER
20
30
174
75
scholars-community
scholars-community
"None" 1 2 3 4 5 6 7 8
0

MONITOR
388
256
562
301
Potential super-spreaders
count turtles with [degree > 100 and degree < 200]
17
1
11

PLOT
901
22
1328
256
State-of-normals
NIL
NIL
0.0
170.0
0.0
10.0
true
true
"set-plot-y-range 0 count turtles with [class = \"N\"]" ""
PENS
"BELIEVERS" 1.0 0 -13345367 true "" ""
"SUSCEPTIBLES" 1.0 0 -7500403 true "" ""
"FACT-CHECKERS" 1.0 0 -2674135 true "" ""

PLOT
902
277
1327
519
State-of-scholars
NIL
NIL
0.0
170.0
0.0
10.0
true
true
"set-plot-y-range 0 count turtles with [class = \"Sc\"]" ""
PENS
"BELIEVERS" 1.0 0 -13345367 true "" ""
"SUSCEPTIBLES" 1.0 0 -7500403 true "" ""
"FACT-CHECKERS" 1.0 0 -2674135 true "" ""

PLOT
902
533
1326
775
State-of-influencers
NIL
NIL
0.0
170.0
0.0
10.0
true
true
"set-plot-y-range 0 count turtles with [class = \"I\"]" ""
PENS
"BELIEVERS" 1.0 0 -14070903 true "" ""
"SUSCEPTIBLES" 1.0 0 -7500403 true "" ""
"FACT-CHECKERS" 1.0 0 -2674135 true "" ""

MONITOR
497
348
582
393
Time-effect
time-effect
2
1
11

SLIDER
538
65
722
98
%-of-initial-believers
%-of-initial-believers
0
100
1.0
1
1
NIL
HORIZONTAL

SWITCH
456
311
615
344
has-time-effect?
has-time-effect?
1
1
-1000

SWITCH
627
311
797
344
night-time-effect?
night-time-effect?
1
1
-1000

MONITOR
666
349
754
394
Night-effect
n-effect
2
1
11

MONITOR
462
201
540
246
% Scholars
count turtles with [class = \"Sc\"] / number-of-agents * 100
2
1
11

TEXTBOX
10
788
400
806
Emotion & Fact-Checking (Extension)
14
0.0
1

SLIDER
10
810
210
843
q
q
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
230
810
430
843
f
f
0
1
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
450
810
650
843
r
r
0
5
2.5
0.05
1
NIL
HORIZONTAL

SLIDER
10
847
210
880
c0
c0
0
1
0.2
0.05
1
NIL
HORIZONTAL

SLIDER
230
847
430
880
fear-contagion-rate
fear-contagion-rate
0
1
0.3
0.05
1
NIL
HORIZONTAL

SLIDER
450
847
650
880
fear-decay-rate
fear-decay-rate
0
1
0.1
0.05
1
NIL
HORIZONTAL

MONITOR
670
810
820
855
Avg. Fear
mean [fear] of turtles
2
1
11

MONITOR
670
857
820
902
Avg. Cost-of-Verifying
mean [cost-of-verifying] of turtles
2
1
11

MONITOR
840
810
990
855
False-alarm reach
false-alarm-reach
3
1
11

SLIDER
10
884
210
917
g
g
0
1
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
230
884
430
917
check-delay
check-delay
1
10
2
1
1
NIL
HORIZONTAL

SLIDER
450
884
650
917
verify-delay
verify-delay
1
10
1
1
1
NIL
HORIZONTAL

SLIDER
10
921
210
954
skepticism-min
skepticism-min
0
1
0
0.05
1
NIL
HORIZONTAL

SLIDER
230
921
430
954
skepticism-max
skepticism-max
0
1
1
0.05
1
NIL
HORIZONTAL

CHOOSER
450
921
650
966
alarm-type
alarm-type
"false" "true"
0

@#$#@#$#@
## WHAT IS IT?

This is an adapted version of an agent-based model originally built to simulate misinformation diffusion (fake news vs. its debunking). Here it's repurposed to simulate how false alarms and real emergency warnings (evacuations, contaminations, fires, etc.) spread on social networks, where an agent's choice to share an alarm immediately or verify it first depends on its emotional state and personality.

Each agent carries a "State" ("S" = susceptible: does not hold the alarm, "B" = believer: sharing the alarm where friends can see it, "V" = verifying it before deciding, "H" = held: its post is hidden while the platform checks it, "F" = fact-checker: knows the alarm is false and does not share it) and belongs to a class (scholar, influencer, bot, or normal person) that still shapes its baseline forgetting/verifying rates, same as in the original model.


## HOW IT WORKS

Each agent also carries a fear level (its current emotional state) and fixed anxiety/skepticism personality traits (skepticism is drawn between skepticism-min and skepticism-max), combining into a cost-of-verifying: cost-of-verifying = max(0, c0 + anxiety * fear - skepticism).

Only believers pass the alarm on. When a susceptible agent receives it from a believer friend, it shares now if cost-of-verifying + f * g > q * f * r, and otherwise verifies first. Here q is the platform's fact-checking level, f the chance the alarm is false, g the payoff from sharing, and r the cost of being flagged for sharing a false alarm. A verifying agent decides after verify-delay ticks: it rejects a false alarm (V -> F) or shares a true one (V -> B).

The platform checks each new post once, with probability q. A checked post is held (hidden) for check-delay ticks, then flagged (H -> F) if the alarm is false or shown (H -> B) if it is true. Forgetting (B, F -> S) works as in the original model, and believers can still realise on their own that an alarm is false (B -> F), for false alarms only. Fear spreads socially: an agent's fear jumps by fear-contagion-rate when it receives the alarm (just before it decides), rises each tick with the share of its friends who are visibly sharing, and decays otherwise.

The alarm-type chooser sets whether the alarm in a run is false or a true warning. Agents never observe this; they only know f. Exactly %-of-initial-believers % of agents (40 at the default 1%) start sharing at tick 0, and their posts get the platform check like any other.

Reporters for experiments: false-alarm-reach (share of agents who were a visible believer at least once), peak-believers, tick-50-reached and tick-90-reached (-1 if never), share-never-reached, simulated-p (share of first decisions that were share now) and mean-c-at-decision.


## HOW TO USE IT

Set up the model by modifying the cluster of scholars (you can see the size of each cluster in the form of % of the total network, on the right side of "Chooser"), spreading rate, % of initial believers, % of each type of bot in the network, probabilities of verifying and forgetting for each class, and the Emotion & Fact-Checking controls (q, f, r, g, c0, fear-contagion-rate, fear-decay-rate, check-delay, verify-delay, skepticism-min, skepticism-max, alarm-type). You can also play around with the effect of time. You can choose to see what if the effect of the alarm gradually decreases during 7 days, or you can see what if agents do not interact during night time (when they are all sleeping.)

The State-of-people graph shows the number of agents in each state, including verifying and held agents. Also, you can see this graph for each class, separately.


## THINGS TO TRY

Change the inputs to investigate their impact on diffusion processes. In particular, sweep q (platform checking rate) to see whether there's a level that suppresses false-alarm reach without badly delaying real warnings.


## EXTENDING THE MODEL

#1 Determine and add more classes based on information on social media
 
#2 Include more networks (other than Facebook) and test the model on them

#3 Try to find new strategies for controling the misinformation 


## CREDITS AND REFERENCES

Khodabandeh Yalabadi, A., et. al. (2023). Controlling the misinformation diffusion in social media by the effect of different classes of agents. In 2023 CSS Conference.


Sulis, E., Tambuscio, M. (2020). Simulation of misinformation spreading processes in social networks: an application with NetLogo. In 2020 IEEE International Conference on Data Science and Advanced Analytics (DSAA), IEEE.
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
NetLogo 6.3.0
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

curved link
1.5
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
