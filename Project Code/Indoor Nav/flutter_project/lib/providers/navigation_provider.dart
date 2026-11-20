import 'package:flutter/material.dart';
import '../models/nav_data.dart';
import '../services/api_service.dart';

class NavigationProvider with ChangeNotifier {
  int? _currentNode;
  int? _nextNode;
  int? _destination;
  List<PathStep> _path = [];
  int _progressIndex = 0;
  int _selectedFloor = 0; // 0 for Ground, 1 for First
  String _instruction = "Select a destination to begin";
  bool _isLoading = false;

  int? get currentNode => _currentNode;
  int? get nextNode => _nextNode;
  int? get destination => _destination;
  List<PathStep> get path => _path;
  int get progressIndex => _progressIndex;
  int get selectedFloor => _selectedFloor;
  String get instruction => _instruction;
  bool get isLoading => _isLoading;

  void setFloor(int floor) {
    _selectedFloor = floor;
    notifyListeners();
  }

  void setDestination(int id) {
    _destination = id;
    notifyListeners();
  }

  void markReached() {
    if (_progressIndex < _path.length - 1) {
      _progressIndex++;
      _currentNode = _path[_progressIndex].id;
      if (_progressIndex < _path.length - 1) {
        _nextNode = _path[_progressIndex + 1].id;
        _instruction = "Head to ${_path[_progressIndex + 1].name}";
      } else {
        _nextNode = null;
        _instruction = "You have reached your destination";
      }
      notifyListeners();
    }
  }

  void undoReached() {
    if (_progressIndex > 0) {
      _progressIndex--;
      _currentNode = _path[_progressIndex].id;
      _nextNode = _path[_progressIndex + 1].id;
      _instruction = "Head to ${_path[_progressIndex + 1].name}";
      notifyListeners();
    }
  }

  Future<void> processScan(int markerId) async {
    _isLoading = true;
    _currentNode = markerId;
    notifyListeners();

    try {
      final data = await ApiService().fetchNextNode(markerId, _destination);
      _path = data.path;
      _progressIndex = 0;
      _nextNode = data.next;
      _instruction = data.instruction;
    } catch (e) {
      _instruction = "Error connecting to navigation server";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
