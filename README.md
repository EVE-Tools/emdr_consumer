# EMDRConsumer

This is a very simple service which just connects EMDR to our internal NSQ. For now it only supports `orders` messages from EMDR. EMDR's messages are split up by rowset before being submitted to the `orders` queue. Also, the order's attributes get mapped for easier access later on. Processing bulk updates of the market can result in lots of messages on NSQ as the original EMDR message contains many rowsets. The application consists of two processes: the `worker` which takes messages from EMDR, reformats them and sends them to the `nsq_publisher` which then takes those messages and pushes them to NSQ.

## Installation
Either use the prebuilt Docker images and pass the appropriate env vars (see below), or:

* Clone this repo
* Run `mix deps.get`
* Configure via `config/config.exs` or environment variables from below
* Run application with `mix run --no-halt`
* Test with `mix test --no-start`

## Deployment Info

Builds, tests and releases are handled by drone.

Environment Variable | Example | Description
--- | --- | ---
EMDR_RELAY_URL | tcp://relay-eu-germany-1.eve-emdr.com:8050 | EMDR relay to connect to
NSQD_SERVER_IP | 127.0.0.1:4150 | Hostname/IP of the NSQD instance to connect to

## Todo
- [ ] Also process `history` messages if necessary later on
- [ ] More efficient processing of huge JSON messages from EMDR, also see `market_scraper`, maybe streaming parser (JSX-style)

## Example Message

Input from EMDR:
```json
{
  "resultType" : "orders",
  "version" : "0.1",
  "uploadKeys" : [
    { "name" : "emk", "key" : "abc" },
    { "name" : "ec" , "key" : "def" }
  ],
  "generator" : { "name" : "Yapeal", "version" : "11.335.1737" },
  "currentTime" : "2011-10-22T15:46:00+00:00",
  "columns" : ["price","volRemaining","range","orderID","volEntered","minVolume","bid","issueDate","duration","stationID","solarSystemID"],
  "rowsets" : [
    {
      "generatedAt" : "2011-10-22T15:43:00+00:00",
      "regionID" : 10000065,
      "typeID" : 11134,
      "rows" : [
        [8999,1,32767,2363806077,1,1,false,"2011-12-03T08:10:59+00:00",90,60008692,30005038],
        [11499.99,10,32767,2363915657,10,1,false,"2011-12-03T10:53:26+00:00",90,60006970,null],
        [11500,48,32767,2363413004,50,1,false,"2011-12-02T22:44:01+00:00",90,60006967,30005039]
      ]
    },
    {
      "generatedAt" : "2011-10-22T15:42:00+00:00",
      "regionID" : null,
      "typeID" : 11135,
      "rows" : [
        [8999,1,32767,2363806077,1,1,false,"2011-12-03T08:10:59+00:00",90,60008692,30005038],
        [11499.99,10,32767,2363915657,10,1,false,"2011-12-03T10:53:26+00:00",90,60006970,null],
        [11500,48,32767,2363413004,50,1,false,"2011-12-02T22:44:01+00:00",90,60006967,30005039]
      ]
    },
    {
      "generatedAt" : "2011-10-22T15:43:00+00:00",
      "regionID" : 10000067,
      "typeID" : 11136,
      "rows" : []
    }
  ]
}
```

Output to NSQ (multiple messages):
```json
[
  {
    "typeID": 11134,
    "regionID": 10000065,
    "orders": [
      {
        "volRemaining": 1,
        "volEntered": 1,
        "stationID": 60008692,
        "solarSystemID": 30005038,
        "range": 32767,
        "price": 8999,
        "orderID": 2363806077,
        "minVolume": 1,
        "issueDate": "2011-12-03T08:10:59+00:00",
        "duration": 90,
        "bid": false
      },
      {
        "volRemaining": 10,
        "volEntered": 10,
        "stationID": 60006970,
        "solarSystemID": null,
        "range": 32767,
        "price": 11499.99,
        "orderID": 2363915657,
        "minVolume": 1,
        "issueDate": "2011-12-03T10:53:26+00:00",
        "duration": 90,
        "bid": false
      },
      {
        "volRemaining": 48,
        "volEntered": 50,
        "stationID": 60006967,
        "solarSystemID": 30005039,
        "range": 32767,
        "price": 11500,
        "orderID": 2363413004,
        "minVolume": 1,
        "issueDate": "2011-12-02T22:44:01+00:00",
        "duration": 90,
        "bid": false
      }
    ],
    "generatedAt": "2011-10-22T15:43:00+00:00"
  },
  {
    "typeID": 11135,
    "regionID": null,
    "orders": [
      {
        "volRemaining": 1,
        "volEntered": 1,
        "stationID": 60008692,
        "solarSystemID": 30005038,
        "range": 32767,
        "price": 8999,
        "orderID": 2363806077,
        "minVolume": 1,
        "issueDate": "2011-12-03T08:10:59+00:00",
        "duration": 90,
        "bid": false
      },
      {
        "volRemaining": 10,
        "volEntered": 10,
        "stationID": 60006970,
        "solarSystemID": null,
        "range": 32767,
        "price": 11499.99,
        "orderID": 2363915657,
        "minVolume": 1,
        "issueDate": "2011-12-03T10:53:26+00:00",
        "duration": 90,
        "bid": false
      },
      {
        "volRemaining": 48,
        "volEntered": 50,
        "stationID": 60006967,
        "solarSystemID": 30005039,
        "range": 32767,
        "price": 11500,
        "orderID": 2363413004,
        "minVolume": 1,
        "issueDate": "2011-12-02T22:44:01+00:00",
        "duration": 90,
        "bid": false
      }
    ],
    "generatedAt": "2011-10-22T15:42:00+00:00"
  },
  {
    "typeID": 11136,
    "regionID": 10000067,
    "orders": [

    ],
    "generatedAt": "2011-10-22T15:43:00+00:00"
  }
]
```
