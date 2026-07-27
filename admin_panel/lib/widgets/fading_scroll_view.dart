import 'package:flutter/material.dart';

/// Softens the top and bottom edges of a scrollable so content dissolves
/// instead of being sliced.
///
/// Every page in the panel scrolls inside a fixed header. Without this the
/// viewport clips with a hard edge, so a heading scrolled halfway out is cut
/// cleanly through the middle of its glyphs and reads as a rendering bug
/// rather than as "there is more above".
///
/// The fade only appears on the edge that actually has content beyond it, so
/// a short page that does not scroll shows no fade at all.
class FadingScrollView extends StatefulWidget {
  const FadingScrollView({
    super.key,
    required this.child,
    this.fadeExtent = 20,
  });

  final Widget child;

  /// Height of the gradient in logical pixels.
  final double fadeExtent;

  @override
  State<FadingScrollView> createState() => _FadingScrollViewState();
}

class _FadingScrollViewState extends State<FadingScrollView> {
  bool _atTop = true;
  bool _atBottom = true;

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    if (!m.hasContentDimensions || m.axis != Axis.vertical) return false;
    final atTop = m.extentBefore <= 1;
    final atBottom = m.extentAfter <= 1;
    if (atTop != _atTop || atBottom != _atBottom) {
      setState(() {
        _atTop = atTop;
        _atBottom = atBottom;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final listener = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );

    // Nothing is clipped, so skip the shader layer entirely.
    if (_atTop && _atBottom) return listener;

    final e = widget.fadeExtent;
    return ShaderMask(
      // dstIn keeps the child's colour and takes alpha from the gradient.
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final fade = (e / bounds.height).clamp(0.0, 0.5);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(_atTop ? 0xFFFFFFFF : 0x00FFFFFF),
            const Color(0xFFFFFFFF),
            const Color(0xFFFFFFFF),
            Color(_atBottom ? 0xFFFFFFFF : 0x00FFFFFF),
          ],
          stops: [0.0, fade, 1.0 - fade, 1.0],
        ).createShader(bounds);
      },
      child: listener,
    );
  }
}
