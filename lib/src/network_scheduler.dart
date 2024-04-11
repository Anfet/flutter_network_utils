import 'dart:async';
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

  final Map<NetworkSchedulerPriority, List<ScheduledRequest>> scheduledRequests = {};

  NetworkScheduler() {
    NetworkSchedulerPriority.values.forEach((priority) {
      scheduledRequests.putIfAbsent(priority, () => []);
    });
  }

  void start() {
    _isPaused = false;
    _loop();
  }

  void pause() => _isPaused = true;

  Future<void> _loop() async {
    while (!_isPaused && scheduledRequests.values.any((it) => it.isNotEmpty)) {
      var scheduledRequest = scheduledRequests.values.firstWhere((list) => list.isNotEmpty).removeAt(0);
      try {
        var result = await scheduledRequest.request;
        scheduledRequest.completer.complete(result);
      } catch (ex, stack) {
        scheduledRequest.completer.completeError(ex, stack);
      }
    }
  }

  Future<void> dropAll({String? tag}) async {
    List<ScheduledRequest> requests;

    if (tag == null) {
      requests = Map.of(scheduledRequests).values.fold([], (previousValue, element) => [...previousValue, ...element]);
      scheduledRequests.clear();
    } else {
      requests = [];
      for (var key in scheduledRequests.keys) {
        var value = scheduledRequests[key];
      }
      requests = Map.of(scheduledRequests).values.fold([], (previousValue, element) => [...previousValue, ...element]);
    }

    for (var request in requests) {
      request.completer.completeError(CancelledException());
    }
  }

  Future<T> schedule<T>(Future<T> request, {NetworkSchedulerPriority priority = NetworkSchedulerPriority.low, String? tag}) {
    if (_isPaused) {
      warn('scheduler is paused; request will be added in queue');
    }

    var scheduledRequest = ScheduledRequest(request: request, tag: tag);
    scheduledRequests[priority]!.add(scheduledRequest);
    _loop();
    return scheduledRequest.completer.future;
  }
}

class ScheduledRequest<T> {
  static int requestId = 0;

  final int id = requestId++;
  final Completer<T> completer = Completer();
  final Future<T> request;
  final String? tag;

  ScheduledRequest({required this.request, this.tag});
}
