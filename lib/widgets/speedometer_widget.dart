import 'package:flutter/material.dart';
import 'dart:math' as math;

class SpeedometerWidget extends StatefulWidget {
  final double speed; // Speed in km/h
  final bool isVisible;
  final String source; // 'phone' or 'mcu'
  
  const SpeedometerWidget({
    super.key,
    required this.speed,
    this.isVisible = true,
    this.source = 'phone',
  });
  
  @override
  State<SpeedometerWidget> createState() => _SpeedometerWidgetState();
}

class _SpeedometerWidgetState extends State<SpeedometerWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _speedAnimation;
  double _previousSpeed = 0.0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _speedAnimation = Tween<double>(
      begin: 0.0,
      end: widget.speed,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    _animationController.forward();
  }
  
  @override
  void didUpdateWidget(SpeedometerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _speedAnimation = Tween<double>(
        begin: _previousSpeed,
        end: widget.speed,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ));
      _previousSpeed = widget.speed;
      _animationController.forward(from: 0.0);
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Color _getSpeedColor(double speed) {
    if (speed == 0) {
      return Colors.grey;
    } else if (speed < 10) {
      return Colors.blue;
    } else if (speed < 30) {
      return Colors.green;
    } else if (speed < 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _speedAnimation,
      builder: (context, child) {
        final animatedSpeed = _speedAnimation.value;
        final speedColor = _getSpeedColor(animatedSpeed);
        
        return Container(
          width: 85,
          height: 85,
          decoration: BoxDecoration(
            color: isDark 
              ? Colors.black.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(
              color: speedColor.withValues(alpha: 0.5),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: speedColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle indicator
              CustomPaint(
                size: const Size(85, 85),
                painter: _SpeedIndicatorPainter(
                  speed: animatedSpeed,
                  maxSpeed: 100.0,
                  color: speedColor,
                ),
              ),
              
              // Speed value and unit
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Speed value
                  Text(
                    animatedSpeed.toStringAsFixed(animatedSpeed >= 10 ? 0 : 1),
                    style: TextStyle(
                      fontSize: animatedSpeed >= 100 ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: speedColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Unit
                  Text(
                    'km/h',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark 
                        ? Colors.grey[400]
                        : Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Source indicator (small icon)
                  if (widget.source == 'mcu')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.satellite_alt,
                        size: 10,
                        color: Colors.orange.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Custom painter for speed indicator arc
class _SpeedIndicatorPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color color;
  
  _SpeedIndicatorPainter({
    required this.speed,
    required this.maxSpeed,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    
    // Draw background arc
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 1.25,
      math.pi * 1.5,
      false,
      backgroundPaint,
    );
    
    // Draw speed arc
    final speedPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final speedPercentage = math.min(speed / maxSpeed, 1.0);
    final sweepAngle = math.pi * 1.5 * speedPercentage;
    
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi * 1.25,
        sweepAngle,
        false,
        speedPaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(_SpeedIndicatorPainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.color != color;
  }
}