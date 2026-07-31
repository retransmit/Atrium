# Tracearr API Guide for Activity, Storage, and Watch

> [!NOTE]
> All these endpoints require serverIds.

1. `GET http://summer.com:3030/api/v1/stats/plays?period=month&serverIds=c0e8e3cc-198c-4de6-824f-95e59351be96&serverIds=a320eed6-e55e-4fe1-af50-6bf03939ac32&timezone=Asia/Kolkata`: Plays by month.

Response Payload:

```bash
{
   "data":[
      {
         "date":"2026-07-29 00:00:00",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "count":1
      },
      {
         "date":"2026-07-29 00:00:00",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "count":1
      },
      {
         "date":"2026-07-30 00:00:00",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "count":4
      },
      {
         "date":"2026-07-30 00:00:00",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "count":4
      },
      {
         "date":"2026-07-31 00:00:00",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "count":5
      },
      {
         "date":"2026-07-31 00:00:00",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "count":6
      }
   ]
}
```

2. `GET /api/v1/stats/plays-by-dayofweek`: Play by days of week.

Response Payload:

```bash
{
   "data":[
      {
         "day":0,
         "name":"Sun",
         "count":0
      },
      {
         "day":1,
         "name":"Mon",
         "count":0
      },
      {
         "day":2,
         "name":"Tue",
         "count":0
      },
      {
         "day":3,
         "name":"Wed",
         "count":2
      },
      {
         "day":4,
         "name":"Thu",
         "count":8
      },
      {
         "day":5,
         "name":"Fri",
         "count":11
      },
      {
         "day":6,
         "name":"Sat",
         "count":0
      }
   ]
}
```

3. `GET /api/v1/stats/plays-by-hourofday`: Plays by hours of day.

Response Payload:

```bash
{
   "data":[
      {
         "hour":0,
         "count":2
      },
      {
         "hour":1,
         "count":6
      },
      {
         "hour":2,
         "count":9
      },
      {
         "hour":3,
         "count":4
      },
      {
         "hour":4,
         "count":0
      },
      {
         "hour":5,
         "count":0
      },
      {
         "hour":6,
         "count":0
      },
      {
         "hour":7,
         "count":0
      },
      {
         "hour":8,
         "count":0
      },
      {
         "hour":9,
         "count":0
      },
      {
         "hour":10,
         "count":0
      },
      {
         "hour":11,
         "count":0
      },
      {
         "hour":12,
         "count":0
      },
      {
         "hour":13,
         "count":0
      },
      {
         "hour":14,
         "count":0
      },
      {
         "hour":15,
         "count":0
      },
      {
         "hour":16,
         "count":0
      },
      {
         "hour":17,
         "count":0
      },
      {
         "hour":18,
         "count":0
      },
      {
         "hour":19,
         "count":0
      },
      {
         "hour":20,
         "count":0
      },
      {
         "hour":21,
         "count":0
      },
      {
         "hour":22,
         "count":2
      },
      {
         "hour":23,
         "count":0
      }
   ]
}
```

4. `GET http://summer.com:3030/api/v1/stats/platforms?period=month&serverIds=c0e8e3cc-198c-4de6-824f-95e59351be96&serverIds=a320eed6-e55e-4fe1-af50-6bf03939ac32&timezone=Asia%2FKolkata`: Plays by platform, month.

Response Payload:

```bash
{
   "data":[
      {
         "platform":"Android TV",
         "count":23
      },
      {
         "platform":"Web",
         "count":4
      },
      {
         "platform":"Android",
         "count":2
      }
   ]
}
```

5. `GET /api/v1/stats/quality`: Quality and streams, month.

Response Payload:

```bash
{
   "directPlay":23,
   "directStream":0,
   "transcode":6,
   "total":29,
   "directPlayPercent":79,
   "directStreamPercent":0,
   "transcodePercent":21
}
```

6. `GET /api/v1/stats/concurrent`: Concurrent plays.

Response Payload:

```bash
{
   "data":[
      {
         "hour":"2026-07-29 00:00:00+00",
         "total":4,
         "direct":4,
         "directStream":0,
         "transcode":0
      },
      {
         "hour":"2026-07-30 00:00:00+00",
         "total":4,
         "direct":4,
         "directStream":0,
         "transcode":0
      }
   ]
}
```

7. `GET /api/v1/stats/engagement`: Engagement.

Response Payload:

```bash
{
   "topContent":[
      {
         "ratingKey":"17491",
         "title":"Plan",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":2,
         "totalSessions":2,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17492",
         "title":"Idols and Relationships",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":1,
         "totalSessions":2,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17492",
         "title":"Idols and Relationships",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":1,
         "totalSessions":2,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17497",
         "title":"Breakdown",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":1,
         "totalSessions":1,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17497",
         "title":"Breakdown",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":1,
         "totalSessions":1,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17499",
         "title":"Blind",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":1,
         "totalSessions":1,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17499",
         "title":"Blind",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":1,
         "totalSessions":1,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17500",
         "title":"Greed and Passion",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":3,
         "totalSessions":3,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17500",
         "title":"Greed and Passion",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":3,
         "totalSessions":3,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      },
      {
         "ratingKey":"17491",
         "title":"Plan",
         "showTitle":"Oshi no Ko",
         "type":"episode",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "year":2026,
         "totalPlays":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "validSessions":2,
         "totalSessions":2,
         "completions":1,
         "rewatches":0,
         "abandonments":0,
         "completionRate":100,
         "abandonmentRate":0
      }
   ],
   "topShows":[
      {
         "showTitle":"Oshi no Ko",
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalEpisodeViews":12,
         "totalWatchHours":4.8,
         "uniqueViewers":2,
         "avgEpisodesPerViewer":6,
         "avgCompletionRate":100,
         "bingeScore":30,
         "validSessions":18,
         "totalSessions":20
      },
      {
         "showTitle":"Ascendance of a Bookworm",
         "thumbPath":"/Items/20485/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalEpisodeViews":2,
         "totalWatchHours":0,
         "uniqueViewers":2,
         "avgEpisodesPerViewer":1,
         "avgCompletionRate":0,
         "bingeScore":8,
         "validSessions":0,
         "totalSessions":8
      },
      {
         "showTitle":"Chainsmoker Cat",
         "thumbPath":"/Items/20237/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalEpisodeViews":2,
         "totalWatchHours":0,
         "uniqueViewers":2,
         "avgEpisodesPerViewer":1,
         "avgCompletionRate":0,
         "bingeScore":8,
         "validSessions":0,
         "totalSessions":2
      },
      {
         "showTitle":"Clevatess",
         "thumbPath":"/Items/20409/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalEpisodeViews":2,
         "totalWatchHours":0.6,
         "uniqueViewers":2,
         "avgEpisodesPerViewer":1,
         "avgCompletionRate":100,
         "bingeScore":9,
         "validSessions":2,
         "totalSessions":2
      },
      {
         "showTitle":"KAIJU GIRL CARAMELISE",
         "thumbPath":"/Items/20250/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalEpisodeViews":2,
         "totalWatchHours":0.4,
         "uniqueViewers":2,
         "avgEpisodesPerViewer":1,
         "avgCompletionRate":50,
         "bingeScore":8.5,
         "validSessions":2,
         "totalSessions":3
      },
      {
         "showTitle":"Smoking Behind the Supermarket with You",
         "thumbPath":"/Items/17306/Images/Primary",
         "serverId":"c0e8e3cc-198c-4de6-824f-95e59351be96",
         "year":2026,
         "totalEpisodeViews":2,
         "totalWatchHours":0.8,
         "uniqueViewers":2,
         "avgEpisodesPerViewer":1,
         "avgCompletionRate":100,
         "bingeScore":9,
         "validSessions":2,
         "totalSessions":2
      }
   ],
   "engagementBreakdown":[
      {
         "tier":"watched",
         "count":17,
         "percentage":70.8
      },
      {
         "tier":"abandoned",
         "count":6,
         "percentage":25
      },
      {
         "tier":"sampled",
         "count":1,
         "percentage":4.2
      }
   ],
   "userProfiles":[
      {
         "serverUserId":"11b8681c-6ab3-476e-8b26-dc5e4dc9e091",
         "username":"Home",
         "thumbUrl":null,
         "identityName":null,
         "contentStarted":12,
         "totalPlays":9,
         "totalWatchHours":3.6,
         "validSessionCount":13,
         "totalSessionCount":19,
         "abandonedCount":3,
         "sampledCount":0,
         "engagedCount":0,
         "watchedCount":9,
         "rewatchedCount":0,
         "completionRate":75,
         "behaviorType":"completionist",
         "favoriteMediaType":"episode"
      },
      {
         "serverUserId":"6b5c58bc-897b-4d23-a875-bd255062e427",
         "username":"Home",
         "thumbUrl":null,
         "identityName":null,
         "contentStarted":12,
         "totalPlays":8,
         "totalWatchHours":3.2,
         "validSessionCount":13,
         "totalSessionCount":20,
         "abandonedCount":3,
         "sampledCount":1,
         "engagedCount":0,
         "watchedCount":8,
         "rewatchedCount":0,
         "completionRate":66.7,
         "behaviorType":"casual",
         "favoriteMediaType":"episode"
      }
   ],
   "summary":{
      "totalPlays":17,
      "totalValidSessions":26,
      "totalAllSessions":39,
      "sessionInflationPct":129.4,
      "avgCompletionRate":70.4
   }
}
```

Samples to refer to when building charts:

1. Bar Chart: https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/bar/bar_chart_sample1.dart
2. Pie Chart: https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/pie/pie_chart_sample1.dart
3. Line Chart: https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/line/line_chart_sample2.dart
