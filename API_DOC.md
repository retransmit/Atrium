1. Top Movies: GET http://summer.com:3030/api/v1/library/top-movies?serverIds=a320eed6-e55e-4fe1-af50-6bf03939ac32&serverIds=be8aa256-17a1-4135-9044-b8f3cca268e0&serverIds=0dbe7229-39d5-4032-897e-864f1ef79ef1&period=30d&sortBy=plays&sortOrder=desc&page=1&pageSize=10

Takes in all the server Ids, displays the top movies. period = {7d, 30d, 90d, 1y, all}

Response Payload: 
```bash
{
   "items":[
      {
         "ratingKey":"imdb:tt26657236",
         "title":"Backrooms",
         "year":2026,
         "thumbPath":"/library/metadata/4/thumb/1785193894",
         "serverId":"0dbe7229-39d5-4032-897e-864f1ef79ef1",
         "serverIds":[
            "0dbe7229-39d5-4032-897e-864f1ef79ef1",
            "a320eed6-e55e-4fe1-af50-6bf03939ac32"
         ],
         "totalPlays":0,
         "totalWatchHours":0.8,
         "uniqueViewers":2,
         "completionRate":0
      }
   ],
   "summary":{
      "totalMovies":1,
      "totalWatchHours":0.8
   },
   "pagination":{
      "page":1,
      "pageSize":10,
      "total":1
   }
}
```

2. Top TV Shows: GET http://summer.com:3030/api/v1/library/top-shows?serverIds=a320eed6-e55e-4fe1-af50-6bf03939ac32&serverIds=be8aa256-17a1-4135-9044-b8f3cca268e0&serverIds=0dbe7229-39d5-4032-897e-864f1ef79ef1&period=30d&sortBy=plays&sortOrder=desc&page=1&pageSize=10

Same thing as movies, but for TV Shows. 

Response Payload: 
```bash
{
   "items":[
      {
         "showTitle":"Oshi no Ko",
         "year":2026,
         "thumbPath":"/Items/17300/Images/Primary",
         "serverId":"be8aa256-17a1-4135-9044-b8f3cca268e0",
         "serverIds":[
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ],
         "totalEpisodeViews":10,
         "totalWatchHours":5.2,
         "uniqueViewers":2,
         "avgCompletionRate":100,
         "bingeScore":100
      },
      {
         "showTitle":"Jaadugar: A Witch in Mongolia",
         "year":2026,
         "thumbPath":"/Items/20400/Images/Primary",
         "serverId":"be8aa256-17a1-4135-9044-b8f3cca268e0",
         "serverIds":[
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ],
         "totalEpisodeViews":6,
         "totalWatchHours":2.4,
         "uniqueViewers":2,
         "avgCompletionRate":100,
         "bingeScore":100
      },
      {
         "showTitle":"Clevatess",
         "year":2026,
         "thumbPath":"/Items/20409/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32"
         ],
         "totalEpisodeViews":1,
         "totalWatchHours":0.3,
         "uniqueViewers":1,
         "avgCompletionRate":100,
         "bingeScore":94
      },
      {
         "showTitle":"Ascendance of a Bookworm",
         "year":2026,
         "thumbPath":"/Items/20485/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32"
         ],
         "totalEpisodeViews":1,
         "totalWatchHours":0,
         "uniqueViewers":1,
         "avgCompletionRate":0,
         "bingeScore":60
      },
      {
         "showTitle":"KAIJU GIRL CARAMELISE",
         "year":2026,
         "thumbPath":"/Items/20250/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32"
         ],
         "totalEpisodeViews":1,
         "totalWatchHours":0,
         "uniqueViewers":1,
         "avgCompletionRate":0,
         "bingeScore":60
      },
      {
         "showTitle":"Chainsmoker Cat",
         "year":2026,
         "thumbPath":"/Items/20237/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32"
         ],
         "totalEpisodeViews":1,
         "totalWatchHours":0,
         "uniqueViewers":1,
         "avgCompletionRate":0,
         "bingeScore":60
      },
      {
         "showTitle":"Smoking Behind the Supermarket with You",
         "year":2026,
         "thumbPath":"/Items/17306/Images/Primary",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32"
         ],
         "totalEpisodeViews":1,
         "totalWatchHours":0.4,
         "uniqueViewers":1,
         "avgCompletionRate":100,
         "bingeScore":94
      }
   ],
   "summary":{
      "totalShows":7,
      "totalWatchHours":8.3
   },
   "pagination":{
      "page":1,
      "pageSize":10,
      "total":7
   }
}
```

3. Completion: GET http://summer.com:3030/api/v1/library/completion?serverId=a320eed6-e55e-4fe1-af50-6bf03939ac32&aggregateLevel=item&page=1&pageSize=1&mediaType=movie

Takes in serverIds (one-by-one). Media type can be movie, or episode. 

Response Payload `mediaType=movie`: 
```bash
{
   "items":[
      {
         "id":"a0c906ce-100c-484c-a503-6790328e0ecf",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Remote",
         "title":"Backrooms",
         "mediaType":"movie",
         "completionPct":3.3,
         "watchedMs":218298,
         "runtimeMs":6628768,
         "showTitle":null,
         "seasonNumber":null,
         "episodeNumber":null,
         "status":"in_progress",
         "lastWatchedAt":"2026-07-29 00:00:00+00"
      }
   ],
   "summary":{
      "totalItems":25,
      "completedCount":0,
      "inProgressCount":1,
      "notStartedCount":24,
      "overallCompletionPct":0.1
   },
   "pagination":{
      "page":1,
      "pageSize":1,
      "total":25
   }
}
```

Response Payload `mediaType=episode':
```bash
{
   "items":[
      {
         "id":"ee3eae90-9802-4a58-87c2-3485cf4e32d8",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Remote",
         "title":"Breakdown",
         "mediaType":"episode",
         "completionPct":97.4,
         "watchedMs":1394699,
         "runtimeMs":1431620,
         "showTitle":"Oshi no Ko",
         "seasonNumber":3,
         "episodeNumber":7,
         "status":"completed",
         "lastWatchedAt":"2026-07-30 00:00:00+00"
      }
   ],
   "summary":{
      "totalItems":499,
      "completedCount":13,
      "inProgressCount":1,
      "notStartedCount":485,
      "overallCompletionPct":2.6
   },
   "pagination":{
      "page":1,
      "pageSize":1,
      "total":499
   }
}
```

We need to aggregate all movies and TV Shows, and display them in a pie chart. Legend = {Completed, In Progress, Not Started}. Also, watch percentage (e.g. 101/800 Watched (% Watched)), Total Watch Time, Completed Items, and Peak Hour must be shown at the top. 

4. GET http://summer.com:3030/api/v1/library/watch?serverIds=a320eed6-e55e-4fe1-af50-6bf03939ac32&serverIds=be8aa256-17a1-4135-9044-b8f3cca268e0&serverIds=0dbe7229-39d5-4032-897e-864f1ef79ef1&page=1&pageSize=20

Response Payload: 
```bash
{
   "items":[
      {
         "id":"0a9bed37-624a-4587-b40f-dad0094db887",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"Practice What You Preach",
         "mediaType":"track",
         "year":1989,
         "fileSize":39425614,
         "resolution":null,
         "addedAt":"2026-06-17 17:37:05+00",
         "watchCount":11,
         "totalWatchMs":3285308,
         "lastWatchedAt":"2026-08-02 08:31:55.182+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"0a7c106f-d9ab-4f7f-910a-bb72eb144893",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"Into the Pit",
         "mediaType":"track",
         "year":1988,
         "fileSize":20747422,
         "resolution":null,
         "addedAt":"2026-06-17 18:05:00+00",
         "watchCount":7,
         "totalWatchMs":1253793,
         "lastWatchedAt":"2026-08-02 08:26:40.042+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"115c1a5d-7ed1-4654-bd71-4a4ae6d89e64",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"Trial by Fire",
         "mediaType":"track",
         "year":1988,
         "fileSize":28897923,
         "resolution":null,
         "addedAt":"2026-06-17 18:04:07+00",
         "watchCount":7,
         "totalWatchMs":1980897,
         "lastWatchedAt":"2026-08-02 08:36:37.178+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"27169035-79da-4bda-837f-abbceb915d43",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"Perilous Nation",
         "mediaType":"track",
         "year":1989,
         "fileSize":45542375,
         "resolution":null,
         "addedAt":"2026-06-17 17:34:48+00",
         "watchCount":7,
         "totalWatchMs":2410919,
         "lastWatchedAt":"2026-08-01 13:04:29.364+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"7242e854-d991-48da-9bf6-5787cc860404",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14331",
         "title":"W.A.V.E - Bonus Track",
         "mediaType":"track",
         "year":2018,
         "fileSize":5489559,
         "resolution":null,
         "addedAt":"2026-06-22 11:09:26+00",
         "watchCount":6,
         "totalWatchMs":1536071,
         "lastWatchedAt":"2026-08-01 11:34:41.013+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"d8c8b070-f4f5-4ff9-b90c-340fc9273daf",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"3",
         "title":"The Beginning",
         "mediaType":"episode",
         "year":2026,
         "fileSize":3337485593,
         "resolution":"1080p",
         "addedAt":"2026-03-25 18:22:27+00",
         "watchCount":6,
         "totalWatchMs":7489617,
         "lastWatchedAt":"2026-08-02 17:58:09.307+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"533c56da-586f-4c3e-81b8-5f17b49c8e1b",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14331",
         "title":"Nebula",
         "mediaType":"track",
         "year":2021,
         "fileSize":4339920,
         "resolution":null,
         "addedAt":"2026-06-22 10:49:47+00",
         "watchCount":6,
         "totalWatchMs":1601973,
         "lastWatchedAt":"2026-08-01 11:31:02.029+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"7dd85afb-7880-45a3-bf5b-c5c870b793d8",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"Over the Wall (Remastered 2024)",
         "mediaType":"track",
         "year":1987,
         "fileSize":32363410,
         "resolution":null,
         "addedAt":"2026-06-17 18:22:07+00",
         "watchCount":5,
         "totalWatchMs":1250640,
         "lastWatchedAt":"2026-08-02 09:13:02.97+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"42f21f0e-4788-4d14-a338-59421974cf50",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"Burnt Offering (Remastered 2024)",
         "mediaType":"track",
         "year":1987,
         "fileSize":39743351,
         "resolution":null,
         "addedAt":"2026-06-17 18:20:35+00",
         "watchCount":5,
         "totalWatchMs":1460923,
         "lastWatchedAt":"2026-08-02 09:22:24.212+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"6a4f130e-d1e2-4dc9-9cf6-673a59266274",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"Electric Crown",
         "mediaType":"track",
         "year":1992,
         "fileSize":42468068,
         "resolution":null,
         "addedAt":"2026-06-17 18:07:37+00",
         "watchCount":5,
         "totalWatchMs":1398019,
         "lastWatchedAt":"2026-08-02 07:38:09.418+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"0d795ba0-6120-452e-87e8-cf1dad0f79cc",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"The Haunting",
         "mediaType":"track",
         "year":2013,
         "fileSize":4648302,
         "resolution":null,
         "addedAt":"2026-06-19 11:13:29+00",
         "watchCount":5,
         "totalWatchMs":1443599,
         "lastWatchedAt":"2026-08-02 08:41:22.238+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"4352edb0-6d49-4c98-a48f-6d0c459bd160",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"Face In The Sky",
         "mediaType":"track",
         "year":1990,
         "fileSize":29654866,
         "resolution":null,
         "addedAt":"2026-06-17 18:02:56+00",
         "watchCount":5,
         "totalWatchMs":1184364,
         "lastWatchedAt":"2026-08-02 08:51:03.315+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"54b9f377-112f-448a-963d-a3fc46950a7c",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"New Order",
         "mediaType":"track",
         "year":2013,
         "fileSize":4942808,
         "resolution":null,
         "addedAt":"2026-06-19 11:14:21+00",
         "watchCount":5,
         "totalWatchMs":1529901,
         "lastWatchedAt":"2026-08-02 08:46:22.263+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"5f473f73-cee8-4e35-94dd-2873e69733e8",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14213",
         "title":"The Haunting (Remastered 2024)",
         "mediaType":"track",
         "year":1987,
         "fileSize":32299351,
         "resolution":null,
         "addedAt":"2026-06-17 18:22:29+00",
         "watchCount":5,
         "totalWatchMs":1289538,
         "lastWatchedAt":"2026-08-02 09:17:18.081+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"1f249e4a-c0ed-4270-b4d8-1f1558a3f8f0",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14331",
         "title":"Hideaway",
         "mediaType":"track",
         "year":2020,
         "fileSize":3498670,
         "resolution":null,
         "addedAt":"2026-06-22 10:51:19+00",
         "watchCount":4,
         "totalWatchMs":780757,
         "lastWatchedAt":"2026-08-01 11:49:10.248+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"6ff078ee-ac11-4867-abdd-37dbe705bdf5",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14331",
         "title":"Resonance",
         "mediaType":"track",
         "year":2014,
         "fileSize":3562412,
         "resolution":null,
         "addedAt":"2026-06-22 10:46:29+00",
         "watchCount":4,
         "totalWatchMs":790462,
         "lastWatchedAt":"2026-08-01 11:14:19.882+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"183b175b-9705-4a49-bd90-6ef40ed5c3b6",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"3",
         "title":"The Roses That Bloom in Safar",
         "mediaType":"episode",
         "year":2026,
         "fileSize":1466129338,
         "resolution":"1080p",
         "addedAt":"2026-07-07 20:16:15+00",
         "watchCount":4,
         "totalWatchMs":2904219,
         "lastWatchedAt":"2026-08-02 11:25:31.785+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"c189755f-3036-4c9c-bf3b-ac583eaf534a",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14331",
         "title":"Arcade Summer",
         "mediaType":"track",
         "year":2016,
         "fileSize":3930055,
         "resolution":null,
         "addedAt":"2026-06-22 10:55:38+00",
         "watchCount":4,
         "totalWatchMs":961100,
         "lastWatchedAt":"2026-08-01 11:38:52.148+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"25e6564b-a96e-4d71-80e7-c482458bd742",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"3",
         "title":"An Undying Flame",
         "mediaType":"episode",
         "year":2026,
         "fileSize":1465363742,
         "resolution":"1080p",
         "addedAt":"2026-07-11 16:15:23+00",
         "watchCount":4,
         "totalWatchMs":2933533,
         "lastWatchedAt":"2026-08-02 18:04:56.677+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      },
      {
         "id":"52077f61-df51-4c29-b947-3eff1b808ddf",
         "serverId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "serverName":"Emby Home",
         "libraryId":"14331",
         "title":"Destination Miami",
         "mediaType":"track",
         "year":2023,
         "fileSize":3063783,
         "resolution":null,
         "addedAt":"2026-06-22 11:03:08+00",
         "watchCount":4,
         "totalWatchMs":755918,
         "lastWatchedAt":"2026-08-01 11:41:58.159+00",
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      }
   ],
   "summary":{
      "totalItems":881,
      "watchedCount":103,
      "unwatchedCount":778,
      "watchedPct":11.7,
      "totalWatchMs":95487038,
      "avgWatchesPerItem":0.29,
      "completedCount":91
   },
   "pagination":{
      "page":1,
      "pageSize":20,
      "total":881
   }
}
```

This is paginated, so we also need to paginate it the way Storage Efficiency and ROI is paginated in the Storage tab. 

5. GET http://summer.com:3030/api/v1/library/patterns?serverIds=a320eed6-e55e-4fe1-af50-6bf03939ac32&serverIds=be8aa256-17a1-4135-9044-b8f3cca268e0&serverIds=0dbe7229-39d5-4032-897e-864f1ef79ef1&periodWeeks=12&timezone=Asia/Kolkata

Response Payload: 
```bash
{
   "bingeShows":[
      {
         "showTitle":"Oshi no Ko",
         "primaryServerId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "thumbPath":"/Items/17300/Images/Primary",
         "totalEpisodeWatches":13,
         "consecutiveEpisodes":8,
         "consecutivePct":66.7,
         "avgGapMinutes":2.8,
         "bingeScore":88,
         "maxEpisodesInOneDay":3,
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32"
         ]
      },
      {
         "showTitle":"Jaadugar: A Witch in Mongolia",
         "primaryServerId":"a320eed6-e55e-4fe1-af50-6bf03939ac32",
         "thumbPath":"/Items/20400/Images/Primary",
         "totalEpisodeWatches":10,
         "consecutiveEpisodes":6,
         "consecutivePct":75,
         "avgGapMinutes":53.6,
         "bingeScore":78,
         "maxEpisodesInOneDay":3,
         "serverIds":[
            "a320eed6-e55e-4fe1-af50-6bf03939ac32",
            "be8aa256-17a1-4135-9044-b8f3cca268e0"
         ]
      }
   ],
   "peakTimes":{
      "hourlyDistribution":[
         {
            "hour":0,
            "watchCount":5,
            "totalWatchMs":9323070,
            "pctOfTotal":1.9
         },
         {
            "hour":1,
            "watchCount":3,
            "totalWatchMs":4035513,
            "pctOfTotal":1.2
         },
         {
            "hour":2,
            "watchCount":7,
            "totalWatchMs":5699712,
            "pctOfTotal":2.7
         },
         {
            "hour":3,
            "watchCount":3,
            "totalWatchMs":2114474,
            "pctOfTotal":1.2
         },
         {
            "hour":13,
            "watchCount":23,
            "totalWatchMs":7212926,
            "pctOfTotal":8.9
         },
         {
            "hour":14,
            "watchCount":36,
            "totalWatchMs":12732488,
            "pctOfTotal":13.9
         },
         {
            "hour":15,
            "watchCount":28,
            "totalWatchMs":10160429,
            "pctOfTotal":10.8
         },
         {
            "hour":16,
            "watchCount":27,
            "totalWatchMs":11100795,
            "pctOfTotal":10.4
         },
         {
            "hour":17,
            "watchCount":43,
            "totalWatchMs":10546971,
            "pctOfTotal":16.6
         },
         {
            "hour":18,
            "watchCount":18,
            "totalWatchMs":4677184,
            "pctOfTotal":6.9
         },
         {
            "hour":19,
            "watchCount":20,
            "totalWatchMs":5291086,
            "pctOfTotal":7.7
         },
         {
            "hour":20,
            "watchCount":13,
            "totalWatchMs":4177946,
            "pctOfTotal":5
         },
         {
            "hour":21,
            "watchCount":7,
            "totalWatchMs":2147397,
            "pctOfTotal":2.7
         },
         {
            "hour":22,
            "watchCount":16,
            "totalWatchMs":3881455,
            "pctOfTotal":6.2
         },
         {
            "hour":23,
            "watchCount":10,
            "totalWatchMs":2385592,
            "pctOfTotal":3.9
         }
      ],
      "peakHour":17,
      "peakDayOfWeek":6
   },
   "seasonalTrends":{
      "monthlyTrends":[
         {
            "month":"2026-07",
            "watchCount":112,
            "totalWatchMs":39596419,
            "uniqueItems":82,
            "avgWatchesPerDay":3.6
         },
         {
            "month":"2026-08",
            "watchCount":147,
            "totalWatchMs":55890619,
            "uniqueItems":123,
            "avgWatchesPerDay":4.7
         }
      ],
      "busiestMonth":"2026-08",
      "quietestMonth":"2026-07"
   },
   "summary":{
      "totalWatchSessions":259,
      "avgSessionsPerDay":51.8,
      "bingeSessionsPct":9.7
   }
}
```

This is basically binge highlights. We also need to display a bar graph for viewing hours and monthly trends (in a line chart). 
