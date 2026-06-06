import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../providers/app_state.dart';
import '../services/sos_service.dart';

class SosActiveScreen extends StatefulWidget {
  const SosActiveScreen({super.key});

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen>
    with TickerProviderStateMixin {
  // ── elapsed SOS timer ──────────────────────────────────────────────────────
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  int _completedStepCount = 1;
  static const int _totalSteps = 6;

  // ── cancel hold ────────────────────────────────────────────────────────────
  static const int _cancelHoldMs = 1300; // 1.3 seconds
  late final AnimationController _cancelController;
  bool _isCancelHolding = false;
  bool _isCancelling = false; // guard against double-pop

  @override
  void initState() {
    super.initState();

    // Elapsed timer
    final triggeredAt =
        context.read<AppState>().sosTriggeredAt ?? DateTime.now();
    _elapsed = DateTime.now().difference(triggeredAt);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final activeAt = context.read<AppState>().sosTriggeredAt ?? triggeredAt;
      setState(() {
        _elapsed = DateTime.now().difference(activeAt);
        if (_completedStepCount < _totalSteps) _completedStepCount++;
      });
    });

    // Cancel hold controller
    _cancelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _cancelHoldMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _executeCancelSos();
      });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _cancelController.dispose();
    super.dispose();
  }

  // ── hold handlers ──────────────────────────────────────────────────────────

  void _onHoldStart() {
    HapticFeedback.mediumImpact();
    setState(() => _isCancelHolding = true);
    _cancelController.forward(from: 0);
  }

  void _onHoldEnd() {
    if (_cancelController.isCompleted) return;
    _cancelController.stop();
    _cancelController.animateBack(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    setState(() => _isCancelHolding = false);
  }

  Future<void> _executeCancelSos() async {
    if (_isCancelling) return;
    _isCancelling = true;

    HapticFeedback.heavyImpact();
    if (!mounted) return;
    context.read<AppState>().setSosState(SosState.idle);
    unawaited(SOSService().writeRtdbSafe());
    Navigator.of(context).pop();
  }

  Future<void> _callPolice() async {
    // Testing number — replace with 100 for production
    const policeNumber = '8756391933';
    final uri = Uri.parse('tel:$policeNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final contacts = appState.emergencyContacts;
    // Show all real contacts — no static fallback
    final notifiedContacts = contacts.toList(growable: false);

    final steps = [
      'GPS Location captured',
      'SMS sent to ${notifiedContacts.isEmpty ? 'contacts' : '${notifiedContacts.length} contact${notifiedContacts.length == 1 ? '' : 's'}'}',
      'Video recording started',
      'Evidence collection active',
      'Uploading to secure server...',
      'Nearby help found (3)',
    ];

    return Scaffold(
      backgroundColor: AppColors.danger,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 28),
            Text(
              'EMERGENCY ACTIVE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
            ),
            const SizedBox(height: 18),
            // SOS pulse rings
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _ring(156, 0.10, 2),
                  _ring(138, 0.08, 1),
                  _ring(120, 0.06, 0, filled: true),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SOS',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Active since ${_elapsed.inSeconds}s',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // White bottom sheet
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F7FB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Steps
                      _SectionCard(
                        child: Column(
                          children: [
                            for (final step in steps)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    _stepDot(steps.indexOf(step) <
                                        _completedStepCount),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        step,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: steps.indexOf(step) <
                                                      _completedStepCount
                                                  ? AppColors.textPrimary
                                                  : const Color(0xFF9CA3AF),
                                              fontWeight: steps.indexOf(step) <
                                                      _completedStepCount
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Contacts
                      _SectionCard(
                        title: 'Contacts Notified',
                        child: notifiedContacts.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 16, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No emergency contacts added yet. Go to Contacts tab to add them.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: const Color(0xFF9CA3AF)),
                                    ),
                                  ),
                                ]),
                              )
                            : Column(
                                children: [
                                  for (final contact in notifiedContacts)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AppColors.primary,
                                            child: Text(
                                              contact.name.isNotEmpty
                                                  ? contact.name[0]
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(contact.name,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                const SizedBox(height: 2),
                                                Text(
                                                    contact
                                                        .formattedPhoneNumber,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD1FAE5),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text('SMS Sent',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: const Color(
                                                          0xFF16A34A),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    )),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      // Call police
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _callPolice,
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('CALL POLICE (100)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                            side: const BorderSide(
                                color: Color(0xFFB91C1C), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // hold-to-cancel button
                      _CancelHoldButton(
                        controller: _cancelController,
                        isHolding: _isCancelHolding,
                        onHoldStart: _onHoldStart,
                        onHoldEnd: _onHoldEnd,
                        holdDurationMs: _cancelHoldMs,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Widget _ring(double size, double alpha, double width, {bool filled = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Colors.white.withValues(alpha: alpha) : null,
        border: filled
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: alpha),
                width: width,
              ),
      ),
    );
  }

  Widget _stepDot(bool done) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? const Color(0xFF22C55E) : const Color(0xFFE5E7EB),
      ),
      child: Icon(
        done ? Icons.check_rounded : Icons.circle,
        color: done ? Colors.white : const Color(0xFFCBD5E1),
        size: 14,
      ),
    );
  }
}

// =============================================================================
// 3-second hold cancel button
// =============================================================================

class _CancelHoldButton extends StatelessWidget {
  final AnimationController controller;
  final bool isHolding;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final int holdDurationMs;

  const _CancelHoldButton({
    required this.controller,
    required this.isHolding,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.holdDurationMs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => onHoldStart(),
      onLongPressEnd: (_) => onHoldEnd(),
      onLongPressCancel: onHoldEnd,
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Hold for 1.3 seconds to cancel SOS'),
            duration: Duration(seconds: 2),
          ));
      },
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final progress = controller.value;
          final secondsLeft = ((holdDurationMs / 1000) * (1 - progress)).ceil();

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: 68,
            decoration: BoxDecoration(
              color:
                  isHolding ? const Color(0xFFFFE4E4) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHolding
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFFB91C1C).withValues(alpha: 0.45),
                width: isHolding ? 2 : 1.5,
              ),
              boxShadow: isHolding
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB91C1C).withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Arc progress ring
                if (progress > 0)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: CustomPaint(
                        painter: _ArcPainter(
                          progress: progress,
                          color: const Color(0xFFB91C1C),
                          strokeWidth: 3.5,
                        ),
                      ),
                    ),
                  ),
                // Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isHolding
                            ? Icons.hourglass_top_rounded
                            : Icons.cancel_outlined,
                        key: ValueKey(isHolding),
                        color: const Color(0xFFB91C1C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CANCEL SOS',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 1.2,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            isHolding
                                ? 'Releasing in ${secondsLeft}s…'
                                : 'Hold for 1.3 seconds',
                            key: ValueKey(
                                isHolding ? 'hold_$secondsLeft' : 'idle'),
                            style: TextStyle(
                              color: const Color(0xFFB91C1C)
                                  .withValues(alpha: 0.72),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Arc progress painter
// =============================================================================

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Track
    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Filled arc — starts from top (-π/2), sweeps clockwise
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// =============================================================================
// Section card
// =============================================================================

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
          ],
          child,
        ],
      ),
    );
  }
}
