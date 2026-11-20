# Indoor Nav

Indoor navigation for a two-floor building, using ArUco markers stuck on the walls. Scan the marker nearest to you, pick where you want to go, and the app shows the route on the building's floor plan.

This started as a college subject project where an ESP32 computed the routes. The current version is a phone app that does everything offline.

## What's in this repo

| Folder | What it is |
| --- | --- |
| [`Project Code/indoor_nav_mobile/`](Project%20Code/indoor_nav_mobile/) | **The current app.** Flutter, Android and iOS. Scans markers with the camera, finds routes on the phone with bidirectional Dijkstra, and draws them on the floor plan. No internet, no ESP32. |
| [`Floor Plan/`](Floor%20Plan/) | The hand-drawn floor plans the node map was built from. The app shows a cropped copy of `New Floor Plan New.jpeg`. |
| [`ArUco/`](ArUco/) | Printable markers (`DICT_4X4_50`, ids 1–27) and `Node Graph.pdf`, which lists what each node is. Marker *N* goes at node *N*. |
| [`Project Code/Indoor Nav/`](Project%20Code/Indoor%20Nav/) | Original React web app and first Flutter app. Both needed the ESP32 through Firebase. Kept for reference. |

The original ESP32 firmware (which ran the route search and talked to Firebase) has been removed. It is still in the first commit if you need it: `git show 693921f:"Project Code/wifi/wifi.ino"`.

## Printing markers

Print the PNGs in `ArUco/` with a white margin around each one (the detector needs a light border around the black square). Stick marker *N* at the place listed as node *N* in `Node Graph.pdf`. Node 28, the vending machine, has no marker; the app lets you tap "I'm at Vending Machine" when the route passes it.
