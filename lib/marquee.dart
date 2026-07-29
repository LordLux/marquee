library marquee;

import 'dart:async';

import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A curve that represents the integral of another curve.
///
/// The constructor takes an other curve and calculates the integral. The
/// values of this curve are then being normalized onto the interval from 0 to
/// 1, but the integration value can always be obtained using the [interval]
/// property.
class _IntegralCurve extends Curve {
  /// Delta for integrating.
  static double delta = 0.01;

  _IntegralCurve._(this.original, this.integral, this._values);

  /// The original curve that was integrated.
  final Curve original;

  /// The integral value.
  final double integral;

  /// Cached cumulative values of the integral.
  final Map<double, double> _values;

  /// The constructor that takes the [original] curve.
  factory _IntegralCurve(Curve original) {
    double integral = 0.0;
    final values = Map<double, double>();

    for (double t = 0.0; t <= 1.0; t += delta) {
      integral += original.transform(t) * delta;
      values[t] = integral;
    }
    values[1.0] = integral;

    // Normalize.
    for (final double t in values.keys) values[t] = values[t]! / integral;

    return _IntegralCurve._(original, integral, values);
  }

  /// Transforms a value to the normalized integrated value of the [original]
  /// curve.
  double transform(double t) {
    if (t < 0) return 0.0;
    for (final key in _values.keys) if (key > t) return _values[key]!;
    return 1.0;
  }
}

/// A widget that repeats a widget and automatically scrolls it infinitely.
class Marquee extends StatefulWidget {
  Marquee({
    super.key,
    required this.child,
    this.containerExtent,
    this.sizeCalculator,
    this.textDirection = TextDirection.ltr,
    this.scrollAxis = Axis.horizontal,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.blankSpace = 0.0,
    this.velocity = 50.0,
    this.startAfter = Duration.zero,
    this.pauseAfterRound = Duration.zero,
    this.showFadingOnlyWhenScrolling = true,
    this.fadingEdgeStartFraction = 0.0,
    this.fadingEdgeEndFraction = 0.0,
    this.numberOfRounds,
    this.startPadding = 0.0,
    this.accelerationDuration = Duration.zero,
    Curve accelerationCurve = Curves.decelerate,
    this.decelerationDuration = Duration.zero,
    Curve decelerationCurve = Curves.decelerate,
    this.onDone,
  })  : assert(!blankSpace.isNaN),
        assert(blankSpace >= 0, "The blankSpace needs to be positive or zero."),
        assert(blankSpace.isFinite),
        assert(!velocity.isNaN),
        assert(velocity != 0.0, "The velocity cannot be zero."),
        assert(velocity.isFinite),
        assert(
          pauseAfterRound >= Duration.zero,
          "The pauseAfterRound cannot be negative as time travel isn't "
          "invented yet.",
        ),
        assert(
          fadingEdgeStartFraction >= 0 && fadingEdgeStartFraction <= 1,
          "The fadingEdgeGradientFractionOnStart value should be between 0 and "
          "1, inclusive",
        ),
        assert(
          fadingEdgeEndFraction >= 0 && fadingEdgeEndFraction <= 1,
          "The fadingEdgeGradientFractionOnEnd value should be between 0 and "
          "1, inclusive",
        ),
        assert(numberOfRounds == null || numberOfRounds > 0),
        assert(
          accelerationDuration >= Duration.zero,
          "The accelerationDuration cannot be negative as time travel isn't "
          "invented yet.",
        ),
        assert(
          decelerationDuration >= Duration.zero,
          "The decelerationDuration must be positive or zero as time travel "
          "isn't invented yet.",
        ),
        assert(containerExtent != null || sizeCalculator != null,
            "Either containerExtent or sizeCalculator must be provided."),
        this.accelerationCurve = _IntegralCurve(accelerationCurve),
        this.decelerationCurve = _IntegralCurve(decelerationCurve);

  /// A factory that creates a [Marquee] from a [String].
  factory Marquee.text({
    Key? key,
    required String text,
    TextStyle? style,
    double? textScaleFactor,
    TextDirection textDirection = TextDirection.ltr,
    Axis scrollAxis = Axis.horizontal,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    double blankSpace = 0.0,
    double velocity = 50.0,
    Duration startAfter = Duration.zero,
    Duration pauseAfterRound = Duration.zero,
    bool showFadingOnlyWhenScrolling = true,
    double fadingEdgeStartFraction = 0.0,
    double fadingEdgeEndFraction = 0.0,
    int? numberOfRounds,
    double startPadding = 0.0,
    Duration accelerationDuration = Duration.zero,
    Curve accelerationCurve = Curves.decelerate,
    Duration decelerationDuration = Duration.zero,
    Curve decelerationCurve = Curves.decelerate,
    VoidCallback? onDone,
  }) {
    return Marquee(
      key: key,
      child: Text(
        text,
        style: style,
        textScaler: textScaleFactor != null
            ? TextScaler.linear(textScaleFactor)
            : null,
      ),
      textDirection: textDirection,
      scrollAxis: scrollAxis,
      crossAxisAlignment: crossAxisAlignment,
      blankSpace: blankSpace,
      velocity: velocity,
      startAfter: startAfter,
      pauseAfterRound: pauseAfterRound,
      showFadingOnlyWhenScrolling: showFadingOnlyWhenScrolling,
      fadingEdgeStartFraction: fadingEdgeStartFraction,
      fadingEdgeEndFraction: fadingEdgeEndFraction,
      numberOfRounds: numberOfRounds,
      startPadding: startPadding,
      accelerationDuration: accelerationDuration,
      accelerationCurve: accelerationCurve,
      decelerationDuration: decelerationDuration,
      decelerationCurve: decelerationCurve,
      onDone: onDone,
      sizeCalculator: (BuildContext context) {
        final span = TextSpan(text: text, style: style);
        final constraints = BoxConstraints(maxWidth: double.infinity);
        final richTextWidget = Text.rich(
          span,
          textScaler: textScaleFactor != null
              ? TextScaler.linear(textScaleFactor)
              : null,
        ).build(context) as RichText;
        final renderObject = richTextWidget.createRenderObject(context);
        renderObject.layout(constraints);
        final boxes = renderObject.getBoxesForSelection(TextSelection(
          baseOffset: 0,
          extentOffset: text.length,
        ));
        return boxes.last.right;
      },
    );
  }

  /// The widget to be displayed.
  final Widget child;

  /// The extent of the [child] along the [scrollAxis].
  final double? containerExtent;

  /// A function to calculate the size of the [child] if [containerExtent] is not provided.
  final double Function(BuildContext)? sizeCalculator;

  /// The text direction.
  final TextDirection textDirection;

  /// The scroll axis.
  final Axis scrollAxis;

  /// The alignment along the cross axis.
  final CrossAxisAlignment crossAxisAlignment;

  /// The extend of blank space to display between instances of the text.
  final double blankSpace;

  /// The scrolling velocity in pixels per second.
  final double velocity;

  /// Start scrolling after this duration after the widget is first displayed.
  final Duration startAfter;

  /// After each round, a pause of this duration occurs.
  final Duration pauseAfterRound;

  /// When the text scrolled around [numberOfRounds] times, it will stop scrolling
  final int? numberOfRounds;

  /// Whether the fading edge should only appear while the text is scrolling.
  final bool showFadingOnlyWhenScrolling;

  /// The fraction of the [Marquee] that will be faded on the left or top.
  final double fadingEdgeStartFraction;

  /// The fraction of the [Marquee] that will be faded on the right or down.
  final double fadingEdgeEndFraction;

  /// A padding for the resting position.
  final double startPadding;

  /// How long the acceleration takes.
  final Duration accelerationDuration;

  /// The acceleration at the start of each round.
  final _IntegralCurve accelerationCurve;

  /// How long the deceleration takes.
  final Duration decelerationDuration;

  /// The deceleration at the end of each round.
  final _IntegralCurve decelerationCurve;

  /// This function will be called if [numberOfRounds] is set and the [Marquee]
  /// finished scrolled the specified number of rounds.
  final VoidCallback? onDone;

  @override
  State<StatefulWidget> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  /// The controller for the scrolling behavior.
  final ScrollController _controller = ScrollController();

  // The scroll positions at various scrolling phases.
  late double _startPosition; // At the start, before accelerating.
  late double
      _accelerationTarget; // After accelerating, before moving linearly.
  late double _linearTarget; // After moving linearly, before decelerating.
  late double _decelerationTarget; // After decelerating.

  // The durations of various scrolling phases.
  late Duration _totalDuration;

  Duration get _accelerationDuration => widget.accelerationDuration;
  Duration? _linearDuration; // The duration of linearly scrolling.
  Duration get _decelerationDuration => widget.decelerationDuration;

  /// A timer that is fired at the start of each round.
  bool _running = false;
  bool _isOnPause = false;
  int _roundCounter = 0;
  bool get isDone => widget.numberOfRounds == null
      ? false
      : widget.numberOfRounds == _roundCounter;
  bool get showFading =>
      !widget.showFadingOnlyWhenScrolling ? true : !_isOnPause;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_running) {
        _running = true;
        if (_controller.hasClients) {
          _controller.jumpTo(_startPosition);
          await Future<void>.delayed(widget.startAfter);
          Future.doWhile(_scroll);
        }
      }
    });
  }

  Future<bool> _scroll() async {
    await _makeRoundTrip();
    if (isDone && widget.onDone != null) {
      widget.onDone!();
    }
    return _running && !isDone && _controller.hasClients;
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget as Marquee);
  }

  @override
  void dispose() {
    _running = false;
    _controller.dispose();
    super.dispose();
  }

  /// Calculates all necessary values for animating, then starts the animation.
  void _initialize(BuildContext context) {
    // Calculate lengths (amount of pixels that each phase needs).
    final contentWidth =
        widget.containerExtent ?? widget.sizeCalculator!(context);
    final totalLength = contentWidth + widget.blankSpace;
    final accelerationLength = widget.accelerationCurve.integral *
        widget.velocity *
        _accelerationDuration.inMilliseconds /
        1000.0;
    final decelerationLength = widget.decelerationCurve.integral *
        widget.velocity *
        _decelerationDuration.inMilliseconds /
        1000.0;
    final linearLength =
        (totalLength - accelerationLength.abs() - decelerationLength.abs()) *
            (widget.velocity > 0 ? 1 : -1);

    // Calculate scroll positions at various scrolling phases.
    _startPosition = 2 * totalLength - widget.startPadding;
    _accelerationTarget = _startPosition + accelerationLength;
    _linearTarget = _accelerationTarget + linearLength;
    _decelerationTarget = _linearTarget + decelerationLength;

    // Calculate durations for the phases.
    _totalDuration = _accelerationDuration +
        _decelerationDuration +
        Duration(milliseconds: (linearLength / widget.velocity * 1000).toInt());
    _linearDuration =
        _totalDuration - _accelerationDuration - _decelerationDuration;

    assert(
      _totalDuration > Duration.zero,
      "With the given values, the total duration for one round would be "
      "negative. As time travel isn't invented yet, this shouldn't happen.",
    );
    assert(
      _linearDuration! >= Duration.zero,
      "Acceleration and deceleration phase overlap. To fix this, try a "
      "combination of these approaches:\n"
      "* Make the text longer, so there's more room to animate within.\n"
      "* Shorten the accelerationDuration or decelerationDuration.\n"
      "* Decrease the velocity, so the duration to animate within is longer.\n",
    );
  }

  /// Causes the controller to scroll one round.
  Future<void> _makeRoundTrip() async {
    // Reset the controller, then accelerate, move linearly and decelerate.
    if (!_controller.hasClients) return;
    _controller.jumpTo(_startPosition);
    if (!_running) return;

    await _accelerate();
    if (!_running) return;

    await _moveLinearly();
    if (!_running) return;

    await _decelerate();

    _roundCounter++;

    if (!_running || !mounted) return;

    if (widget.pauseAfterRound > Duration.zero) {
      setState(() => _isOnPause = true);

      await Future.delayed(widget.pauseAfterRound);

      if (!mounted || isDone) return;
      setState(() => _isOnPause = false);
    }
  }

  // Methods that animate the controller.
  Future<void> _accelerate() async {
    await _animateTo(
      _accelerationTarget,
      _accelerationDuration,
      widget.accelerationCurve,
    );
  }

  Future<void> _moveLinearly() async {
    await _animateTo(_linearTarget, _linearDuration, Curves.linear);
  }

  Future<void> _decelerate() async {
    await _animateTo(
      _decelerationTarget,
      _decelerationDuration,
      widget.decelerationCurve.flipped,
    );
  }

  /// Helping method that either animates to the given target position or jumps
  /// right to it if the duration is Duration.zero.
  Future<void> _animateTo(
    double? target,
    Duration? duration,
    Curve curve,
  ) async {
    if (!_controller.hasClients) return;
    if (duration! > Duration.zero) {
      await _controller.animateTo(target!, duration: duration, curve: curve);
    } else {
      _controller.jumpTo(target!);
    }
  }

  @override
  Widget build(BuildContext context) {
    _initialize(context);
    bool isHorizontal = widget.scrollAxis == Axis.horizontal;

    Alignment? alignment;

    switch (widget.crossAxisAlignment) {
      case CrossAxisAlignment.start:
        alignment = isHorizontal ? Alignment.topCenter : Alignment.centerLeft;
        break;
      case CrossAxisAlignment.end:
        alignment =
            isHorizontal ? Alignment.bottomCenter : Alignment.centerRight;
        break;
      case CrossAxisAlignment.center:
        alignment = Alignment.center;
        break;
      case CrossAxisAlignment.stretch:
      case CrossAxisAlignment.baseline:
        alignment = null;
        break;
    }

    Widget marquee = ListView.builder(
      controller: _controller,
      scrollDirection: widget.scrollAxis,
      reverse: widget.textDirection == TextDirection.rtl,
      physics: NeverScrollableScrollPhysics(),
      itemBuilder: (_, i) {
        final item = i.isEven
            ? (widget.containerExtent != null
                ? SizedBox(
                    width: widget.scrollAxis == Axis.horizontal
                        ? widget.containerExtent
                        : null,
                    height: widget.scrollAxis == Axis.vertical
                        ? widget.containerExtent
                        : null,
                    child: widget.child,
                  )
                : widget.child)
            : _buildBlankSpace();
        return alignment == null
            ? item
            : Align(alignment: alignment, child: item);
      },
    );

    return kIsWeb ? marquee : _wrapWithFadingEdgeScrollView(marquee);
  }

  /// Builds the blank space between children.
  Widget _buildBlankSpace() {
    return SizedBox(
      width: widget.scrollAxis == Axis.horizontal ? widget.blankSpace : null,
      height: widget.scrollAxis == Axis.vertical ? widget.blankSpace : null,
    );
  }

  Widget _wrapWithFadingEdgeScrollView(Widget child) {
    return FadingEdgeScrollView.fromScrollView(
      gradientFractionOnStart:
          !showFading ? 0.0 : widget.fadingEdgeStartFraction,
      gradientFractionOnEnd: !showFading ? 0.0 : widget.fadingEdgeEndFraction,
      child: child as ScrollView,
    );
  }
}
