import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../client/presentation/bloc/language_cubit.dart';
class PlannedOrdersScreen extends StatelessWidget {
  const PlannedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return const SizedBox.shrink();

    final fs = FirestoreService();
    final t = context.watch<LanguageCubit>().state.t;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('planned_orders')),
        backgroundColor: AppColors.background,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.streamPlannedOrdersForTechnician(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${t('error')}: ${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final orders = snapshot.data!;

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFeef2ef),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 36,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('no_planned_orders'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('planned_orders_empty_description'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              return _PlannedOrderCard(
                order: orders[i],
                techId: uid,
                fs: fs,
              );
            },
          );
        },
      ),
    );
  }
}

class _PlannedOrderCard extends StatefulWidget {
  const _PlannedOrderCard({
    required this.order,
    required this.techId,
    required this.fs,
  });

  final Map<String, dynamic> order;
  final String techId;
  final FirestoreService fs;

  @override
  State<_PlannedOrderCard> createState() => _PlannedOrderCardState();
}

class _PlannedOrderCardState extends State<_PlannedOrderCard> {
  bool _working = false;
  bool _cancelling = false;
  bool _showQr = false;

  Timer? _timer;

  Map<String, dynamic> get order => widget.order;

  Timestamp? get scheduledAt => order['scheduledAt'] as Timestamp?;

  bool get canReveal =>
      FirestoreService.canRevealPlannedOrderCode(order);

  Duration get timeUntil {
    if (scheduledAt == null) return Duration.zero;

    return scheduledAt!.toDate().difference(DateTime.now());
  }

  String _countdownText(String Function(String) t) {
    final d = timeUntil;

    if (d.isNegative) {
      return t('past_time');
    }

    if (d.inDays > 0) {
      final h = d.inHours % 24;

      return t('in_days_hours')
          .replaceFirst('{days}', d.inDays.toString())
          .replaceFirst('{hours}', h.toString());
    }

    if (d.inHours > 0) {
      final m = d.inMinutes % 60;

      return t('in_hours_minutes')
          .replaceFirst('{hours}', d.inHours.toString())
          .replaceFirst(
            '{minutes}',
            m.toString().padLeft(2, '0'),
          );
    }

    if (d.inMinutes > 0) {
      final s = d.inSeconds % 60;

      return t('in_minutes_seconds')
          .replaceFirst('{minutes}', d.inMinutes.toString())
          .replaceFirst(
            '{seconds}',
            s.toString().padLeft(2, '0'),
          );
    }

    return t('in_seconds').replaceFirst(
      '{seconds}',
      d.inSeconds.toString(),
    );
  }

  Color get countdownColor {
    final d = timeUntil;

    if (d.isNegative) {
      return AppColors.danger;
    }

    if (d.inHours < 3) {
      return AppColors.gold;
    }

    return AppColors.success;
  }

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _goEnRoute() async {
    final t = context.read<LanguageCubit>().state.t;

    setState(() => _working = true);

    try {
      await widget.fs.techGoEnRoutePlanned(
        requestId: order['requestId'] as String,
        techId: widget.techId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('en_route_client_notified'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _cancel() async {
    final t = context.read<LanguageCubit>().state.t;

    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          t('cancel_order'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('client_will_be_notified'),
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: t('cancel_reason_hint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t('back'),
            ),
          ),
          TextButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;

              Navigator.pop(ctx, true);
            },
            child: Text(
              t('confirm'),
              style: const TextStyle(
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reason = reasonCtrl.text.trim();

    if (reason.isEmpty) return;

    setState(() => _cancelling = true);

    try {
      await widget.fs.techCancelRequest(
        requestId: order['requestId'] as String,
        techId: widget.techId,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('order_cancelled'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
            ),
          ),
        );

        setState(() => _cancelling = false);
      }
    } finally {
      reasonCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;

    final label =
        order['serviceLabel'] as String? ?? t('service');

    final clientName =
        order['clientName'] as String? ?? t('client');

    final price =
        (order['priceQuoteMAD'] as num?)?.toDouble() ?? 0;

    final otp =
        order['otpCode'] as String? ?? '----';

    final scheduled = scheduledAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(
            scheduledAt!.toDate(),
          )
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canReveal
              ? AppColors.gold.withOpacity(0.6)
              : AppColors.border,
          width: canReveal ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: canReveal
                  ? const Color(0xFFfbf3e3)
                  : AppColors.primaryLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: canReveal
                        ? AppColors.gold
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    canReveal
                        ? Icons.access_time_filled_rounded
                        : Icons.event_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        scheduled,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: countdownColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _countdownText(t),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: countdownColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${price.toStringAsFixed(0)} MAD',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (canReveal) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFfbf3e3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_open_rounded,
                              size: 16,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t('three_hour_window_open'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            setState(
                              () => _showQr = !_showQr,
                            );
                          },
                          child: Column(
                            children: [
                              if (_showQr) ...[
                                QrImageView(
                                  data: otp,
                                  version: QrVersions.auto,
                                  size: 160,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  otp,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ] else
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.qr_code_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        t('show_qr_otp'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _working ? null : _goEnRoute,
                      icon: _working
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.directions_car_rounded,
                              size: 18,
                            ),
                      label: Text(
                        t('i_am_on_my_way'),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFeef2ef),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t('qr_otp_available_before'),
                            style: const TextStyle(
                              fontSize: 12,
                              color:
                                  AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        (_cancelling || _working)
                            ? null
                            : _cancel,
                    icon: const Icon(
                      Icons.cancel_outlined,
                      size: 16,
                    ),
                    label: Text(
                      t('cancel_this_order'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}