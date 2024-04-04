import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/rendering/viewport_offset.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_network/siberian_network.dart';

class NetworkLogScreeen extends StatefulWidget {
  final String textIfEmpty;
  final String deleteToastMessage;

  const NetworkLogScreeen({
    super.key,
    this.textIfEmpty = 'No network logs',
    this.deleteToastMessage = 'Network log cleared',
  });

  @override
  State<NetworkLogScreeen> createState() => _NetworkLogScreeenState();
}

class _NetworkLogScreeenState extends State<NetworkLogScreeen> with MountedStateMixin {
  Loadable<String> text = const Loadable.loading();

  Timer? timer;

  @override
  void initState() {
    loadNetworkLog();
    super.initState();
  }

  @override
  void dispose() {
    cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: false,
        title: Text('Network log', style: Theme.of(context).textTheme.titleSmall?.medium()),
        actions: [
          IconButton(
            onPressed: () {
              if (timer?.isActive == true) {
                cancelTimer();
                markNeedsRebuild();
              } else {
                scheduleTimer();
              }
            },
            icon: Icon(timer?.isActive == true ? Icons.pause : Icons.play_arrow),
            tooltip: timer?.isActive == true ? 'Pause watch' : 'Resume watch',
          ),
          IconButton(
            onPressed: () {
              Share.share(text.value ?? '');
            },
            icon: const Icon(Icons.share),
            tooltip: 'Share whole log',
          ),
          IconButton(
            onPressed: () async {
              NetworkLoggers.networkLogFile.then((file) => file.delete()).ignore();
              showToast(widget.deleteToastMessage);
              setState(() {
                text = const Loadable('');
              });
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete log file',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (text.isLoading) {
            return const Center(child: CupertinoActivityIndicator(radius: 24));
          }

          if (text.value == '') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(widget.textIfEmpty, style: Theme.of(context).textTheme.bodySmall?.medium()),
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RawScrollbar(
                  scrollbarOrientation: ScrollbarOrientation.right,
                  trackVisibility: true,
                  trackColor: Theme.of(context).colorScheme.primary,
                  radius: const Radius.circular(4),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.vertical,
                    child: RawScrollbar(
                      trackVisibility: true,
                      trackColor: Theme.of(context).colorScheme.primary,
                      thumbColor: Theme.of(context).colorScheme.primary,
                      radius: const Radius.circular(4),
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          text.value ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'SpaceMono'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text('You can select parts of text to share', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
              const VSpacer(12),
              const NavbarSpacer.bottom(),
            ],
          );
        },
      ),
    );
  }

  Future<void> loadNetworkLog() async {
    var file = await NetworkLoggers.networkLogFile;
    var text = file.existsSync() ? await file.readAsString() : '';

    setState(() {
      this.text = text.asValue;
    });

    scheduleTimer();
  }

  void scheduleTimer() {
    cancelTimer();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      loadNetworkLog();
    });
    markNeedsRebuild();
  }

  void cancelTimer() => timer?.cancel();
}

class TwoDimensinalScrollText extends TwoDimensionalScrollView {
  const TwoDimensinalScrollText({super.key, 
    super.primary,
    super.mainAxis = Axis.vertical,
    super.verticalDetails = const ScrollableDetails.vertical(),
    super.horizontalDetails = const ScrollableDetails.horizontal(),
    super.cacheExtent,
    super.diagonalDragBehavior = DiagonalDragBehavior.free,
    super.dragStartBehavior = DragStartBehavior.start,
    super.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    super.clipBehavior = Clip.hardEdge,
    required super.delegate,
  });

  @override
  Widget buildViewport(BuildContext context, ViewportOffset verticalOffset, ViewportOffset horizontalOffset) {
    return TwoDimensionalTextViewport(
      delegate: delegate,
      horizontalAxisDirection: horizontalDetails.direction,
      horizontalOffset: horizontalOffset,
      mainAxis: mainAxis,
      verticalAxisDirection: verticalDetails.direction,
      verticalOffset: verticalOffset,
      clipBehavior: clipBehavior,
      key: key,
      cacheExtent: cacheExtent,
    );
  }
}

class TwoDimensionalTextViewport extends TwoDimensionalViewport {
  const TwoDimensionalTextViewport({
    super.key,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    super.cacheExtent,
    super.clipBehavior = Clip.hardEdge,
  });

  @override
  RenderTwoDimensionalTextViewport createRenderObject(BuildContext context) {
    return RenderTwoDimensionalTextViewport(
      horizontalOffset: horizontalOffset,
      horizontalAxisDirection: horizontalAxisDirection,
      verticalOffset: verticalOffset,
      verticalAxisDirection: verticalAxisDirection,
      delegate: delegate,
      mainAxis: mainAxis,
      childManager: context as TwoDimensionalChildManager,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderTwoDimensionalTextViewport renderObject) {
    renderObject
      ..cacheExtent = cacheExtent
      ..clipBehavior = clipBehavior
      ..verticalOffset = verticalOffset
      ..mainAxis = mainAxis
      ..horizontalOffset = horizontalOffset
      ..delegate = delegate
      ..verticalAxisDirection = verticalAxisDirection
      ..horizontalOffset = horizontalOffset
      ..horizontalAxisDirection = horizontalAxisDirection;
  }
}

class RenderTwoDimensionalTextViewport extends RenderTwoDimensionalViewport {
  RenderTwoDimensionalTextViewport({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    required super.childManager,
  });

  @override
  void layoutChildSequence() {
    final double horizontalPixels = horizontalOffset.pixels;
    final double verticalPixels = verticalOffset.pixels;
    final double viewportWidth = viewportDimension.width + cacheExtent;
    final double viewportHeight = viewportDimension.height + cacheExtent;
    final TwoDimensionalChildBuilderDelegate builderDelegate = delegate as TwoDimensionalChildBuilderDelegate;

    final int maxRowIndex = builderDelegate.maxYIndex!;
    final int maxColumnIndex = builderDelegate.maxXIndex!;

    final int leadingColumn = math.max((horizontalPixels / 200).floor(), 0);
    final int leadingRow = math.max((verticalPixels / 200).floor(), 0);
    final int trailingColumn = math.min(
      ((horizontalPixels + viewportWidth) / 200).ceil(),
      maxColumnIndex,
    );
    final int trailingRow = math.min(
      ((verticalPixels + viewportHeight) / 200).ceil(),
      maxRowIndex,
    );

    double xLayoutOffset = (leadingColumn * 200) - horizontalOffset.pixels;
    for (int column = leadingColumn; column <= trailingColumn; column++) {
      double yLayoutOffset = (leadingRow * 200) - verticalOffset.pixels;
      for (int row = leadingRow; row <= trailingRow; row++) {
        final ChildVicinity vicinity = ChildVicinity(xIndex: column, yIndex: row);
        final RenderBox child = buildOrObtainChildFor(vicinity)!;
        child.layout(constraints.loosen());

        // Subclasses only need to set the normalized layout offset. The super
        // class adjusts for reversed axes.
        parentDataOf(child).layoutOffset = Offset(xLayoutOffset, yLayoutOffset);
        yLayoutOffset += 200;
      }
      xLayoutOffset += 200;
    }

    // Set the min and max scroll extents for each axis.
    final double verticalExtent = 200 * (maxRowIndex + 1);
    verticalOffset.applyContentDimensions(
      0.0,
      clampDouble(verticalExtent - viewportDimension.height, 0.0, double.infinity),
    );
    final double horizontalExtent = 200 * (maxColumnIndex + 1);
    horizontalOffset.applyContentDimensions(
      0.0,
      clampDouble(horizontalExtent - viewportDimension.width, 0.0, double.infinity),
    );
  }
}
