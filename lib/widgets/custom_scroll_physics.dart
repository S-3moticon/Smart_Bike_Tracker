import 'package:flutter/material.dart';

class CustomScrollPhysics extends ScrollPhysics {
  const CustomScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // When at the top and scrolling up, or at the bottom and scrolling down,
    // allow the parent to handle the scroll
    if ((position.pixels <= position.minScrollExtent && offset < 0) ||
        (position.pixels >= position.maxScrollExtent && offset > 0)) {
      return 0.0; // Let parent handle the scroll
    }
    return offset;
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Always accept user input
    return true;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Don't apply boundary conditions when at edges
    // This allows the parent scroll view to take over
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return 0.0; // At top, scrolling up - let parent handle
    }
    if (value > position.pixels && position.pixels >= position.maxScrollExtent) {
      return 0.0; // At bottom, scrolling down - let parent handle
    }
    
    // Apply normal boundary conditions
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }
}