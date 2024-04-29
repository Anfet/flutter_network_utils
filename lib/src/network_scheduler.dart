import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_logger/siberian_logger.dart';
import 'package:siberian_network/siberian_network.dart';

enum NetworkSchedulerPriority {
  immediate,
  critical,
  highest,
  high,
  aboveNormal,
  normal,
  belowNormal,
  low,
  ;
}

class NetworkScheduler with Logging {
  bool _isPaused = false;
  bool _isLooping = false;

  final Map<NetworkSchedulerPriority, List<ScheduledRequest>> _scheduledRequests = {};

  Iterable<NetworkSchedulerPriority> get _keysWithRequests => _scheduledRequests.keys.where((key) => require(_scheduledRequests[key]).isNotEmpty);

  NetworkScheduler() {
    for (var priority in NetworkSchedulerPriority.values) {
      _scheduledRequests.putIfAbsent(priority, () => []);
    }
  }

  void start() {
    _isPaused = false;
    _loop();
  }

  void pause() => _isPaused = true;

  void dispose() => drop();

  Future<void> _loop() async {
    if (_isLooping) {
      return;
    }
    _isLooping = true;
    try {
      while (!_isPaused) {
        var keys = _keysWithRequests;
        if (keys.isEmpty) {
          break;
        }

        var requests = require(_scheduledRequests[keys.first]);
        var scheduledRequest = requests.first;
        if (!scheduledRequest.completer.isCompleted) {
          await _executeRequest(scheduledRequest);
        }
        requests.remove(scheduledRequest);
      }
    } finally {
      _isLooping = false;
    }
  }

  void drop({final Iterable<String> tags = const [], final Iterable<int> ids = const []}) {
    List<ScheduledRequest> requests = [];

    if (tags.isEmpty && ids.isEmpty) {
      requests = Map.of(_scheduledRequests).values.fold([], (previousValue, element) => [...previousValue, ...element]);
      _scheduledRequests.clear();
      return;
    }

    var keys = _keysWithRequests;
    for (var key in keys) {
      var list = _scheduledRequests[key] ?? [];
      list.removeWhere(
        (request) {
          var doRemove = tags.contains(request.tag) || ids.contains(request.id);
          if (doRemove) {
            requests.add(request);
          }
          return doRemove;
        },
      );
    }

    for (var request in requests) {
      trace('request #${request.id} dropped');
      request.completer.completeError(CancelledException());
    }
  }

  ScheduledRequest<T> schedule<T>(AsyncValueGetter<T> request, {NetworkSchedulerPriority priority = NetworkSchedulerPriority.low, String? tag}) {
    if (_isPaused) {
      warn('scheduler is paused; request will be added in queue');
    }

    ScheduledRequest<T> scheduledRequest = ScheduledRequest<T>(request: request, tag: tag);
    trace('scheduling request #${scheduledRequest.id} / ${priority.name}');
    if (priority == NetworkSchedulerPriority.immediate) {
      _executeRequest(scheduledRequest);
    } else {
      require(_scheduledRequests[priority]).add(scheduledRequest);
      _loop();
    }

    return scheduledRequest;
  }

  Future _executeRequest(ScheduledRequest scheduledRequest) async {
    if (scheduledRequest.completer.isCompleted) {
      return;
    }

    Loadable result = const Loadable.loading();
    try {
      trace('executing request #${scheduledRequest.id}');
      result = result.result(await scheduledRequest.request());
    } catch (ex, stack) {
      result = result.fail(ex, stack);
    } finally {
      if (!scheduledRequest.completer.isCompleted) {
        if (result.hasError) {
          scheduledRequest.completer.completeError(result.requireError, result.stack);
        } else {
          scheduledRequest.completer.complete(result.value);
        }
      }
    }
  }
}

class ScheduledRequest<T> {
  static int requestId = 0;

  final int id = requestId++;
  final Completer<T> completer = Completer();
  final AsyncValueGetter<T> request;
  final String? tag;

  Future<T> get future => completer.future;

  ScheduledRequest({required this.request, this.tag});
}
