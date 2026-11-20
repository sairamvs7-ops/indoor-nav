import 'package:flutter/material.dart';

import '../map/building_map.dart';

IconData iconFor(NodeType type) => switch (type) {
  NodeType.room => Icons.meeting_room_outlined,
  NodeType.washroom => Icons.wc,
  NodeType.lift => Icons.elevator_outlined,
  NodeType.stairs => Icons.stairs_outlined,
  NodeType.entry => Icons.door_front_door_outlined,
  NodeType.landmark => Icons.place_outlined,
};
