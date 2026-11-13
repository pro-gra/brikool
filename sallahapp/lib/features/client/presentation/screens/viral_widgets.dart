import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';

/// ==================================================================
/// 1) BRANDED SHARE CARD — a beautiful screenshot-ready card + a
///    WhatsApp-ready text copied in one tap.
/// ==================================================================
void showShareCardDialog(
  BuildContext context, {
  required String serviceLabel,
  required String techName,
  required double priceMad,
  required double rating,
  String city = '',
}) {
  final shareText =
      '✅ $serviceLabel réparé via SALLAH صلاح\n👨‍🔧 $techName ($rating★)\n💰 ${priceMad.toStringAsFixed(0)} MAD, prix négocié\n${city.isEmpty ? '' : '📍 $city\n'}👉 Téléchargez SALLAH pour tous vos dépannages !';

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The card itself — designed to be screenshotted.
          Container(
            width: 300,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('SALLAH صلاح',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark)),
                    ),
                    const Spacer(),
                    const Icon(Icons.verified_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('✅', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(serviceLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('par $techName · ${rating.toStringAsFixed(1)} ★',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('${priceMad.toStringAsFixed(0)} MAD',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const SizedBox(height: 6),
                const Text('prix négocié, sans surprise',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 14),
                Text(
                    city.isEmpty
                        ? 'sallah.ma — dépannage au Maroc 🇲🇦'
                        : '📍 $city · sallah.ma 🇲🇦',
                    style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: const Color(0xFF25D366)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shareText));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Message copié ✓ — collez-le dans WhatsApp !')));
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copier pour WhatsApp'),
              ),
              const SizedBox(width: 10),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer',
                      style: TextStyle(color: Colors.white))),
            ],
          ),
        ],
      ),
    ),
  );
}

/// ==================================================================
/// 2) LIVE TRACKING SHARE — WhatsApp-ready status text.
/// ==================================================================
void shareTracking(
  BuildContext context, {
  required String techName,
  required String serviceLabel,
  required String status,
}) {
  final statusLabel = switch (status) {
    'accepted' => 'a accepté ma demande',
    'en_route' => 'est en route vers moi 🚗',
    'in_progress' => 'travaille en ce moment 🔧',
    _ => 's\'occupe de ma demande',
  };
  final text =
      '🔔 Suivi SALLAH: $techName $statusLabel\n🛠 $serviceLabel\nJe vous tiens au courant ! (app SALLAH صلاح 🇲🇦)';
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Suivi copié ✓ — partagez-le à vos proches !')));
}

/// ==================================================================
/// 3) REWARD WHEEL — spins after rating; credits land on the profile.
/// ==================================================================
Future<void> showRewardWheel(BuildContext context, String uid) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RewardWheelDialog(uid: uid),
  );
}

class _RewardWheelDialog extends StatefulWidget {
  const _RewardWheelDialog({required this.uid});
  final String uid;

  @override
  State<_RewardWheelDialog> createState() => _RewardWheelDialogState();
}

class _RewardWheelDialogState extends State<_RewardWheelDialog>
    with SingleTickerProviderStateMixin {
  static const _prizes = [5, 10, 5, 20, 10, 30, 5, 15];
  static const _colors = [
    Color(0xFF0E7C66),
    Color(0xFF12A184),
    Color(0xFF0E7C66),
    Color(0xFFC9A227),
    Color(0xFF12A184),
    Color(0xFFB3541E),
    Color(0xFF0E7C66),
    Color(0xFF12A184),
  ];

  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400));
  late final int _targetIndex = Random().nextInt(_prizes.length);
  bool _spun = false;
  bool _done = false;
  bool _saving = false;

  double get _finalAngle =>
      2 * pi * 5 + (2 * pi) * (1 - (_targetIndex + 0.5) / _prizes.length);

  Future<void> _spin() async {
    setState(() => _spun = true);
    await _controller.animateTo(1, curve: Curves.easeOutQuart);
    setState(() => _done = true);
  }

  Future<void> _claim() async {
    setState(() => _saving = true);
    try {
      await FirestoreService()
          .addClientCredit(widget.uid, _prizes[_targetIndex].toDouble());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '+${_prizes[_targetIndex]} MAD de crédit SALLAH ajoutés 🎉')));
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_done ? '🎉 Bravo !' : 'Merci pour votre avis !',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                _done
                    ? 'Vous gagnez ${_prizes[_targetIndex]} MAD de crédit'
                    : 'Tournez la roue et gagnez un crédit 🎁',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Transform.rotate(
                      angle: _finalAngle *
                          Curves.easeOutQuart.transform(_controller.value),
                      child: child,
                    ),
                    child: CustomPaint(
                      size: const Size(220, 220),
                      painter: _WheelPainter(
                          prizes: _prizes, colors: _colors),
                    ),
                  ),
                  // center cap
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.card_giftcard_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  // pointer
                  const Positioned(
                    top: -2,
                    child: Icon(Icons.arrow_drop_down_rounded,
                        size: 44, color: AppColors.danger),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : !_spun
                        ? _spin
                        : _done
                            ? _claim
                            : null,
                child: Text(_saving
                    ? '…'
                    : !_spun
                        ? 'Tourner la roue 🎰'
                        : _done
                            ? 'Récupérer mes ${_prizes[_targetIndex]} MAD'
                            : '…'),
              ),
            ),
            if (!_spun)
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Non merci',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted))),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.prizes, required this.colors});
  final List<int> prizes;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segment = 2 * pi / prizes.length;

    for (var i = 0; i < prizes.length; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      final startAngle = -pi / 2 + i * segment;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, segment, true, paint);

      // label
      final labelAngle = startAngle + segment / 2;
      final labelOffset = Offset(
        center.dx + cos(labelAngle) * radius * 0.65,
        center.dy + sin(labelAngle) * radius * 0.65,
      );
      final textPainter = TextPainter(
        text: TextSpan(
            text: '${prizes[i]}',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
          canvas,
          labelOffset -
              Offset(textPainter.width / 2, textPainter.height / 2));
    }

    // rim
    canvas.drawCircle(
        center,
        radius - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}